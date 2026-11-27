import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ios_bottom_tab_bar.dart';
import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';
import '../../core/network/image_cache_manager.dart';
import '../../domain/model/drama.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onDramaTap;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToWatchCircle;

  const DiscoverScreen({
    super.key,
    required this.onDramaTap,
    required this.onNavigateToSettings,
    required this.onNavigateToWatchCircle,
  });

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const List<String> _genreFilters = [
    'All Genres',
    'Drama',
    'Sci-Fi & Fantasy',
    'Action & Adventure',
    'Comedy',
    'Crime',
    'Mystery',
    'Animation',
    'Romance',
  ];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _headerCollapsed = false;
  String _selectedGenre = 'All Genres';

  List<Drama> _filterByGenre(List<Drama> items) {
    if (_selectedGenre == 'All Genres') return items;
    final needle = _selectedGenre.toLowerCase();
    return items
        .where(
          (d) =>
              d.genres.toLowerCase().contains(needle) ||
              d.genreList.any((g) => g.toLowerCase().contains(needle)),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(hasApiKeyProvider)) {
        ref
            .read(dramaControllerProvider)
            .loadDiscoverRails(forceRefresh: false);
      }
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (!_headerCollapsed && offset > 56) {
      setState(() => _headerCollapsed = true);
    } else if (_headerCollapsed && offset < 16) {
      setState(() => _headerCollapsed = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _quickAddToPlanned(Drama drama) {
    MoglogHaptics.mediumImpact();
    final ctrl = ref.read(dramaControllerProvider);
    final existing =
        ref.read(dramaRepositoryProvider).getLocalDramaById(drama.id);
    ctrl.saveDrama(drama.copyWith(status: 'Planned', isDeleted: false));
    ref.read(toastProvider.notifier).show(
          'Added "${drama.title}" to Planned',
          actionLabel: 'Undo',
          onAction: () {
            if (existing != null) {
              ctrl.saveDrama(existing);
            } else {
              ctrl.deleteDramaPermanently(drama);
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final reduceMotion = context.reduceMotion;
    final screenW = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final searchCols = screenW >= 840
        ? 6
        : screenW >= 600
            ? 5
            : screenW >= 460
                ? 4
                : screenW < 310
                    ? 2
                    : 3;
    final hasKey = ref.watch(hasApiKeyProvider);
    final rails = ref.watch(discoverRailsProvider);
    final searchState = ref.watch(discoverSearchProvider);
    final settings = ref.watch(currentSettingsProvider);
    final myDramas = ref.watch(currentDramasProvider);
    final authState = ref.watch(authControllerProvider);

    final savedIds =
        myDramas.where((d) => !d.isDeleted).map((d) => d.id).toSet();
    final shellBottomPad = MoglogLayout.shellScrollBottomPadding(context);
    final chipStripHeight = 38.0 * textScale.clamp(1.0, 1.8);
    final searchGridAspect =
        textScale > 1.3 ? (0.56 / textScale.clamp(1.0, 1.32)) : 0.56;

    return TabRetapListener(
      branchIndex: 1,
      scrollController: _scrollController,
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            IosLargeTitleHeader(
              title: 'Discover',
              collapsed: _headerCollapsed,
              trailingActions: [
                IosCircleIconButton(
                  icon: MoglogIcons.users,
                  tooltip: 'Watch Circle',
                  tint: c.accentText,
                  showBadgeDot: authState.circleNudges.isNotEmpty,
                  onTap: widget.onNavigateToWatchCircle,
                ),
              ],
            ),
            Expanded(
              child: !hasKey
                  ? Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: shellBottomPad * 0.65),
                        child: IosEmptyState(
                          icon: MoglogIcons.key,
                          title: 'TMDB API Key Required',
                          subtitle:
                              'Add your free TMDB API key or Read Access Token in Settings to browse trending shows and search the catalog.',
                          actionLabel: 'Configure API Key',
                          onAction: widget.onNavigateToSettings,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: c.accent,
                      backgroundColor: c.elevatedSurface,
                      displacement: 28,
                      strokeWidth: 2.2,
                      onRefresh: () async {
                        MoglogHaptics.lightImpact();
                        await ref
                            .read(dramaControllerProvider)
                            .loadDiscoverRails(forceRefresh: true);
                      },
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(bottom: shellBottomPad),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              MoglogSpacing.md,
                              8,
                              MoglogSpacing.md,
                              12,
                            ),
                            child: IosSearchBar(
                              controller: _searchController,
                              placeholder: 'Shows, anime, dramas…',
                              onChanged: (q) {
                                ref
                                    .read(dramaControllerProvider)
                                    .updateSearchQuery(q);
                                setState(() {});
                              },
                            ),
                          ),
                          if (searchState.query.trim().isNotEmpty) ...[
                            if (searchState.isLoading)
                              Padding(
                                padding: MoglogSpacing.screenHorizontal,
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: searchCols * 2,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: searchCols,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.62,
                                  ),
                                  itemBuilder: (_, __) => const ShimmerBox(),
                                ),
                              )
                            else if (searchState.results.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: IosEmptyState(
                                  icon: MoglogIcons.search,
                                  title: 'No Results',
                                  subtitle:
                                      'No shows found for "${searchState.query.trim()}"',
                                ),
                              )
                            else
                              Padding(
                                padding: MoglogSpacing.screenHorizontal,
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: searchState.results.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: searchCols,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: searchGridAspect,
                                  ),
                                  itemBuilder: (_, i) {
                                    final d = searchState.results[i];
                                    final isSaved = savedIds.contains(d.id);
                                    return _DiscoverPosterTile(
                                      drama: d,
                                      isSaved: isSaved,
                                      onTap: () {
                                        ref
                                            .read(dramaControllerProvider)
                                            .cacheTransientDrama(d);
                                        widget.onDramaTap(d.id);
                                      },
                                      onQuickAdd: () => _quickAddToPlanned(d),
                                    );
                                  },
                                ),
                              ),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                MoglogSpacing.md,
                                0,
                                MoglogSpacing.md,
                                14,
                              ),
                              child: _WatchCircleBanner(
                                friends: authState.circleFriends,
                                unreadNudges: authState.circleNudges.length,
                                isSignedIn: authState.user != null,
                                onTap: widget.onNavigateToWatchCircle,
                              ),
                            ),
                            if (settings.recentSearches.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  MoglogSpacing.md,
                                  0,
                                  MoglogSpacing.md,
                                  12,
                                ),
                                child: SizedBox(
                                  height: chipStripHeight,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      Center(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: Text(
                                            'Recent:',
                                            style: t.caption.copyWith(
                                              color: c.secondaryLabel,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (final term
                                          in settings.recentSearches.take(5))
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: IosPressable(
                                              onTap: () {
                                                _searchController.text = term;
                                                ref
                                                    .read(
                                                        dramaControllerProvider)
                                                    .updateSearchQuery(term);
                                                setState(() {});
                                              },
                                              focusRadius:
                                                  MoglogShapes.pillRadius,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: c.secondaryBackground,
                                                  borderRadius:
                                                      MoglogShapes.pill,
                                                  border: Border.all(
                                                    color: c.glassBorder,
                                                    width: c.hairlineWidth,
                                                  ),
                                                ),
                                                child: Text(
                                                  term,
                                                  style: t.caption.copyWith(
                                                    color: c.label,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Center(
                                        child: IosPressable(
                                          semanticLabel:
                                              'Clear recent searches',
                                          onTap: () => ref
                                              .read(settingsStoreProvider)
                                              .clearRecentSearches(),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              'Clear',
                                              style: t.caption.copyWith(
                                                color: c.accentText,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (rails.trending.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: SizedBox(
                                  height: chipStripHeight,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: MoglogSpacing.screenHorizontal,
                                    itemCount: _genreFilters.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, idx) {
                                      final g = _genreFilters[idx];
                                      final selected = _selectedGenre == g;
                                      return Center(
                                        child: IosPressable(
                                          semanticSelected: selected,
                                          onTap: () {
                                            MoglogHaptics.selectionChanged();
                                            setState(() => _selectedGenre = g);
                                          },
                                          pressedScale: 0.95,
                                          focusRadius: MoglogShapes.pillRadius,
                                          child: AnimatedContainer(
                                            duration: reduceMotion
                                                ? Duration.zero
                                                : MoglogMotion.fast,
                                            curve: MoglogMotion.curve,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 13,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? c.accent
                                                  : c.secondaryBackground,
                                              borderRadius: MoglogShapes.pill,
                                              border: Border.all(
                                                color: selected
                                                    ? c.accent
                                                    : c.glassBorder,
                                                width: c.hairlineWidth,
                                              ),
                                            ),
                                            child: Text(
                                              g,
                                              style: t.caption.copyWith(
                                                color: selected
                                                    ? c.onAccent
                                                    : c.label,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (rails.isLoading && rails.trending.isEmpty)
                              const _DiscoverRailSkeleton()
                            else if (rails.error != null &&
                                rails.trending.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: IosEmptyState(
                                  icon: MoglogIcons.refresh,
                                  title: 'Unable to Load Discover',
                                  subtitle: rails.error!,
                                  actionLabel: 'Retry',
                                  onAction: () => ref
                                      .read(dramaControllerProvider)
                                      .loadDiscoverRails(forceRefresh: true),
                                ),
                              )
                            else ...[
                              if (_filterByGenre(rails.trending).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    MoglogSpacing.md,
                                    0,
                                    MoglogSpacing.md,
                                    18,
                                  ),
                                  child: _TrendingSpotlightCard(
                                    drama: _filterByGenre(rails.trending).first,
                                    isSaved: savedIds.contains(
                                      _filterByGenre(rails.trending).first.id,
                                    ),
                                    onTap: () {
                                      final hero =
                                          _filterByGenre(rails.trending).first;
                                      ref
                                          .read(dramaControllerProvider)
                                          .cacheTransientDrama(hero);
                                      widget.onDramaTap(hero.id);
                                    },
                                    onQuickAdd: () => _quickAddToPlanned(
                                      _filterByGenre(rails.trending).first,
                                    ),
                                  ),
                                ),
                              _DiscoverRail(
                                title: 'Trending This Week',
                                shows: _filterByGenre(rails.trending),
                                savedIds: savedIds,
                                onDramaTap: (d) {
                                  ref
                                      .read(dramaControllerProvider)
                                      .cacheTransientDrama(d);
                                  widget.onDramaTap(d.id);
                                },
                                onQuickAdd: _quickAddToPlanned,
                              ),
                              _DiscoverRail(
                                title: 'Popular Right Now',
                                shows: _filterByGenre(rails.popular),
                                savedIds: savedIds,
                                onDramaTap: (d) {
                                  ref
                                      .read(dramaControllerProvider)
                                      .cacheTransientDrama(d);
                                  widget.onDramaTap(d.id);
                                },
                                onQuickAdd: _quickAddToPlanned,
                              ),
                              _DiscoverRail(
                                title: 'Airing Today',
                                shows: _filterByGenre(rails.airingToday),
                                savedIds: savedIds,
                                onDramaTap: (d) {
                                  ref
                                      .read(dramaControllerProvider)
                                      .cacheTransientDrama(d);
                                  widget.onDramaTap(d.id);
                                },
                                onQuickAdd: _quickAddToPlanned,
                              ),
                              _DiscoverRail(
                                title: 'Currently On The Air',
                                shows: _filterByGenre(rails.onTheAir),
                                savedIds: savedIds,
                                onDramaTap: (d) {
                                  ref
                                      .read(dramaControllerProvider)
                                      .cacheTransientDrama(d);
                                  widget.onDramaTap(d.id);
                                },
                                onQuickAdd: _quickAddToPlanned,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchCircleBanner extends StatelessWidget {
  final List<dynamic> friends;
  final int unreadNudges;
  final bool isSignedIn;
  final VoidCallback onTap;

  const _WatchCircleBanner({
    required this.friends,
    required this.unreadNudges,
    required this.isSignedIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    final subtitle = !isSignedIn
        ? 'Connect with friends to compare Taste Blends & race episodes.'
        : friends.isEmpty
            ? 'Share your 6-char Circle Code to add your first friend.'
            : '${friends.length} friend${friends.length == 1 ? "" : "s"} connected'
                '${unreadNudges > 0 ? " · $unreadNudges new nudge${unreadNudges == 1 ? "" : "s"}" : ""}';

    return IosPressable(
      onTap: onTap,
      hapticOnTap: true,
      focusRadius: MoglogShapes.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(c.accentSubtle, c.secondaryBackground),
              c.secondaryBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: MoglogShapes.smooth(
            MoglogShapes.cardRadius,
            side: BorderSide(
              color: c.accent.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: ShapeDecoration(
                color: c.accentSubtle,
                shape: MoglogShapes.smooth(13),
              ),
              alignment: Alignment.center,
              child: Icon(MoglogIcons.users, color: c.accentText, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Watch Circle & Taste Blend',
                    style: t.callout.copyWith(
                      color: c.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: t.footnote.copyWith(color: c.secondaryLabel),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: SizedBox(
                  width: 54,
                  height: 30,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      for (var i = 0; i < friends.length && i < 3; i++)
                        Positioned(
                          left: i * 14.0,
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: c.tertiaryBackground,
                            backgroundImage:
                                (friends[i].photoBase64 as String).isNotEmpty
                                    ? MemoryImage(
                                        base64Decode(
                                          friends[i].photoBase64 as String,
                                        ),
                                      )
                                    : ((friends[i].photoUrl as String)
                                            .isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            friends[i].photoUrl as String,
                                            cacheManager:
                                                MoglogImageCacheManager.instance,
                                          ) as ImageProvider
                                        : null),
                            child: ((friends[i].photoBase64 as String)
                                        .isEmpty &&
                                    (friends[i].photoUrl as String).isEmpty)
                                ? Text(
                                    (friends[i].displayName as String)
                                            .isNotEmpty
                                        ? (friends[i].displayName as String)[0]
                                            .toUpperCase()
                                        : '?',
                                    style: t.microBadge.copyWith(color: c.label),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Icon(MoglogIcons.chevronRight, size: 18, color: c.tertiaryLabel),
          ],
        ),
      ),
    );
  }
}

class _DiscoverRail extends StatelessWidget {
  final String title;
  final List<Drama> shows;
  final Set<int> savedIds;
  final ValueChanged<Drama> onDramaTap;
  final ValueChanged<Drama> onQuickAdd;

  const _DiscoverRail({
    required this.title,
    required this.shows,
    required this.savedIds,
    required this.onDramaTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (shows.isEmpty) return const SizedBox.shrink();
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final railHeight =
        216.0 + ((textScale - 1.0).clamp(0.0, 1.0) * 40.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IosSectionHeader(title: title),
          ),
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: MoglogSpacing.screenHorizontal,
              itemCount: shows.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, idx) {
                final d = shows[idx];
                return SizedBox(
                  width: 120,
                  child: _DiscoverPosterTile(
                    drama: d,
                    isSaved: savedIds.contains(d.id),
                    onTap: () => onDramaTap(d),
                    onQuickAdd: () => onQuickAdd(d),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverPosterTile extends StatelessWidget {
  final Drama drama;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  const _DiscoverPosterTile({
    required this.drama,
    required this.isSaved,
    required this.onTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return IosPressable(
      onTap: onTap,
      pressedScale: 0.96,
      semanticLabel: drama.title,
      focusRadius: MoglogShapes.posterRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PosterImage(
                  url: drama.posterPath,
                  borderRadius: MoglogShapes.poster,
                ),
                if (drama.rating > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: ShapeDecoration(
                        color: c.mediaScrim,
                        shape: MoglogShapes.smooth(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MoglogIcons.starFilled,
                            size: 10,
                            color: c.starGold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            drama.rating.toStringAsFixed(1),
                            style: t.microBadge.copyWith(
                              color: c.onMedia,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: IosPressable(
                    semanticLabel: isSaved
                        ? '${drama.title} in library'
                        : 'Add ${drama.title} to Planned',
                    onTap: isSaved ? onTap : onQuickAdd,
                    hapticOnTap: true,
                    pressedScale: 0.88,
                    focusRadius: MoglogShapes.pillRadius,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 42,
                        minHeight: 42,
                      ),
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isSaved ? c.accent : c.mediaScrim,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSaved ? c.accent : c.onMediaSecondary,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isSaved ? MoglogIcons.check : MoglogIcons.plus,
                            size: 15,
                            color: isSaved ? c.onAccent : c.onMedia,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            drama.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(
              color: c.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (drama.releaseYear > 0)
            Text(
              '${drama.releaseYear}',
              maxLines: 1,
              style: t.caption2.copyWith(color: c.secondaryLabel),
            ),
        ],
      ),
    );
  }
}

class _DiscoverRailSkeleton extends StatelessWidget {
  const _DiscoverRailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MoglogSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(
            width: double.infinity,
            height: 154,
            borderRadius: MoglogShapes.card,
          ),
          const SizedBox(height: 22),
          for (var r = 0; r < 2; r++) ...[
            const ShimmerBox(width: 164, height: 22),
            const SizedBox(height: 10),
            SizedBox(
              height: 184,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) =>
                    const ShimmerBox(width: 120, height: 184),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _TrendingSpotlightCard extends StatelessWidget {
  final Drama drama;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  const _TrendingSpotlightCard({
    required this.drama,
    required this.isSaved,
    required this.onTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return IosCard(
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterImage(
            url: drama.posterPath,
            width: 88,
            height: 132,
            borderRadius: MoglogShapes.poster,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentSubtle,
                        borderRadius: MoglogShapes.pill,
                      ),
                      child: Text(
                        '#1 TRENDING NOW',
                        style: t.microBadge.copyWith(
                          color: c.accentText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (drama.rating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MoglogIcons.starFilled,
                            size: 12,
                            color: c.starGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            drama.rating.toStringAsFixed(1),
                            style: t.caption.copyWith(
                              color: c.label,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  drama.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.headline.copyWith(color: c.label),
                ),
                if (drama.overview.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    drama.overview.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(
                      color: c.secondaryLabel,
                      height: 1.38,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (isSaved)
                  IosSecondaryButton(
                    text: 'In Library',
                    leadingIcon: MoglogIcons.check,
                    size: MoglogButtonSize.small,
                    expand: false,
                    textColor: c.accentText,
                    onTap: onTap,
                  )
                else
                  IosPrimaryButton(
                    text: 'Add to Planned',
                    leadingIcon: MoglogIcons.plus,
                    size: MoglogButtonSize.small,
                    expand: false,
                    onTap: onQuickAdd,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
