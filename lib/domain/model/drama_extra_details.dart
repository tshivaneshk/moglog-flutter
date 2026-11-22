import 'drama.dart';

class DramaExtraDetails {
  final String? trailerKey;
  final List<CastMember> cast;
  final List<String> genres;
  final int releaseYear;
  final int totalSeasons;
  final int totalEpisodes;
  final int episodeRuntime;
  final List<SeasonInfo> seasons;
  final List<StreamingProvider> watchProviders;
  final List<Drama> recommendations;
  final String? nextEpisodeAirDate;
  final int nextEpisodeNumber;
  final int nextSeasonNumber;
  final List<DramaReview> reviews;

  const DramaExtraDetails({
    this.trailerKey,
    this.cast = const [],
    this.genres = const [],
    this.releaseYear = 0,
    this.totalSeasons = 0,
    this.totalEpisodes = 0,
    this.episodeRuntime = 45,
    this.seasons = const [],
    this.watchProviders = const [],
    this.recommendations = const [],
    this.nextEpisodeAirDate,
    this.nextEpisodeNumber = 0,
    this.nextSeasonNumber = 0,
    this.reviews = const [],
  });

  Map<String, dynamic> toJson() => {
        'trailerKey': trailerKey,
        'cast': cast.map((e) => e.toJson()).toList(),
        'genres': genres,
        'releaseYear': releaseYear,
        'totalSeasons': totalSeasons,
        'totalEpisodes': totalEpisodes,
        'episodeRuntime': episodeRuntime,
        'seasons': seasons.map((e) => e.toJson()).toList(),
        'watchProviders': watchProviders.map((e) => e.toJson()).toList(),
        'recommendations': recommendations.map((e) => e.toJson()).toList(),
        'nextEpisodeAirDate': nextEpisodeAirDate,
        'nextEpisodeNumber': nextEpisodeNumber,
        'nextSeasonNumber': nextSeasonNumber,
        'reviews': reviews.map((e) => e.toJson()).toList(),
      };

  factory DramaExtraDetails.fromJson(Map<String, dynamic> json) {
    return DramaExtraDetails(
      trailerKey: json['trailerKey'] as String?,
      cast: (json['cast'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CastMember.fromJson)
          .toList(),
      genres: (json['genres'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      releaseYear: (json['releaseYear'] as num?)?.toInt() ?? 0,
      totalSeasons: (json['totalSeasons'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? 0,
      episodeRuntime: (json['episodeRuntime'] as num?)?.toInt() ?? 45,
      seasons: (json['seasons'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SeasonInfo.fromJson)
          .toList(),
      watchProviders: (json['watchProviders'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StreamingProvider.fromJson)
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Drama.fromJson)
          .toList(),
      nextEpisodeAirDate: json['nextEpisodeAirDate'] as String?,
      nextEpisodeNumber: (json['nextEpisodeNumber'] as num?)?.toInt() ?? 0,
      nextSeasonNumber: (json['nextSeasonNumber'] as num?)?.toInt() ?? 0,
      reviews: (json['reviews'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DramaReview.fromJson)
          .toList(),
    );
  }
}

class DramaReview {
  final String id;
  final String author;
  final String content;
  final String? url;
  final double? rating;
  final String? avatarUrl;

  const DramaReview({
    required this.id,
    required this.author,
    required this.content,
    this.url,
    this.rating,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'content': content,
        'url': url,
        'rating': rating,
        'avatarUrl': avatarUrl,
      };

  factory DramaReview.fromJson(Map<String, dynamic> json) {
    return DramaReview(
      id: (json['id'] as String?) ?? '',
      author: (json['author'] as String?) ?? 'Audience Member',
      content: (json['content'] as String?) ?? '',
      url: json['url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class CastMember {
  final String name;
  final String character;
  final String? profilePath;

  const CastMember({
    required this.name,
    required this.character,
    this.profilePath,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'character': character,
        'profilePath': profilePath,
      };

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: (json['name'] as String?) ?? '',
      character: (json['character'] as String?) ?? '',
      profilePath: json['profilePath'] as String?,
    );
  }
}

class SeasonInfo {
  final int seasonNumber;
  final String name;
  final int episodeCount;

  const SeasonInfo({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
  });

  Map<String, dynamic> toJson() => {
        'seasonNumber': seasonNumber,
        'name': name,
        'episodeCount': episodeCount,
      };

  factory SeasonInfo.fromJson(Map<String, dynamic> json) {
    return SeasonInfo(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 1,
      name: (json['name'] as String?) ?? 'Season 1',
      episodeCount: (json['episodeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StreamingProvider {
  final int id;
  final String name;
  final String? logoUrl;
  final String? link;
  final String? availabilityType;
  final String? regionCode;
  final bool isRegionFallback;

  const StreamingProvider({
    required this.id,
    required this.name,
    this.logoUrl,
    this.link,
    this.availabilityType = 'Stream',
    this.regionCode,
    this.isRegionFallback = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'link': link,
        'availabilityType': availabilityType,
        'regionCode': regionCode,
        'isRegionFallback': isRegionFallback,
      };

  factory StreamingProvider.fromJson(Map<String, dynamic> json) {
    return StreamingProvider(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Stream',
      logoUrl: json['logoUrl'] as String?,
      link: json['link'] as String?,
      availabilityType: (json['availabilityType'] as String?) ?? 'Stream',
      regionCode: json['regionCode'] as String?,
      isRegionFallback: (json['isRegionFallback'] as bool?) ?? false,
    );
  }
}
