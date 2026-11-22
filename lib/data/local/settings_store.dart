import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/model/app_settings.dart';

/// 1:1 port of Kotlin `SettingsStore.kt` (all 21 keys, defaults, and `\u001F` delimiter).
class SettingsStore {
  static const String _delimiter = '\u001F';

  static const String _keyFirstLaunch = 'is_first_launch';
  static const String _keySyncFrequency = 'sync_frequency';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyDynamicTint = 'dynamic_poster_tint';
  static const String _keyGridColumns = 'grid_columns';
  static const String _keyLayoutMode = 'layout_mode';
  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyAppLockTimeoutSec = 'app_lock_timeout_sec';
  static const String _keyHideInRecents = 'hide_in_recents';
  static const String _keyEncryptedCloudBackup = 'encrypted_cloud_backup';
  static const String _keyEpisodeReminders = 'episode_reminders';
  static const String _keyLastSyncedAt = 'last_synced_at';
  static const String _keyRecentSearches = 'recent_searches';
  static const String _keySqlCipherMigrated = 'sqlcipher_migrated';
  static const String _keyCustomProfileImage = 'custom_profile_image_b64';
  static const String _keyCustomDisplayName = 'custom_display_name';
  static const String _keyWatchCircleSharing = 'watch_circle_sharing';
  static const String _keyHiddenFromCircleIds = 'hidden_from_circle_ids';
  static const String _keyTopFourFavoriteIds = 'top_four_favorite_ids';
  static const String _keyCustomCollections = 'custom_collections';
  static const String _keyCustomInviteCode = 'custom_invite_code';

  SharedPreferences? _prefs;
  AppSettings _state = const AppSettings();
  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  AppSettings get state => _state;
  Stream<AppSettings> get stream async* {
    yield _state;
    yield* _controller.stream;
  }

  Future<void> init({SharedPreferences? prefs}) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final p = _prefs;
    if (p == null) return;

    final rawRecent = p.getString(_keyRecentSearches) ?? '';
    final recentList = rawRecent.trim().isEmpty
        ? const <String>[]
        : rawRecent.split(_delimiter).where((e) => e.trim().isNotEmpty).toList();

    final rawHidden = p.getString(_keyHiddenFromCircleIds) ?? '';
    final hiddenIds = rawHidden.trim().isEmpty
        ? const <int>{}
        : rawHidden
            .split(_delimiter)
            .map(int.tryParse)
            .whereType<int>()
            .toSet();

    final rawTopFour = p.getString(_keyTopFourFavoriteIds) ?? '';
    final topFour = rawTopFour.trim().isEmpty
        ? const <int>[]
        : rawTopFour
            .split(_delimiter)
            .map(int.tryParse)
            .whereType<int>()
            .toSet()
            .take(4)
            .toList();

