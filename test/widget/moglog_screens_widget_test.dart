import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moglog_flutter/app/providers.dart';
import 'package:moglog_flutter/core/design_system/components.dart';
import 'package:moglog_flutter/core/design_system/icons.dart';
import 'package:moglog_flutter/core/design_system/theme.dart';
import 'package:moglog_flutter/domain/model/app_settings.dart';
import 'package:moglog_flutter/domain/model/drama.dart';
import 'package:moglog_flutter/features/library/library_screen.dart';
import 'package:moglog_flutter/features/settings/appearance_settings_screen.dart';
import 'package:moglog_flutter/features/settings/privacy_screen.dart';
import 'package:moglog_flutter/features/stats/stats_screen.dart';

Widget _wrapWithApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: MoglogTheme.dark(),
      home: child,
    ),
  );
}

void main() {
  testWidgets('LibraryScreen renders empty state and Discover CTA', (tester) async {
    var tappedDiscover = false;
    await tester.pumpWidget(
      _wrapWithApp(
        LibraryScreen(
          onDramaTap: (_) {},
          onNavigateToDiscover: () => tappedDiscover = true,
        ),
        overrides: [
          currentDramasProvider.overrideWithValue(const []),
          currentSettingsProvider.overrideWithValue(const AppSettings()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Library is Empty'), findsOneWidget);
    await tester.tap(find.text('Discover Shows'));
    await tester.pump();
    expect(tappedDiscover, isTrue);
  });

  testWidgets('LibraryScreen renders Continue Watching rail and shows', (tester) async {
    final dramas = [
      const Drama(
        id: 1,
        title: 'Severance',
        status: 'Watching',
        episodesWatched: 4,
        totalEpisodes: 9,
        rating: 8.8,
        addedAt: 1000,
        updatedAt: 2000,
      ),
    ];

    await tester.pumpWidget(
      _wrapWithApp(
        LibraryScreen(
          onDramaTap: (_) {},
          onNavigateToDiscover: () {},
        ),
        overrides: [
          currentDramasProvider.overrideWithValue(dramas),
          currentSettingsProvider.overrideWithValue(const AppSettings()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('Severance'), findsWidgets);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('StatsScreen renders Moglog Wrapped Hero Card and metrics', (tester) async {
    final dramas = [
      const Drama(
        id: 1,
        title: 'Shogun',
        status: 'Done',
        episodesWatched: 10,
        totalEpisodes: 10,
        myRating: 9.5,
        genres: 'Drama, History',
        addedAt: 1000,
        updatedAt: 2000,
        completedAt: 3000,
      ),
    ];

    await tester.pumpWidget(
      _wrapWithApp(
        StatsScreen(onDramaTap: (_) {}),
        overrides: [
          currentDramasProvider.overrideWithValue(dramas),
          currentSettingsProvider.overrideWithValue(const AppSettings()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('TOTAL SHOWS'), findsOneWidget);
    expect(find.text('Status Breakdown'), findsOneWidget);
  });

  testWidgets('PrivacyScreen hides tech stack behind info popup button', (tester) async {
    await tester.pumpWidget(
      _wrapWithApp(PrivacyScreen(onBack: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Built for Local-First Privacy'), findsOneWidget);
    expect(find.textContaining('SQLCipher'), findsNothing);

    await tester.tap(find.byIcon(MoglogIcons.info).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('SQLCipher'), findsOneWidget);
  });

  testWidgets('LibraryScreen shows full numbers on Watching and Planned tabs', (tester) async {
    final dramas = [
      const Drama(id: 1, title: 'Show A', status: 'Watching'),
      const Drama(id: 2, title: 'Show B', status: 'Planned'),
    ];
    await tester.pumpWidget(
      _wrapWithApp(
        LibraryScreen(
          onDramaTap: (_) {},
          onNavigateToDiscover: () {},
        ),
        overrides: [
          currentDramasProvider.overrideWithValue(dramas),
          currentSettingsProvider.overrideWithValue(const AppSettings()),
          librarySelectedStatusProvider.overrideWith((_) => 'Watching'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Watching (1)'), findsOneWidget);
  });

  testWidgets('Circular PosterImage renders exact square ClipOval', (tester) async {
    await tester.pumpWidget(
      _wrapWithApp(
        const Scaffold(
          body: Center(
            child: PosterImage(
              url: '',
              width: 64,
              height: 64,
              isCircular: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ovalFinder = find.byType(ClipOval);
    expect(ovalFinder, findsOneWidget);
    final size = tester.getSize(ovalFinder);
    expect(size.width, 64.0);
    expect(size.height, 64.0);
  });

  testWidgets('AppearanceSettingsScreen renders faithfully', (tester) async {
    await tester.pumpWidget(
      _wrapWithApp(
        AppearanceSettingsScreen(onBack: () {}),
        overrides: [
          currentSettingsProvider.overrideWithValue(const AppSettings()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dynamic Poster Accent Tint'), findsOneWidget);
    expect(find.text('3 Columns'), findsOneWidget);
  });
}
