import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/drama.dart';

class BingePersona {
  final String title;
  final String rankBadge;
  final int tierLevel;
  final int accentColorHex;
  final String nextRankTitle;
  final int nextMilestoneHours;
  final double progressFraction;

  const BingePersona({
    required this.title,
    required this.rankBadge,
    required this.tierLevel,
    required this.accentColorHex,
    required this.nextRankTitle,
    required this.nextMilestoneHours,
    required this.progressFraction,
  });
}

class PrestigeTierInfo {
  final int level;
  final int minHours;
  final int maxHours;
  final String hoursRangeLabel;
  final String badge;
  final String sampleTitle;
  final String unlockCriteria;
  final int colorHex;

  const PrestigeTierInfo({
    required this.level,
    required this.minHours,
    required this.maxHours,
    required this.hoursRangeLabel,
    required this.badge,
    required this.sampleTitle,
    required this.unlockCriteria,
    required this.colorHex,
  });
}

class MonthlyActivityBucket {
  final String monthLabel;
  final int count;
  const MonthlyActivityBucket(this.monthLabel, this.count);
}

class StatsSnapshot {
  final List<Drama> activeDramas;
  final int watchingCount;
  final int plannedCount;
  final int doneCount;
  final int totalEpisodesWatched;
  final int estimatedHours;
  final List<MapEntry<String, int>> genreBreakdown;
  final List<MonthlyActivityBucket> monthlyActivity;
  final int currentStreakMonths;
  final List<Drama> topRatedShows;
  final String topGenreName;
  final BingePersona bingePersona;
  final List<Drama> releaseRadarShows;
  final List<Drama> diaryEntries;

  const StatsSnapshot({
    required this.activeDramas,
    required this.watchingCount,
    required this.plannedCount,
    required this.doneCount,
    required this.totalEpisodesWatched,
    required this.estimatedHours,
    required this.genreBreakdown,
    required this.monthlyActivity,
    required this.currentStreakMonths,
    required this.topRatedShows,
    required this.topGenreName,
    required this.bingePersona,
    required this.releaseRadarShows,
    required this.diaryEntries,
  });
}

String resolveCleanGenre(String topGenre) {
  final lower = topGenre.toLowerCase();
  if (lower.contains('sci-fi')) return 'Sci-Fi';
  if (lower.contains('action')) return 'Action';
  if (lower.contains('mystery')) return 'Mystery';
  if (lower.contains('comedy')) return 'Comedy';
  if (lower.contains('romance')) return 'Romance';
  if (lower.contains('crime')) return 'Crime';
  if (lower.contains('animation')) return 'Animation';
  if (lower.contains('fantasy')) return 'Fantasy';
  if (lower.contains('drama')) return 'Drama';
  if (topGenre.trim().isEmpty || topGenre == 'Multi-Genre') return 'Cinema';
  return topGenre.split(' ').first;
}