    final rawCollections = p.getString(_keyCustomCollections);
    final List<String> collections;
    if (rawCollections == null) {
      collections = AppSettings.defaultCollections;
    } else if (rawCollections.trim().isEmpty) {
      collections = const [];
    } else {
      collections = rawCollections
          .split(_delimiter)
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    _state = AppSettings(
      isFirstLaunch: p.getBool(_keyFirstLaunch) ?? true,
      syncFrequency: p.getString(_keySyncFrequency) ?? 'On Every Change',
      themeMode: ThemeModeSetting.fromKey(p.getString(_keyThemeMode)),
      dynamicPosterTint: p.getBool(_keyDynamicTint) ?? true,
      gridColumns: (p.getInt(_keyGridColumns) ?? 3).clamp(2, 4),
      layoutMode: LibraryLayoutMode.fromKey(p.getString(_keyLayoutMode)),
      appLockEnabled: p.getBool(_keyAppLockEnabled) ?? false,
      appLockTimeoutSeconds: p.getInt(_keyAppLockTimeoutSec) ?? 60,
      hideInRecents: p.getBool(_keyHideInRecents) ?? false,
      encryptedCloudBackupEnabled: p.getBool(_keyEncryptedCloudBackup) ?? false,
      episodeRemindersEnabled: p.getBool(_keyEpisodeReminders) ?? false,
      lastSyncedAt: p.getInt(_keyLastSyncedAt) ?? 0,
      recentSearches: recentList,
      sqlCipherMigrated: p.getBool(_keySqlCipherMigrated) ?? true,
      customProfileImageBase64: p.getString(_keyCustomProfileImage) ?? '',
      customDisplayName: p.getString(_keyCustomDisplayName) ?? '',
      watchCircleSharingEnabled: p.getBool(_keyWatchCircleSharing) ?? true,
      hiddenFromCircleDramaIds: hiddenIds,
      topFourFavoriteIds: topFour,
      customCollections: collections,
      customInviteCode: p.getString(_keyCustomInviteCode) ?? '',
    );
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  Future<void> setFirstLaunchCompleted() async {
    await _prefs?.setBool(_keyFirstLaunch, false);
    _state = _state.copyWith(isFirstLaunch: false);
    _emit();
  }

  Future<void> setSyncFrequency(String frequency) async {
    await _prefs?.setString(_keySyncFrequency, frequency);
    _state = _state.copyWith(syncFrequency: frequency);
    _emit();
  }

  Future<void> setThemeMode(ThemeModeSetting mode) async {
    await _prefs?.setString(_keyThemeMode, mode.key);
    _state = _state.copyWith(themeMode: mode);
    _emit();
  }

  Future<void> setDynamicPosterTint(bool enabled) async {
    await _prefs?.setBool(_keyDynamicTint, enabled);
    _state = _state.copyWith(dynamicPosterTint: enabled);
    _emit();
  }

  Future<void> setGridColumns(int columns) async {
    final clamped = columns.clamp(2, 4);
    await _prefs?.setInt(_keyGridColumns, clamped);
    _state = _state.copyWith(gridColumns: clamped);
    _emit();
  }

  Future<void> setLayoutMode(LibraryLayoutMode mode) async {
    await _prefs?.setString(_keyLayoutMode, mode.key);
    _state = _state.copyWith(layoutMode: mode);
    _emit();
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _prefs?.setBool(_keyAppLockEnabled, enabled);
    _state = _state.copyWith(appLockEnabled: enabled);
    _emit();
  }

  Future<void> setAppLockTimeoutSeconds(int seconds) async {
    await _prefs?.setInt(_keyAppLockTimeoutSec, seconds);
    _state = _state.copyWith(appLockTimeoutSeconds: seconds);
    _emit();
  }

  Future<void> setHideInRecents(bool enabled) async {
    await _prefs?.setBool(_keyHideInRecents, enabled);
    _state = _state.copyWith(hideInRecents: enabled);
    _emit();
  }

  Future<void> setEncryptedCloudBackupEnabled(bool enabled) async {
    await _prefs?.setBool(_keyEncryptedCloudBackup, enabled);
    _state = _state.copyWith(encryptedCloudBackupEnabled: enabled);
    _emit();
  }

  Future<void> setEpisodeRemindersEnabled(bool enabled) async {
    await _prefs?.setBool(_keyEpisodeReminders, enabled);
    _state = _state.copyWith(episodeRemindersEnabled: enabled);
    _emit();
  }

  Future<void> setLastSyncedAt(int timestampMs) async {
    await _prefs?.setInt(_keyLastSyncedAt, timestampMs);
    _state = _state.copyWith(lastSyncedAt: timestampMs);
    _emit();
  }

  Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return;
    final filtered = _state.recentSearches
        .where((e) => e.toLowerCase() != clean.toLowerCase())
        .toList();
    final updated = [clean, ...filtered].take(8).toList();
    await _prefs?.setString(_keyRecentSearches, updated.join(_delimiter));
    _state = _state.copyWith(recentSearches: updated);
    _emit();
  }

  Future<void> clearRecentSearches() async {
    await _prefs?.remove(_keyRecentSearches);
    _state = _state.copyWith(recentSearches: const []);
    _emit();
  }

  Future<void> setCustomProfileImageBase64(String base64) async {
    if (base64.trim().isEmpty) {
      await _prefs?.remove(_keyCustomProfileImage);
      _state = _state.copyWith(customProfileImageBase64: '');
    } else {
      await _prefs?.setString(_keyCustomProfileImage, base64);
      _state = _state.copyWith(customProfileImageBase64: base64);
    }
    _emit();
  }

