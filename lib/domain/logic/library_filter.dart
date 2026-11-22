import 'dart:math';

import '../model/app_settings.dart';
import '../model/drama.dart';

const String kTopFourShelfKey = '__TOP_FOUR__';

const List<String> kPresetGenres = [
  'Action & Adventure',
  'Animation',
  'Comedy',
  'Crime',
  'Documentary',
  'Drama',
  'Family',
  'Fantasy',
  'History',
  'Horror',
  'Kids',
  'Mystery',
  'Reality',
  'Romance',
  'Sci-Fi & Fantasy',
  'Thriller',
  'War & Politics',
  'Western',
];

/// Filters and sorts active library shows matching Kotlin `LibraryScreen.kt` 1:1.
List<Drama> filterAndSortLibrary({
  required List<Drama> allDramas,
  required String selectedStatus,
  required String? selectedShelf,
  required List<int> topFourFavoriteIds,
  required String searchQuery,
  required LibraryFilterState filterState,
}) {
  final active = allDramas.where((d) => !d.isDeleted);
  final query = searchQuery.trim().toLowerCase();

  final filtered = active.where((drama) {
    if (selectedStatus != 'All' && drama.status != selectedStatus) {
      return false;
    }
    if (selectedShelf != null) {
      if (selectedShelf == kTopFourShelfKey) {
        if (!topFourFavoriteIds.contains(drama.id)) return false;
      } else {
        final hasShelf = drama.tagList
            .any((t) => t.toLowerCase() == selectedShelf.toLowerCase());
        if (!hasShelf) return false;
      }
    }
    if (filterState.onlyPartiallyDone && !drama.isPartiallyDone) {
      return false;
    }
    if (query.isNotEmpty) {
      final matchTitle = drama.title.toLowerCase().contains(query);
      final matchNotes = drama.notes.toLowerCase().contains(query);
      final matchTags = drama.tags.toLowerCase().contains(query);
      if (!matchTitle && !matchNotes && !matchTags) return false;
    }
    if (filterState.minRating > 0.0) {
      if (drama.effectiveRating < filterState.minRating) return false;
    }
    if (filterState.selectedGenres.isNotEmpty) {
      final lowerSelected =
          filterState.selectedGenres.map((g) => g.toLowerCase()).toSet();
      final matchesGenre =
          drama.genreList.any((g) => lowerSelected.contains(g.toLowerCase()));
      if (!matchesGenre) return false;
    }
    return true;
  }).toList();

  if (selectedShelf == kTopFourShelfKey) {
    final orderMap = {
      for (var i = 0; i < topFourFavoriteIds.length; i++)
        topFourFavoriteIds[i]: i,
    };
    filtered.sort((a, b) => (orderMap[a.id] ?? 99).compareTo(orderMap[b.id] ?? 99));
    return filtered;
  }

  switch (filterState.sortOption) {
    case LibrarySortOption.recentlyAdded:
      filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    case LibrarySortOption.recentlyUpdated:
      filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case LibrarySortOption.recentlyCompleted:
      filtered.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    case LibrarySortOption.tmdbRating:
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    case LibrarySortOption.myRating:
      filtered.sort((a, b) => b.effectiveRating.compareTo(a.effectiveRating));
    case LibrarySortOption.titleAz:
      filtered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case LibrarySortOption.year:
      filtered.sort((a, b) => b.releaseYear.compareTo(a.releaseYear));
  }
  return filtered;
}

/// Last-Write-Wins merge by `updatedAt` matching Kotlin `DramaViewModel.reconcileCloudAndLocal`.
Drama resolveLwwMerge(Drama local, Drama incoming) {
  return incoming.updatedAt >= local.updatedAt ? incoming : local;
}

/// Exact port of `ContinueWatchingSection.computeAiringCountdownLabel`.
String? computeAiringCountdownLabel(String? nextAirDateIso, {DateTime? now}) {
  if (nextAirDateIso == null || nextAirDateIso.trim().isEmpty) return null;
  try {
    final datePart = nextAirDateIso.trim().substring(0, min(10, nextAirDateIso.trim().length));
    final parsed = DateTime.parse(datePart);
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final days = target.difference(today).inDays;
    if (days < 0) return null;
    if (days == 0) return 'AIRS TODAY';
    if (days == 1) return 'TOMORROW';
    if (days >= 2 && days <= 14) return 'IN ${days}D';
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[target.month - 1]} ${target.day}';
  } catch (_) {
    return null;
  }
}

/// CSV export with formula-injection neutralization matching Kotlin `DramaViewModel.escapeCsvField`.
String escapeCsvField(String value) {
  var str = value.trim();
  if (str.startsWith('=') ||
      str.startsWith('+') ||
      str.startsWith('-') ||
      str.startsWith('@')) {
    str = "'$str";
  }
  if (str.contains(',') ||
      str.contains('"') ||
      str.contains('\n') ||
      str.contains('\r')) {
    return '"${str.replaceAll('"', '""')}"';
  }
  return str;
}