List<PrestigeTierInfo> getPrestigeTiersCatalog(String topGenre) {
  final cleanGenre = resolveCleanGenre(topGenre);
  return [
    const PrestigeTierInfo(
      level: 1,
      minHours: 0,
      maxHours: 10,
      hoursRangeLabel: '0–10h',
      badge: 'TIER I · PILOT SCOUT',
      sampleTitle: 'Pilot Episode Scout / Emerging Queue Curator',
      unlockCriteria: 'Starting rank (0 to 10h streamed)',
      colorHex: 0xFF94A3B8,
    ),
    PrestigeTierInfo(
      level: 2,
      minHours: 10,
      maxHours: 30,
      hoursRangeLabel: '10–30h',
      badge: 'TIER II · FIRST-ACT INITIATE',
      sampleTitle: 'First-Act $cleanGenre Seeker',
      unlockCriteria: 'Requires 10+ hours or 1+ completed show',
      colorHex: 0xFF38BDF8,
    ),
    PrestigeTierInfo(
      level: 3,
      minHours: 30,
      maxHours: 65,
      hoursRangeLabel: '30–65h',
      badge: 'TIER III · BRONZE VOYAGER',
      sampleTitle: 'Dedicated Season Finisher / $cleanGenre Voyager',
      unlockCriteria: 'Requires 30+ hours or 3+ completed shows',
      colorHex: 0xFFD97706,
    ),
    PrestigeTierInfo(
      level: 4,
      minHours: 65,
      maxHours: 120,
      hoursRangeLabel: '65–120h',
      badge: 'TIER IV · SILVER AFICIONADO',
      sampleTitle: 'Precision $cleanGenre Finisher / Silver Screen Devotee',
      unlockCriteria: 'Requires 65+ hours or 7+ completed shows',
      colorHex: 0xFFA3E635,
    ),
    PrestigeTierInfo(
      level: 5,
      minHours: 120,
      maxHours: 220,
      hoursRangeLabel: '120–220h',
      badge: 'TIER V · EMERALD MARATHONER',
      sampleTitle: 'Midnight $cleanGenre Marathoner / Emerald Navigator',
      unlockCriteria: 'Requires 120+ hours or 12+ completed shows',
      colorHex: 0xFF10B981,
    ),
    const PrestigeTierInfo(
      level: 6,
      minHours: 220,
      maxHours: 350,
      hoursRangeLabel: '220–350h',
      badge: 'TIER VI · GOLD SPECIALIST',
      sampleTitle: 'Veteran Cliffhanger Survivor / Golden Era Specialist',
      unlockCriteria: 'Requires 220+ hours or 22+ completed shows',
      colorHex: 0xFFFACC15,
    ),
    PrestigeTierInfo(
      level: 7,
      minHours: 350,
      maxHours: 500,
      hoursRangeLabel: '350–500h',
      badge: 'TIER VII · DIAMOND ARCHITECT',
      sampleTitle: 'Prime Watchlist Architect / Diamond $cleanGenre Tactician',
      unlockCriteria: 'Requires 350+ hours or 35+ completed shows',
      colorHex: 0xFF00F5D4,
    ),
    const PrestigeTierInfo(
      level: 8,
      minHours: 500,
      maxHours: 750,
      hoursRangeLabel: '500–750h',
      badge: 'TIER VIII · PLATINUM VANGUARD',
      sampleTitle: 'Relentless Finale Commander / Platinum Vanguard',
      unlockCriteria: 'Requires 500+ hours or 50+ completed shows',
      colorHex: 0xFF6366F1,
    ),
    PrestigeTierInfo(
      level: 9,
      minHours: 750,
      maxHours: 1000,
      hoursRangeLabel: '750–1,000h',
      badge: 'TIER IX · APEX ARCHIVIST',
      sampleTitle: 'Imperial Series Archivist / Apex $cleanGenre Connoisseur',
      unlockCriteria: 'Requires 750+ hours or 75+ completed shows',
      colorHex: 0xFFA855F7,
    ),
    PrestigeTierInfo(
      level: 10,
      minHours: 1000,
      maxHours: 1500,
      hoursRangeLabel: '1,000–1,500h',
      badge: 'TIER X · LEGENDARY CENTURION',
      sampleTitle: 'Centurion $cleanGenre Virtuoso / Sovereign of 1,000 Hours',
      unlockCriteria: 'Requires 1,000+ hours or 100+ completed shows',
      colorHex: 0xFFEF4444,
    ),
    PrestigeTierInfo(
      level: 11,
      minHours: 1500,
      maxHours: 2200,
      hoursRangeLabel: '1,500–2,200h',
      badge: 'TIER XI · SUPREME LUMINARY',
      sampleTitle: 'Grand Chancellor of Cinema / Supreme $cleanGenre Luminary',
      unlockCriteria: 'Requires 1,500+ hours or 150+ completed shows',
      colorHex: 0xFFFF6B00,
    ),
    PrestigeTierInfo(
      level: 12,
      minHours: 2200,
      maxHours: 3500,
      hoursRangeLabel: '2,200–3,500h',
      badge: 'TIER XII · MYTHIC PANTHEON',
      sampleTitle: 'Mythic $cleanGenre Sovereign',
      unlockCriteria: 'Requires 2,200+ hours or 220+ completed shows',
      colorHex: 0xFFF43F9E,
    ),
    PrestigeTierInfo(
      level: 13,
      minHours: 3500,
      maxHours: 5000,
      hoursRangeLabel: '3,500h+',
      badge: 'TIER XIII · CELESTIAL IMMORTAL',
      sampleTitle: 'Celestial $cleanGenre Immortal / Eternal Showrunner',
      unlockCriteria: 'Requires 3,500+ hours or 350+ completed shows',
      colorHex: 0xFF38BDF8,
    ),
  ];
}