  Future<void> setCustomDisplayName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      await _prefs?.remove(_keyCustomDisplayName);
      _state = _state.copyWith(customDisplayName: '');
    } else {
      await _prefs?.setString(_keyCustomDisplayName, clean);
      _state = _state.copyWith(customDisplayName: clean);
    }
    _emit();
  }

  Future<void> setWatchCircleSharingEnabled(bool enabled) async {
    await _prefs?.setBool(_keyWatchCircleSharing, enabled);
    _state = _state.copyWith(watchCircleSharingEnabled: enabled);
    _emit();
  }

  Future<void> setDramaHiddenFromCircle(int dramaId, bool hidden) async {
    final updated = Set<int>.from(_state.hiddenFromCircleDramaIds);
    if (hidden) {
      updated.add(dramaId);
    } else {
      updated.remove(dramaId);
    }
    if (updated.isEmpty) {
      await _prefs?.remove(_keyHiddenFromCircleIds);
    } else {
      await _prefs?.setString(_keyHiddenFromCircleIds, updated.join(_delimiter));
    }
    _state = _state.copyWith(hiddenFromCircleDramaIds: updated);
    _emit();
  }

  Future<bool> toggleTopFourFavorite(int dramaId) async {
    final current = List<int>.from(_state.topFourFavoriteIds);
    bool added;
    if (current.contains(dramaId)) {
      current.remove(dramaId);
      added = false;
    } else {
      if (current.length >= 4) {
        current.removeAt(0);
      }
      current.add(dramaId);
      added = true;
    }
    await setTopFourFavorites(current);
    return added;
  }

  Future<void> setTopFourFavorites(List<int> ids) async {
    final clean = ids.toSet().take(4).toList();
    if (clean.isEmpty) {
      await _prefs?.remove(_keyTopFourFavoriteIds);
    } else {
      await _prefs?.setString(_keyTopFourFavoriteIds, clean.join(_delimiter));
    }
    _state = _state.copyWith(topFourFavoriteIds: clean);
    _emit();
  }

  Future<void> addCustomCollection(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final current = List<String>.from(_state.customCollections);
    if (!current.any((c) => c.toLowerCase() == clean.toLowerCase())) {
      current.add(clean);
      await setCustomCollections(current);
    }
  }

  Future<void> removeCustomCollection(String name) async {
    final updated = _state.customCollections
        .where((c) => c.toLowerCase() != name.toLowerCase())
        .toList();
    await setCustomCollections(updated);
  }

  Future<void> renameCustomCollection(String oldName, String newName) async {
    final cleanNew = newName.trim();
    if (cleanNew.isEmpty) return;
    final updated = _state.customCollections.map((c) {
      return c.toLowerCase() == oldName.toLowerCase() ? cleanNew : c;
    }).toSet().toList();
    await setCustomCollections(updated);
  }

  Future<void> setCustomCollections(List<String> collections) async {
    final clean = collections.toSet().toList();
    await _prefs?.setString(_keyCustomCollections, clean.join(_delimiter));
    _state = _state.copyWith(customCollections: clean);
    _emit();
  }

  Future<void> setCustomInviteCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      await _prefs?.remove(_keyCustomInviteCode);
      _state = _state.copyWith(customInviteCode: '');
    } else {
      await _prefs?.setString(_keyCustomInviteCode, clean);
      _state = _state.copyWith(customInviteCode: clean);
    }
    _emit();
  }

  // Known Watch Circle friends for new-friend notification tracking
  Set<String> getKnownFriends(String uid) {
    final list = _prefs?.getStringList('known_friends_$uid');
    return list?.toSet() ?? const {};
  }

  bool isKnownFriendsInitialized(String uid) {
    return _prefs?.containsKey('known_friends_$uid') ?? false;
  }

  Future<void> saveKnownFriends(String uid, Set<String> friends) async {
    await _prefs?.setStringList('known_friends_$uid', friends.toList());
  }

  void dispose() {
    _controller.close();
  }
}