String exportDramasToCsv(List<Drama> dramas) {
  final sb = StringBuffer();
  sb.writeln('title,tmdb_id,status,episodes_watched,total_episodes,season,rating,genres,tags');
  for (final d in dramas.where((e) => !e.isDeleted)) {
    final rate = d.myRating > 0.0 ? d.myRating : d.rating;
    sb
      ..write(escapeCsvField(d.title))
      ..write(',')
      ..write(d.id)
      ..write(',')
      ..write(escapeCsvField(d.status))
      ..write(',')
      ..write(d.episodesWatched)
      ..write(',')
      ..write(d.totalEpisodes)
      ..write(',')
      ..write(d.currentSeason)
      ..write(',')
      ..write(rate.toStringAsFixed(1))
      ..write(',')
      ..write(escapeCsvField(d.genres))
      ..write(',')
      ..write(escapeCsvField(d.tags))
      ..writeln();
  }
  return sb.toString();
}

class ParsedCsvShowRow {
  final String title;
  int tmdbId;
  String status;
  int episodesWatched;
  int maxSeason;
  double rating;
  int rowCount;

  ParsedCsvShowRow({
    required this.title,
    this.tmdbId = 0,
    this.status = 'Watching',
    this.episodesWatched = 0,
    this.maxSeason = 1,
    this.rating = 0.0,
    this.rowCount = 0,
  });

  int get effectiveEpisodes =>
      episodesWatched > 0 ? episodesWatched : (rowCount > 1 ? rowCount : 0);
}

List<String> splitCsvRow(String row) {
  final result = <String>[];
  final current = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < row.length; i++) {
    final ch = row[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if ((ch == ',' || ch == ';') && !inQuotes) {
      result.add(_stripOuterQuotes(current.toString().trim()));
      current.clear();
    } else {
      current.write(ch);
    }
  }
  result.add(_stripOuterQuotes(current.toString().trim()));
  return result;
}

String _stripOuterQuotes(String s) {
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    return s.substring(1, s.length - 1).replaceAll('""', '"');
  }
  return s;
}

/// Parses Moglog, TV Time, and Trakt CSV exports using the exact header alias rules from Kotlin.
Map<String, ParsedCsvShowRow> parseCsvHistoryRows(String rawCsv) {
  final lines = rawCsv
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return {};

  final headers = splitCsvRow(lines.first).map((h) => h.toLowerCase()).toList();
  int findIdx(List<String> aliases) => headers.indexWhere(aliases.contains);

  final rawTitleIdx = findIdx(
    const ['title', 'show_title', 'series_title', 'name', 'show', 'tv_show_name', 'series'],
  );
  final titleIdx = rawTitleIdx >= 0 ? rawTitleIdx : 0;
  final tmdbIdx = findIdx(const ['tmdb_id', 'tmdbid', 'tmdb', 'show_tmdb_id', 'id']);
  final statusIdx = findIdx(const ['status', 'watch_status', 'state', 'list']);
  final episodesIdx = findIdx(
    const ['episodes_watched', 'watched_episodes', 'episodes', 'episode_number', 'episode', 'plays'],
  );
  final seasonIdx = findIdx(const ['season', 'season_number', 'current_season']);
  final ratingIdx = findIdx(const ['rating', 'my_rating', 'user_rating', 'score']);

  final grouped = <String, ParsedCsvShowRow>{};

  for (final line in lines.skip(1)) {
    final cols = splitCsvRow(line);
    if (titleIdx >= cols.length) continue;
    final rawTitle = cols[titleIdx].trim();
    if (rawTitle.isEmpty) continue;
    final key = rawTitle.toLowerCase();
    final agg = grouped.putIfAbsent(key, () => ParsedCsvShowRow(title: rawTitle));
    agg.rowCount++;

    if (tmdbIdx >= 0 && tmdbIdx < cols.length) {
      final parsedId = int.tryParse(cols[tmdbIdx]) ?? 0;
      if (parsedId > 0) agg.tmdbId = parsedId;
    }
    if (statusIdx >= 0 && statusIdx < cols.length) {
      final rawSt = cols[statusIdx].toLowerCase();
      if (rawSt.contains('done') || rawSt.contains('complet') || rawSt.contains('finish')) {
        agg.status = 'Done';
      } else if (rawSt.contains('plan') || rawSt.contains('watchlist') || rawSt.contains('to watch')) {
        agg.status = 'Planned';
      } else {
        agg.status = 'Watching';
      }
    }
    if (episodesIdx >= 0 && episodesIdx < cols.length) {
      final epVal = int.tryParse(cols[episodesIdx]) ?? 0;
      if (epVal > agg.episodesWatched) agg.episodesWatched = epVal;
    }
    if (seasonIdx >= 0 && seasonIdx < cols.length) {
      final sVal = int.tryParse(cols[seasonIdx]) ?? 1;
      if (sVal > agg.maxSeason) agg.maxSeason = sVal;
    }
    if (ratingIdx >= 0 && ratingIdx < cols.length) {
      final rVal = double.tryParse(cols[ratingIdx]) ?? 0.0;
      if (rVal > 0.0) {
        agg.rating = (rVal <= 5.0 && !headers[ratingIdx].contains('10'))
            ? rVal * 2.0
            : rVal.clamp(0.0, 10.0);
      }
    }
  }
  return grouped;
}