class _TierDef {
  final int level;
  final int minHours;
  final int maxHours;
  final String badge;
  final int colorHex;
  final String Function() titleBuilder;
  final String nextTitle;

  const _TierDef({
    required this.level,
    required this.minHours,
    required this.maxHours,
    required this.badge,
    required this.colorHex,
    required this.titleBuilder,
    required this.nextTitle,
  });
}

BingePersona computeBingePersona({
  required int hoursWatched,
  required int doneCount,
  required int totalShows,
  required int episodesWatched,
  required String topGenre,
}) {
  final cleanGenre = resolveCleanGenre(topGenre);
  final completionRatio = totalShows > 0 ? doneCount / totalShows : 0.0;
  final effectiveHours = max(hoursWatched, doneCount * 10);

  final tiers = <_TierDef>[
    _TierDef(
      level: 1,
      minHours: 0,
      maxHours: 10,
      badge: 'TIER I · PILOT SCOUT',
      colorHex: 0xFF94A3B8,
      titleBuilder: () =>
          totalShows >= 5 ? 'Emerging Queue Curator' : 'Pilot Episode Scout',
      nextTitle: 'First-Act Initiate (10h)',
    ),
    _TierDef(
      level: 2,
      minHours: 10,
      maxHours: 30,
      badge: 'TIER II · FIRST-ACT INITIATE',
      colorHex: 0xFF38BDF8,
      titleBuilder: () => 'First-Act $cleanGenre Seeker',
      nextTitle: 'Bronze Voyager (30h)',
    ),
    _TierDef(
      level: 3,
      minHours: 30,
      maxHours: 65,
      badge: 'TIER III · BRONZE VOYAGER',
      colorHex: 0xFFD97706,
      titleBuilder: () =>
          doneCount >= 5 ? 'Dedicated Season Finisher' : '$cleanGenre Story Voyager',
      nextTitle: 'Silver Aficionado (65h)',
    ),
    _TierDef(
      level: 4,
      minHours: 65,
      maxHours: 120,
      badge: 'TIER IV · SILVER AFICIONADO',
      colorHex: 0xFFA3E635,
      titleBuilder: () => completionRatio >= 0.6
          ? 'Precision $cleanGenre Finisher'
          : 'Silver Screen $cleanGenre Devotee',
      nextTitle: 'Emerald Marathoner (120h)',
    ),
    _TierDef(
      level: 5,
      minHours: 120,
      maxHours: 220,
      badge: 'TIER V · EMERALD MARATHONER',
      colorHex: 0xFF10B981,
      titleBuilder: () => episodesWatched >= 250
          ? 'Midnight $cleanGenre Marathoner'
          : 'Emerald $cleanGenre Navigator',
      nextTitle: 'Gold Specialist (220h)',
    ),
    _TierDef(
      level: 6,
      minHours: 220,
      maxHours: 350,
      badge: 'TIER VI · GOLD SPECIALIST',
      colorHex: 0xFFFACC15,
      titleBuilder: () => doneCount >= 30
          ? 'Veteran Cliffhanger Survivor'
          : 'Golden Era $cleanGenre Specialist',
      nextTitle: 'Diamond Architect (350h)',
    ),
    _TierDef(
      level: 7,
      minHours: 350,
      maxHours: 500,
      badge: 'TIER VII · DIAMOND ARCHITECT',
      colorHex: 0xFF00F5D4,
      titleBuilder: () => totalShows >= 75
          ? 'Prime Watchlist Architect'
          : 'Diamond $cleanGenre Tactician',
      nextTitle: 'Platinum Vanguard (500h)',
    ),
    _TierDef(
      level: 8,
      minHours: 500,
      maxHours: 750,
      badge: 'TIER VIII · PLATINUM VANGUARD',
      colorHex: 0xFF6366F1,
      titleBuilder: () => doneCount >= 60
          ? 'Relentless Finale Commander'
          : 'Platinum $cleanGenre Vanguard',
      nextTitle: 'Apex Archivist (750h)',
    ),
    _TierDef(
      level: 9,
      minHours: 750,
      maxHours: 1000,
      badge: 'TIER IX · APEX ARCHIVIST',
      colorHex: 0xFFA855F7,
      titleBuilder: () => doneCount >= 80
          ? 'Imperial Series Archivist'
          : 'Apex $cleanGenre Connoisseur',
      nextTitle: 'Legendary Centurion (1,000h)',
    ),
    _TierDef(
      level: 10,
      minHours: 1000,
      maxHours: 1500,
      badge: 'TIER X · LEGENDARY CENTURION',
      colorHex: 0xFFEF4444,
      titleBuilder: () {
        if (doneCount >= 100) return 'Centurion $cleanGenre Virtuoso';
        if (episodesWatched >= 1400) return 'Sovereign of 1,000 Hours';
        return 'Legendary $cleanGenre Auteur';
      },
      nextTitle: 'Supreme Luminary (1,500h)',
    ),
    _TierDef(
      level: 11,
      minHours: 1500,
      maxHours: 2200,
      badge: 'TIER XI · SUPREME LUMINARY',
      colorHex: 0xFFFF6B00,
      titleBuilder: () => doneCount >= 150
          ? 'Grand Chancellor of Cinema'
          : 'Supreme $cleanGenre Luminary',
      nextTitle: 'Mythic Pantheon (2,200h)',
    ),
    _TierDef(
      level: 12,
      minHours: 2200,
      maxHours: 3500,
      badge: 'TIER XII · MYTHIC PANTHEON',
      colorHex: 0xFFF43F9E,
      titleBuilder: () => 'Mythic $cleanGenre Sovereign',
      nextTitle: 'Celestial Immortal (3,500h)',
    ),
    _TierDef(
      level: 13,
      minHours: 3500,
      maxHours: 5000,
      badge: 'TIER XIII · CELESTIAL IMMORTAL',
      colorHex: 0xFF38BDF8,
      titleBuilder: () => doneCount >= 350
          ? 'Eternal $cleanGenre Showrunner'
          : 'Celestial $cleanGenre Immortal',
      nextTitle: 'Supreme Celestial Rank',
    ),
  ];

  final matched = tiers.lastWhere(
    (t) => effectiveHours >= t.minHours,
    orElse: () => tiers.first,
  );
  final span = max(1, matched.maxHours - matched.minHours);
  final currentTierProgress = matched.level >= 13
      ? 1.0
      : ((effectiveHours - matched.minHours) / span).clamp(0.0, 1.0);
  final progress =
      (((matched.level - 1) + currentTierProgress) / tiers.length).clamp(0.04, 1.0);

  return BingePersona(
    title: matched.titleBuilder(),
    rankBadge: matched.badge,
    tierLevel: matched.level,
    accentColorHex: matched.colorHex,
    nextRankTitle: matched.nextTitle,
    nextMilestoneHours: matched.maxHours,
    progressFraction: progress,
  );
}

