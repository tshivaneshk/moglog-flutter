import 'dart:convert';

import '../../domain/model/drama.dart';
import '../../domain/model/drama_extra_details.dart';
import '../../domain/model/shortcut.dart';
import '../local/app_database.dart';
import '../remote/tmdb_api.dart';

class _CachedList {
  final List<Drama> items;
  final int timestamp;
  const _CachedList(this.items, this.timestamp);
}

/// 1:1 port of Kotlin `DramaRepositoryImpl`:
/// - Local SQLCipher DB
/// - 7-day persistent detail cache (`drama_details_cache`) with stale offline fallback
/// - 30-min in-memory Discover & Search caches
class DramaRepositoryImpl {
  static const int _cacheTtlMs = 7 * 24 * 60 * 60 * 1000;
  static const int _discoverMemoryTtlMs = 30 * 60 * 1000;

  final TmdbApi api;
  final AppDatabase db;

  final Map<String, _CachedList> _searchMemoryCache = {};
  final Map<String, _CachedList> _railMemoryCache = {};
  final Map<String, Future<List<Drama>>> _inFlightRails = {};
  final Map<int, DramaExtraDetails> _extraMemoryCache = {};

  DramaRepositoryImpl({required this.api, required this.db});

  Stream<List<Drama>> watchAllDramas() => db.watchAllDramas();

  List<Drama> getAllDramasSync() => db.getAllDramasSync();

  Drama? getLocalDramaById(int id) => db.getDramaById(id);

  Future<List<Drama>> searchDramas(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _searchMemoryCache[normalized];
    if (cached != null && (now - cached.timestamp) < _discoverMemoryTtlMs) {
      return cached.items;
    }
    try {
      final results = await api.searchDramas(query);
      if (results.isNotEmpty) {
        _searchMemoryCache[normalized] = _CachedList(results, now);
      }
      return results;
    } catch (_) {
      return cached?.items ?? const [];
    }
  }

  Future<List<Drama>> getTrendingDramas({bool forceRefresh = false}) =>
      _fetchCachedRail('trending', api.getTrendingDramas, forceRefresh: forceRefresh);

  Future<List<Drama>> getPopularDramas({bool forceRefresh = false}) =>
      _fetchCachedRail('popular', api.getPopularDramas, forceRefresh: forceRefresh);

  Future<List<Drama>> getAiringTodayDramas({bool forceRefresh = false}) =>
      _fetchCachedRail('airing_today', api.getAiringTodayDramas, forceRefresh: forceRefresh);

  Future<List<Drama>> getOnTheAirDramas({bool forceRefresh = false}) =>
      _fetchCachedRail('on_the_air', api.getOnTheAirDramas, forceRefresh: forceRefresh);

  Future<List<Drama>> _fetchCachedRail(
    String key,
    Future<List<Drama>> Function() fetcher, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _railMemoryCache[key];
    if (!forceRefresh &&
        cached != null &&
        (now - cached.timestamp) < _discoverMemoryTtlMs) {
      return cached.items;
    }
    final inFlight = _inFlightRails[key];
    if (!forceRefresh && inFlight != null) {
      return inFlight;
    }
    final Future<List<Drama>> future = () async {
      try {
        final fresh = await fetcher();
        if (fresh.isNotEmpty) {
          _railMemoryCache[key] =
              _CachedList(fresh, DateTime.now().millisecondsSinceEpoch);
        }
        return fresh;
      } catch (_) {
        return cached?.items ?? const <Drama>[];
      } finally {
        _inFlightRails.remove(key);
      }
    }();
    _inFlightRails[key] = future;
    return future;
  }

  /// Synchronous/instant lookup of extra details from RAM or 7-day SQLite cache.
  DramaExtraDetails? getDramaExtraDetailsImmediate(
    int id, {
    bool allowStale = false,
  }) {
    final mem = _extraMemoryCache[id];
    if (mem != null) return mem;

    final cached = db.getDetailCache(id);
    if (cached == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!allowStale && (now - cached.cachedAt) >= _cacheTtlMs) {
      return null;
    }
    try {
      final decoded = jsonDecode(cached.payloadJson) as Map<String, dynamic>;
      final parsed = DramaExtraDetails.fromJson(decoded);
      if (_extraMemoryCache.length >= 64) {
        _extraMemoryCache.remove(_extraMemoryCache.keys.first);
      }
      _extraMemoryCache[id] = parsed;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// Fetches both summary and extra details in a SINGLE TMDB API call (with 7-day cache).
  Future<({Drama? drama, DramaExtraDetails? extra})> fetchFullDrama(
    int id, {
    bool skipSummaryFetchIfCached = false,
  }) async {
    final cachedExtra = getDramaExtraDetailsImmediate(id);
    if (cachedExtra != null && skipSummaryFetchIfCached) {
      return (drama: null, extra: cachedExtra);
    }

    try {
      final dto = await api.getRawDramaDetails(id);
      if (dto == null) throw Exception('Empty TMDB response');
      final summary = TmdbApi.dtoToDomainSummary(dto);
      final details = TmdbApi.parseExtraDetails(dto);
      final now = DateTime.now().millisecondsSinceEpoch;
      db.putDetailCache(id, jsonEncode(details.toJson()), now);
      if (_extraMemoryCache.length >= 64) {
        _extraMemoryCache.remove(_extraMemoryCache.keys.first);
      }
      _extraMemoryCache[id] = details;
      return (drama: summary, extra: details);
    } catch (_) {
      final stale = cachedExtra ??
          getDramaExtraDetailsImmediate(id, allowStale: true);
      return (drama: null, extra: stale);
    }
  }

  Future<Drama?> getDramaDetails(int id) async {
    final bundle = await fetchFullDrama(id);
    return bundle.drama;
  }

  Future<DramaExtraDetails?> getDramaExtraDetails(int id) async {
    final cached = getDramaExtraDetailsImmediate(id);
    if (cached != null) return cached;
    final bundle = await fetchFullDrama(id);
    return bundle.extra;
  }

  void saveDrama(Drama drama) => db.upsertDrama(drama);

  void updateDramaStatus(int id, String status) => db.updateDramaStatus(id, status);

  void deleteDrama(Drama drama) => db.deleteDramaById(drama.id);

  void clearAllDramas() => db.clearAllDramas();

  void clearMetadataCache() {
    db.clearDetailCache();
    api.clearMemoryCache();
    _searchMemoryCache.clear();
    _railMemoryCache.clear();
    _extraMemoryCache.clear();
  }

  Shortcut? getShortcutForDrama(int dramaId) => db.getShortcutForDrama(dramaId);

  void saveShortcutForDrama(int dramaId, Shortcut? shortcut) =>
      db.saveShortcutForDrama(dramaId, shortcut);
}
