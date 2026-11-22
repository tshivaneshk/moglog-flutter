import 'dart:math';

/// Core TV show / drama domain model matching Kotlin `Drama` 1:1,
/// including exact Gson JSON field names for Firestore & `.moglog` compatibility.
class Drama {
  final int id;
  final String title;
  final String overview;
  final double rating;
  final String posterPath;
  final String status; // "Planned", "Watching", "Done"
  final int episodesWatched;
  final int totalEpisodes;
  final bool isDeleted;
  final int addedAt;
  final int updatedAt;
  final int completedAt;
  final double myRating;
  final String notes;
  final String tags;
  final String genres;
  final int releaseYear;
  final int totalSeasons;
  final int currentSeason;
  final int currentEpisode;
  final String? nextEpisodeAirDate;
  final int nextEpisodeNumber;
  final int nextSeasonNumber;
  final int deletedAt;

  const Drama({
    required this.id,
    required this.title,
    this.overview = '',
    this.rating = 0.0,
    this.posterPath = '',
    this.status = 'Planned',
    this.episodesWatched = 0,
    this.totalEpisodes = 0,
    this.isDeleted = false,
    this.addedAt = 0,
    this.updatedAt = 0,
    this.completedAt = 0,
    this.myRating = 0.0,
    this.notes = '',
    this.tags = '',
    this.genres = '',
    this.releaseYear = 0,
    this.totalSeasons = 0,
    this.currentSeason = 1,
    this.currentEpisode = 0,
    this.nextEpisodeAirDate,
    this.nextEpisodeNumber = 0,
    this.nextSeasonNumber = 0,
    this.deletedAt = 0,
  });

  List<String> get genreList => genres.trim().isEmpty
      ? const []
      : genres
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  List<String> get tagList => tags.trim().isEmpty
      ? const []
      : tags
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  double get progressFraction => totalEpisodes > 0
      ? (episodesWatched / totalEpisodes).clamp(0.0, 1.0)
      : 0.0;

  double get effectiveRating => myRating > 0.0 ? myRating : rating;

  /// True when at least one season has been completed in a multi-season series
  /// while the overall series is not yet fully Done.
  bool get isPartiallyDone {
    if (isDeleted || status == 'Done') return false;
    if (totalEpisodes > 0 && episodesWatched >= totalEpisodes) return false;
    if (currentSeason > 1) return true;
    if (totalSeasons > 1 && totalEpisodes > 0) {
      final avgPerSeason = max(1, totalEpisodes ~/ totalSeasons);
      return episodesWatched >= avgPerSeason;
    }
    return false;
  }

  Drama copyWith({
    int? id,
    String? title,
    String? overview,
    double? rating,
    String? posterPath,
    String? status,
    int? episodesWatched,
    int? totalEpisodes,
    bool? isDeleted,
    int? addedAt,
    int? updatedAt,
    int? completedAt,
    double? myRating,
    String? notes,
    String? tags,
    String? genres,
    int? releaseYear,
    int? totalSeasons,
    int? currentSeason,
    int? currentEpisode,
    Object? nextEpisodeAirDate = _sentinel,
    int? nextEpisodeNumber,
    int? nextSeasonNumber,
    int? deletedAt,
  }) {
    return Drama(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      rating: rating ?? this.rating,
      posterPath: posterPath ?? this.posterPath,
      status: status ?? this.status,
      episodesWatched: episodesWatched ?? this.episodesWatched,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      isDeleted: isDeleted ?? this.isDeleted,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      myRating: myRating ?? this.myRating,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      genres: genres ?? this.genres,
      releaseYear: releaseYear ?? this.releaseYear,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      nextEpisodeAirDate: identical(nextEpisodeAirDate, _sentinel)
          ? this.nextEpisodeAirDate
          : nextEpisodeAirDate as String?,
      nextEpisodeNumber: nextEpisodeNumber ?? this.nextEpisodeNumber,
      nextSeasonNumber: nextSeasonNumber ?? this.nextSeasonNumber,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'overview': overview,
      'rating': rating,
      'posterPath': posterPath,
      'status': status,
      'episodesWatched': episodesWatched,
      'totalEpisodes': totalEpisodes,
      'isDeleted': isDeleted,
      'addedAt': addedAt,
      'updatedAt': updatedAt,
      'completedAt': completedAt,
      'myRating': myRating,
      'notes': notes,
      'tags': tags,
      'genres': genres,
      'releaseYear': releaseYear,
      'totalSeasons': totalSeasons,
      'currentSeason': currentSeason,
      'currentEpisode': currentEpisode,
      if (nextEpisodeAirDate != null) 'nextEpisodeAirDate': nextEpisodeAirDate,
      'nextEpisodeNumber': nextEpisodeNumber,
      'nextSeasonNumber': nextSeasonNumber,
      'deletedAt': deletedAt,
    };
  }