StatsSnapshot computeStatsSnapshot(List<Drama> dramas, {DateTime? now}) {
  final active = dramas.where((d) => !d.isDeleted).toList();
  final watchingCount = active.where((d) => d.status == 'Watching').length;
  final plannedCount = active.where((d) => d.status == 'Planned').length;
  final doneCount = active.where((d) => d.status == 'Done').length;

  var totalEpisodesWatched = 0;
  for (final d in active) {
    if (d.status == 'Done' && d.episodesWatched == 0 && d.totalEpisodes > 0) {
      totalEpisodesWatched += d.totalEpisodes;
    } else {
      totalEpisodesWatched += d.episodesWatched;
    }
  }
  final estimatedHours = (totalEpisodesWatched * 45) ~/ 60;

  final genreCounts = <String, int>{};
  for (final d in active) {
    for (final g in d.genreList) {
      genreCounts[g] = (genreCounts[g] ?? 0) + 1;
    }
  }
  final genreBreakdown = genreCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top6Genres = genreBreakdown.take(6).toList();

  final ref = now ?? DateTime.now();
  final monthFmt = DateFormat('MMM', 'en_US');
  final buckets = <MonthlyActivityBucket>[];
  for (var i = 11; i >= 0; i--) {
    final dt = DateTime(ref.year, ref.month - i, 1);
    final label = monthFmt.format(dt);
    final count = active.where((d) {
      final ts = d.completedAt > 0
          ? d.completedAt
          : (d.updatedAt > 0 ? d.updatedAt : d.addedAt);
      if (ts <= 0) return false;
      final dDt = DateTime.fromMillisecondsSinceEpoch(ts);
      return dDt.year == dt.year && dDt.month == dt.month;
    }).length;
    buckets.add(MonthlyActivityBucket(label, count));
  }

  var streak = 0;
  for (var i = buckets.length - 1; i >= 0; i--) {
    if (buckets[i].count > 0) {
      streak++;
    } else {
      break;
    }
  }

  final topRated = List<Drama>.from(active)
    ..sort((a, b) => b.effectiveRating.compareTo(a.effectiveRating));
  final top5Rated = topRated.take(5).toList();

  final topGenreName =
      top6Genres.isNotEmpty ? top6Genres.first.key : 'Multi-Genre';

  final persona = computeBingePersona(
    hoursWatched: estimatedHours,
    doneCount: doneCount,
    totalShows: active.length,
    episodesWatched: totalEpisodesWatched,
    topGenre: topGenreName,
  );

  final radar = active
      .where(
        (d) =>
            (d.nextEpisodeAirDate ?? '').trim().isNotEmpty &&
            (d.status == 'Watching' || d.status == 'Planned'),
      )
      .toList()
    ..sort((a, b) => (a.nextEpisodeAirDate ?? '').compareTo(b.nextEpisodeAirDate ?? ''));

  final diary = active
      .where((d) => d.updatedAt > 0 || d.completedAt > 0 || d.addedAt > 0)
      .toList()
    ..sort(
      (a, b) => max(b.completedAt, max(b.updatedAt, b.addedAt))
          .compareTo(max(a.completedAt, max(a.updatedAt, a.addedAt))),
    );

  return StatsSnapshot(
    activeDramas: active,
    watchingCount: watchingCount,
    plannedCount: plannedCount,
    doneCount: doneCount,
    totalEpisodesWatched: totalEpisodesWatched,
    estimatedHours: estimatedHours,
    genreBreakdown: top6Genres,
    monthlyActivity: buckets,
    currentStreakMonths: streak,
    topRatedShows: top5Rated,
    topGenreName: topGenreName,
    bingePersona: persona,
    releaseRadarShows: radar.take(8).toList(),
    diaryEntries: diary.take(7).toList(),
  );
}

