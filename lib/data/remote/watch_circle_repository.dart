import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/notifications/notification_service.dart';
import '../../domain/model/drama.dart';
import '../../domain/model/watch_circle_models.dart';
import '../local/settings_store.dart';

/// 100% Firestore wire-compatible port of Kotlin `WatchCircleRepository.kt`.
class WatchCircleRepository {
  static const String codeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  final SettingsStore settingsStore;
  final NotificationService notificationService;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;
  Future<(List<FriendProfile>, List<CircleNudge>)>? _inFlightFetch;

  WatchCircleRepository({
    required this.settingsStore,
    required this.notificationService,
  });

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseAuth? get _auth => isFirebaseReady ? FirebaseAuth.instance : null;
  FirebaseFirestore? get _firestore =>
      isFirebaseReady ? FirebaseFirestore.instance : null;

  /// Legacy deterministic 6-char invite code (exact SHA-256 algorithm parity).
  static String generateInviteCode(String uid) {
    if (uid.trim().isEmpty) return '';
    final digest = sha256.convert(utf8.encode('moglog-circle-v1:$uid')).bytes;
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      final index = (digest[i] & 0xFF) % codeAlphabet.length;
      sb.write(codeAlphabet[index]);
    }
    return sb.toString();
  }

  /// CSPRNG 6-character invite code.
  static String generateRandomInviteCode() {
    final rng = Random.secure();
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      sb.write(codeAlphabet[rng.nextInt(codeAlphabet.length)]);
    }
    return sb.toString();
  }

  static String normalizeInviteCode(String input) {
    var clean = input.trim().toUpperCase();
    if (clean.startsWith('MOG-')) {
      clean = clean.substring(4);
    }
    clean = clean.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return clean.length > 6 ? clean.substring(0, 6) : clean;
  }

  /// Smart clipboard extractor supporting `CODE: XXXXXX`, `MOG-XXXXXX`, or standalone 6-char code.
  static String? extractCodeFromClipboard(String rawText) {
    final upper = rawText.toUpperCase();
    final prefixed = RegExp(r'(?:CODE[:\s]+|MOG-)([A-Z0-9]{6})').firstMatch(upper);
    if (prefixed != null) return prefixed.group(1);
    final standalone = RegExp(r'\b([23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6})\b').firstMatch(upper);
    return standalone?.group(1);
  }

  String getMyInviteCode() {
    final uid = _auth?.currentUser?.uid ?? '';
    if (uid.isEmpty) return '';
    final custom = settingsStore.state.customInviteCode.trim();
    if (custom.length == 6) return custom;
    return generateInviteCode(uid);
  }

  Future<String> rotateMyInviteCode(List<Drama> myDramas) async {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null) {
      throw StateError('Sign in with Google to rotate your Circle Code.');
    }
    final uid = user.uid;
    final oldCode = getMyInviteCode();
    var newCode = generateRandomInviteCode();
    var attempts = 0;
    while (attempts < 5) {
      if (newCode != oldCode) {
        final exists = (await fs.collection('invite_codes').doc(newCode).get()).exists;
        if (!exists) break;
      }
      newCode = generateRandomInviteCode();
      attempts++;
    }
    await settingsStore.setCustomInviteCode(newCode);
    if (oldCode.isNotEmpty && oldCode != newCode) {
      try {
        await fs.collection('invite_codes').doc(oldCode).delete();
      } catch (_) {}
    }
    await fs.collection('users').doc(uid).set(
      {
        'customInviteCode': newCode,
        'lastSyncedAt': DateTime.now().millisecondsSinceEpoch,
      },
      SetOptions(merge: true),
    );
    await publishMyActivity(myDramas);
    return newCode;
  }

  Future<void> publishMyActivity(List<Drama> dramas) async {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return;

    final uid = user.uid;
    final now = DateTime.now().millisecondsSinceEpoch;
    var settings = settingsStore.state;
    var inviteCode = settings.customInviteCode.trim();

    if (inviteCode.length != 6) {
      try {
        final existing = await fs.collection('social_profiles').doc(uid).get();
        final remoteCode = (existing.data()?['inviteCode'] as String?)?.trim() ?? '';
        inviteCode = remoteCode.length == 6 ? remoteCode : generateRandomInviteCode();
      } catch (_) {
        inviteCode = generateInviteCode(uid);
      }
      if (inviteCode.length == 6) {
        await settingsStore.setCustomInviteCode(inviteCode);
        settings = settingsStore.state;
      }
    }

    final displayName = settings.customDisplayName.trim().isNotEmpty
        ? settings.customDisplayName.trim()
        : ((user.displayName ?? '').trim().isNotEmpty
            ? user.displayName!.trim()
            : 'Moglog User');
    final photoUrl = user.photoURL ?? '';
    final photoBase64 = settings.customProfileImageBase64.length <= 120000
        ? settings.customProfileImageBase64
        : '';
    final sharingEnabled = settings.watchCircleSharingEnabled;
    final hiddenIds = settings.hiddenFromCircleDramaIds;

    final active = dramas
        .where((d) => !d.isDeleted && !hiddenIds.contains(d.id))
        .toList();

    final genreCounts = <String, int>{};
    for (final d in active) {
      for (final g in d.genreList) {
        genreCounts[g] = (genreCounts[g] ?? 0) + 1;
      }
    }
    final topGenres = (genreCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => e.key)
        .toList();

    Map<String, dynamic> toSharedMap(Drama d) => {
          'id': d.id,
          'title': d.title.length > 160 ? d.title.substring(0, 160) : d.title,
          'posterPath':
              d.posterPath.length > 300 ? d.posterPath.substring(0, 300) : d.posterPath,
          'status': d.status,
          'episodesWatched': d.episodesWatched,
          'totalEpisodes': d.totalEpisodes,
          'rating': d.rating,
          'myRating': d.myRating,
          'genres': d.genres.length > 200 ? d.genres.substring(0, 200) : d.genres,
          'updatedAt': d.updatedAt,
        };

    final watchingList = sharingEnabled
        ? (active.where((d) => d.status == 'Watching').toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
            .take(15)
            .map(toSharedMap)
            .toList()
        : const <Map<String, dynamic>>[];

    final completedList = sharingEnabled
        ? (active.where((d) => d.status == 'Done').toList()
              ..sort((a, b) {
                final rCmp = b.myRating.compareTo(a.myRating);
                return rCmp != 0 ? rCmp : b.completedAt.compareTo(a.completedAt);
              }))
            .take(15)
            .map(toSharedMap)
            .toList()
        : const <Map<String, dynamic>>[];

    final plannedList = sharingEnabled
        ? (active.where((d) => d.status == 'Planned').toList()
              ..sort((a, b) => b.addedAt.compareTo(a.addedAt)))
            .take(10)
            .map(toSharedMap)
            .toList()
        : const <Map<String, dynamic>>[];

    final activeMap = {for (final d in active) d.id: d};
    final topFourList = sharingEnabled
        ? settings.topFourFavoriteIds
            .map((id) => activeMap[id])
            .whereType<Drama>()
            .take(4)
            .map(toSharedMap)
            .toList()
        : const <Map<String, dynamic>>[];

    final totalWatchedCount =
        sharingEnabled ? active.where((d) => d.status == 'Done').length : 0;
    final totalEpisodesCount = sharingEnabled
        ? active.fold<int>(0, (acc, d) => acc + d.episodesWatched)
        : 0;

    try {
      final batch = fs.batch();
      batch.set(
        fs.collection('social_profiles').doc(uid),
        {
          'uid': uid,
          'inviteCode': inviteCode,
          'displayName': displayName,
          'photoUrl': photoUrl,
          'photoBase64': photoBase64,
          'sharingEnabled': sharingEnabled,
          'updatedAt': now,
          'totalWatched': totalWatchedCount,
          'totalEpisodes': totalEpisodesCount,
          'topGenres': sharingEnabled ? topGenres : const <String>[],
          'currentlyWatching': watchingList,
          'recentlyCompleted': completedList,
          'plannedShows': plannedList,
          'topFourFavorites': topFourList,
        },
        SetOptions(merge: true),
      );
      batch.set(fs.collection('invite_codes').doc(inviteCode), {
        'uid': uid,
        'displayName': displayName,
        'updatedAt': now,
      });
      await batch.commit();
    } catch (_) {}
  }

  Future<FriendProfile> joinByInviteCode(
    String rawCode,
    List<Drama> myDramas,
  ) async {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null) {
      throw StateError('Sign in with Google to join a Watch Circle.');
    }
    final myUid = user.uid;
    final code = normalizeInviteCode(rawCode);
    if (code.length != 6) {
      throw ArgumentError('Enter a valid 6-character Circle Code.');
    }
    final myCode = getMyInviteCode();
    if (code == myCode || code == generateInviteCode(myUid)) {
      throw ArgumentError(
        "That's your own Watch Circle code! Share it with a friend.",
      );
    }

    await publishMyActivity(myDramas);
    final codeSnap = await fs.collection('invite_codes').doc(code).get();
    if (!codeSnap.exists) {
      throw ArgumentError('No user found with Circle Code "$code".');
    }

    final friendUid = (codeSnap.data()?['uid'] as String?) ?? '';
    if (friendUid.isEmpty || friendUid == myUid) {
      throw ArgumentError('Invalid Circle Code.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await fs
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid)
        .set({'uid': friendUid, 'addedAt': now});

    try {
      await fs
          .collection('social_profiles')
          .doc(friendUid)
          .collection('circle_members')
          .doc(myUid)
          .set({'uid': myUid, 'addedAt': now});
    } catch (_) {}

    final friendSnap = await fs.collection('social_profiles').doc(friendUid).get();
    return _parseFriendProfile(
      friendSnap,
      fallbackUid: friendUid,
      fallbackName: codeSnap.data()?['displayName'] as String?,
    );
  }

  Future<(List<FriendProfile>, List<CircleNudge>)> fetchWatchCircle(
    List<Drama> myDramas, {
    bool publishOwnActivity = false,
  }) async {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null) {
      return (const <FriendProfile>[], const <CircleNudge>[]);
    }

    final existing = _inFlightFetch;
    if (existing != null) {
      if (publishOwnActivity) {
        unawaited(publishMyActivity(myDramas).catchError((_) {}));
      }
      return existing;
    }

    final future = _doFetchWatchCircle(
      user.uid,
      fs,
      myDramas,
      publishOwnActivity: publishOwnActivity,
    );
    _inFlightFetch = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightFetch, future)) {
        _inFlightFetch = null;
      }
    }
  }

  Future<(List<FriendProfile>, List<CircleNudge>)> _doFetchWatchCircle(
    String myUid,
    FirebaseFirestore fs,
    List<Drama> myDramas, {
    required bool publishOwnActivity,
  }) async {
    final Future<void>? publishFuture = publishOwnActivity
        ? publishMyActivity(myDramas).catchError((_) {})
        : null;

    final outboundFuture = fs
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .get()
        .then((s) => s.docs.map((d) => (d.data()['uid'] as String?) ?? d.id).toList())
        .catchError((_) => const <String>[]);

    final inboundFuture = fs
        .collection('social_profiles')
        .doc(myUid)
        .collection('circle_members')
        .get()
        .then((s) => s.docs.map((d) => (d.data()['uid'] as String?) ?? d.id).toList())
        .catchError((_) => const <String>[]);

    final nudgesFuture = fs
        .collection('social_profiles')
        .doc(myUid)
        .collection('nudges')
        .get()
        .then((s) {
          final list = <CircleNudge>[];
          for (final doc in s.docs) {
            final m = doc.data();
            final fromUid = m['fromUid'] as String?;
            if (fromUid == null || fromUid.isEmpty) continue;
            list.add(
              CircleNudge(
                id: doc.id,
                fromUid: fromUid,
                fromName: (m['fromName'] as String?) ?? 'Friend',
                dramaId: (m['dramaId'] as num?)?.toInt() ?? 0,
                dramaTitle: (m['dramaTitle'] as String?) ?? '',
                emoji: (m['emoji'] as String?) ?? 'ZAP',
                message: (m['message'] as String?) ?? '',
                createdAt: (m['createdAt'] as num?)?.toInt() ??
                    (m['timestamp'] as num?)?.toInt() ??
                    0,
              ),
            );
          }
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list.take(20).toList();
        })
        .catchError((_) => const <CircleNudge>[]);

    final outbound = await outboundFuture;
    final inbound = await inboundFuture;
    final friendUids = {...outbound, ...inbound}
        .where((id) => id.trim().isNotEmpty && id != myUid)
        .toList();

    final profileFutures = friendUids.map((fUid) async {
      try {
        final snap = await fs.collection('social_profiles').doc(fUid).get();
        if (!snap.exists) return null;
        return _parseFriendProfile(snap, fallbackUid: fUid);
      } catch (_) {
        return null;
      }
    });
    final profiles = (await Future.wait(profileFutures))
        .whereType<FriendProfile>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Notify on newly connected friends
    final initialized = settingsStore.isKnownFriendsInitialized(myUid);
    final known = settingsStore.getKnownFriends(myUid);
    if (initialized) {
      for (final newUid in friendUids.where((u) => !known.contains(u))) {
        final name = profiles
                .where((p) => p.uid == newUid)
                .map((p) => p.displayName)
                .firstOrNull ??
            'A friend';
        await notificationService.showFriendAddedNotification(
          friendName: name,
          friendUid: newUid,
        );
      }
    }
    await settingsStore.saveKnownFriends(myUid, {...known, ...friendUids});
    await settingsStore.saveCachedCircleFriends(myUid, profiles);
    if (publishFuture != null) {
      await publishFuture;
    }

    return (profiles, await nudgesFuture);
  }

  void startListeningForCircleMembers({void Function()? onMemberChanged}) {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null || _membersSub != null) return;
    final myUid = user.uid;

    _membersSub = fs
        .collection('social_profiles')
        .doc(myUid)
        .collection('circle_members')
        .snapshots()
        .listen((snap) async {
      final initialized = settingsStore.isKnownFriendsInitialized(myUid);
      final known = settingsStore.getKnownFriends(myUid);
      var changed = false;
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.removed) {
          changed = true;
        }
        if (change.type == DocumentChangeType.added) {
          final fUid = change.doc.id;
          if (fUid.isNotEmpty && fUid != myUid && !known.contains(fUid)) {
            if (initialized) {
              try {
                final fSnap = await fs.collection('social_profiles').doc(fUid).get();
                final name = (fSnap.data()?['displayName'] as String?) ?? 'A friend';
                await notificationService.showFriendAddedNotification(
                  friendName: name,
                  friendUid: fUid,
                );
                await settingsStore.saveKnownFriends(
                  myUid,
                  {...settingsStore.getKnownFriends(myUid), fUid},
                );
              } catch (_) {}
            }
          }
        }
      }
      if (changed && onMemberChanged != null) {
        onMemberChanged();
      }
    });
  }

  void stopListeningForCircleMembers() {
    _membersSub?.cancel();
    _membersSub = null;
  }

  Future<void> removeFriend(String friendUid) async {
    final myUid = _auth?.currentUser?.uid;
    final fs = _firestore;
    if (myUid == null || fs == null) return;
    try {
      await fs.collection('users').doc(myUid).collection('friends').doc(friendUid).delete();
    } catch (_) {}
    try {
      await fs
          .collection('social_profiles')
          .doc(myUid)
          .collection('circle_members')
          .doc(friendUid)
          .delete();
    } catch (_) {}
    try {
      await fs
          .collection('social_profiles')
          .doc(friendUid)
          .collection('circle_members')
          .doc(myUid)
          .delete();
    } catch (_) {}
  }

  Future<bool> sendNudge({
    required String toUid,
    required int dramaId,
    required String dramaTitle,
    required String emoji,
    required String message,
  }) async {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null) return false;
    final s = settingsStore.state;
    final myName = s.customDisplayName.trim().isNotEmpty
        ? s.customDisplayName.trim()
        : ((user.displayName ?? '').trim().isNotEmpty
            ? user.displayName!.trim()
            : 'Friend');
    try {
      await fs.collection('social_profiles').doc(toUid).collection('nudges').add({
        'fromUid': user.uid,
        'fromName': myName.length > 60 ? myName.substring(0, 60) : myName,
        'dramaId': dramaId,
        'dramaTitle': dramaTitle.length > 120 ? dramaTitle.substring(0, 120) : dramaTitle,
        'emoji': emoji.length > 8 ? emoji.substring(0, 8) : emoji,
        'message': message.length > 140 ? message.substring(0, 140) : message,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismissNudge(String nudgeId) async {
    final myUid = _auth?.currentUser?.uid;
    final fs = _firestore;
    if (myUid == null || fs == null) return;
    try {
      await fs
          .collection('social_profiles')
          .doc(myUid)
          .collection('nudges')
          .doc(nudgeId)
          .delete();
    } catch (_) {}
  }

  FriendProfile _parseFriendProfile(
    DocumentSnapshot<Map<String, dynamic>> snap, {
    required String fallbackUid,
    String? fallbackName,
  }) {
    final data = snap.data() ?? const {};
    List<SharedShowItem> parseList(String field, [String? fallbackField]) {
      final raw = data[field] ?? (fallbackField != null ? data[fallbackField] : null);
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SharedShowItem.fromMap)
          .where((s) => s.id > 0 && s.title.isNotEmpty)
          .toList();
    }

    final uid = (data['uid'] as String?) ?? fallbackUid;
    return FriendProfile(
      uid: uid,
      inviteCode: (data['inviteCode'] as String?) ?? generateInviteCode(uid),
      displayName: (data['displayName'] as String?) ?? fallbackName ?? 'Moglog Friend',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      photoBase64: (data['photoBase64'] as String?) ?? '',
      sharingEnabled: (data['sharingEnabled'] as bool?) ?? true,
      updatedAt: (data['updatedAt'] as num?)?.toInt() ?? 0,
      totalWatched: (data['totalWatched'] as num?)?.toInt() ?? 0,
      totalEpisodes: (data['totalEpisodes'] as num?)?.toInt() ?? 0,
      topGenres: (data['topGenres'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      currentlyWatching: parseList('currentlyWatching'),
      recentlyCompleted: parseList('recentlyCompleted'),
      plannedShows: parseList('plannedShows', 'recentlyPlanned'),
      topFourFavorites: parseList('topFourFavorites'),
    );
  }
}
