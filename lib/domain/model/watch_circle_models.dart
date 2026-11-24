import 'dart:math';

import 'drama.dart';

/// Sanitized, zero-knowledge safe show item shared with Watch Circle friends.
/// Never includes private personal notes or internal tags.
class SharedShowItem {
  final int id;
  final String title;
  final String posterPath;
  final String status;
  final int episodesWatched;
  final int totalEpisodes;
  final double rating;
  final double myRating;
  final String genres;
  final int updatedAt;

  const SharedShowItem({
    this.id = 0,
    this.title = '',
    this.posterPath = '',
    this.status = 'Watching',
    this.episodesWatched = 0,
    this.totalEpisodes = 0,
    this.rating = 0.0,
    this.myRating = 0.0,
    this.genres = '',
    this.updatedAt = 0,
  });

  double get effectiveScore => myRating > 0.0 ? myRating : rating;

  double get progressFraction {
    if (status == 'Done') return 1.0;
    if (totalEpisodes > 0) return (episodesWatched / totalEpisodes).clamp(0.0, 1.0);
    if (episodesWatched > 0) return 0.5;
    return 0.0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'posterPath': posterPath,
        'status': status,
        'episodesWatched': episodesWatched,
        'totalEpisodes': totalEpisodes,
        'rating': rating,
        'myRating': myRating,
        'genres': genres,
        'updatedAt': updatedAt,
      };

