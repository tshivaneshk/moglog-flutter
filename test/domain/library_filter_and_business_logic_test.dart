import 'package:flutter_test/flutter_test.dart';
import 'package:moglog_flutter/core/security/secure_store.dart';
import 'package:moglog_flutter/data/remote/watch_circle_repository.dart';
import 'package:moglog_flutter/domain/logic/library_filter.dart';
import 'package:moglog_flutter/domain/logic/season_progress.dart';
import 'package:moglog_flutter/domain/logic/stats_calculator.dart';
import 'package:moglog_flutter/domain/logic/version_checker.dart';
import 'package:moglog_flutter/domain/model/app_settings.dart';
import 'package:moglog_flutter/domain/model/drama.dart';
import 'package:moglog_flutter/domain/model/drama_extra_details.dart';
import 'package:moglog_flutter/domain/model/watch_circle_models.dart';

void main() {
  final sampleDramas = [
    const Drama(
      id: 1,
      title: 'Alchemy of Souls',
      overview: 'Fantasy romance',
      rating: 8.7,
      myRating: 9.5,
      posterPath: '/p1.jpg',
      status: 'Done',
      episodesWatched: 20,
      totalEpisodes: 20,
      genres: 'Drama, Sci-Fi & Fantasy',
      tags: 'Comfort Shows',
      releaseYear: 2022,
      addedAt: 1000,
      updatedAt: 3000,
      completedAt: 4000,
    ),
    const Drama(
      id: 2,
      title: 'Moving',
      overview: 'Superheroes',
      rating: 8.5,
      myRating: 9.0,
      posterPath: '/p2.jpg',
      status: 'Watching',
      episodesWatched: 12,
      totalEpisodes: 20,
      totalSeasons: 2,
      currentSeason: 2,
      genres: 'Action & Adventure, Mystery',
      tags: 'Weekend Binge',
      releaseYear: 2023,
      addedAt: 2000,
      updatedAt: 5000,
    ),
    const Drama(
      id: 3,
      title: 'Beyond Evil',
      overview: 'Psychological thriller',
      rating: 8.2,
      myRating: 0.0,
      posterPath: '/p3.jpg',
      status: 'Planned',
      episodesWatched: 0,
      totalEpisodes: 16,
      genres: 'Crime, Mystery',
      releaseYear: 2021,
      addedAt: 3000,
      updatedAt: 2500,
    ),
  ];

  group('Library filtering, sorting & LWW merge', () {
    test('filtering by genre and minimum rating returns matching shows', () {
      final result = filterAndSortLibrary(
        allDramas: sampleDramas,
        selectedStatus: 'All',
        selectedShelf: null,
        topFourFavoriteIds: const [],
        searchQuery: '',
        filterState: const LibraryFilterState(
          sortOption: LibrarySortOption.myRating,
          selectedGenres: {'Mystery'},
          minRating: 8.4,
        ),
      );
      expect(result.length, 1);
      expect(result.first.title, 'Moving');
    });

    test('partially done filter detects multi-season in-progress shows', () {
      final result = filterAndSortLibrary(
        allDramas: sampleDramas,
        selectedStatus: 'All',
        selectedShelf: null,
        topFourFavoriteIds: const [],
        searchQuery: '',
        filterState: const LibraryFilterState(onlyPartiallyDone: true),
      );
      expect(result.length, 1);
      expect(result.first.id, 2);
    });

    test('LWW merge keeps newer updatedAt record', () {
      final local = sampleDramas[1]; // updatedAt = 5000, ep = 12
      final older = local.copyWith(episodesWatched: 8, updatedAt: 4000);
      final newer = local.copyWith(episodesWatched: 15, updatedAt: 7500);

      expect(resolveLwwMerge(local, older).episodesWatched, 12);
      expect(resolveLwwMerge(local, newer).episodesWatched, 15);
    });

    test('CSV export neutralizes formula injection and round-trips CSV parser', () {
      final dangerous = [
        sampleDramas[0].copyWith(title: '=CMD|calc', tags: '+evil'),
      ];
      final csv = exportDramasToCsv(dangerous);
      expect(csv, contains("'=CMD|calc"));
      expect(csv, contains("'+evil"));

      final parsed = parseCsvHistoryRows(
        'series_title,tmdb_id,watch_status,watched_episodes,season_number,score\n'
        '"Moving",2,watching,12,2,4.5\n',
      );
      expect(parsed['moving']?.tmdbId, 2);
      expect(parsed['moving']?.episodesWatched, 12);
      expect(parsed['moving']?.rating, 9.0); // 5-star scaled to 10-point scale
    });
  });

  group('Airing countdown, season breakdown & binge calculator', () {
    test('computeAiringCountdownLabel matches Kotlin labels', () {
      final ref = DateTime(2026, 5, 10);
      expect(computeAiringCountdownLabel('2026-05-10', now: ref), 'AIRS TODAY');
      expect(computeAiringCountdownLabel('2026-05-11', now: ref), 'TOMORROW');
      expect(computeAiringCountdownLabel('2026-05-15', now: ref), 'IN 5D');
      expect(computeAiringCountdownLabel('2026-06-02', now: ref), 'JUN 2');
      expect(computeAiringCountdownLabel('2026-05-09', now: ref), isNull);
    });

    test('resolveSeasonBreakdown synthesizes even offline split', () {
      final seasons = resolveSeasonBreakdown(
        seasons: const <SeasonInfo>[],
        totalSeasons: 3,
        totalEpisodes: 25,
      );
      expect(seasons.length, 3);
      expect(seasons[0].episodeCount, 8);
      expect(seasons[1].episodeCount, 8);
      expect(seasons[2].episodeCount, 9);
    });

    test('computeBingeEstimate calculates remaining time and pace days', () {
      final est = computeBingeEstimate(
        episodesWatched: 4,
        totalEpisodes: 14,
        episodeRuntimeMinutes: 60,
      );
      expect(est.remainingEpisodes, 10);
      expect(est.remainingHours, 10);
      expect(est.daysAtPace[1], 10);
      expect(est.daysAtPace[2], 5);
      expect(est.daysAtPace[3], 4);
      expect(est.daysAtPace[5], 2);
    });
  });

  group('Stats 13 Prestige Tiers, Taste Blend & Version Checker', () {
    test('13 Prestige Tiers advance accurately across hours thresholds', () {
      expect(getPrestigeTiersCatalog('Sci-Fi & Fantasy').length, 13);

      final tier1 = computeBingePersona(
        hoursWatched: 4,
        doneCount: 0,
        totalShows: 2,
        episodesWatched: 6,
        topGenre: 'Drama',
      );
      expect(tier1.tierLevel, 1);

      final tier5 = computeBingePersona(
        hoursWatched: 150,
        doneCount: 14,
        totalShows: 20,
        episodesWatched: 260,
        topGenre: 'Sci-Fi & Fantasy',
      );
      expect(tier5.tierLevel, 5);
      expect(tier5.title, 'Midnight Sci-Fi Marathoner');

      final tier13 = computeBingePersona(
        hoursWatched: 3600,
        doneCount: 360,
        totalShows: 400,
        episodesWatched: 4800,
        topGenre: 'Mystery',
      );
      expect(tier13.tierLevel, 13);
      expect(tier13.progressFraction, 1.0);
    });

    test('TasteBlendCalculator computes compatibility and CoWatchPairs', () {
      const friend = FriendProfile(
        uid: 'f1',
        displayName: 'Alex',
        topGenres: ['Mystery', 'Drama'],
        currentlyWatching: [
          SharedShowItem(
            id: 2,
            title: 'Moving',
            status: 'Watching',
            episodesWatched: 10,
            totalEpisodes: 20,
            myRating: 9.0,
            genres: 'Action & Adventure, Mystery',
          ),
        ],
        recentlyCompleted: [
          SharedShowItem(
            id: 1,
            title: 'Alchemy of Souls',
            status: 'Done',
            episodesWatched: 20,
            totalEpisodes: 20,
            myRating: 9.5,
            genres: 'Drama, Sci-Fi & Fantasy',
          ),
        ],
      );

      final blend = TasteBlendCalculator.computeBlend(sampleDramas, friend);
      expect(blend.sharedShows.length, 2);
      expect(blend.compatibilityPercent, greaterThanOrEqualTo(75));

      final pairs = TasteBlendCalculator.buildCoWatchPairs(sampleDramas, [friend]);
      expect(pairs.length, 1);
      expect(pairs.first.episodeDelta, 2); // 12 - 10
    });

    test('WatchCircle invite code generator & clipboard extractor work cleanly', () {
      final code = WatchCircleRepository.generateInviteCode('uid_12345');
      expect(code.length, 6);
      expect(
        WatchCircleRepository.extractCodeFromClipboard('Join me! CODE: MOG-$code'),
        isNotNull,
      );
      expect(WatchCircleRepository.normalizeInviteCode('mog-ab23cd'), 'AB23CD');
    });

    test('Version checker handles 2-digit patch semantics & trusted host sanitizer', () {
      expect(isNewerVersion(current: '3.0.7', latest: '3.0.71'), isTrue);
      expect(isNewerVersion(current: '3.0.71', latest: '3.0.8'), isTrue);
      expect(isNewerVersion(current: '3.0.73', latest: '3.0.73'), isFalse);

      expect(
        sanitizeTrustedUpdateUrl(
          'https://github.com/tshivaneshk/Moglog-Releases/releases/download/v3.1.0/app.apk',
          'https://fallback',
        ),
        contains('github.com'),
      );
      expect(
        sanitizeTrustedUpdateUrl(
          'https://evil.example.com/app.apk',
          'https://fallback',
        ),
        'https://fallback',
      );
    });

    test('buildShowShareText includes Track With Moglog and instruction webpage link', () {
      final shareText = buildShowShareText(
        drama: sampleDramas[1],
        isInLibrary: true,
        primaryWatch: ('Disney+', 'https://www.disneyplus.com/search?q=Moving'),
      );
      expect(shareText, contains('Moving (2023)'));
      expect(shareText, contains('My Rating: 9.0/10'));
      expect(shareText, contains('Status: Watching · Ep 12/20'));
      expect(shareText, contains('Track With Moglog'));
      expect(shareText, contains('https://moglog-instructions.vercel.app'));
    });

    test('normalizePosterUrl converts relative TMDB paths to HTTPS full URLs', () {
      expect(
        normalizePosterUrl('/abc123.jpg'),
        'https://image.tmdb.org/t/p/w500/abc123.jpg',
      );
      expect(
        normalizePosterUrl('http://image.tmdb.org/t/p/w500/xyz.jpg'),
        'https://image.tmdb.org/t/p/w500/xyz.jpg',
      );
      expect(normalizePosterUrl(''), '');
    });

    test('TMDB credential validator blocks compromised legacy key and validates v3/v4', () {
      expect(
        SecureStore.isValidTmdbCredentialFormat('b30d871ab7f51c18054f0e6d0921da16'),
        isFalse,
      );
      expect(
        SecureStore.isValidTmdbCredentialFormat('a1b2c3d4e5f60718293a4b5c6d7e8f90'),
        isTrue,
      );
      expect(
        SecureStore.isValidTmdbCredentialFormat(
          'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MCJ9.abcdef1234567890abcdef',
        ),
        isTrue,
      );
    });
  });
}
