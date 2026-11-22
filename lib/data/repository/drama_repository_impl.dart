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
    try {
      final fresh = await fetcher();
      if (fresh.isNotEmpty) {
        _railMemoryCache[key] = _CachedList(fresh, now);
      }
      return fresh;
    } catch (_) {
      return cached?.items ?? const [];
    }
  }

  Future<Drama?> getDramaDetails(int id) async {
    try {
      final dto = await api.getRawDramaDetails(id);
      if (dto == null) return null;
      return TmdbApi.dtoToDomainSummary(dto);
    } catch (_) {
      return null;
    }
  }

  Future<DramaExtraDetails?> getDramaExtraDetails(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = db.getDetailCache(id);
    if (cached != null && (now - cached.cachedAt) < _cacheTtlMs) {
      try {
        final decoded = jsonDecode(cached.payloadJson) as Map<String, dynamic>;
        return DramaExtraDetails.fromJson(decoded);
      } catch (_) {}
    }

    try {
      final dto = await api.getRawDramaDetails(id);
      if (dto == null) throw Exception('Empty TMDB response');
      final details = TmdbApi.parseExtraDetails(dto);
      db.putDetailCache(id, jsonEncode(details.toJson()), now);
      return details;
    } catch (_) {
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached.payloadJson) as Map<String, dynamic>;
          return DramaExtraDetails.fromJson(decoded);
        } catch (_) {}
      }
      return null;
    }
  }

  void saveDrama(Drama drama) => db.upsertDrama(drama);

  void updateDramaStatus(int id, String status) => db.updateDramaStatus(id, status);

  void deleteDrama(Drama drama) => db.deleteDramaById(drama.id);

  void clearAllDramas() => db.clearAllDramas();

  void clearMetadataCache() {
    db.clearDetailCache();
    _searchMemoryCache.clear();
    _railMemoryCache.clear();
  }

  Shortcut? getShortcutForDrama(int dramaId) => db.getShortcutForDrama(dramaId);

  void saveShortcutForDrama(int dramaId, Shortcut? shortcut) =>
      db.saveShortcutForDrama(dramaId, shortcut);
}
