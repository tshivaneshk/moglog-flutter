import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Byte-compatible port of Kotlin `BackupEnvelopePayload` (`MOGLOG_ENC_V1`).
class BackupEnvelopePayload {
  static const String formatMagic = 'MOGLOG_ENC_V1';
  static const int currentSchemaVersion = 1;
  static const String kdfAlgo = 'PBKDF2WithHmacSHA256';
  static const int defaultIterations = 600000;

  final String format;
  final int schemaVersion;
  final String kdf;
  final int kdfIterations;
  final String salt;
  final String iv;
  final String ciphertext;
  final String uid;
  final int createdAt;

  BackupEnvelopePayload({
    this.format = formatMagic,
    this.schemaVersion = currentSchemaVersion,
    this.kdf = kdfAlgo,
    this.kdfIterations = defaultIterations,
    required this.salt,
    required this.iv,
    required this.ciphertext,
    this.uid = 'local',
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  BackupEnvelopePayload copyWith({
    String? format,
    int? schemaVersion,
    String? kdf,
    int? kdfIterations,
    String? salt,
    String? iv,
    String? ciphertext,
    String? uid,
    int? createdAt,
  }) {
    return BackupEnvelopePayload(
      format: format ?? this.format,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      kdf: kdf ?? this.kdf,
      kdfIterations: kdfIterations ?? this.kdfIterations,
      salt: salt ?? this.salt,
      iv: iv ?? this.iv,
      ciphertext: ciphertext ?? this.ciphertext,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'schemaVersion': schemaVersion,
        'kdf': kdf,
        'kdfIterations': kdfIterations,
        'salt': salt,
        'iv': iv,
        'ciphertext': ciphertext,
        'uid': uid,
        'createdAt': createdAt,
      };

  factory BackupEnvelopePayload.fromJson(Map<String, dynamic> json) {
    return BackupEnvelopePayload(
      format: (json['format'] as String?) ?? '',
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      kdf: (json['kdf'] as String?) ?? kdfAlgo,
      kdfIterations:
          (json['kdfIterations'] as num?)?.toInt() ?? defaultIterations,
      salt: (json['salt'] as String?) ?? '',
      iv: (json['iv'] as String?) ?? '',
      ciphertext: (json['ciphertext'] as String?) ?? '',
      uid: (json['uid'] as String?) ?? 'local',
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class BackupDecryptionException implements Exception {
  final String message;
  const BackupDecryptionException(this.message);
  @override
  String toString() => 'BackupDecryptionException: $message';
}

/// Versioned client-side encryption envelope 100% byte-compatible with Kotlin
/// `BackupCryptoEnvelope.kt`:
/// - KDF: PBKDF2WithHmacSHA256, 600,000 iterations, 16-byte salt, 256-bit key
/// - Cipher: AES/GCM/NoPadding, 12-byte IV, 128-bit auth tag appended to ciphertext
/// - AAD: UTF-8 bytes of `"moglog-backup:v<schemaVersion>:uid=<uid>"`
class BackupCryptoEnvelope {
  static const int _saltBytes = 16;
  static const int _ivBytes = 12;
  static const int _keyBits = 256;
  static const int _gcmTagBytes = 16;

  static Future<BackupEnvelopePayload> encrypt({
    required String plaintextJson,
    required String passphrase,
    String uid = 'local',
    int schemaVersion = BackupEnvelopePayload.currentSchemaVersion,
    int iterations = BackupEnvelopePayload.defaultIterations,
    Uint8List? fixedSaltForTesting,
    Uint8List? fixedIvForTesting,
    bool runInIsolate = true,
  }) async {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('Passphrase must not be blank');
    }

    Future<BackupEnvelopePayload> work() => _encryptSyncOrAsync(
          plaintextJson: plaintextJson,
          passphrase: passphrase,
          uid: uid,
          schemaVersion: schemaVersion,
          iterations: iterations,
          fixedSalt: fixedSaltForTesting,
          fixedIv: fixedIvForTesting,
        );

    if (runInIsolate) {
      return Isolate.run(work);
    }
    return work();
  }

  static Future<String> decrypt({
    required BackupEnvelopePayload envelope,
    required String passphrase,
    String? expectedUid,
    bool runInIsolate = true,
  }) async {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('Passphrase required to decrypt backup');
    }

    Future<String> work() => _decryptSyncOrAsync(
          envelope: envelope,
          passphrase: passphrase,
          expectedUid: expectedUid,
        );

    if (runInIsolate) {
      return Isolate.run(work);
    }
    return work();
  }

  static Future<BackupEnvelopePayload> _encryptSyncOrAsync({
    required String plaintextJson,
    required String passphrase,
    required String uid,
    required int schemaVersion,
    required int iterations,
    Uint8List? fixedSalt,
    Uint8List? fixedIv,
  }) async {
    final rng = Random.secure();
    final salt = fixedSalt ??
        Uint8List.fromList(List<int>.generate(_saltBytes, (_) => rng.nextInt(256)));
    final iv = fixedIv ??
        Uint8List.fromList(List<int>.generate(_ivBytes, (_) => rng.nextInt(256)));

    final secretKey = await _deriveKey(passphrase, salt, iterations);
    final cipher = AesGcm.with256bits();
    final aad = buildAad(uid, schemaVersion);
    final plaintextBytes = utf8.encode(plaintextJson);

    final box = await cipher.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: iv,
      aad: aad,
    );

    // Match Java JCE `AES/GCM/NoPadding` output format: ciphertext || 16-byte MAC tag
    final combined = Uint8List(box.cipherText.length + box.mac.bytes.length);
    combined.setRange(0, box.cipherText.length, box.cipherText);
    combined.setRange(box.cipherText.length, combined.length, box.mac.bytes);

    return BackupEnvelopePayload(
      schemaVersion: schemaVersion,
      kdfIterations: iterations,
      salt: base64.encode(salt),
      iv: base64.encode(iv),
      ciphertext: base64.encode(combined),
      uid: uid,
    );
  }

  static Future<String> _decryptSyncOrAsync({
    required BackupEnvelopePayload envelope,
    required String passphrase,
    String? expectedUid,
  }) async {
    final uidForAad = expectedUid ?? envelope.uid;
    final salt = base64.decode(envelope.salt);
    final iv = base64.decode(envelope.iv);
    final combined = base64.decode(envelope.ciphertext);

    if (combined.length < _gcmTagBytes) {
      throw const BackupDecryptionException('Ciphertext too short');
    }

    final cipherText = combined.sublist(0, combined.length - _gcmTagBytes);
    final macBytes = combined.sublist(combined.length - _gcmTagBytes);
    final iterations = envelope.kdfIterations.clamp(10000, 2000000);

    final secretKey = await _deriveKey(passphrase, salt, iterations);
    final cipher = AesGcm.with256bits();
    final aad = buildAad(uidForAad, envelope.schemaVersion);

    try {
      final box = SecretBox(cipherText, nonce: iv, mac: Mac(macBytes));
      final decrypted = await cipher.decrypt(
        box,
        secretKey: secretKey,
        aad: aad,
      );
      return utf8.decode(decrypted);
    } on SecretBoxAuthenticationError {
      throw const BackupDecryptionException(
        'Authentication failed: wrong passphrase, tampered ciphertext, or mismatched UID.',
      );
    } catch (e) {
      throw BackupDecryptionException(e.toString());
    }
  }

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _keyBits,
    );
    return pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
  }

  static List<int> buildAad(String uid, int schemaVersion) {
    return utf8.encode('moglog-backup:v$schemaVersion:uid=$uid');
  }

  static String serializeEnvelope(BackupEnvelopePayload envelope) {
    return jsonEncode(envelope.toJson());
  }

  static BackupEnvelopePayload? parseEnvelopeOrNull(String rawJson) {
    final trimmed = rawJson.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return null;
      final parsed = BackupEnvelopePayload.fromJson(decoded);
      if (parsed.format == BackupEnvelopePayload.formatMagic &&
          parsed.salt.trim().isNotEmpty &&
          parsed.iv.trim().isNotEmpty &&
          parsed.ciphertext.trim().isNotEmpty) {
        return parsed;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
