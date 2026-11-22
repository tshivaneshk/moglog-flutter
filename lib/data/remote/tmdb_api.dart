import 'dart:ui' as ui;

import 'package:dio/dio.dart';

import '../../core/security/secure_store.dart';
import '../../domain/model/drama.dart';
import '../../domain/model/drama_extra_details.dart';

class TmdbApi {
  static const String baseUrl = 'https://api.themoviedb.org/3/';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBaseUrl = 'https://image.tmdb.org/t/p/w780';
  static const String logoBaseUrl = 'https://image.tmdb.org/t/p/w154';
  static const String thumbBaseUrl = 'https://image.tmdb.org/t/p/w185';

  static const Map<int, String> genreMap = {
    10759: 'Action & Adventure',
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10762: 'Kids',
    10402: 'Music',
    9648: 'Mystery',
    10763: 'News',
    10764: 'Reality',
    10749: 'Romance',
    10765: 'Sci-Fi & Fantasy',
    878: 'Science Fiction',
    10766: 'Soap',
    10767: 'Talk',
    53: 'Thriller',
    10768: 'War & Politics',
    10752: 'War',
    37: 'Western',
  };

  final SecureStore secureStore;
  late final Dio _dio;

  TmdbApi({required this.secureStore, Dio? dio}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 15),
            headers: const {'Accept': 'application/json'},
          ),
        );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final cred = secureStore.getTmdbCredential().trim();
          if (cred.isNotEmpty) {
            if (secureStore.isBearerToken(cred)) {
              options.headers['Authorization'] = 'Bearer $cred';
            } else {
              options.queryParameters = {
                ...options.queryParameters,
                'api_key': cred,
              };
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<List<Drama>> searchDramas(String query) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'search/tv',
      queryParameters: {'query': query, 'language': 'en-US'},
    );
    return _parseResultsList(res.data);
  }

  Future<List<Drama>> getTrendingDramas() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'trending/tv/week',
      queryParameters: {'language': 'en-US'},
    );
    return _parseResultsList(res.data);
  }

  Future<List<Drama>> getPopularDramas() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'tv/popular',
      queryParameters: {'language': 'en-US'},
    );
    return _parseResultsList(res.data);
  }

  Future<List<Drama>> getAiringTodayDramas() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'tv/airing_today',
      queryParameters: {'language': 'en-US'},
    );
    return _parseResultsList(res.data);
  }

  Future<List<Drama>> getOnTheAirDramas() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'tv/on_the_air',
      queryParameters: {'language': 'en-US'},
    );
    return _parseResultsList(res.data);
  }

  Future<Map<String, dynamic>?> getRawDramaDetails(int id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'tv/$id',
      queryParameters: {
        'language': 'en-US',
        'append_to_response':
            'credits,videos,watch/providers,recommendations,reviews',
      },
    );
    return res.data;
  }

  List<Drama> _parseResultsList(Map<String, dynamic>? data) {
    final raw = data?['results'];
    if (raw is! List) return const [];
    final list = <Drama>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final d = dtoToDomainSummary(item);
        if (d != null) list.add(d);
      }
    }
    return list;
  }

  static Drama? dtoToDomainSummary(Map<String, dynamic> dto) {
    final name = (dto['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final firstAirDate = dto['first_air_date'] as String?;
    final parsedYear = (firstAirDate != null && firstAirDate.length >= 4)
        ? (int.tryParse(firstAirDate.substring(0, 4)) ?? 0)
        : 0;

    final genreNames = <String>[];
    final genresRaw = dto['genres'];
    if (genresRaw is List && genresRaw.isNotEmpty) {
      for (final g in genresRaw) {
        if (g is Map && g['name'] is String && (g['name'] as String).isNotEmpty) {
          genreNames.add(g['name'] as String);
        }
      }
    } else if (dto['genre_ids'] is List) {
      for (final id in (dto['genre_ids'] as List)) {
        final mapped = genreMap[(id as num?)?.toInt()];
        if (mapped != null) genreNames.add(mapped);
      }
    }

    final posterPath = dto['poster_path'] as String?;
    final nextEp = dto['next_episode_to_air'] as Map<String, dynamic>?;

    return Drama(
      id: (dto['id'] as num?)?.toInt() ?? 0,
      title: name,
      overview: (dto['overview'] as String?) ?? '',
      rating: (dto['vote_average'] as num?)?.toDouble() ?? 0.0,
      posterPath: posterPath != null && posterPath.isNotEmpty
          ? '$imageBaseUrl$posterPath'
          : '',
      totalEpisodes: (dto['number_of_episodes'] as num?)?.toInt() ?? 0,
      totalSeasons: (dto['number_of_seasons'] as num?)?.toInt() ?? 0,
      releaseYear: parsedYear,
      genres: genreNames.join(', '),
      nextEpisodeAirDate: nextEp?['air_date'] as String?,
      nextEpisodeNumber: (nextEp?['episode_number'] as num?)?.toInt() ?? 0,
      nextSeasonNumber: (nextEp?['season_number'] as num?)?.toInt() ?? 0,
    );
  }

  static DramaExtraDetails parseExtraDetails(
    Map<String, dynamic> dto, {
    String? overrideCountryCode,
  }) {
    // Trailer
    String? trailerKey;
    final videosRaw = (dto['videos'] as Map<String, dynamic>?)?['results'];
    if (videosRaw is List) {
      for (final v in videosRaw.whereType<Map<String, dynamic>>()) {
        final site = (v['site'] as String? ?? '').toLowerCase();
        final type = (v['type'] as String? ?? '').toLowerCase();
        if (site == 'youtube' && (type == 'trailer' || type == 'teaser')) {
          trailerKey = v['key'] as String?;
          if (trailerKey != null && trailerKey.isNotEmpty) break;
        }
      }
    }

    // Cast (up to 12)
    final cast = <CastMember>[];
    final castRaw = (dto['credits'] as Map<String, dynamic>?)?['cast'];
    if (castRaw is List) {
      for (final c in castRaw.whereType<Map<String, dynamic>>().take(12)) {
        final profile = c['profile_path'] as String?;
        cast.add(
          CastMember(
            name: (c['name'] as String?) ?? '',
            character: (c['character'] as String?) ?? '',
            profilePath: profile != null && profile.isNotEmpty
                ? '$imageBaseUrl$profile'
                : null,
          ),
        );
      }
    }

    // Genres
    final genres = <String>[];
    final genresRaw = dto['genres'];
    if (genresRaw is List) {
      for (final g in genresRaw.whereType<Map<String, dynamic>>()) {
        final n = (g['name'] as String?)?.trim() ?? '';
        if (n.isNotEmpty) genres.add(n);
      }
    }

    // Release year
    final firstAirDate = dto['first_air_date'] as String?;
    final releaseYear = (firstAirDate != null && firstAirDate.length >= 4)
        ? (int.tryParse(firstAirDate.substring(0, 4)) ?? 0)
        : 0;

    // Seasons (season_number > 0)
    final seasons = <SeasonInfo>[];
    final seasonsRaw = dto['seasons'];
    if (seasonsRaw is List) {
      for (final s in seasonsRaw.whereType<Map<String, dynamic>>()) {
        final numVal = (s['season_number'] as num?)?.toInt() ?? 0;
        if (numVal > 0) {
          seasons.add(
            SeasonInfo(
              seasonNumber: numVal,
              name: (s['name'] as String?) ?? 'Season $numVal',
              episodeCount: (s['episode_count'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
    }

    // Watch providers with device country -> US -> first available fallback
    final deviceCountry = (overrideCountryCode ??
            ui.PlatformDispatcher.instance.locale.countryCode ??
            'US')
        .toUpperCase();
    final effectiveCountry = deviceCountry.isEmpty ? 'US' : deviceCountry;

    final wpMap =
        ((dto['watch/providers'] as Map<String, dynamic>?)?['results']
                as Map<String, dynamic>?) ??
            const {};
    String matchedRegion;
    if (wpMap.containsKey(effectiveCountry)) {
      matchedRegion = effectiveCountry;
    } else if (wpMap.containsKey('US')) {
      matchedRegion = 'US';
    } else if (wpMap.isNotEmpty) {
      matchedRegion = wpMap.keys.first;
    } else {
      matchedRegion = effectiveCountry;
    }
    final isRegionFallback = matchedRegion != effectiveCountry && wpMap.isNotEmpty;
    final countryObj = wpMap[matchedRegion] as Map<String, dynamic>?;
    final regionLink = countryObj?['link'] as String?;

    final seenIds = <int>{};
    final watchProviders = <StreamingProvider>[];
    void addBucket(String key, String label) {
      final list = countryObj?[key];
      if (list is! List) return;
      for (final p in list.whereType<Map<String, dynamic>>()) {
        final pid = (p['provider_id'] as num?)?.toInt() ?? 0;
        if (pid <= 0 || !seenIds.add(pid)) continue;
        final logo = p['logo_path'] as String?;
        watchProviders.add(
          StreamingProvider(
            id: pid,
            name: (p['provider_name'] as String?) ?? 'Stream',
            logoUrl: logo != null && logo.isNotEmpty ? '$logoBaseUrl$logo' : null,
            link: regionLink,
            availabilityType: label,
            regionCode: matchedRegion,
            isRegionFallback: isRegionFallback,
          ),
        );
      }
    }

    addBucket('flatrate', 'Stream');
    addBucket('free', 'Free');
    addBucket('ads', 'Free with Ads');
    addBucket('rent', 'Rent');
    addBucket('buy', 'Buy');

    // Recommendations (up to 12)
    final recommendations = <Drama>[];
    final recRaw = (dto['recommendations'] as Map<String, dynamic>?)?['results'];
    if (recRaw is List) {
      for (final r in recRaw.whereType<Map<String, dynamic>>().take(12)) {
        final d = dtoToDomainSummary(r);
        if (d != null) recommendations.add(d);
      }
    }

    // Reviews (up to 8)
    final reviews = <DramaReview>[];
    final revRaw = (dto['reviews'] as Map<String, dynamic>?)?['results'];
    if (revRaw is List) {
      for (final r in revRaw.whereType<Map<String, dynamic>>()) {
        final content = (r['content'] as String?)?.trim() ?? '';
        if (content.isEmpty) continue;
        final details = r['author_details'] as Map<String, dynamic>?;
        final rawAvatar = details?['avatar_path'] as String?;
        String? avatarUrl;
        if (rawAvatar != null && rawAvatar.trim().isNotEmpty) {
          if (rawAvatar.startsWith('/http')) {
            avatarUrl = rawAvatar.substring(1);
          } else if (rawAvatar.startsWith('http')) {
            avatarUrl = rawAvatar;
          } else {
            avatarUrl = '$thumbBaseUrl$rawAvatar';
          }
        }
        final author = (r['author'] as String?)?.trim();
        reviews.add(
          DramaReview(
            id: (r['id'] as String?) ?? '${reviews.length}',
            author: (author != null && author.isNotEmpty)
                ? author
                : 'Audience Member',
            content: content,
            url: r['url'] as String?,
            rating: (details?['rating'] as num?)?.toDouble(),
            avatarUrl: avatarUrl,
          ),
        );
        if (reviews.length >= 8) break;
      }
    }

    // Episode runtime
    var epRuntime = 45;
    final runtimes = dto['episode_run_time'];
    if (runtimes is List) {
      for (final r in runtimes) {
        final val = (r as num?)?.toInt() ?? 0;
        if (val > 0) {
          epRuntime = val;
          break;
        }
      }
    }

    final nextEp = dto['next_episode_to_air'] as Map<String, dynamic>?;

    return DramaExtraDetails(
      trailerKey: trailerKey,
      cast: cast,
      genres: genres,
      releaseYear: releaseYear,
      totalSeasons: (dto['number_of_seasons'] as num?)?.toInt() ?? seasons.length,
      totalEpisodes: (dto['number_of_episodes'] as num?)?.toInt() ?? 0,
      episodeRuntime: epRuntime,
      seasons: seasons,
      watchProviders: watchProviders.take(10).toList(),
      recommendations: recommendations,
      nextEpisodeAirDate: nextEp?['air_date'] as String?,
      nextEpisodeNumber: (nextEp?['episode_number'] as num?)?.toInt() ?? 0,
      nextSeasonNumber: (nextEp?['season_number'] as num?)?.toInt() ?? 0,
      reviews: reviews,
    );
  }
}