  factory Drama.fromJson(Map<String, dynamic> json) {
    final deletedVal = json['isDeleted'] ?? json['deleted'];
    final bool parsedDeleted = switch (deletedVal) {
      bool b => b,
      num n => n != 0,
      _ => false,
    };

    return Drama(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      posterPath: (json['posterPath'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'Planned',
      episodesWatched: (json['episodesWatched'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? 0,
      isDeleted: parsedDeleted,
      addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      completedAt: (json['completedAt'] as num?)?.toInt() ?? 0,
      myRating: (json['myRating'] as num?)?.toDouble() ?? 0.0,
      notes: (json['notes'] as String?) ?? '',
      tags: (json['tags'] as String?) ?? '',
      genres: (json['genres'] as String?) ?? '',
      releaseYear: (json['releaseYear'] as num?)?.toInt() ?? 0,
      totalSeasons: (json['totalSeasons'] as num?)?.toInt() ?? 0,
      currentSeason: (json['currentSeason'] as num?)?.toInt() ?? 1,
      currentEpisode: (json['currentEpisode'] as num?)?.toInt() ?? 0,
      nextEpisodeAirDate: json['nextEpisodeAirDate'] as String?,
      nextEpisodeNumber: (json['nextEpisodeNumber'] as num?)?.toInt() ?? 0,
      nextSeasonNumber: (json['nextSeasonNumber'] as num?)?.toInt() ?? 0,
      deletedAt: (json['deletedAt'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Drama &&
        other.id == id &&
        other.title == title &&
        other.overview == overview &&
        other.rating == rating &&
        other.posterPath == posterPath &&
        other.status == status &&
        other.episodesWatched == episodesWatched &&
        other.totalEpisodes == totalEpisodes &&
        other.isDeleted == isDeleted &&
        other.addedAt == addedAt &&
        other.updatedAt == updatedAt &&
        other.completedAt == completedAt &&
        other.myRating == myRating &&
        other.notes == notes &&
        other.tags == tags &&
        other.genres == genres &&
        other.releaseYear == releaseYear &&
        other.totalSeasons == totalSeasons &&
        other.currentSeason == currentSeason &&
        other.currentEpisode == currentEpisode &&
        other.nextEpisodeAirDate == nextEpisodeAirDate &&
        other.nextEpisodeNumber == nextEpisodeNumber &&
        other.nextSeasonNumber == nextSeasonNumber &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        overview,
        rating,
        posterPath,
        status,
        episodesWatched,
        totalEpisodes,
        isDeleted,
        addedAt,
        updatedAt,
        completedAt,
        myRating,
        notes,
        tags,
        genres,
        releaseYear,
        totalSeasons,
        currentSeason,
        currentEpisode,
        nextEpisodeAirDate,
        nextEpisodeNumber,
        nextSeasonNumber,
        deletedAt,
      ]);
}

const Object _sentinel = Object();
