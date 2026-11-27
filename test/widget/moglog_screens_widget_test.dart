import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moglog_flutter/app/ios_bottom_tab_bar.dart';
import 'package:moglog_flutter/app/providers.dart';
import 'package:moglog_flutter/core/design_system/components.dart';
import 'package:moglog_flutter/core/design_system/icons.dart';
import 'package:moglog_flutter/core/design_system/theme.dart';
import 'package:moglog_flutter/domain/model/app_settings.dart';
import 'package:moglog_flutter/domain/model/drama.dart';
import 'package:moglog_flutter/domain/model/show_comment.dart';
import 'package:moglog_flutter/features/detail/widgets/rating_and_notes_card.dart';
import 'package:moglog_flutter/features/library/library_screen.dart';
import 'package:moglog_flutter/features/settings/appearance_settings_screen.dart';
import 'package:moglog_flutter/features/settings/privacy_screen.dart';
import 'package:moglog_flutter/features/settings/recycle_bin_screen.dart';
import 'package:moglog_flutter/features/stats/stats_screen.dart';

Widget _wrapWithApp(
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
  double textScale = 1.0,
  bool highContrast = false,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? MoglogTheme.dark(),
      builder: (context, inner) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            highContrast: highContrast,
            disableAnimations: disableAnimations,
          ),
          child: inner ?? const SizedBox.shrink(),
        );
      },
      home: child,
    ),
  );
}

