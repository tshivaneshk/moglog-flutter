import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hardware Keystore-backed encrypted secret storage matching Kotlin `SecureStore.kt`.
class SecureStore {
  static const String _keyTmdbCredential = 'enc_tmdb_credential';
  static const String _keyDbPassphrase = 'enc_db_passphrase';
  static const String _keyBackupPassphrase = 'enc_backup_passphrase';
  static const String _compromisedLegacyKey = 'b30d871ab7f51c18054f0e6d0921da16';

  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryCache = {};

  final ValueNotifier<bool> hasApiKeyNotifier = ValueNotifier<bool>(false);

  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> init() async {
    try {
      final tmdb = await _storage.read(key: _keyTmdbCredential);
      if (tmdb != null && tmdb.trim().isNotEmpty && tmdb.trim() != _compromisedLegacyKey) {
        _memoryCache[_keyTmdbCredential] = tmdb.trim();
      }
      final backupPass = await _storage.read(key: _keyBackupPassphrase);
      if (backupPass != null && backupPass.isNotEmpty) {
        _memoryCache[_keyBackupPassphrase] = backupPass;
      }
      final dbPass = await _storage.read(key: _keyDbPassphrase);
      if (dbPass != null && dbPass.isNotEmpty) {
        _memoryCache[_keyDbPassphrase] = dbPass;
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
    if (clean.isEmpty || clean == _compromisedLegacyKey) {
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
    if (clean == _compromisedLegacyKey) return false;
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
  Future<String> getOrCreateDatabaseKeyHex() async {
    final existing = _memoryCache[_keyDbPassphrase];
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    try {
      final stored = await _storage.read(key: _keyDbPassphrase);
      if (stored != null && stored.isNotEmpty) {
        _memoryCache[_keyDbPassphrase] = stored;
        return stored;
      }
    } catch (_) {}

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
