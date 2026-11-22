import 'dart:math';

import '../model/drama_extra_details.dart';

/// Exact port of `ProgressStepperCard.resolveSeasonBreakdown`.
List<SeasonInfo> resolveSeasonBreakdown({
  required List<SeasonInfo> seasons,
  required int totalSeasons,
  required int totalEpisodes,
}) {
  final valid = seasons
      .where((s) => s.seasonNumber >= 1 && s.episodeCount > 0)
      .toList()
    ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
  if (valid.isNotEmpty) return valid;
  if (totalSeasons <= 1) return const [];

  final count = min(totalSeasons, 30);
  final baseEps = totalEpisodes > 0 ? max(1, totalEpisodes ~/ count) : 0;
  return List<SeasonInfo>.generate(count, (idx) {
    final sNum = idx + 1;
    final epCount = (totalEpisodes > 0 && sNum == count)
        ? max(1, totalEpisodes - baseEps * (count - 1))
        : baseEps;
    return SeasonInfo(
      seasonNumber: sNum,
      name: 'Season $sNum',
      episodeCount: epCount,
    );
  });
}

class BingeEstimate {
  final int remainingEpisodes;
  final int remainingMinutes;
  final int remainingHours;
  final int remainingRemainderMinutes;
  final Map<int, int> daysAtPace; // pace (1, 2, 3, 5) -> days

  const BingeEstimate({
    required this.remainingEpisodes,
    required this.remainingMinutes,
    required this.remainingHours,
    required this.remainingRemainderMinutes,
    required this.daysAtPace,
  });

  String get formattedRemainingTime {
    if (remainingEpisodes <= 0) return 'Completed';
    if (remainingHours > 0) {
      return '${remainingHours}h ${remainingRemainderMinutes}m';
    }
    return '${remainingRemainderMinutes}m';
  }
}

BingeEstimate computeBingeEstimate({
  required int episodesWatched,
  required int totalEpisodes,
  int episodeRuntimeMinutes = 45,
}) {
  final runtime = episodeRuntimeMinutes > 0 ? episodeRuntimeMinutes : 45;
  final remaining = max(0, totalEpisodes - episodesWatched);
  final totalMinutes = remaining * runtime;
  final hours = totalMinutes ~/ 60;
  final mins = totalMinutes % 60;
  final paces = <int, int>{};
  for (final pace in const [1, 2, 3, 5]) {
    paces[pace] = remaining > 0 ? (remaining / pace).ceil() : 0;
  }
  return BingeEstimate(
    remainingEpisodes: remaining,
    remainingMinutes: totalMinutes,
    remainingHours: hours,
    remainingRemainderMinutes: mins,
    daysAtPace: paces,
  );
}
