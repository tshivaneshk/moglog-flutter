import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/background/background_scheduler.dart';
import '../core/celebration/show_completion_celebration.dart';
import '../core/notifications/notification_service.dart';
import '../core/platform/platform_bridge.dart';
import '../core/security/backup_crypto_envelope.dart';
import '../core/security/secure_store.dart';
import '../data/local/app_database.dart';
import '../data/local/settings_store.dart';
import '../data/remote/cloud_sync_repository.dart';
import '../data/remote/tmdb_api.dart';
import '../data/remote/watch_circle_repository.dart';
import '../data/repository/drama_repository_impl.dart';
import '../domain/logic/library_filter.dart';
import '../domain/model/app_settings.dart';
import '../domain/model/drama.dart';
import '../domain/model/drama_extra_details.dart';
import '../domain/model/watch_circle_models.dart';

// ---------------------------------------------------------------------------
// Core singletons (overridden in main.dart after async bootstrap)
// ---------------------------------------------------------------------------

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final tmdbApiProvider = Provider<TmdbApi>(
  (ref) => TmdbApi(secureStore: ref.watch(secureStoreProvider)),
);

final dramaRepositoryProvider = Provider<DramaRepositoryImpl>(
  (ref) => DramaRepositoryImpl(
    api: ref.watch(tmdbApiProvider),
    db: ref.watch(appDatabaseProvider),
  ),
);

final cloudSyncRepositoryProvider = Provider<CloudSyncRepository>(
  (ref) => CloudSyncRepository(
    secureStore: ref.watch(secureStoreProvider),
    settingsStore: ref.watch(settingsStoreProvider),
  ),
);

final watchCircleRepositoryProvider = Provider<WatchCircleRepository>(
  (ref) => WatchCircleRepository(
    settingsStore: ref.watch(settingsStoreProvider),
    notificationService: ref.watch(notificationServiceProvider),
  ),
);

final backgroundSchedulerProvider = Provider<BackgroundScheduler>(
  (ref) => BackgroundScheduler(
    db: ref.watch(appDatabaseProvider),
    dramaRepository: ref.watch(dramaRepositoryProvider),
    settingsStore: ref.watch(settingsStoreProvider),
    notificationService: ref.watch(notificationServiceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Reactive streams & UI state
// ---------------------------------------------------------------------------

final appSettingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsStoreProvider).stream,
);

final currentSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(appSettingsProvider).valueOrNull ??
      ref.watch(settingsStoreProvider).state,
);

final allDramasProvider = StreamProvider<List<Drama>>(
  (ref) => ref.watch(dramaRepositoryProvider).watchAllDramas(),
);

final currentDramasProvider = Provider<List<Drama>>(
  (ref) => ref.watch(allDramasProvider).valueOrNull ??
      ref.watch(dramaRepositoryProvider).getAllDramasSync(),
);

final hasApiKeyProvider = StateProvider<bool>(
  (ref) => ref.read(secureStoreProvider).getTmdbCredential().isNotEmpty,
);

final isInitialReadyProvider = StateProvider<bool>((ref) => false);

final celebrationTriggerProvider = StateProvider<int>((ref) => 0);

// Library persisted filter/tab/search state across navigation
final libraryFilterStateProvider =
    StateProvider<LibraryFilterState>((ref) => const LibraryFilterState());
final librarySelectedStatusProvider = StateProvider<String>((ref) => 'All');
final librarySearchQueryProvider = StateProvider<String>((ref) => '');
final librarySelectedShelfProvider = StateProvider<String?>((ref) => null);

