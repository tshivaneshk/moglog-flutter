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
  static const int discoverCacheTtlMs = 6 * 60 * 60 * 1000; // 6 hours
  static const int _searchMemoryTtlMs = 60 * 60 * 1000; // 1 hour

  static const Map<String, int> _railDbCacheIds = {
    'trending': -1001,
    'popular': -1002,
    'airing_today': -1003,
    'on_the_air': -1004,
  };

  final TmdbApi api;
  final AppDatabase db;

  final Map<String, _CachedList> _searchMemoryCache = {};
  final Map<String, Future<List<Drama>>> _inFlightSearches = {};
  final Map<String, _CachedList> _railMemoryCache = {};
  final Map<String, Future<List<Drama>>> _inFlightRails = {};
  final Map<int, Drama> _summaryMemoryCache = {};
  final Map<int, DramaExtraDetails> _extraMemoryCache = {};
  final Map<int, Future<({Drama? drama, DramaExtraDetails? extra})>>
      _inFlightFullDramas = {};

  DramaRepositoryImpl({required this.api, required this.db});

  Stream<List<Drama>> watchAllDramas() => db.watchAllDramas();

  List<Drama> getAllDramasSync() => db.getAllDramasSync();

  Drama? getLocalDramaById(int id) => db.getDramaById(id);

  Future<List<Drama>> searchDramas(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _searchMemoryCache[normalized];
    if (cached != null && (now - cached.timestamp) < _searchMemoryTtlMs) {
      return cached.items;
    }
    final inFlight = _inFlightSearches[normalized];
    if (inFlight != null) return inFlight;

    final Future<List<Drama>> future = () async {
      try {
        final results = await api.searchDramas(query);
        if (results.isNotEmpty) {
          _searchMemoryCache[normalized] = _CachedList(
            results,
            DateTime.now().millisecondsSinceEpoch,
          );
          for (final d in results) {
            _summaryMemoryCache[d.id] = d;
          }
        }
        return results;
      } catch (_) {
        return cached?.items ?? const <Drama>[];
      } finally {
        _inFlightSearches.remove(normalized);
      }
    }();
    _inFlightSearches[normalized] = future;
    return future;
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
        (now - cached.timestamp) < discoverCacheTtlMs) {
      return cached.items;
    }

    // Check L2 SQLCipher persistent cache (6-hour TTL) before making any network request
    final dbId = _railDbCacheIds[key];
    List<Drama>? staleDbItems;
    if (dbId != null) {
      final dbCached = db.getDetailCache(dbId);
      if (dbCached != null) {
        try {
          final decoded = jsonDecode(dbCached.payloadJson);
          if (decoded is List) {
            final parsed = decoded
                .whereType<Map>()
                .map((m) => Drama.fromJson(Map<String, dynamic>.from(m)))
                .where((d) => d.id > 0 && d.title.isNotEmpty)
                .toList();
            if (parsed.isNotEmpty) {
              staleDbItems = parsed;
              for (final d in parsed) {
                _summaryMemoryCache[d.id] = d;
              }
              if (!forceRefresh &&
                  (now - dbCached.cachedAt) < discoverCacheTtlMs) {
                _railMemoryCache[key] = _CachedList(parsed, dbCached.cachedAt);
                return parsed;
              }
            }
          }
        } catch (_) {}
      }
    }

    final inFlight = _inFlightRails[key];
    if (!forceRefresh && inFlight != null) {
      return inFlight;
    }
    final Future<List<Drama>> future = () async {
      try {
        final fresh = await fetcher();
        if (fresh.isNotEmpty) {
          final fetchedAt = DateTime.now().millisecondsSinceEpoch;
          _railMemoryCache[key] = _CachedList(fresh, fetchedAt);
          for (final d in fresh) {
            _summaryMemoryCache[d.id] = d;
          }
          if (dbId != null) {
            try {
              db.putDetailCache(
                dbId,
                jsonEncode(fresh.map((d) => d.toJson()).toList()),
                fetchedAt,
              );
            } catch (_) {}
          }
          return fresh;
        }
        return cached?.items ?? staleDbItems ?? const <Drama>[];
      } catch (_) {
        return cached?.items ?? staleDbItems ?? const <Drama>[];
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

  /// Fetches both summary and extra details in a SINGLE TMDB API call (with 7-day cache & in-flight deduplication).
  Future<({Drama? drama, DramaExtraDetails? extra})> fetchFullDrama(
    int id, {
    bool skipSummaryFetchIfCached = false,
  }) async {
    final cachedExtra = getDramaExtraDetailsImmediate(id);
    final cachedSummary = _summaryMemoryCache[id] ?? db.getDramaById(id);
    if (cachedExtra != null &&
        (skipSummaryFetchIfCached || cachedSummary != null)) {
      return (drama: cachedSummary, extra: cachedExtra);
    }

    final inFlight = _inFlightFullDramas[id];
    if (inFlight != null) return inFlight;

    final Future<({Drama? drama, DramaExtraDetails? extra})> future = () async {
      try {
        final dto = await api.getRawDramaDetails(id);
        if (dto == null) throw Exception('Empty TMDB response');
        final summary = TmdbApi.dtoToDomainSummary(dto);
        final details = TmdbApi.parseExtraDetails(dto);
        final now = DateTime.now().millisecondsSinceEpoch;
        db.putDetailCache(id, jsonEncode(details.toJson()), now);
        if (summary != null) {
          _summaryMemoryCache[id] = summary;
        }
        for (final rec in details.recommendations) {
          _summaryMemoryCache[rec.id] = rec;
        }
        if (_extraMemoryCache.length >= 64) {
          _extraMemoryCache.remove(_extraMemoryCache.keys.first);
        }
        _extraMemoryCache[id] = details;
        return (drama: summary, extra: details);
      } catch (_) {
        final stale = cachedExtra ??
            getDramaExtraDetailsImmediate(id, allowStale: true);
        return (drama: cachedSummary, extra: stale);
      } finally {
        _inFlightFullDramas.remove(id);
      }
    }();
    _inFlightFullDramas[id] = future;
    return future;
  }

  Future<Drama?> getDramaDetails(int id) async {
    final cachedSummary = _summaryMemoryCache[id] ?? db.getDramaById(id);
    if (cachedSummary != null) return cachedSummary;
    final bundle = await fetchFullDrama(id);
    return bundle.drama;
  }

  Future<DramaExtraDetails?> getDramaExtraDetails(int id) async {
    final cached = getDramaExtraDetailsImmediate(id);
    if (cached != null) return cached;
    final bundle = await fetchFullDrama(id, skipSummaryFetchIfCached: true);
    return bundle.extra;
  }

  void saveDrama(Drama drama) {
    _summaryMemoryCache[drama.id] = drama;
    db.upsertDrama(drama);
  }

  void saveDramasBatch(List<Drama> dramas) {
    if (dramas.isEmpty) return;
    for (final d in dramas) {
      _summaryMemoryCache[d.id] = d;
    }
    db.upsertDramasBatch(dramas);
  }

  void updateDramaStatus(int id, String status) => db.updateDramaStatus(id, status);

  void deleteDrama(Drama drama) => db.deleteDramaById(drama.id);

  void clearAllDramas() => db.clearAllDramas();

  void clearMetadataCache() {
    db.clearDetailCache();
    api.clearMemoryCache();
    _searchMemoryCache.clear();
    _inFlightSearches.clear();
    _railMemoryCache.clear();
    _summaryMemoryCache.clear();
    _extraMemoryCache.clear();
    _inFlightFullDramas.clear();
  }

  Shortcut? getShortcutForDrama(int dramaId) => db.getShortcutForDrama(dramaId);

  void saveShortcutForDrama(int dramaId, Shortcut? shortcut) =>
      db.saveShortcutForDrama(dramaId, shortcut);
}
