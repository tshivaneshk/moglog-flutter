import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(hasApiKeyProvider)) {
        ref.read(dramaControllerProvider).loadDiscoverRails(forceRefresh: false);
      }
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (!_headerCollapsed && offset > 60) {
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
    final ctrl = ref.read(dramaControllerProvider);
    ctrl.saveDrama(drama.copyWith(status: 'Planned', isDeleted: false));
    ref
        .read(toastProvider.notifier)
        .show('Added "${drama.title}" to Planned');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final hasKey = ref.watch(hasApiKeyProvider);
    final rails = ref.watch(discoverRailsProvider);
    final searchState = ref.watch(discoverSearchProvider);
    final settings = ref.watch(currentSettingsProvider);
    final myDramas = ref.watch(currentDramasProvider);
    final authState = ref.watch(authControllerProvider);

    final savedIds = myDramas
        .where((d) => !d.isDeleted)
        .map((d) => d.id)
        .toSet();

    return Scaffold(
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
                tint: c.accent,
                showBadgeDot: authState.circleNudges.isNotEmpty,
                onTap: widget.onNavigateToWatchCircle,
              ),
              if (hasKey)
                IosCircleIconButton(
                  icon: MoglogIcons.refresh,
                  tooltip: 'Refresh Discover',
                  onTap: () => ref
                      .read(dramaControllerProvider)
                      .loadDiscoverRails(forceRefresh: true),
                ),
            ],
          ),
          Expanded(
            child: !hasKey
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 72),
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
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 104),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 6,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: searchState.results.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.56,
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
                        // Watch Circle & Blend Promo / Status Banner
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: _WatchCircleBanner(
                            friends: authState.circleFriends,
                            unreadNudges: authState.circleNudges.length,
                            isSignedIn: authState.user != null,
                            onTap: widget.onNavigateToWatchCircle,
                          ),
                        ),

                        // Recent Searches (up to 5 shown)
                        if (settings.recentSearches.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent Searches',
                                      style: t.headline.copyWith(color: c.label),
                                    ),
                                    IosPressable(
                                      onTap: () => ref
                                          .read(settingsStoreProvider)
                                          .clearRecentSearches(),
                                      child: Text(
                                        'Clear',
                                        style: t.footnote.copyWith(
                                          color: c.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: settings.recentSearches
                                      .take(5)
                                      .map((term) {
                                    return IosPressable(
                                      onTap: () {
                                        _searchController.text = term;
                                        ref
                                            .read(dramaControllerProvider)
                                            .updateSearchQuery(term);
                                        setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.secondaryBackground,
                                          borderRadius: MoglogShapes.pill,
                                          border: Border.all(
                                            color: c.separator,
                                            width: 0.7,
                                          ),
                                        ),
                                        child: Text(
                                          term,
                                          style: t.caption.copyWith(
                                            color: c.label,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                        if (rails.isLoading && rails.trending.isEmpty)
                          const _DiscoverRailSkeleton()
                        else if (rails.error != null && rails.trending.isEmpty)
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
                          _DiscoverRail(
                            title: 'Trending This Week',
                            shows: rails.trending,
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
                            shows: rails.popular,
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
                            shows: rails.airingToday,
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
                            shows: rails.onTheAir,
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
        ],
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            colors: [
              c.accent.withValues(alpha: 0.18),
              c.secondaryBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: MoglogShapes.smooth(
            MoglogShapes.cardRadius,
            side: BorderSide(
              color: c.accent.withValues(alpha: 0.35),
              width: 0.9,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(MoglogIcons.users, color: c.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Watch Circle & Taste Blend',
                    style: t.headline.copyWith(color: c.label, fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: t.footnote.copyWith(color: c.secondaryLabel),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 52,
                  height: 28,
                  child: Stack(
                    children: [
                      for (var i = 0; i < friends.length && i < 3; i++)
                        Positioned(
                          left: i * 14.0,
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: c.tertiaryBackground,
                            backgroundImage: (friends[i].photoBase64 as String).isNotEmpty
                                ? MemoryImage(
                                    base64Decode(friends[i].photoBase64 as String),
                                  )
                                : ((friends[i].photoUrl as String).isNotEmpty
                                    ? NetworkImage(friends[i].photoUrl as String)
                                        as ImageProvider
                                    : null),
                            child: ((friends[i].photoBase64 as String).isEmpty &&
                                    (friends[i].photoUrl as String).isEmpty)
                                ? Text(
                                    (friends[i].displayName as String).isNotEmpty
                                        ? (friends[i].displayName as String)[0]
                                            .toUpperCase()
                                        : '?',
                                    style: t.caption2.copyWith(color: c.label),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Icon(MoglogIcons.chevronRight, size: 18, color: c.secondaryLabel),
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
    final c = context.colors;
    final t = context.typo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(title, style: t.title3.copyWith(color: c.label)),
          ),
          SizedBox(
            height: 215,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: shows.length,
              separatorBuilder: (_, __) => const SizedBox(width: 11),
              itemBuilder: (_, idx) {
                final d = shows[idx];
                return SizedBox(
                  width: 118,
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
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(6),
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
                            style: t.caption2.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: IosPressable(
                    onTap: isSaved ? onTap : onQuickAdd,
                    hapticOnTap: true,
                    pressedScale: 0.88,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSaved
                            ? c.accent
                            : Colors.black.withValues(alpha: 0.78),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSaved ? c.accent : Colors.white30,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isSaved ? MoglogIcons.check : MoglogIcons.plus,
                        size: 15,
                        color: isSaved ? c.onAccent : Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = 0; r < 2; r++) ...[
            const ShimmerBox(width: 160, height: 22),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (_, __) => const ShimmerBox(width: 118, height: 180),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
