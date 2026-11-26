import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../platform/platform_bridge.dart';

/// Hardware Keystore / Keychain-backed encrypted secret storage:
/// - Android: `AES/GCM/NoPadding` + `RSA/ECB/OAEPWithSHA-256AndMGF1Padding` (via `flutter_secure_storage` v11)
/// - iOS: Keychain (`first_unlock_this_device`, non-synchronizable)
class SecureStore {
  static const String _keyTmdbCredential = 'enc_tmdb_credential';
  static const String _keyDbPassphrase = 'enc_db_passphrase';
  static const String _keyBackupPassphrase = 'enc_backup_passphrase';
  // SHA-256 Base64 digest of revoked legacy demo key (avoids embedding raw hex token in binary)
  static const String _compromisedLegacyKeySha256B64 =
      'v0DNa/o+RbMKdzCM4ydyF139gLVgs0slaeahbOE/WGE=';
  static final RegExp _dbHexKeyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryCache = {};

  final ValueNotifier<bool> hasApiKeyNotifier = ValueNotifier<bool>(false);

  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: false,
                migrateOnAlgorithmChange: true,
                keyCipherAlgorithm:
                    KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
                storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
            );

  static bool _isCompromisedLegacyKey(String input) {
    final clean = input.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final digestB64 = base64.encode(sha256.convert(utf8.encode(clean)).bytes);
    return digestB64 == _compromisedLegacyKeySha256B64;
  }

  Future<void> init() async {
    try {
      var results = await Future.wait<String?>([
        _storage.read(key: _keyTmdbCredential),
        _storage.read(key: _keyBackupPassphrase),
        _storage.read(key: _keyDbPassphrase),
      ]);

      // Seamless one-time migration from v3.1.0/v3.1.1 Jetpack EncryptedSharedPreferences (v9) to v11 AES-GCM
      if (Platform.isAndroid &&
          (results[0] == null || results[0]!.isEmpty) &&
          (results[1] == null || results[1]!.isEmpty) &&
          (results[2] == null || results[2]!.isEmpty)) {
        final legacyV9 = await PlatformBridge.migrateV9EncryptedPrefs();
        if (legacyV9 != null && legacyV9.isNotEmpty) {
          var migratedAll = true;
          for (final key in const [
            _keyTmdbCredential,
            _keyBackupPassphrase,
            _keyDbPassphrase,
          ]) {
            final val = legacyV9[key];
            if (val != null && val.isNotEmpty) {
              try {
                await _storage.write(key: key, value: val);
              } catch (_) {
                migratedAll = false;
              }
            }
          }
          results = [
            legacyV9[_keyTmdbCredential] ?? results[0],
            legacyV9[_keyBackupPassphrase] ?? results[1],
            legacyV9[_keyDbPassphrase] ?? results[2],
          ];
          if (migratedAll) {
            await PlatformBridge.purgeV9EncryptedPrefs();
          }
        }
      }

      final tmdb = results[0];
      if (tmdb != null &&
          tmdb.trim().isNotEmpty &&
          !_isCompromisedLegacyKey(tmdb)) {
        _memoryCache[_keyTmdbCredential] = tmdb.trim();
      }
      final backupPass = results[1];
      if (backupPass != null && backupPass.isNotEmpty) {
        _memoryCache[_keyBackupPassphrase] = backupPass;
      }
      final dbPass = results[2];
      if (dbPass != null && _dbHexKeyPattern.hasMatch(dbPass.trim())) {
        _memoryCache[_keyDbPassphrase] = dbPass.trim();
      }
    } catch (_) {
      // Graceful recovery if keystore is unavailable in test/emulator edge cases
    }
    hasApiKeyNotifier.value = getTmdbCredential().isNotEmpty;
  }

  String getTmdbCredential() => _memoryCache[_keyTmdbCredential] ?? '';

  String getUserTmdbCredentialOrEmpty() => getTmdbCredential();

  Future<void> setTmdbCredential(String credential) async {
    final clean = credential.trim();
    if (clean.isEmpty || _isCompromisedLegacyKey(clean)) {
      _memoryCache.remove(_keyTmdbCredential);
      try {
        await _storage.delete(key: _keyTmdbCredential);
      } catch (_) {}
      hasApiKeyNotifier.value = false;
    } else {
      _memoryCache[_keyTmdbCredential] = clean;
      try {
        await _storage.write(key: _keyTmdbCredential, value: clean);
      } catch (_) {}
      hasApiKeyNotifier.value = true;
    }
  }

  /// Validates either a TMDB v3 API key (32 hex chars) or a TMDB v4 Read Access Token (JWT).
  static bool isValidTmdbCredentialFormat(String input) {
    final clean = input.trim();
    if (_isCompromisedLegacyKey(clean)) return false;
    final isV3Hex = RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(clean);
    final dotCount = '.'.allMatches(clean).length;
    final isV4Jwt = clean.startsWith('eyJ') && dotCount == 2 && clean.length >= 60;
    return isV3Hex || isV4Jwt;
  }

  bool isBearerToken([String? credential]) {
    final clean = (credential ?? getTmdbCredential()).trim();
    return clean.startsWith('eyJ') && '.'.allMatches(clean).length == 2;
  }

  /// Returns or generates a 256-bit (32-byte) random key encoded as hex for SQLCipher `PRAGMA key`.
  Future<String> getOrCreateDatabaseKeyHex({bool existingDbOnDisk = false}) async {
    final existing = _memoryCache[_keyDbPassphrase];
    if (existing != null && _dbHexKeyPattern.hasMatch(existing)) {
      return existing;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final stored = await _storage.read(key: _keyDbPassphrase);
        if (stored != null && _dbHexKeyPattern.hasMatch(stored.trim())) {
          final cleanKey = stored.trim();
          _memoryCache[_keyDbPassphrase] = cleanKey;
          return cleanKey;
        }
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
      }
    }

    if (Platform.isAndroid) {
      final legacyV9 = await PlatformBridge.migrateV9EncryptedPrefs();
      final recovered = legacyV9?[_keyDbPassphrase]?.trim();
      if (recovered != null && _dbHexKeyPattern.hasMatch(recovered)) {
        _memoryCache[_keyDbPassphrase] = recovered;
        try {
          await _storage.write(key: _keyDbPassphrase, value: recovered);
          await PlatformBridge.purgeV9EncryptedPrefs();
        } catch (_) {}
        return recovered;
      }
    }

    if (existingDbOnDisk) {
      throw StateError(
        'Encrypted database key could not be unlocked from device secure storage.',
      );
    }

    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final hexKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _memoryCache[_keyDbPassphrase] = hexKey;
    try {
      await _storage.write(key: _keyDbPassphrase, value: hexKey);
    } catch (_) {}
    return hexKey;
  }

  String getBackupPassphrase() => _memoryCache[_keyBackupPassphrase] ?? '';

  bool hasBackupPassphrase() => getBackupPassphrase().isNotEmpty;

  Future<void> setBackupPassphrase(String? passphrase) async {
    if (passphrase == null || passphrase.trim().isEmpty) {
      _memoryCache.remove(_keyBackupPassphrase);
      try {
        await _storage.delete(key: _keyBackupPassphrase);
      } catch (_) {}
    } else {
      _memoryCache[_keyBackupPassphrase] = passphrase;
      try {
        await _storage.write(key: _keyBackupPassphrase, value: passphrase);
      } catch (_) {}
    }
  }

  static String encodeBase64Bytes(List<int> bytes) => base64.encode(bytes);
}