/// Renders the exact 1080×1350 Moglog Wrapped PNG card offscreen using `dart:ui`.
Future<Uint8List> renderWrappedCardPng({
  required int totalShows,
  required int doneShows,
  required int episodesWatched,
  required int hoursWatched,
  required String topGenre,
  required BingePersona persona,
  required List<Drama> topShows,
}) async {
  const double width = 1080;
  const double height = 1350;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));
  final tierColor = Color(persona.accentColorHex);

  // Obsidian gradient background
  final bgPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0E141B), Color(0xFF121318), Color(0xFF0B1F17)],
      stops: [0.0, 0.55, 1.0],
    ).createShader(const Rect.fromLTWH(0, 0, width, height));
  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

  // Outer card
  final outerRRect = RRect.fromRectAndRadius(
    const Rect.fromLTRB(64, 64, width - 64, height - 64),
    const Radius.circular(48),
  );
  canvas.drawRRect(outerRRect, Paint()..color = const Color(0xFF1C1E24));
  canvas.drawRRect(
    outerRRect,
    Paint()
      ..color = tierColor.withAlpha(130)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  void drawText(
    String text,
    double x,
    double y, {
    required Color color,
    required double fontSize,
    FontWeight weight = FontWeight.bold,
    double letterSpacing = 0,
    double maxWidth = width - 248,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: letterSpacing,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(x, y));
  }

  // Top badge
  drawText(
    'MOGLOG WRAPPED  ·  ${persona.rankBadge}',
    124,
    120,
    color: tierColor,
    fontSize: 24,
    letterSpacing: 1.5,
  );

  // Auto-fitting persona title
  var titleSize = 52.0;
  while (titleSize > 32) {
    final probe = TextPainter(
      text: TextSpan(
        text: persona.title,
        style: TextStyle(fontFamily: 'Inter', fontSize: titleSize, fontWeight: FontWeight.bold),
      ),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    if (probe.width <= width - 248) break;
    titleSize -= 2;
  }
  drawText(persona.title, 124, 168, color: Colors.white, fontSize: titleSize);

  final daysWatched = (hoursWatched / 24.0).toStringAsFixed(1);
  drawText(
    'Top Genre: $topGenre  ·  ~$daysWatched full days streamed  ·  Rank ${persona.tierLevel}/13',
    124,
    244,
    color: const Color(0xB3EBEBF5),
    fontSize: 26,
    weight: FontWeight.normal,
  );

  // Progress track
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTRB(124, 296, width - 124, 308),
      const Radius.circular(6),
    ),
    Paint()..color = const Color(0xFF2B2F3A),
  );
  final fillW = max(18.0, (width - 248) * persona.progressFraction);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(124, 296, fillW, 12),
      const Radius.circular(6),
    ),
    Paint()..color = tierColor,
  );

  // 2x2 Metric Boxes
  final metrics = [
    ('HOURS STREAMED', '${hoursWatched}h'),
    ('EPISODES LOGGED', '$episodesWatched'),
    ('TOTAL SERIES', '$totalShows'),
    ('COMPLETED', '$doneShows'),
  ];
  for (var idx = 0; idx < metrics.length; idx++) {
    final col = idx % 2;
    final row = idx ~/ 2;
    final left = 124.0 + col * 430.0;
    final top = 342.0 + row * 210.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, 400, 180),
        const Radius.circular(28),
      ),
      Paint()..color = const Color(0xFF262932),
    );
    drawText(metrics[idx].$1, left + 32, top + 34, color: tierColor, fontSize: 22, maxWidth: 340);
    drawText(metrics[idx].$2, left + 32, top + 78, color: Colors.white, fontSize: 58, maxWidth: 340);
  }

  // Top Rated Shows
  drawText(
    'TOP RATED IN MY LIBRARY',
    124,
    798,
    color: tierColor,
    fontSize: 24,
    letterSpacing: 1.5,
  );
  for (var i = 0; i < min(4, topShows.length); i++) {
    final d = topShows[i];
    final y = 860.0 + i * 78.0;
    final score = d.effectiveRating.toStringAsFixed(1);
    drawText('${i + 1}. ${d.title}', 124, y, color: Colors.white, fontSize: 34, maxWidth: 610);
    drawText('$score / 10', width - 310, y, color: const Color(0xFFFFD60A), fontSize: 33, maxWidth: 200);
  }

  drawText(
    'Tracked privately with Moglog  ·  Next Rank: ${persona.nextRankTitle}',
    124,
    height - 138,
    color: const Color(0x80EBEBF5),
    fontSize: 24,
    weight: FontWeight.normal,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