void main() {
  testWidgets('LibraryScreen renders empty state and Discover CTA',
      (tester) async {
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

  testWidgets('LibraryScreen renders Continue Watching rail and shows',
      (tester) async {
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

  testWidgets('StatsScreen renders Moglog Wrapped Hero Card and metrics',
      (tester) async {
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

    expect(find.text('Statistics'), findsWidgets);
    expect(find.text('TOTAL SHOWS'), findsOneWidget);
    expect(find.text('Status Breakdown'), findsOneWidget);
  });

  testWidgets('PrivacyScreen hides tech stack behind info popup button',
      (tester) async {
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

  testWidgets('LibraryScreen shows full numbers on Watching and Planned tabs',
      (tester) async {
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

  testWidgets('Circular PosterImage renders exact square ClipOval',
      (tester) async {
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

  testWidgets(
      'Floating IosBottomTabBar exposes accessible tab semantics, >=48dp targets, and reduce-transparency fallback',
      (tester) async {
    final handle = tester.ensureSemantics();
    var selectedTab = 0;

    await tester.pumpWidget(
      _wrapWithApp(
        StatefulBuilder(
          builder: (ctx, setState) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: IosBottomTabBar(
                currentIndex: selectedTab,
                onTap: (idx) => setState(() => selectedTab = idx),
              ),
            ),
          ),
        ),
        highContrast: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Library, tab 1 of 4'), findsOneWidget);
    expect(find.bySemanticsLabel('Discover, tab 2 of 4'), findsOneWidget);
    expect(find.bySemanticsLabel('Stats, tab 3 of 4'), findsOneWidget);
    expect(find.bySemanticsLabel('Settings, tab 4 of 4'), findsOneWidget);

    // Reduce-transparency fallback omits BackdropFilter
    expect(find.byType(BackdropFilter), findsNothing);

    final libBox = tester.getSize(find.bySemanticsLabel('Library, tab 1 of 4'));
    expect(libBox.height, greaterThanOrEqualTo(48.0));

    await tester.tap(find.bySemanticsLabel('Stats, tab 3 of 4'));
    await tester.pumpAndSettle();
    expect(selectedTab, 2);
    handle.dispose();
  });

  testWidgets(
      'Glossy IosPrimaryButton maintains stable width during loading and >=48dp touch target',
      (tester) async {
    var isLoading = false;
    await tester.pumpWidget(
      _wrapWithApp(
        StatefulBuilder(
          builder: (ctx, setState) => Scaffold(
            body: Center(
              child: IosPrimaryButton(
                text: 'Add to Library',
                expand: false,
                loading: isLoading,
                onTap: () => setState(() => isLoading = true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(IosPrimaryButton);
    final initialSize = tester.getSize(buttonFinder);
    expect(initialSize.height, greaterThanOrEqualTo(48.0));

    await tester.tap(buttonFinder);
    await tester.pump();
    final loadingSize = tester.getSize(buttonFinder);
    expect(loadingSize.width, closeTo(initialSize.width, 0.5));
  });

  testWidgets('IosSearchBar reveals Cancel button on input and clears cleanly',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      _wrapWithApp(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: IosSearchBar(
              controller: ctrl,
              placeholder: 'Search library',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Reply 1988');
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(ctrl.text, isEmpty);
  });

  testWidgets(
      'IosCircleIconButton aligns to left and right corners in Stack headers',
      (tester) async {
    await tester.pumpWidget(
      _wrapWithApp(
        Scaffold(
          body: SizedBox(
            width: 400,
            child: IosLargeTitleHeader(
              title: 'Settings Subpage',
              collapsed: true,
              leadingActions: IosCircleIconButton(
                icon: MoglogIcons.chevronLeft,
                tooltip: 'Back',
                onTap: () {},
              ),
              trailingActions: [
                IosCircleIconButton(
                  icon: MoglogIcons.moreHorizontal,
                  tooltip: 'More',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final backRect = tester.getRect(find.byTooltip('Back'));
    final moreRect = tester.getRect(find.byTooltip('More'));
    expect(backRect.left, lessThan(40));
    expect(moreRect.right, greaterThan(360));
  });

  testWidgets(
      'RatingAndNotesCard shows slider only (no 6-10 pills) and Write/Edit Review actions',
      (tester) async {
    await tester.pumpWidget(
      _wrapWithApp(
        Scaffold(
          body: SingleChildScrollView(
            child: RatingAndNotesCard(
              dramaId: 100,
              dramaTitle: 'Signal',
              myRating: 8.5,
              reviews: const [],
              communityComments: const [
                ShowComment(
                  id: 'u1',
                  dramaId: 100,
                  uid: 'u1',
                  author: 'Alex',
                  content: 'Masterpiece thriller.',
                  rating: 9.0,
                  createdAt: 1000,
                  updatedAt: 1000,
                ),
              ],
              currentUserUid: 'u1',
              isSignedIn: true,
              accentColor: const Color(0xFF30D158),
              onRatingChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('★ 6'), findsNothing);
    expect(find.text('★ 10'), findsNothing);
    expect(find.text('Masterpiece thriller.'), findsOneWidget);
    expect(find.text('Edit Your Review'), findsOneWidget);
  });

  testWidgets(
      '2.0x Accessibility Text Scaling on 360dp narrow viewport renders without overflow across Light & Dark themes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final dramas = [
      const Drama(
        id: 1,
        title: 'Extraordinary Attorney Woo',
        status: 'Watching',
        episodesWatched: 8,
        totalEpisodes: 16,
        rating: 9.1,
        myRating: 9.5,
        genres: 'Drama, Comedy',
        nextEpisodeAirDate: '2026-12-01',
        nextSeasonNumber: 1,
        nextEpisodeNumber: 9,
        addedAt: 1000,
        updatedAt: 2000,
      ),
      const Drama(
        id: 2,
        title: 'Deleted Sample Series',
        status: 'Planned',
        isDeleted: true,
        deletedAt: 1500,
      ),
    ];

    for (final theme in [MoglogTheme.dark(), MoglogTheme.light()]) {
      for (final screen in <Widget>[
        LibraryScreen(onDramaTap: (_) {}, onNavigateToDiscover: () {}),
        LibraryScreen(onDramaTap: (_) {}, onNavigateToDiscover: () {}),
        StatsScreen(onDramaTap: (_) {}),
        AppearanceSettingsScreen(onBack: () {}),
        PrivacyScreen(onBack: () {}),
        RecycleBinScreen(onBack: () {}),
      ]) {
        await tester.pumpWidget(
          _wrapWithApp(
            screen,
            theme: theme,
            textScale: 2.0,
            disableAnimations: true,
            overrides: [
              currentDramasProvider.overrideWithValue(dramas),
              currentSettingsProvider.overrideWithValue(
                const AppSettings(layoutMode: LibraryLayoutMode.list),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Overflow in ${screen.runtimeType} (brightness=${theme.brightness})',
        );
      }
    }
  });
}