// Floating iOS Toast state
class ToastMessage {
  final int id;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ToastMessage({
    required this.id,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
}

typedef VoidCallback = void Function();

class ToastNotifier extends StateNotifier<ToastMessage?> {
  Timer? _timer;
  int _counter = 0;

  ToastNotifier() : super(null);

  void show(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    _timer?.cancel();
    _counter++;
    state = ToastMessage(
      id: _counter,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _timer = Timer(
      duration ?? Duration(milliseconds: actionLabel != null ? 3800 : 2600),
      () => state = null,
    );
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final toastProvider =
    StateNotifierProvider<ToastNotifier, ToastMessage?>((ref) => ToastNotifier());

// ---------------------------------------------------------------------------
// Discover & Search state
// ---------------------------------------------------------------------------

class DiscoverRailsState {
  final bool isLoading;
  final List<Drama> trending;
  final List<Drama> popular;
  final List<Drama> airingToday;
  final List<Drama> onTheAir;
  final String? error;

  const DiscoverRailsState({
    this.isLoading = false,
    this.trending = const [],
    this.popular = const [],
    this.airingToday = const [],
    this.onTheAir = const [],
    this.error,
  });

  DiscoverRailsState copyWith({
    bool? isLoading,
    List<Drama>? trending,
    List<Drama>? popular,
    List<Drama>? airingToday,
    List<Drama>? onTheAir,
    Object? error = _sentinel,
  }) {
    return DiscoverRailsState(
      isLoading: isLoading ?? this.isLoading,
      trending: trending ?? this.trending,
      popular: popular ?? this.popular,
      airingToday: airingToday ?? this.airingToday,
      onTheAir: onTheAir ?? this.onTheAir,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class DiscoverSearchState {
  final String query;
  final List<Drama> results;
  final bool isLoading;

  const DiscoverSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
  });
}

class ImportSummary {
  final int added;
  final int updated;
  final int skipped;
  final String? errorMessage;

  const ImportSummary({
    required this.added,
    required this.updated,
    required this.skipped,
    this.errorMessage,
  });
}

final discoverRailsProvider =
    StateProvider<DiscoverRailsState>((ref) => const DiscoverRailsState());

final discoverSearchProvider =
    StateProvider<DiscoverSearchState>((ref) => const DiscoverSearchState());

// ---------------------------------------------------------------------------
// DramaController (1:1 port of Kotlin DramaViewModel)
// ---------------------------------------------------------------------------

class DramaController {
  final Ref ref;
  final Map<int, Drama> _transientDramas = {};
  Timer? _searchDebounce;
  Timer? _cloudSyncDebounce;
  StreamSubscription<dynamic>? _realtimeSub;
  String? _listeningUid;

  DramaController(this.ref);

  DramaRepositoryImpl get _repo => ref.read(dramaRepositoryProvider);
  SettingsStore get _settings => ref.read(settingsStoreProvider);
  SecureStore get _secure => ref.read(secureStoreProvider);
  CloudSyncRepository get _cloud => ref.read(cloudSyncRepositoryProvider);
  WatchCircleRepository get _circle => ref.read(watchCircleRepositoryProvider);

  Future<void> initialize() async {
    final startMs = DateTime.now().millisecondsSinceEpoch;
    ensureRealtimeListenerStarted();

    // Preload Discover rails if TMDB key is configured
    if (_secure.getTmdbCredential().isNotEmpty) {
      unawaited(loadDiscoverRails(forceRefresh: false));
    }

    // Hold splash >= 750ms matching Kotlin startup overlay
    final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
    if (elapsed < 750) {
      await Future<void>.delayed(Duration(milliseconds: 750 - elapsed));
    }
    ref.read(isInitialReadyProvider.notifier).state = true;
  }

  void triggerCompletionCelebration() {
    ref.read(celebrationTriggerProvider.notifier).state =
        DateTime.now().millisecondsSinceEpoch;
    unawaited(CelebrationAudio.playCompletionChime());
    unawaited(CelebrationHaptics.playCelebrationHaptic());
  }

  void ensureRealtimeListenerStarted() {
    if (!_cloud.isFirebaseReady) return;
    final uid = _cloud.currentUser?.uid;
    if (uid == null) {
      _realtimeSub?.cancel();
      _realtimeSub = null;
      _listeningUid = null;
      return;
    }
    if (_realtimeSub != null && _listeningUid == uid) return;
    _realtimeSub?.cancel();
    _listeningUid = uid;
    _realtimeSub = _cloud.startRealtimeSyncListener(() async {
      await reconcileCloudAndLocal();
    });
  }

  Future<void> reconcileCloudAndLocal() async {
    CloudData? cloud;
    try {
      cloud = await _cloud.fetchFromCloud();
    } catch (_) {
      return;
    }
    if (cloud == null) return;

    final localList = _repo.getAllDramasSync();
    final localMap = {for (final d in localList) d.id: d};
    final cloudMap = {for (final d in cloud.dramas) d.id: d};
    var localNeedsPush = false;

    for (final incoming in cloud.dramas) {
      final existing = localMap[incoming.id];
      if (existing == null || incoming.updatedAt >= existing.updatedAt) {
        _repo.saveDrama(incoming);
        localMap[incoming.id] = incoming;
      } else {
        localNeedsPush = true;
      }
    }

    for (final id in localMap.keys) {
      if (!cloudMap.containsKey(id)) {
        localNeedsPush = true;
      }
    }

    if (localNeedsPush && localMap.isNotEmpty) {
      try {
        await _cloud.syncToCloud(localMap.values.toList());
      } catch (_) {}
    } else {
      final remoteLast = await _cloud.fetchRemoteLastSyncedAt();
      if (remoteLast > 0) {
        await _settings.setLastSyncedAt(remoteLast);
      }
    }
  }

  void _scheduleDebouncedCloudSync(List<Drama> currentList) {
    _cloudSyncDebounce?.cancel();
    _cloudSyncDebounce = Timer(const Duration(milliseconds: 320), () async {
      if (_cloud.isSignedIn()) {
        try {
          await _cloud.syncToCloud(currentList);
        } catch (_) {}
      }
      try {
        await _circle.publishMyActivity(currentList);
      } catch (_) {}
    });
  }

  Future<void> loadDiscoverRails({bool forceRefresh = false}) async {
    if (_secure.getTmdbCredential().isEmpty) return;
    final current = ref.read(discoverRailsProvider);
    if (!forceRefresh && current.trending.isNotEmpty) return;

    ref.read(discoverRailsProvider.notifier).state =
        current.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getTrendingDramas(forceRefresh: forceRefresh),
        _repo.getPopularDramas(forceRefresh: forceRefresh),
        _repo.getAiringTodayDramas(forceRefresh: forceRefresh),
        _repo.getOnTheAirDramas(forceRefresh: forceRefresh),
      ]);
      for (final list in results) {
        for (final d in list) {
          _transientDramas[d.id] = d;
        }
      }
      ref.read(discoverRailsProvider.notifier).state = DiscoverRailsState(
        isLoading: false,
        trending: results[0],
        popular: results[1],
        airingToday: results[2],
        onTheAir: results[3],
      );
    } catch (e) {
      ref.read(discoverRailsProvider.notifier).state = current.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void updateSearchQuery(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      ref.read(discoverSearchProvider.notifier).state =
          const DiscoverSearchState();
      return;
    }
    ref.read(discoverSearchProvider.notifier).state = DiscoverSearchState(
      query: query,
      results: ref.read(discoverSearchProvider).results,
      isLoading: true,
    );
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await _repo.searchDramas(query);
      for (final d in results) {
        _transientDramas[d.id] = d;
      }
      ref.read(discoverSearchProvider.notifier).state = DiscoverSearchState(
        query: query,
        results: results,
        isLoading: false,
      );
      if (results.isNotEmpty) {
        await _settings.addRecentSearch(query);
      }
    });
  }

  void cacheTransientDrama(Drama drama) {
    _transientDramas[drama.id] = drama;
  }

  Future<Drama?> resolveDramaById(int id) async {
    final local = _repo.getLocalDramaById(id);
    if (local != null) return local;
    final cachedTransient = _transientDramas[id];
    final remote = await _repo.getDramaDetails(id);
    if (remote != null) {
      _transientDramas[id] = remote;
      return remote;
    }
    return cachedTransient;
  }

  Future<DramaExtraDetails?> getDramaExtraDetails(int id) async {
    final details = await _repo.getDramaExtraDetails(id);
    if (details != null) {
      final existing = _repo.getLocalDramaById(id);
      if (existing != null) {
        final updated = existing.copyWith(
          genres: existing.genres.trim().isNotEmpty
              ? existing.genres
              : details.genres.join(', '),
          releaseYear:
              existing.releaseYear > 0 ? existing.releaseYear : details.releaseYear,
          totalSeasons:
              existing.totalSeasons > 0 ? existing.totalSeasons : details.totalSeasons,
          totalEpisodes: existing.totalEpisodes > 0
              ? existing.totalEpisodes
              : details.totalEpisodes,
          nextEpisodeAirDate:
              details.nextEpisodeAirDate ?? existing.nextEpisodeAirDate,
          nextEpisodeNumber: details.nextEpisodeNumber > 0
              ? details.nextEpisodeNumber
              : existing.nextEpisodeNumber,
          nextSeasonNumber: details.nextSeasonNumber > 0
              ? details.nextSeasonNumber
              : existing.nextSeasonNumber,
        );
        if (updated != existing) {
          _repo.saveDrama(updated);
        }
      }
    }
    return details;
  }

  void saveDrama(Drama drama) {
    final existing = _repo.getLocalDramaById(drama.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    final newDrama = drama.copyWith(
      addedAt: (existing != null && existing.addedAt > 0) ? existing.addedAt : now,
      updatedAt: now,
      completedAt: (drama.status == 'Done' && existing?.status != 'Done')
          ? now
          : (existing?.completedAt ?? 0),
    );
    _repo.saveDrama(newDrama);
    _scheduleDebouncedCloudSync(_repo.getAllDramasSync());
  }

  /// Quick +1 episode from Library / Continue Watching / Context Menu with Undo & celebration.
  void incrementEpisodeQuick(Drama drama) {
    final previous = drama;
    final nextEp = drama.totalEpisodes > 0
        ? (drama.episodesWatched + 1).clamp(0, drama.totalEpisodes)
        : drama.episodesWatched + 1;
    final reachedEnd = drama.totalEpisodes > 0 && nextEp >= drama.totalEpisodes;
    final newStatus = reachedEnd
        ? 'Done'
        : (drama.status == 'Planned' ? 'Watching' : drama.status);

    final updated = drama.copyWith(
      episodesWatched: nextEp,
      currentEpisode: nextEp,
      status: newStatus,
    );
    saveDrama(updated);

    if (reachedEnd && drama.status != 'Done') {
      triggerCompletionCelebration();
      ref.read(toastProvider.notifier).show(
            'Completed "${drama.title}"!',
            actionLabel: 'Undo',
            onAction: () => saveDrama(previous),
          );
    } else {
      ref.read(toastProvider.notifier).show(
            '${drama.title} · Episode $nextEp',
            actionLabel: 'Undo',
            onAction: () => saveDrama(previous),
          );
    }
  }

  void updateDramaStatus(int id, String status) {
    final existing = _repo.getLocalDramaById(id);
    if (existing != null) {
      saveDrama(existing.copyWith(status: status));
    }
  }

  Future<void> moveToRecycleBin(Drama drama) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = drama.copyWith(isDeleted: true, deletedAt: now, updatedAt: now);
    _repo.saveDrama(updated);
    if (_cloud.isSignedIn()) {
      unawaited(_cloud.syncToCloud(_repo.getAllDramasSync()).catchError((_) {}));
    }
  }

  Future<void> restoreDrama(Drama drama) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = drama.copyWith(isDeleted: false, deletedAt: 0, updatedAt: now);
    _repo.saveDrama(updated);
    if (_cloud.isSignedIn()) {
      unawaited(_cloud.syncToCloud(_repo.getAllDramasSync()).catchError((_) {}));
    }
  }

  Future<void> deleteDramaPermanently(Drama drama) async {
    _repo.deleteDrama(drama);
    if (_cloud.isSignedIn()) {
      unawaited(_cloud.syncToCloud(_repo.getAllDramasSync()).catchError((_) {}));
    }
  }

  Future<void> emptyRecycleBin() async {
    final deleted = _repo.getAllDramasSync().where((d) => d.isDeleted).toList();
    for (final d in deleted) {
      _repo.deleteDrama(d);
    }
    if (_cloud.isSignedIn()) {
      unawaited(_cloud.syncToCloud(_repo.getAllDramasSync()).catchError((_) {}));
    }
  }

  Future<bool> toggleTopFourFavorite(int dramaId) async {
    final added = await _settings.toggleTopFourFavorite(dramaId);
    unawaited(_circle.publishMyActivity(_repo.getAllDramasSync()));
    unawaited(_cloud.syncProfileOnly());
    return added;
  }

  Future<void> addCustomCollection(String name) async {
    await _settings.addCustomCollection(name);
    unawaited(_cloud.syncProfileOnly());
  }

  Future<void> deleteShelf(String name) async {
    await _settings.removeCustomCollection(name);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final drama in _repo.getAllDramasSync()) {
      if (drama.tagList.any((t) => t.toLowerCase() == name.toLowerCase())) {
        final newTags = drama.tagList
            .where((t) => t.toLowerCase() != name.toLowerCase())
            .join(', ');
        _repo.saveDrama(drama.copyWith(tags: newTags, updatedAt: now));
      }
    }
    unawaited(_cloud.syncProfileOnly());
  }