  factory SharedShowItem.fromMap(Map<String, dynamic> m) => SharedShowItem(
        id: (m['id'] as num?)?.toInt() ?? 0,
        title: (m['title'] as String?) ?? '',
        posterPath: (m['posterPath'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'Watching',
        episodesWatched: (m['episodesWatched'] as num?)?.toInt() ?? 0,
        totalEpisodes: (m['totalEpisodes'] as num?)?.toInt() ?? 0,
        rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
        myRating: (m['myRating'] as num?)?.toDouble() ?? 0.0,
        genres: (m['genres'] as String?) ?? '',
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

class FriendProfile {
  final String uid;
  final String inviteCode;
  final String displayName;
  final String photoUrl;
  final String photoBase64;
  final bool sharingEnabled;
  final int updatedAt;
  final int totalWatched;
  final int totalEpisodes;
  final List<String> topGenres;
  final List<SharedShowItem> currentlyWatching;
  final List<SharedShowItem> recentlyCompleted;
  final List<SharedShowItem> plannedShows;
  final List<SharedShowItem> topFourFavorites;

  const FriendProfile({
    this.uid = '',
    this.inviteCode = '',
    this.displayName = 'Moglog User',
    this.photoUrl = '',
    this.photoBase64 = '',
    this.sharingEnabled = true,
    this.updatedAt = 0,
    this.totalWatched = 0,
    this.totalEpisodes = 0,
    this.topGenres = const [],
    this.currentlyWatching = const [],
    this.recentlyCompleted = const [],
    this.plannedShows = const [],
    this.topFourFavorites = const [],
  });

  List<SharedShowItem> get allSharedShows {
    final seen = <int>{};
    final result = <SharedShowItem>[];
    for (final item in [
      ...topFourFavorites,
      ...currentlyWatching,
      ...recentlyCompleted,
      ...plannedShows,
    ]) {
      if (seen.add(item.id)) {
        result.add(item);
      }
    }
    return result;
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'inviteCode': inviteCode,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'photoBase64': photoBase64,
        'sharingEnabled': sharingEnabled,
        'updatedAt': updatedAt,
        'totalWatched': totalWatched,
        'totalEpisodes': totalEpisodes,
        'topGenres': topGenres,
        'currentlyWatching': currentlyWatching.map((s) => s.toMap()).toList(),
        'recentlyCompleted': recentlyCompleted.map((s) => s.toMap()).toList(),
        'plannedShows': plannedShows.map((s) => s.toMap()).toList(),
        'topFourFavorites': topFourFavorites.map((s) => s.toMap()).toList(),
      };

  factory FriendProfile.fromMap(Map<String, dynamic> m) {
    List<SharedShowItem> parseList(String key) {
      final raw = m[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => SharedShowItem.fromMap(Map<String, dynamic>.from(e)))
          .where((s) => s.id > 0 && s.title.isNotEmpty)
          .toList();
    }

    return FriendProfile(
      uid: (m['uid'] as String?) ?? '',
      inviteCode: (m['inviteCode'] as String?) ?? '',
      displayName: (m['displayName'] as String?) ?? 'Moglog Friend',
      photoUrl: (m['photoUrl'] as String?) ?? '',
      photoBase64: (m['photoBase64'] as String?) ?? '',
      sharingEnabled: (m['sharingEnabled'] as bool?) ?? true,
      updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      totalWatched: (m['totalWatched'] as num?)?.toInt() ?? 0,
      totalEpisodes: (m['totalEpisodes'] as num?)?.toInt() ?? 0,
      topGenres: (m['topGenres'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      currentlyWatching: parseList('currentlyWatching'),
      recentlyCompleted: parseList('recentlyCompleted'),
      plannedShows: parseList('plannedShows'),
      topFourFavorites: parseList('topFourFavorites'),
    );
  }
}

class TasteBlendResult {
  final int compatibilityPercent;
  final String badgeTitle;
  final List<SharedShowItem> sharedShows;
  final List<String> sharedGenres;

  const TasteBlendResult({
    required this.compatibilityPercent,
    required this.badgeTitle,
    required this.sharedShows,
    required this.sharedGenres,
  });
}

class CoWatchPair {
  final int dramaId;
  final String title;
  final String posterPath;
  final int totalEpisodes;
  final int myEpisodes;
  final String myStatus;
  final int friendEpisodes;
  final String friendStatus;
  final String friendUid;
  final String friendName;
  final String friendPhotoBase64;
  final String friendPhotoUrl;

  const CoWatchPair({
    required this.dramaId,
    required this.title,
    required this.posterPath,
    required this.totalEpisodes,
    required this.myEpisodes,
    required this.myStatus,
    required this.friendEpisodes,
    required this.friendStatus,
    required this.friendUid,
    required this.friendName,
    required this.friendPhotoBase64,
    required this.friendPhotoUrl,
  });

  int get episodeDelta => myEpisodes - friendEpisodes;
}

class CircleNudge {
  final String id;
  final String fromUid;
  final String fromName;
  final int dramaId;
  final String dramaTitle;
  final String emoji;
  final String message;
  final int createdAt;

  const CircleNudge({
    this.id = '',
    this.fromUid = '',
    this.fromName = '',
    this.dramaId = 0,
    this.dramaTitle = '',
    this.emoji = 'ZAP',
    this.message = '',
    this.createdAt = 0,
  });
}

/// Exact 1:1 port of Kotlin `TasteBlendCalculator`.
class TasteBlendCalculator {
  static TasteBlendResult computeBlend(List<Drama> myDramas, FriendProfile friend) {
    final activeMyDramas = myDramas.where((d) => !d.isDeleted).toList();
    final friendShows = friend.allSharedShows;

    if (activeMyDramas.isEmpty || friendShows.isEmpty) {
      return const TasteBlendResult(
        compatibilityPercent: 50,
        badgeTitle: 'New Watch Buddies',
        sharedShows: [],
        sharedGenres: [],
      );
    }

    final myMap = {for (final d in activeMyDramas) d.id: d};
    final sharedShows = friendShows.where((fs) => myMap.containsKey(fs.id)).toList();

    // 1. Show Overlap Score (0..45 pts)
    final smallerPool = max(1, min(activeMyDramas.length, friendShows.length));
    final denomPool = min(15, smallerPool);
    final overlapRatio = (sharedShows.length / denomPool).clamp(0.0, 1.0);
    final showScore = overlapRatio * 45.0;

    // 2. Genre Affinity Score (0..35 pts)
    final myGenreCounts = <String, int>{};
    for (final d in activeMyDramas) {
      for (final g in d.genreList) {
        myGenreCounts[g] = (myGenreCounts[g] ?? 0) + 1;
      }
    }
    final myTopEntries = myGenreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final myTopGenres = myTopEntries.take(5).map((e) => e.key).toList();

    List<String> friendTopGenres;
    if (friend.topGenres.isNotEmpty) {
      friendTopGenres = friend.topGenres;
    } else {
      final counts = <String, int>{};
      for (final s in friendShows) {
        for (final g in s.genres.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
          counts[g] = (counts[g] ?? 0) + 1;
        }
      }
      final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      friendTopGenres = sorted.take(5).map((e) => e.key).toList();
    }

    final sharedGenres = myTopGenres
        .where((g) => friendTopGenres.any((fg) => fg.toLowerCase() == g.toLowerCase()))
        .toList();
    final genreDenominator = max(1, min(myTopGenres.length, friendTopGenres.length));
    final genreRatio = (sharedGenres.length / genreDenominator).clamp(0.0, 1.0);
    final genreScore = genreRatio * 35.0;

    // 3. Rating Harmony Score (0..20 pts)
    final ratedTogether = <double>[];
    for (final fs in sharedShows) {
      final mine = myMap[fs.id];
      if (mine == null) continue;
      final myScore = mine.myRating > 0 ? mine.myRating : mine.rating;
      final friendScore = fs.effectiveScore;
      if (myScore > 0 && friendScore > 0) {
        ratedTogether.add((myScore - friendScore).abs());
      }
    }
    final double ratingScore;
    if (ratedTogether.isNotEmpty) {
      final avgDiff = ratedTogether.reduce((a, b) => a + b) / ratedTogether.length;
      ratingScore = ((10.0 - avgDiff) / 10.0).clamp(0.0, 1.0) * 20.0;
    } else {
      ratingScore = 14.0;
    }

    final rawTotal = (showScore + genreScore + ratingScore).round();
    final int finalPercent;
    if (sharedShows.isNotEmpty) {
      finalPercent = rawTotal.clamp(42, 99);
    } else if (sharedGenres.isNotEmpty) {
      finalPercent = rawTotal.clamp(28, 78);
    } else {
      finalPercent = rawTotal.clamp(18, 60);
    }

    final String badgeTitle;
    if (finalPercent >= 88) {
      badgeTitle = 'Soulmate Watchers';
    } else if (finalPercent >= 75) {
      badgeTitle = 'Binge Twins';
    } else if (finalPercent >= 60) {
      badgeTitle = 'Vibe Match';
    } else if (finalPercent >= 40) {
      badgeTitle = 'Genre Explorers';
    } else {
      badgeTitle = 'Opposites Attract';
    }

    return TasteBlendResult(
      compatibilityPercent: finalPercent,
      badgeTitle: badgeTitle,
      sharedShows: sharedShows,
      sharedGenres: sharedGenres,
    );
  }

  static List<CoWatchPair> buildCoWatchPairs(
    List<Drama> myDramas,
    List<FriendProfile> friends,
  ) {
    final activeMyMap = {
      for (final d in myDramas.where((e) => !e.isDeleted)) d.id: d,
    };
    final pairs = <CoWatchPair>[];

    for (final friend in friends) {
      if (!friend.sharingEnabled) continue;
      for (final friendShow in friend.currentlyWatching) {
        final mine = activeMyMap[friendShow.id];
        if (mine == null) continue;
        final totalEps = max(mine.totalEpisodes, friendShow.totalEpisodes);
        pairs.add(
          CoWatchPair(
            dramaId: friendShow.id,
            title: friendShow.title,
            posterPath: friendShow.posterPath.trim().isNotEmpty
                ? friendShow.posterPath
                : mine.posterPath,
            totalEpisodes: totalEps,
            myEpisodes: (mine.status == 'Done' && totalEps > 0)
                ? totalEps
                : mine.episodesWatched,
            myStatus: mine.status,
            friendEpisodes: friendShow.episodesWatched,
            friendStatus: friendShow.status,
            friendUid: friend.uid,
            friendName: friend.displayName,
            friendPhotoBase64: friend.photoBase64,
            friendPhotoUrl: friend.photoUrl,
          ),
        );
      }
    }

    pairs.sort((a, b) {
      final aWatching = a.myStatus == 'Watching' ? 1 : 0;
      final bWatching = b.myStatus == 'Watching' ? 1 : 0;
      return bWatching.compareTo(aWatching);
    });
    return pairs;
  }
}
