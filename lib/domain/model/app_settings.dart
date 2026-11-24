enum ThemeModeSetting {
  system('SYSTEM'),
  dark('DARK'),
  light('LIGHT');

  final String key;
  const ThemeModeSetting(this.key);

  static ThemeModeSetting fromKey(String? key) {
    return ThemeModeSetting.values.firstWhere(
      (e) => e.key == key,
      orElse: () => ThemeModeSetting.dark,
    );
  }
}

enum LibraryLayoutMode {
  grid('GRID'),
  list('LIST');

  final String key;
  const LibraryLayoutMode(this.key);

  static LibraryLayoutMode fromKey(String? key) {
    return LibraryLayoutMode.values.firstWhere(
      (e) => e.key == key,
      orElse: () => LibraryLayoutMode.grid,
    );
  }
}

enum LibrarySortOption {
  recentlyAdded('RECENTLY_ADDED', 'Recently Added'),
  recentlyUpdated('RECENTLY_UPDATED', 'Recently Updated'),
  recentlyCompleted('RECENTLY_COMPLETED', 'Recently Completed'),
  tmdbRating('TMDB_RATING', 'TMDB Rating'),
  myRating('MY_RATING', 'My Rating'),
  titleAz('TITLE_AZ', 'Title (A–Z)'),
  year('YEAR', 'Release Year');

  final String key;
  final String label;
  const LibrarySortOption(this.key, this.label);

  static LibrarySortOption fromKey(String key) {
    return LibrarySortOption.values.firstWhere(
      (e) => e.key == key || e.label == key,
      orElse: () => LibrarySortOption.recentlyAdded,
    );
  }
}

class LibraryFilterState {
  final LibrarySortOption sortOption;
  final Set<String> selectedGenres;
  final double minRating;
  final bool onlyWithNotes;
  final bool onlyPartiallyDone;

  const LibraryFilterState({
    this.sortOption = LibrarySortOption.recentlyAdded,
    this.selectedGenres = const {},
    this.minRating = 0.0,
    this.onlyWithNotes = false,
    this.onlyPartiallyDone = false,
  });

  bool get isDefault =>
      sortOption == LibrarySortOption.recentlyAdded &&
      selectedGenres.isEmpty &&
      minRating <= 0.0 &&
      !onlyPartiallyDone;

  LibraryFilterState copyWith({
    LibrarySortOption? sortOption,
    Set<String>? selectedGenres,
    double? minRating,
    bool? onlyWithNotes,
    bool? onlyPartiallyDone,
  }) {
    return LibraryFilterState(
      sortOption: sortOption ?? this.sortOption,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      minRating: minRating ?? this.minRating,
      onlyWithNotes: onlyWithNotes ?? this.onlyWithNotes,
      onlyPartiallyDone: onlyPartiallyDone ?? this.onlyPartiallyDone,
    );
  }
}

class AppSettings {
  final bool isFirstLaunch;
  final String syncFrequency;
  final ThemeModeSetting themeMode;
  final bool dynamicPosterTint;
  final int gridColumns;
  final LibraryLayoutMode layoutMode;
  final bool showLayoutSwitchInHome;
  final bool appLockEnabled;
  final int appLockTimeoutSeconds;
  final bool hideInRecents;
  final bool encryptedCloudBackupEnabled;
  final bool episodeRemindersEnabled;
  final int lastSyncedAt;
  final List<String> recentSearches;
  final bool sqlCipherMigrated;
  final String customProfileImageBase64;
  final String customDisplayName;
  final bool watchCircleSharingEnabled;
  final Set<int> hiddenFromCircleDramaIds;
  final List<int> topFourFavoriteIds;
  final List<String> customCollections;
  final String customInviteCode;

  static const List<String> defaultCollections = [
    'Comfort Shows',
    'Weekend Binge',
    'Must Watch',
  ];

  const AppSettings({
    this.isFirstLaunch = true,
    this.syncFrequency = 'On Every Change',
    this.themeMode = ThemeModeSetting.dark,
    this.dynamicPosterTint = true,
    this.gridColumns = 3,
    this.layoutMode = LibraryLayoutMode.grid,
    this.showLayoutSwitchInHome = true,
    this.appLockEnabled = false,
    this.appLockTimeoutSeconds = 60,
    this.hideInRecents = false,
    this.encryptedCloudBackupEnabled = false,
    this.episodeRemindersEnabled = false,
    this.lastSyncedAt = 0,
    this.recentSearches = const [],
    this.sqlCipherMigrated = false,
    this.customProfileImageBase64 = '',
    this.customDisplayName = '',
    this.watchCircleSharingEnabled = true,
    this.hiddenFromCircleDramaIds = const {},
    this.topFourFavoriteIds = const [],
    this.customCollections = defaultCollections,
    this.customInviteCode = '',
  });

  AppSettings copyWith({
    bool? isFirstLaunch,
    String? syncFrequency,
    ThemeModeSetting? themeMode,
    bool? dynamicPosterTint,
    int? gridColumns,
    LibraryLayoutMode? layoutMode,
    bool? showLayoutSwitchInHome,
    bool? appLockEnabled,
    int? appLockTimeoutSeconds,
    bool? hideInRecents,
    bool? encryptedCloudBackupEnabled,
    bool? episodeRemindersEnabled,
    int? lastSyncedAt,
    List<String>? recentSearches,
    bool? sqlCipherMigrated,
    String? customProfileImageBase64,
    String? customDisplayName,
    bool? watchCircleSharingEnabled,
    Set<int>? hiddenFromCircleDramaIds,
    List<int>? topFourFavoriteIds,
    List<String>? customCollections,
    String? customInviteCode,
  }) {
    return AppSettings(
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      themeMode: themeMode ?? this.themeMode,
      dynamicPosterTint: dynamicPosterTint ?? this.dynamicPosterTint,
      gridColumns: gridColumns ?? this.gridColumns,
      layoutMode: layoutMode ?? this.layoutMode,
      showLayoutSwitchInHome:
          showLayoutSwitchInHome ?? this.showLayoutSwitchInHome,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockTimeoutSeconds: appLockTimeoutSeconds ?? this.appLockTimeoutSeconds,
      hideInRecents: hideInRecents ?? this.hideInRecents,
      encryptedCloudBackupEnabled:
          encryptedCloudBackupEnabled ?? this.encryptedCloudBackupEnabled,
      episodeRemindersEnabled:
          episodeRemindersEnabled ?? this.episodeRemindersEnabled,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      recentSearches: recentSearches ?? this.recentSearches,
      sqlCipherMigrated: sqlCipherMigrated ?? this.sqlCipherMigrated,
      customProfileImageBase64:
          customProfileImageBase64 ?? this.customProfileImageBase64,
      customDisplayName: customDisplayName ?? this.customDisplayName,
      watchCircleSharingEnabled:
          watchCircleSharingEnabled ?? this.watchCircleSharingEnabled,
      hiddenFromCircleDramaIds:
          hiddenFromCircleDramaIds ?? this.hiddenFromCircleDramaIds,
      topFourFavoriteIds: topFourFavoriteIds ?? this.topFourFavoriteIds,
      customCollections: customCollections ?? this.customCollections,
      customInviteCode: customInviteCode ?? this.customInviteCode,
    );
  }
}