  Future<void> renameShelf(String oldName, String newName) async {
    final cleanNew = newName.trim();
    if (cleanNew.isEmpty || cleanNew.toLowerCase() == oldName.toLowerCase()) {
      return;
    }
    await _settings.renameCustomCollection(oldName, cleanNew);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final drama in _repo.getAllDramasSync()) {
      if (drama.tagList.any((t) => t.toLowerCase() == oldName.toLowerCase())) {
        final newTags = drama.tagList
            .map((t) => t.toLowerCase() == oldName.toLowerCase() ? cleanNew : t)
            .toSet()
            .join(', ');
        _repo.saveDrama(drama.copyWith(tags: newTags, updatedAt: now));
      }
    }
    unawaited(_cloud.syncProfileOnly());
  }

  Future<void> setDramaHiddenFromCircle(int dramaId, bool hidden) async {
    await _settings.setDramaHiddenFromCircle(dramaId, hidden);
    unawaited(_circle.publishMyActivity(_repo.getAllDramasSync()));
  }

  Future<void> saveTmdbApiKey(String key) async {
    await _secure.setTmdbCredential(key);
    ref.read(hasApiKeyProvider.notifier).state =
        _secure.getTmdbCredential().isNotEmpty;
    if (_secure.getTmdbCredential().isNotEmpty) {
      unawaited(loadDiscoverRails(forceRefresh: true));
    }
  }

  void clearMetadataCache() {
    _repo.clearMetadataCache();
  }

  // --- Export / Import (.moglog AES-256-GCM + CSV) ---
  Future<Uint8List> buildExportBytes({String? passphrase}) async {
    final active = _repo.getAllDramasSync().where((d) => !d.isDeleted).toList();
    if (passphrase != null && passphrase.trim().isNotEmpty) {
      final plainJson = jsonEncode(active.map((d) => d.toJson()).toList());
      final envelope = await BackupCryptoEnvelope.encrypt(
        plaintextJson: plainJson,
        passphrase: passphrase,
        uid: 'local',
      );
      return Uint8List.fromList(
        utf8.encode(BackupCryptoEnvelope.serializeEnvelope(envelope)),
      );
    } else {
      final csv = exportDramasToCsv(active);
      return Uint8List.fromList(utf8.encode(csv));
    }
  }

  Future<ImportSummary> importBackupBytes(
    Uint8List bytes, {
    String? passphrase,
  }) async {
    const maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      return const ImportSummary(
        added: 0,
        updated: 0,
        skipped: 0,
        errorMessage: 'Backup file exceeds 10 MB limit.',
      );
    }
    final rawText = utf8.decode(bytes, allowMalformed: true);
    if (rawText.trim().isEmpty) {
      return const ImportSummary(
        added: 0,
        updated: 0,
        skipped: 0,
        errorMessage: 'Selected file is empty.',
      );
    }

    final trimmedStart = rawText.trimLeft();
    if (!trimmedStart.startsWith('[') && !trimmedStart.startsWith('{')) {
      return _importCsvHistory(rawText);
    }

    final envelope = BackupCryptoEnvelope.parseEnvelopeOrNull(rawText);
    if (envelope == null) {
      return const ImportSummary(
        added: 0,
        updated: 0,
        skipped: 0,
        errorMessage:
            'Unsupported file format. Please select an encrypted .moglog or CSV file.',
      );
    }
    if (passphrase == null || passphrase.trim().isEmpty) {
      return const ImportSummary(
        added: 0,
        updated: 0,
        skipped: 0,
        errorMessage: 'Passphrase required to unlock encrypted .moglog backup.',
      );
    }

    String decryptedJson;
    try {
      decryptedJson = await BackupCryptoEnvelope.decrypt(
        envelope: envelope,
        passphrase: passphrase,
      );
    } catch (_) {
      return const ImportSummary(
        added: 0,
        updated: 0,
        skipped: 0,
        errorMessage: 'Incorrect passphrase or corrupted encrypted backup.',
      );
    }

    final imported = CloudSyncRepository.parseDramasFromJson(decryptedJson);
    final localMap = {for (final d in _repo.getAllDramasSync()) d.id: d};
    final seenIds = <int>{};
    var added = 0;
    var updated = 0;
    var skipped = 0;

    for (final incoming in imported) {
      if (!seenIds.add(incoming.id)) continue;
      if (incoming.id <= 0 || incoming.title.trim().isEmpty) {
        skipped++;
        continue;
      }
      final sanitized = incoming.copyWith(
        rating: incoming.rating.clamp(0.0, 10.0),
        myRating: incoming.myRating.clamp(0.0, 10.0),
        episodesWatched: incoming.episodesWatched < 0 ? 0 : incoming.episodesWatched,
        totalEpisodes: incoming.totalEpisodes < 0 ? 0 : incoming.totalEpisodes,
        status: const ['Watching', 'Planned', 'Done'].contains(incoming.status)
            ? incoming.status
            : 'Planned',
      );
      final existing = localMap[sanitized.id];
      if (existing == null) {
        _repo.saveDrama(sanitized);
        added++;
      } else if (sanitized.updatedAt > existing.updatedAt) {
        _repo.saveDrama(sanitized);
        updated++;
      } else {
        skipped++;
      }
    }
    return ImportSummary(added: added, updated: updated, skipped: skipped);
  }

  Future<ImportSummary> _importCsvHistory(String rawCsv) async {
    final grouped = parseCsvHistoryRows(rawCsv);
    if (grouped.isEmpty) {
      return const ImportSummary(
        added: 0,
        updated: 0,
        skipped: 0,
        errorMessage: 'CSV file contains no show rows.',
      );
    }

    final localAll = _repo.getAllDramasSync();
    final localById = {for (final d in localAll) d.id: d};
    final localByTitle = {for (final d in localAll) d.title.toLowerCase(): d};
    final now = DateTime.now().millisecondsSinceEpoch;
    var added = 0;
    var updated = 0;
    var skipped = 0;
    var tmdbLookups = 0;

    for (final entry in grouped.entries) {
      final key = entry.key;
      final item = entry.value;
      final effectiveEps = item.effectiveEpisodes;
      final existing =
          (item.tmdbId > 0 ? localById[item.tmdbId] : null) ?? localByTitle[key];

      if (existing != null) {
        final mergedEps =
            effectiveEps > existing.episodesWatched ? effectiveEps : existing.episodesWatched;
        final mergedRating =
            existing.myRating > 0.0 ? existing.myRating : item.rating;
        if (mergedEps != existing.episodesWatched ||
            mergedRating != existing.myRating) {
          _repo.saveDrama(
            existing.copyWith(
              episodesWatched: mergedEps,
              myRating: mergedRating,
              updatedAt: now,
            ),
          );
          updated++;
        } else {
          skipped++;
        }
        continue;
      }

      Drama? resolved;
      if (_secure.getTmdbCredential().isNotEmpty && tmdbLookups < 35) {
        tmdbLookups++;
        if (item.tmdbId > 0) {
          resolved = await _repo.getDramaDetails(item.tmdbId);
        } else {
          final results = await _repo.searchDramas(item.title);
          if (results.isNotEmpty) resolved = results.first;
        }
      }

      final finalId = resolved?.id ??
          (item.tmdbId > 0
              ? item.tmdbId
              : (item.title.toLowerCase().hashCode & 0x7FFFFFFF));
      if (finalId <= 0) {
        skipped++;
        continue;
      }

      String finalStatus;
      if (resolved != null &&
          resolved.totalEpisodes > 0 &&
          effectiveEps >= resolved.totalEpisodes) {
        finalStatus = 'Done';
      } else if (const ['Watching', 'Planned', 'Done'].contains(item.status)) {
        finalStatus = item.status;
      } else if (effectiveEps > 0) {
        finalStatus = 'Watching';
      } else {
        finalStatus = 'Planned';
      }

      final newDrama = Drama(
        id: finalId,
        title: resolved?.title ?? item.title,
        overview: resolved?.overview ?? '',
        posterPath: resolved?.posterPath ?? '',
        rating: resolved?.rating ?? 0.0,
        status: finalStatus,
        episodesWatched: effectiveEps,
        totalEpisodes: resolved?.totalEpisodes ?? 0,
        currentSeason: item.maxSeason < 1 ? 1 : item.maxSeason,
        currentEpisode: effectiveEps,
        totalSeasons: resolved?.totalSeasons ?? 0,
        releaseYear: resolved?.releaseYear ?? 0,
        genres: resolved?.genres ?? '',
        myRating: item.rating,
        addedAt: now,
        updatedAt: now,
        completedAt: finalStatus == 'Done' ? now : 0,
      );
      _repo.saveDrama(newDrama);
      added++;
    }

    return ImportSummary(added: added, updated: updated, skipped: skipped);
  }

  void dispose() {
    _searchDebounce?.cancel();
    _cloudSyncDebounce?.cancel();
    _realtimeSub?.cancel();
  }
}

