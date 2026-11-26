import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/security/backup_crypto_envelope.dart';
import '../../core/security/secure_store.dart';
import '../../domain/model/drama.dart';
import '../local/settings_store.dart';

class CloudData {
  final List<Drama> dramas;
  const CloudData({required this.dramas});
}

/// 100% Firestore wire-compatible port of Kotlin `CloudSyncRepository.kt`.
/// Safely degrades when Firebase has not yet been configured for this flavor.
class CloudSyncRepository {
  static const int maxChunkChars = 240000;

  final SecureStore secureStore;
  final SettingsStore settingsStore;
  int _lastLocalSyncTimestamp = 0;

  CloudSyncRepository({
    required this.secureStore,
    required this.settingsStore,
  });

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _auth => isFirebaseReady ? FirebaseAuth.instance : null;
  FirebaseFirestore? get _firestore =>
      isFirebaseReady ? FirebaseFirestore.instance : null;

  bool isSignedIn() => _auth?.currentUser != null;
  User? get currentUser => _auth?.currentUser;

  static List<Drama> parseDramasFromJson(String jsonStr) {
    final trimmed = jsonStr.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(Drama.fromJson)
            .toList();
      }
      if (decoded is Map<String, dynamic> && decoded['dramas'] is List) {
        return (decoded['dramas'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Drama.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static List<String> chunkString(String input, int chunkSize) {
    if (input.isEmpty) return [''];
    final chunks = <String>[];
    for (var i = 0; i < input.length; i += chunkSize) {
      final end = (i + chunkSize < input.length) ? i + chunkSize : input.length;
      chunks.add(input.substring(i, end));
    }
    return chunks;
  }

  Future<bool> checkCloudHasShows() async {
    if (!isSignedIn()) return false;
    try {
      final cloud = await fetchFromCloud();
      return cloud != null && cloud.dramas.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkAccountExists(String uid) async {
    final fs = _firestore;
    if (fs == null) return false;
    try {
      final snap = await fs.collection('users').doc(uid).get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncToCloud(List<Drama> dramas) async {
    final user = currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return;

    final uid = user.uid;
    final now = DateTime.now().millisecondsSinceEpoch;
    final settings = settingsStore.state;
    final passphrase = secureStore.getBackupPassphrase();
    final useE2e = settings.encryptedCloudBackupEnabled && passphrase.trim().isNotEmpty;

    final userDocRef = fs.collection('users').doc(uid);
    final backupColl = userDocRef.collection('backup');
    _lastLocalSyncTimestamp = now;
    await settingsStore.setLastSyncedAt(now);

    QuerySnapshot<Map<String, dynamic>>? existingSnap;
    try {
      existingSnap = await backupColl.get();
    } catch (_) {
      if (dramas.isEmpty) {
        // Fail safe on transient read errors: abort rather than risking an empty overwrite
        return;
      }
    }
    if (dramas.isEmpty && existingSnap != null && existingSnap.docs.isNotEmpty) {
      // Safety guard: never overwrite existing non-empty cloud backup with 0 shows
      return;
    }

    final jsonPayload = jsonEncode(dramas.map((d) => d.toJson()).toList());
    final batch = fs.batch();

    if (useE2e) {
      final envelope = await BackupCryptoEnvelope.encrypt(
        plaintextJson: jsonPayload,
        passphrase: passphrase,
        uid: uid,
      );
      final chunks = chunkString(envelope.ciphertext, maxChunkChars);
      final activeIds = <String>{};
      for (var idx = 0; idx < chunks.length; idx++) {
        final docId = 'chunk_$idx';
        activeIds.add(docId);
        batch.set(backupColl.doc(docId), {
          'index': idx,
          'totalChunks': chunks.length,
          'encrypted': true,
          'format': envelope.format,
          'schemaVersion': envelope.schemaVersion,
          'kdf': envelope.kdf,
          'kdfIterations': envelope.kdfIterations,
          'salt': envelope.salt,
          'iv': envelope.iv,
          'ciphertextChunk': chunks[idx],
          'updatedAt': now,
        });
      }
      if (existingSnap != null) {
        for (final doc in existingSnap.docs) {
          if (!activeIds.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }
      } else {
        for (var extra = chunks.length; extra <= chunks.length + 5; extra++) {
          batch.delete(backupColl.doc('chunk_$extra'));
        }
      }
      batch.set(
        userDocRef,
        _buildRootMetadata(
          encryptedBackup: true,
          backupChunks: chunks.length,
          now: now,
        ),
        SetOptions(merge: true),
      );
      await batch.commit();
    } else {
      final chunks = chunkString(jsonPayload, maxChunkChars);
      final activeIds = <String>{};
      for (var idx = 0; idx < chunks.length; idx++) {
        final docId = 'chunk_$idx';
        activeIds.add(docId);
        batch.set(backupColl.doc(docId), {
          'index': idx,
          'totalChunks': chunks.length,
          'encrypted': false,
          'payloadChunk': chunks[idx],
          'updatedAt': now,
        });
      }
      if (existingSnap != null) {
        for (final doc in existingSnap.docs) {
          if (!activeIds.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }
      } else {
        for (var extra = chunks.length; extra <= chunks.length + 5; extra++) {
          batch.delete(backupColl.doc('chunk_$extra'));
        }
      }
      batch.set(
        userDocRef,
        _buildRootMetadata(
          encryptedBackup: false,
          backupChunks: chunks.length,
          now: now,
        ),
        SetOptions(merge: true),
      );
      await batch.commit();
    }
  }

  Map<String, dynamic> _buildRootMetadata({
    required bool encryptedBackup,
    required int backupChunks,
    required int now,
  }) {
    final s = settingsStore.state;
    return {
      'encryptedBackup': encryptedBackup,
      'backupChunks': backupChunks,
      'lastSyncedAt': now,
      'topFourFavoriteIds': s.topFourFavoriteIds,
      'customCollections': s.customCollections,
      'dramas': FieldValue.delete(),
      'tmdbApiKey': FieldValue.delete(),
      'profileImageBase64': s.customProfileImageBase64.trim().isNotEmpty
          ? s.customProfileImageBase64
          : FieldValue.delete(),
      'customDisplayName': s.customDisplayName.trim().isNotEmpty
          ? s.customDisplayName
          : FieldValue.delete(),
      'customInviteCode': s.customInviteCode.trim().isNotEmpty
          ? s.customInviteCode
          : FieldValue.delete(),
    };
  }

  Future<CloudData?> fetchFromCloud({String? explicitPassphrase}) async {
    final user = currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return null;

    final uid = user.uid;
    final docRef = fs.collection('users').doc(uid);
    final results = await Future.wait([
      docRef.get(),
      docRef.collection('backup').get(),
    ]);
    final snapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final backupSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

    if (!snapshot.exists) return null;
    final rootData = snapshot.data() ?? const {};

    // Purge any legacy tmdbApiKey from Firestore immediately
    if (rootData.containsKey('tmdbApiKey')) {
      unawaited(
        docRef.update({'tmdbApiKey': FieldValue.delete()}).catchError((_) {}),
      );
    }

    if (rootData.containsKey('profileImageBase64')) {
      await settingsStore.setCustomProfileImageBase64(
        (rootData['profileImageBase64'] as String?) ?? '',
      );
    }
    if (rootData.containsKey('customDisplayName')) {
      await settingsStore.setCustomDisplayName(
        (rootData['customDisplayName'] as String?) ?? '',
      );
    }
    if (rootData.containsKey('customInviteCode')) {
      final code = (rootData['customInviteCode'] as String?) ?? '';
      if (code.length == 6) {
        await settingsStore.setCustomInviteCode(code);
      }
    }
    if (rootData['topFourFavoriteIds'] is List) {
      final ids = (rootData['topFourFavoriteIds'] as List)
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();
      await settingsStore.setTopFourFavorites(ids);
    }
    if (rootData['customCollections'] is List) {
      final cols = (rootData['customCollections'] as List)
          .whereType<String>()
          .toList();
      if (cols.isNotEmpty) {
        await settingsStore.setCustomCollections(cols);
      }
    }

    // 1. Subcollection `users/{uid}/backup`
    final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      backupSnap.docs,
    )..sort((a, b) {
        final ai = (a.data()['index'] as num?)?.toInt() ?? 0;
        final bi = (b.data()['index'] as num?)?.toInt() ?? 0;
        return ai.compareTo(bi);
      });

    if (sortedDocs.isNotEmpty) {
      final first = sortedDocs.first.data();
      final declaredChunks = (first['totalChunks'] as num?)?.toInt() ??
          (rootData['backupChunks'] as num?)?.toInt();
      final backupDocs = (declaredChunks != null && declaredChunks > 0)
          ? sortedDocs.where((d) {
              final idx = (d.data()['index'] as num?)?.toInt();
              return idx != null && idx >= 0 && idx < declaredChunks;
            }).toList()
          : sortedDocs;
      final isEncrypted = first['encrypted'] == true;
      if (isEncrypted) {
        final pass = (explicitPassphrase != null && explicitPassphrase.trim().isNotEmpty)
            ? explicitPassphrase
            : secureStore.getBackupPassphrase();
        if (pass.trim().isEmpty) {
          throw StateError(
            'Cloud backup is encrypted. Please set your Backup Passphrase.',
          );
        }
        final fullCiphertext = backupDocs
            .map((d) => (d.data()['ciphertextChunk'] as String?) ?? '')
            .join();
        final envelope = BackupEnvelopePayload(
          format: (first['format'] as String?) ?? BackupEnvelopePayload.formatMagic,
          schemaVersion: (first['schemaVersion'] as num?)?.toInt() ??
              BackupEnvelopePayload.currentSchemaVersion,
          kdf: (first['kdf'] as String?) ?? BackupEnvelopePayload.kdfAlgo,
          kdfIterations: (first['kdfIterations'] as num?)?.toInt() ??
              BackupEnvelopePayload.defaultIterations,
          salt: (first['salt'] as String?) ?? '',
          iv: (first['iv'] as String?) ?? '',
          ciphertext: fullCiphertext,
          uid: uid,
        );
        try {
          final decryptedJson = await BackupCryptoEnvelope.decrypt(
            envelope: envelope,
            passphrase: pass,
            expectedUid: uid,
          );
          return CloudData(dramas: parseDramasFromJson(decryptedJson));
        } catch (_) {
          throw StateError(
            'Incorrect backup passphrase or corrupted cloud backup.',
          );
        }
      } else {
        final fullJson = backupDocs
            .map((d) => (d.data()['payloadChunk'] as String?) ?? '')
            .join();
        if (fullJson.trim().isNotEmpty) {
          return CloudData(dramas: parseDramasFromJson(fullJson));
        }
      }
    }

    // 2. Legacy root `dramas` array fallback
    final dramasRaw = rootData['dramas'];
    if (dramasRaw is List) {
      final dramas = dramasRaw
          .whereType<Map<String, dynamic>>()
          .map(Drama.fromJson)
          .toList();
      return CloudData(dramas: dramas);
    }
    return const CloudData(dramas: []);
  }

  Future<void> syncProfileOnly() async {
    final user = currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = settingsStore.state;
    try {
      _lastLocalSyncTimestamp = now;
      await fs.collection('users').doc(user.uid).set(
        {
          'lastSyncedAt': now,
          'topFourFavoriteIds': s.topFourFavoriteIds,
          'customCollections': s.customCollections,
          'profileImageBase64': s.customProfileImageBase64.trim().isNotEmpty
              ? s.customProfileImageBase64
              : FieldValue.delete(),
          'customDisplayName': s.customDisplayName.trim().isNotEmpty
              ? s.customDisplayName
              : FieldValue.delete(),
          'customInviteCode': s.customInviteCode.trim().isNotEmpty
              ? s.customInviteCode
              : FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      await settingsStore.setLastSyncedAt(now);
    } catch (_) {}
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      startRealtimeSyncListener(Future<void> Function() onRemoteUpdate) {
    final user = currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return null;

    return fs.collection('users').doc(user.uid).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final remoteLastSynced = (data['lastSyncedAt'] as num?)?.toInt() ?? 0;
      final localLastSynced = settingsStore.state.lastSyncedAt;

      if (data['topFourFavoriteIds'] is List) {
        final remoteTopFour = (data['topFourFavoriteIds'] as List)
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();
        if (remoteTopFour.toString() !=
            settingsStore.state.topFourFavoriteIds.toString()) {
          await settingsStore.setTopFourFavorites(remoteTopFour);
        }
      }
      if (data['customCollections'] is List) {
        final remoteCols =
            (data['customCollections'] as List).whereType<String>().toList();
        if (remoteCols.isNotEmpty &&
            remoteCols.toString() !=
                settingsStore.state.customCollections.toString()) {
          await settingsStore.setCustomCollections(remoteCols);
        }
      }
      final remoteImg = (data['profileImageBase64'] as String?) ?? '';
      if (remoteImg != settingsStore.state.customProfileImageBase64) {
        await settingsStore.setCustomProfileImageBase64(remoteImg);
      }
      final remoteName = (data['customDisplayName'] as String?) ?? '';
      if (remoteName != settingsStore.state.customDisplayName) {
        await settingsStore.setCustomDisplayName(remoteName);
      }
      final remoteCode = (data['customInviteCode'] as String?) ?? '';
      if (remoteCode.length == 6 &&
          remoteCode != settingsStore.state.customInviteCode) {
        await settingsStore.setCustomInviteCode(remoteCode);
      }

      if (!snapshot.metadata.hasPendingWrites &&
          remoteLastSynced > 0 &&
          remoteLastSynced != _lastLocalSyncTimestamp &&
          remoteLastSynced != localLastSynced) {
        try {
          await onRemoteUpdate();
          await settingsStore.setLastSyncedAt(remoteLastSynced);
        } catch (_) {}
      }
    });
  }

  Future<int> fetchRemoteLastSyncedAt() async {
    final user = currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return 0;
    try {
      final snap = await fs.collection('users').doc(user.uid).get();
      return (snap.data()?['lastSyncedAt'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> deleteUserCloudData({required Set<String> inviteCodes}) async {
    final user = currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return;
    final uid = user.uid;

    Future<void> deleteSubcollection(
      CollectionReference<Map<String, dynamic>> coll,
    ) async {
      try {
        final snap = await coll.get();
        for (final doc in snap.docs) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }

    await deleteSubcollection(fs.collection('users').doc(uid).collection('backup'));
    await deleteSubcollection(fs.collection('users').doc(uid).collection('friends'));
    await deleteSubcollection(
      fs.collection('social_profiles').doc(uid).collection('circle_members'),
    );
    await deleteSubcollection(
      fs.collection('social_profiles').doc(uid).collection('nudges'),
    );

    for (final code in inviteCodes.where((c) => c.trim().isNotEmpty)) {
      try {
        await fs.collection('invite_codes').doc(code).delete();
      } catch (_) {}
    }
    try {
      await fs.collection('social_profiles').doc(uid).delete();
    } catch (_) {}
    await fs.collection('users').doc(uid).delete();
    await user.delete();
  }
}
