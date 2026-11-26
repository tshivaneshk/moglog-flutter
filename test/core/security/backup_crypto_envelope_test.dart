import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moglog_flutter/core/security/backup_crypto_envelope.dart';

void main() {
  const testIterations = 20000;

  group('BackupCryptoEnvelope (MOGLOG_ENC_V1 Kotlin byte-compatibility)', () {
    test('encrypt and decrypt round-trip preserves exact UTF-8 JSON payload', () async {
      const sampleJson =
          '[{"id":1399,"title":"Game of Thrones","myRating":9.5,"notes":"Winter is coming ❄️"}]';
      const passphrase = 'correct-horse-battery-staple';
      const uid = 'user_abc_123';

      final envelope = await BackupCryptoEnvelope.encrypt(
        plaintextJson: sampleJson,
        passphrase: passphrase,
        uid: uid,
        iterations: testIterations,
        runInIsolate: false,
      );

      final serialized = BackupCryptoEnvelope.serializeEnvelope(envelope);
      final parsed = BackupCryptoEnvelope.parseEnvelopeOrNull(serialized);
      expect(parsed, isNotNull);
      expect(parsed!.format, BackupEnvelopePayload.formatMagic);
      expect(parsed.kdf, BackupEnvelopePayload.kdfAlgo);
      expect(parsed.schemaVersion, 1);

      final decrypted = await BackupCryptoEnvelope.decrypt(
        envelope: parsed,
        passphrase: passphrase,
        expectedUid: uid,
        runInIsolate: false,
      );
      expect(decrypted, sampleJson);
    });

    test('deterministic salt+iv produces exact JCE-compatible ciphertext||tag layout', () async {
      // Fixed 16-byte salt (0..15) and 12-byte IV (0..11) for cross-platform verification
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final iv = Uint8List.fromList(List.generate(12, (i) => i + 16));
      const plaintext = '[{"id":1,"title":"Severance"}]';
      const passphrase = 'moglog-vector-passphrase';
      const uid = 'local';

      final envA = await BackupCryptoEnvelope.encrypt(
        plaintextJson: plaintext,
        passphrase: passphrase,
        uid: uid,
        iterations: 10000,
        fixedSaltForTesting: salt,
        fixedIvForTesting: iv,
        runInIsolate: false,
      );
      final envB = await BackupCryptoEnvelope.encrypt(
        plaintextJson: plaintext,
        passphrase: passphrase,
        uid: uid,
        iterations: 10000,
        fixedSaltForTesting: salt,
        fixedIvForTesting: iv,
        runInIsolate: false,
      );

      // Identical inputs yield identical ciphertext + 16-byte GCM auth tag
      expect(envA.ciphertext, envB.ciphertext);
      final rawCipher = base64.decode(envA.ciphertext);
      expect(rawCipher.length, utf8.encode(plaintext).length + 16);

      final decrypted = await BackupCryptoEnvelope.decrypt(
        envelope: envA,
        passphrase: passphrase,
        expectedUid: uid,
        runInIsolate: false,
      );
      expect(decrypted, plaintext);
    });

    test('encrypt generates unique salt and IV on every invocation', () async {
      const payload = '[{"id":1,"title":"Test"}]';
      const pass = 'same-passphrase-123';

      final env1 = await BackupCryptoEnvelope.encrypt(
        plaintextJson: payload,
        passphrase: pass,
        iterations: testIterations,
        runInIsolate: false,
      );
      final env2 = await BackupCryptoEnvelope.encrypt(
        plaintextJson: payload,
        passphrase: pass,
        iterations: testIterations,
        runInIsolate: false,
      );

      expect(env1.salt, isNot(env2.salt));
      expect(env1.iv, isNot(env2.iv));
      expect(env1.ciphertext, isNot(env2.ciphertext));
    });

    test('decrypt with wrong passphrase throws BackupDecryptionException', () async {
      final envelope = await BackupCryptoEnvelope.encrypt(
        plaintextJson: '[{"id":42,"title":"Severance"}]',
        passphrase: 'right-passphrase',
        uid: 'u1',
        iterations: testIterations,
        runInIsolate: false,
      );

      expect(
        () => BackupCryptoEnvelope.decrypt(
          envelope: envelope,
          passphrase: 'wrong-passphrase',
          expectedUid: 'u1',
          runInIsolate: false,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('decrypt with tampered ciphertext fails authentication', () async {
      final envelope = await BackupCryptoEnvelope.encrypt(
        plaintextJson: '[{"id":100,"title":"Shogun"}]',
        passphrase: 'secret-passphrase',
        uid: 'u1',
        iterations: testIterations,
        runInIsolate: false,
      );

      final rawBytes = base64.decode(envelope.ciphertext);
      rawBytes[0] = rawBytes[0] ^ 0xFF;
      final tampered = envelope.copyWith(ciphertext: base64.encode(rawBytes));

      expect(
        () => BackupCryptoEnvelope.decrypt(
          envelope: tampered,
          passphrase: 'secret-passphrase',
          expectedUid: 'u1',
          runInIsolate: false,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('decrypt with mismatched AAD uid fails authentication', () async {
      final envelope = await BackupCryptoEnvelope.encrypt(
        plaintextJson: '[{"id":7,"title":"Arcane"}]',
        passphrase: 'secret-passphrase',
        uid: 'owner_uid_1',
        iterations: testIterations,
        runInIsolate: false,
      );

      expect(
        () => BackupCryptoEnvelope.decrypt(
          envelope: envelope,
          passphrase: 'secret-passphrase',
          expectedUid: 'attacker_uid_2',
          runInIsolate: false,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('parseEnvelopeOrNull returns null for plain JSON array', () {
      const plainArray = '[{"id":1,"title":"Plain JSON"}]';
      expect(BackupCryptoEnvelope.parseEnvelopeOrNull(plainArray), isNull);
    });

    test('decrypt rejects unsupported format, KDF, or out-of-range iterations', () async {
      final valid = await BackupCryptoEnvelope.encrypt(
        plaintextJson: '[{"id":9,"title":"Andor"}]',
        passphrase: 'strong-passphrase-abc',
        uid: 'u9',
        iterations: testIterations,
        runInIsolate: false,
      );

      expect(
        () => BackupCryptoEnvelope.decrypt(
          envelope: valid.copyWith(format: 'UNTRUSTED_V0'),
          passphrase: 'strong-passphrase-abc',
          expectedUid: 'u9',
          runInIsolate: false,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );

      expect(
        () => BackupCryptoEnvelope.decrypt(
          envelope: valid.copyWith(kdf: 'PlainSHA256'),
          passphrase: 'strong-passphrase-abc',
          expectedUid: 'u9',
          runInIsolate: false,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );

      expect(
        () => BackupCryptoEnvelope.decrypt(
          envelope: valid.copyWith(kdfIterations: 1),
          passphrase: 'strong-passphrase-abc',
          expectedUid: 'u9',
          runInIsolate: false,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });
  });
}