final dramaControllerProvider = Provider<DramaController>((ref) {
  final ctrl = DramaController(ref);
  ref.onDispose(ctrl.dispose);
  return ctrl;
});

// ---------------------------------------------------------------------------
// Auth & Watch Circle Controller (1:1 port of Kotlin AuthViewModel)
// ---------------------------------------------------------------------------

class AuthUiState {
  final User? user;
  final bool isSyncing;
  final bool isLoadingCircle;
  final List<FriendProfile> circleFriends;
  final List<CircleNudge> circleNudges;
  final bool pendingCreateAccountPrompt;

  const AuthUiState({
    this.user,
    this.isSyncing = false,
    this.isLoadingCircle = false,
    this.circleFriends = const [],
    this.circleNudges = const [],
    this.pendingCreateAccountPrompt = false,
  });

  AuthUiState copyWith({
    Object? user = _sentinel,
    bool? isSyncing,
    bool? isLoadingCircle,
    List<FriendProfile>? circleFriends,
    List<CircleNudge>? circleNudges,
    bool? pendingCreateAccountPrompt,
  }) {
    return AuthUiState(
      user: identical(user, _sentinel) ? this.user : user as User?,
      isSyncing: isSyncing ?? this.isSyncing,
      isLoadingCircle: isLoadingCircle ?? this.isLoadingCircle,
      circleFriends: circleFriends ?? this.circleFriends,
      circleNudges: circleNudges ?? this.circleNudges,
      pendingCreateAccountPrompt:
          pendingCreateAccountPrompt ?? this.pendingCreateAccountPrompt,
    );
  }
}

class AuthController extends StateNotifier<AuthUiState> {
  final Ref ref;
  StreamSubscription<User?>? _authSub;

  AuthController(this.ref) : super(const AuthUiState()) {
    if (Firebase.apps.isNotEmpty) {
      final auth = FirebaseAuth.instance;
      state = state.copyWith(user: auth.currentUser);
      _authSub = auth.authStateChanges().listen((user) {
        state = state.copyWith(user: user);
        ref.read(dramaControllerProvider).ensureRealtimeListenerStarted();
        if (user != null) {
          ref.read(watchCircleRepositoryProvider).startListeningForCircleMembers();
          unawaited(ref.read(dramaControllerProvider).reconcileCloudAndLocal());
        } else {
          ref.read(watchCircleRepositoryProvider).stopListeningForCircleMembers();
        }
      });
    }
  }

  CloudSyncRepository get _cloud => ref.read(cloudSyncRepositoryProvider);
  WatchCircleRepository get _circle => ref.read(watchCircleRepositoryProvider);
  DramaRepositoryImpl get _repo => ref.read(dramaRepositoryProvider);

  Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<String?> signInWithGoogle() async {
    if (Firebase.apps.isEmpty) {
      return 'Firebase is not yet configured for com.skech.moglog.flutter. Run flutterfire configure to enable Google Cloud Sync.';
    }
    if (!await isOnline()) {
      return 'Offline: Connect to the internet to sign in.';
    }
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final user = userCred.user;
      if (user == null) return 'Google Sign-In failed.';

      final exists = await _cloud.checkAccountExists(user.uid);
      if (!exists) {
        state = state.copyWith(user: user, pendingCreateAccountPrompt: true);
      } else {
        state = state.copyWith(user: user);
        unawaited(fetchFromCloud().catchError((_) => null));
        unawaited(refreshWatchCircle());
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> confirmCreateCloudAccount() async {
    state = state.copyWith(pendingCreateAccountPrompt: false);
    await syncToCloud();
    await refreshWatchCircle();
  }

  Future<void> cancelCreateCloudAccount() async {
    state = state.copyWith(pendingCreateAccountPrompt: false);
    await signOut();
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    if (Firebase.apps.isNotEmpty) {
      await FirebaseAuth.instance.signOut();
    }
    _circle.stopListeningForCircleMembers();
    state = const AuthUiState();
  }

  Future<bool> checkCloudHasShows() => _cloud.checkCloudHasShows();

  Future<bool> syncToCloud() async {
    if (!await isOnline()) {
      ref.read(toastProvider.notifier).show('Offline: Cannot sync to cloud.');
      return false;
    }
    if (!_cloud.isSignedIn()) return false;
    state = state.copyWith(isSyncing: true);
    try {
      final dramas = _repo.getAllDramasSync();
      await _cloud.syncToCloud(dramas).timeout(const Duration(seconds: 15));
      await _circle.publishMyActivity(dramas);
      state = state.copyWith(isSyncing: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSyncing: false);
      ref.read(toastProvider.notifier).show('Sync failed: $e');
      return false;
    }
  }

  Future<CloudData?> fetchFromCloud({String? explicitPassphrase}) async {
    if (!await isOnline()) {
      throw StateError('Device is offline. Check internet connection.');
    }
    state = state.copyWith(isSyncing: true);
    try {
      final data = await _cloud
          .fetchFromCloud(explicitPassphrase: explicitPassphrase)
          .timeout(const Duration(seconds: 30));
      if (data != null && data.dramas.isNotEmpty) {
        final localMap = {for (final d in _repo.getAllDramasSync()) d.id: d};
        for (final remote in data.dramas) {
          final local = localMap[remote.id];
          if (local == null || remote.updatedAt >= local.updatedAt) {
            _repo.saveDrama(remote);
          }
        }
      }
      state = state.copyWith(isSyncing: false);
      return data;
    } catch (e) {
      state = state.copyWith(isSyncing: false);
      rethrow;
    }
  }

  Future<void> syncProfileOnly() async {
    if (!await isOnline() || state.user == null) return;
    await _cloud.syncProfileOnly();
    await _circle.publishMyActivity(_repo.getAllDramasSync());
  }

  Future<String?> deleteAccount({required bool deleteLocalData}) async {
    final user = state.user;
    if (user == null) return 'Not signed in';
    try {
      await _cloud.deleteUserCloudData(
        inviteCodes: {
          _circle.getMyInviteCode(),
          WatchCircleRepository.generateInviteCode(user.uid),
        },
      );
      if (deleteLocalData) {
        _repo.clearAllDramas();
      }
      await signOut();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // --- Watch Circle ---
  String getMyInviteCode() => _circle.getMyInviteCode();

  Future<String> rotateMyInviteCode() async {
    if (!await isOnline()) {
      throw StateError('Offline: Connect to the internet to rotate your Circle Code.');
    }
    state = state.copyWith(isLoadingCircle: true);
    try {
      return await _circle.rotateMyInviteCode(_repo.getAllDramasSync());
    } finally {
      state = state.copyWith(isLoadingCircle: false);
    }
  }

  Future<void> refreshWatchCircle() async {
    if (!await isOnline() || state.user == null) return;
    state = state.copyWith(isLoadingCircle: true);
    try {
      final (friends, nudges) =
          await _circle.fetchWatchCircle(_repo.getAllDramasSync());
      state = state.copyWith(
        circleFriends: friends,
        circleNudges: nudges,
        isLoadingCircle: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingCircle: false);
    }
  }

  Future<FriendProfile> joinCircleByCode(String code) async {
    if (!await isOnline()) {
      throw StateError('Offline: Connect to the internet to join a Watch Circle.');
    }
    state = state.copyWith(isLoadingCircle: true);
    try {
      final friend =
          await _circle.joinByInviteCode(code, _repo.getAllDramasSync());
      final updatedFriends = List<FriendProfile>.from(state.circleFriends);
      final idx = updatedFriends.indexWhere((f) => f.uid == friend.uid);
      if (idx >= 0) {
        updatedFriends[idx] = friend;
      } else {
        updatedFriends.insert(0, friend);
      }
      state = state.copyWith(circleFriends: updatedFriends);
      unawaited(refreshWatchCircle());
      return friend;
    } finally {
      state = state.copyWith(isLoadingCircle: false);
    }
  }

  Future<void> removeFriendFromCircle(String friendUid) async {
    state = state.copyWith(
      circleFriends:
          state.circleFriends.where((f) => f.uid != friendUid).toList(),
    );
    await _circle.removeFriend(friendUid);
    await refreshWatchCircle();
  }

  Future<bool> sendNudge({
    required String toUid,
    required int dramaId,
    required String dramaTitle,
    required String emoji,
    required String message,
  }) {
    return _circle.sendNudge(
      toUid: toUid,
      dramaId: dramaId,
      dramaTitle: dramaTitle,
      emoji: emoji,
      message: message,
    );
  }

  Future<void> dismissNudge(String nudgeId) async {
    state = state.copyWith(
      circleNudges: state.circleNudges.where((n) => n.id != nudgeId).toList(),
    );
    await _circle.dismissNudge(nudgeId);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) => AuthController(ref));

/// Helper to keep Android `FLAG_SECURE` synchronized with settings.
Future<void> syncFlagSecure(AppSettings settings) async {
  if (Platform.isAndroid) {
    await PlatformBridge.setFlagSecure(
      settings.hideInRecents || settings.appLockEnabled,
    );
  }
}

const Object _sentinel = Object();
