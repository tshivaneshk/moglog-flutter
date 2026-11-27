import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';
import '../../core/network/image_cache_manager.dart';
import '../../core/platform/platform_bridge.dart';
import '../../data/remote/watch_circle_repository.dart';
import '../../domain/model/drama.dart';
import '../../domain/model/watch_circle_models.dart';

class WatchCircleScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<int> onDramaTap;

  const WatchCircleScreen({
    super.key,
    required this.onBack,
    required this.onDramaTap,
  });

  @override
  ConsumerState<WatchCircleScreen> createState() => _WatchCircleScreenState();
}

class _WatchCircleScreenState extends ConsumerState<WatchCircleScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;

  static const _presetNudges = [
    ('FIRE', 'No spoilers, that episode was fire!'),
    ('WAIT', 'Wait for me! Watching the next episode tonight.'),
    ('PACE', 'Catch up so we can talk about the finale!'),
    ('AWARD', 'Adding this to my must-watch list right now.'),
    ('SPARK', 'Our Taste Blend is undefeated!'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authControllerProvider).user != null) {
        ref.read(authControllerProvider.notifier).refreshWatchCircle();
      }
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (!_headerCollapsed && offset > 48) {
      setState(() => _headerCollapsed = true);
    } else if (_headerCollapsed && offset < 14) {
      setState(() => _headerCollapsed = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showJoinCircleSheet() {
    final ctrl = TextEditingController();
    String? errorMsg;
    var submitting = false;

    showIosBottomSheet<void>(
      context: context,
      disposeAfter: [ctrl],
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          return SingleChildScrollView(
            padding: MoglogSpacing.sheetPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter Friend Code',
                  style: t.title2.copyWith(color: c.label),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your friend\'s 6-character Watch Circle code or paste an invite message.',
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: ShapeDecoration(
                    color: c.tertiaryBackground,
                    shape: MoglogShapes.smooth(
                      MoglogShapes.controlRadius,
                      side: BorderSide(
                        color: errorMsg != null ? c.destructive : c.glassBorder,
                        width: errorMsg != null ? 1.2 : c.hairlineWidth,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: ctrl,
                    textCapitalization: TextCapitalization.characters,
                    cursorColor: c.accent,
                    style: t.title3.copyWith(
                      color: c.label,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'ABC123',
                      hintStyle: t.title3.copyWith(
                        color: c.tertiaryLabel,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: t.footnote.copyWith(color: c.destructive),
                  ),
                ],
                const SizedBox(height: 12),
                IosSecondaryButton(
                  text: 'Paste from Clipboard',
                  leadingIcon: MoglogIcons.copy,
                  onTap: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final raw = data?.text ?? '';
                    final extracted =
                        WatchCircleRepository.extractCodeFromClipboard(raw) ??
                            WatchCircleRepository.normalizeInviteCode(raw);
                    if (extracted.isNotEmpty) {
                      ctrl.text = extracted;
                      setSheetState(() => errorMsg = null);
                    }
                  },
                ),
                const SizedBox(height: 10),
                IosPrimaryButton(
                  text: 'Connect Friend',
                  loading: submitting,
                  onTap: () async {
                    setSheetState(() {
                      submitting = true;
                      errorMsg = null;
                    });
                    try {
                      final friend = await ref
                          .read(authControllerProvider.notifier)
                          .joinCircleByCode(ctrl.text);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      ref.read(toastProvider.notifier).show(
                            'Connected with ${friend.displayName}!',
                          );
                    } catch (e) {
                      setSheetState(() {
                        submitting = false;
                        errorMsg = e
                            .toString()
                            .replaceFirst('Bad state: ', '')
                            .replaceFirst('Invalid argument(s): ', '');
                      });
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPickFavoriteSheet(List<Drama> myDramas, List<int> currentTop4) {
    final searchCtrl = TextEditingController();
    final active = myDramas.where((d) => !d.isDeleted).toList()
      ..sort((a, b) => b.effectiveRating.compareTo(a.effectiveRating));

    showIosBottomSheet<void>(
      disposeAfter: [searchCtrl],
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          final q = searchCtrl.text.trim().toLowerCase();
          final matches = q.isEmpty
              ? active
              : active.where((d) => d.title.toLowerCase().contains(q)).toList();

          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pin to Top 4 Favorites',
                        style: t.title3.copyWith(color: c.label),
                      ),
                      const SizedBox(height: 10),
                      IosSearchBar(
                        controller: searchCtrl,
                        placeholder: 'Search your library…',
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: matches.isEmpty
                      ? const Center(
                          child: IosEmptyState(
                            icon: MoglogIcons.starOutline,
                            title: 'No Shows Found',
                            subtitle:
                                'Add shows to your library first to pin your Top 4.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                          itemCount: matches.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final d = matches[i];
                            final pinned = currentTop4.contains(d.id);
                            return IosPressable(
                              semanticSelected: pinned,
                              semanticLabel: pinned
                                  ? 'Unpin ${d.title} from Top 4'
                                  : 'Pin ${d.title} to Top 4',
                              onTap: () async {
                                await ref
                                    .read(dramaControllerProvider)
                                    .toggleTopFourFavorite(d.id);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: ShapeDecoration(
                                  color: c.tertiaryBackground,
                                  shape: MoglogShapes.smooth(
                                    14,
                                    side: BorderSide(
                                      color: pinned ? c.starGold : c.glassBorder,
                                      width: pinned ? 1.0 : c.hairlineWidth,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    PosterImage(
                                      url: d.posterPath,
                                      width: 40,
                                      height: 56,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        d.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.subhead.copyWith(
                                          color: c.label,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      pinned
                                          ? MoglogIcons.starFilled
                                          : MoglogIcons.starOutline,
                                      color: pinned
                                          ? c.starGold
                                          : c.secondaryLabel,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSendNudgeSheet({
    required String toUid,
    required String friendName,
    required int dramaId,
    required String dramaTitle,
  }) {
    showIosActionSheet(
      context: context,
      title: 'Nudge $friendName',
      message: dramaTitle,
      actions: [
        for (final preset in _presetNudges)
          ActionSheetItem(
            label: preset.$2,
            icon: _nudgeIcon(preset.$1),
            onTap: () async {
              final ok =
                  await ref.read(authControllerProvider.notifier).sendNudge(
                        toUid: toUid,
                        dramaId: dramaId,
                        dramaTitle: dramaTitle,
                        emoji: preset.$1,
                        message: preset.$2,
                      );
              ref.read(toastProvider.notifier).show(
                    ok ? 'Sent nudge to $friendName!' : 'Unable to send nudge',
                  );
            },
          ),
      ],
    );
  }

  void _showFriendBlendDetailSheet(
    FriendProfile friend,
    TasteBlendResult blend,
    List<Drama> myDramas,
  ) {
    final savedIds =
        myDramas.where((d) => !d.isDeleted).map((d) => d.id).toSet();
    var selectedTab = 0;

    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          final List<SharedShowItem> tabShows = switch (selectedTab) {
            0 => friend.currentlyWatching,
            1 => blend.sharedShows,
            _ => friend.recentlyCompleted,
          };

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: MoglogSpacing.sheetPadding,
              children: [
                Row(
                  children: [
                    _AvatarCircle(
                      photoBase64: friend.photoBase64,
                      photoUrl: friend.photoUrl,
                      name: friend.displayName,
                      radius: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.title3.copyWith(color: c.label),
                          ),
                          Text(
                            '${friend.totalWatched} done · ${friend.totalEpisodes} eps',
                            style: t.footnote.copyWith(color: c.secondaryLabel),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentSubtle,
                        borderRadius: MoglogShapes.pill,
                      ),
                      child: Text(
                        '${blend.compatibilityPercent}% Match',
                        style: t.footnote.copyWith(
                          color: c.accentText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: ShapeDecoration(
                    color: c.tertiaryBackground,
                    shape: MoglogShapes.smooth(
                      16,
                      side: BorderSide(
                        color: c.glassBorder,
                        width: c.hairlineWidth,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blend.badgeTitle,
                        style: t.headline.copyWith(color: c.accentText),
                      ),
                      if (blend.sharedGenres.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Shared vibes: ${blend.sharedGenres.join(" · ")}',
                          style: t.footnote.copyWith(color: c.secondaryLabel),
                        ),
                      ],
                    ],
                  ),
                ),
                if (friend.topFourFavorites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Top 4 Favorites',
                    style: t.headline.copyWith(color: c.label),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final fav in friend.topFourFavorites.take(4))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: IosPressable(
                              semanticLabel: fav.title,
                              onTap: () {
                                Navigator.of(ctx).pop();
                                widget.onDramaTap(fav.id);
                              },
                              child: AspectRatio(
                                aspectRatio: 0.68,
                                child: PosterImage(url: fav.posterPath),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                IosSegmentedControl(
                  labels: const ['Watching', 'In Common', 'Top Done'],
                  selectedIndex: selectedTab,
                  onSelected: (i) => setSheetState(() => selectedTab = i),
                ),
                const SizedBox(height: 12),
                if (tabShows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No shows in this section yet.',
                        style: t.footnote.copyWith(color: c.secondaryLabel),
                      ),
                    ),
                  )
                else
                  for (final s in tabShows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: ShapeDecoration(
                        color: c.tertiaryBackground,
                        shape: MoglogShapes.smooth(
                          14,
                          side: BorderSide(
                            color: c.glassBorder,
                            width: c.hairlineWidth,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          PosterImage(
                            url: s.posterPath,
                            width: 40,
                            height: 56,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: IosPressable(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                widget.onDramaTap(s.id);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.subhead.copyWith(
                                      color: c.label,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    s.totalEpisodes > 0
                                        ? 'Ep ${s.episodesWatched}/${s.totalEpisodes}'
                                        : s.status,
                                    style: t.caption.copyWith(
                                      color: c.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IosCircleIconButton(
                            icon: MoglogIcons.zap,
                            tooltip: 'Nudge ${friend.displayName} about ${s.title}',
                            size: 34,
                            iconSize: 16,
                            tint: c.starGold,
                            onTap: () => _showSendNudgeSheet(
                              toUid: friend.uid,
                              friendName: friend.displayName,
                              dramaId: s.id,
                              dramaTitle: s.title,
                            ),
                          ),
                          if (!savedIds.contains(s.id)) ...[
                            const SizedBox(width: 2),
                            IosCircleIconButton(
                              icon: MoglogIcons.plus,
                              tooltip: 'Add ${s.title} to Planned',
                              size: 34,
                              iconSize: 16,
                              tint: c.accentText,
                              onTap: () {
                                ref.read(dramaControllerProvider).saveDrama(
                                      Drama(
                                        id: s.id,
                                        title: s.title,
                                        posterPath: s.posterPath,
                                        rating: s.rating,
                                        totalEpisodes: s.totalEpisodes,
                                        genres: s.genres,
                                        status: 'Planned',
                                      ),
                                    );
                                ref.read(toastProvider.notifier).show(
                                      'Added "${s.title}" to Planned',
                                    );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                IosDestructiveButton(
                  text: 'Remove Friend',
                  filled: false,
                  leadingIcon: MoglogIcons.trash,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showIosActionSheet(
                      context: context,
                      title: 'Remove ${friend.displayName}?',
                      message:
                          'They will be disconnected from your Watch Circle.',
                      actions: [
                        ActionSheetItem(
                          label: 'Remove Friend',
                          isDestructive: true,
                          onTap: () => ref
                              .read(authControllerProvider.notifier)
                              .removeFriendFromCircle(friend.uid),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _nudgeIcon(String code) => switch (code.toUpperCase()) {
        'FIRE' => MoglogIcons.flame,
        'WAIT' => MoglogIcons.clock,
        'PACE' => MoglogIcons.trendingUp,
        'AWARD' => MoglogIcons.award,
        'SPARK' => MoglogIcons.sparkles,
        _ => MoglogIcons.zap,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final authState = ref.watch(authControllerProvider);
    final settings = ref.watch(currentSettingsProvider);
    final myDramas = ref.watch(currentDramasProvider);
    final user = authState.user;

    final activeMap = {
      for (final d in myDramas.where((e) => !e.isDeleted)) d.id: d,
    };
    final topFourDramas = settings.topFourFavoriteIds
        .map((id) => activeMap[id])
        .whereType<Drama>()
        .take(4)
        .toList();

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final coWatchPairs = TasteBlendCalculator.buildCoWatchPairs(
      myDramas,
      authState.circleFriends,
    );

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'Watch Circle',
            collapsed: user == null ? true : _headerCollapsed,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              tooltip: 'Back',
              onTap: widget.onBack,
            ),
          ),
          Expanded(
            child: user == null
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: IosEmptyState(
                        icon: MoglogIcons.users,
                        title: 'Watch Circle & Taste Blend',
                        subtitle:
                            'Sign in with Google to get your personal 6-character Circle Code, compare Taste Blends, race episodes with friends, and showcase your Top 4.',
                        actionLabel: 'Sign In with Google',
                        onAction: () async {
                          final err = await ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle();
                          if (err != null) {
                            ref.read(toastProvider.notifier).show(err);
                          }
                        },
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: c.accent,
                    backgroundColor: c.elevatedSurface,
                    displacement: 28,
                    strokeWidth: 2.2,
                    onRefresh: () => ref
                        .read(authControllerProvider.notifier)
                        .refreshWatchCircle(
                          forceRefresh: true,
                          publishOwnActivity: true,
                        ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isLandscape ? 780 : double.infinity,
                        ),
                        child: ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            MoglogSpacing.md,
                            MoglogSpacing.sm,
                            MoglogSpacing.md,
                            56,
                          ),
                          children: [
                            _MyPassCard(
                              displayName: settings.customDisplayName.isNotEmpty
                                  ? settings.customDisplayName
                                  : (user.displayName ?? 'Moglog User'),
                              photoBase64: settings.customProfileImageBase64,
                              photoUrl: user.photoURL ?? '',
                              inviteCode: ref
                                  .read(authControllerProvider.notifier)
                                  .getMyInviteCode(),
                              sharingEnabled:
                                  settings.watchCircleSharingEnabled,
                              topFourDramas: topFourDramas,
                              onCopyCode: (code) {
                                PlatformBridge.copySensitiveClipboard(
                                  code,
                                  label: 'Watch Circle Code',
                                );
                                ref
                                    .read(toastProvider.notifier)
                                    .show('Copied Circle Code $code');
                              },
                              onRotateCode: () async {
                                try {
                                  final newCode = await ref
                                      .read(authControllerProvider.notifier)
                                      .rotateMyInviteCode();
                                  ref
                                      .read(toastProvider.notifier)
                                      .show('Rotated Circle Code to $newCode');
                                } catch (e) {
                                  ref
                                      .read(toastProvider.notifier)
                                      .show(e.toString());
                                }
                              },
                              onShareCode: (code) => SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'Join my Moglog Watch Circle! Enter my Circle Code: $code (MOG-$code)',
                                ),
                              ),
                              onEnterFriendCode: _showJoinCircleSheet,
                              onToggleSharing: (v) async {
                                await ref
                                    .read(settingsStoreProvider)
                                    .setWatchCircleSharingEnabled(v);
                                await ref
                                    .read(watchCircleRepositoryProvider)
                                    .publishMyActivity(myDramas);
                              },
                              onPickTopFour: () => _showPickFavoriteSheet(
                                myDramas,
                                settings.topFourFavoriteIds,
                              ),
                              onTopFourTap: (d) => widget.onDramaTap(d.id),
                              onTopFourLongPress: (d) {
                                showIosActionSheet(
                                  context: context,
                                  title: d.title,
                                  actions: [
                                    ActionSheetItem(
                                      label: 'Open Details',
                                      onTap: () => widget.onDramaTap(d.id),
                                    ),
                                    ActionSheetItem(
                                      label: 'Unpin from Top 4',
                                      isDestructive: true,
                                      onTap: () => ref
                                          .read(dramaControllerProvider)
                                          .toggleTopFourFavorite(d.id),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),

                            // 2. Incoming Nudges & Reactions
                            if (authState.circleNudges.isNotEmpty) ...[
                              const IosSectionHeader(
                                title: 'Incoming Nudges',
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(height: 10),
                              for (final nudge
                                  in authState.circleNudges.take(4))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: IosCard(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: ShapeDecoration(
                                            color: c.starGold
                                                .withValues(alpha: 0.16),
                                            shape: MoglogShapes.smooth(11),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            _nudgeIcon(nudge.emoji),
                                            size: 18,
                                            color: c.starGold,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${nudge.fromName} · ${nudge.dramaTitle}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: t.footnote.copyWith(
                                                  color: c.label,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                nudge.message,
                                                style: t.caption.copyWith(
                                                  color: c.secondaryLabel,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IosCircleIconButton(
                                          icon: MoglogIcons.close,
                                          tooltip: 'Dismiss nudge',
                                          size: 32,
                                          iconSize: 15,
                                          onTap: () => ref
                                              .read(authControllerProvider
                                                  .notifier)
                                              .dismissNudge(nudge.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                            ],

                            // 3. Co-Watching Episode Race
                            if (coWatchPairs.isNotEmpty) ...[
                              const IosSectionHeader(
                                title: 'Co-Watching Episode Race',
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(height: 10),
                              for (final pair in coWatchPairs.take(4))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: IosCard(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        PosterImage(
                                          url: pair.posterPath,
                                          width: 46,
                                          height: 66,
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(9),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                pair.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: t.subhead.copyWith(
                                                  color: c.label,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'You: Ep ${pair.myEpisodes} · ${pair.friendName}: Ep ${pair.friendEpisodes}',
                                                style: t.caption.copyWith(
                                                  color: c.secondaryLabel,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius: MoglogShapes.pill,
                                                child: LinearProgressIndicator(
                                                  value: pair.totalEpisodes > 0
                                                      ? (pair.myEpisodes /
                                                              pair.totalEpisodes)
                                                          .clamp(0.0, 1.0)
                                                      : 0.5,
                                                  minHeight: 4,
                                                  backgroundColor:
                                                      c.tertiaryBackground,
                                                  color: c.accent,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              ClipRRect(
                                                borderRadius: MoglogShapes.pill,
                                                child: LinearProgressIndicator(
                                                  value: pair.totalEpisodes > 0
                                                      ? (pair.friendEpisodes /
                                                              pair.totalEpisodes)
                                                          .clamp(0.0, 1.0)
                                                      : 0.5,
                                                  minHeight: 4,
                                                  backgroundColor:
                                                      c.tertiaryBackground,
                                                  color: c.statusWatching,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IosCircleIconButton(
                                          icon: MoglogIcons.zap,
                                          tooltip:
                                              'Nudge ${pair.friendName} about ${pair.title}',
                                          tint: c.starGold,
                                          onTap: () => _showSendNudgeSheet(
                                            toUid: pair.friendUid,
                                            friendName: pair.friendName,
                                            dramaId: pair.dramaId,
                                            dramaTitle: pair.title,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                            ],

                            // 4. Circle Members Feed
                            IosSectionHeader(
                              title:
                                  'Circle Members (${authState.circleFriends.length})',
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 10),
                            if (authState.isLoadingCircle &&
                                authState.circleFriends.isEmpty) ...[
                              const ShimmerBox(
                                width: double.infinity,
                                height: 140,
                                borderRadius: MoglogShapes.card,
                              ),
                              const SizedBox(height: 12),
                              const ShimmerBox(
                                width: double.infinity,
                                height: 140,
                                borderRadius: MoglogShapes.card,
                              ),
                            ] else if (authState.circleFriends.isEmpty)
                              IosCard(
                                padding: const EdgeInsets.all(22),
                                child: Text(
                                  'No friends in your circle yet. Share your Circle Code or enter a friend\'s code above!',
                                  style: t.subhead
                                      .copyWith(color: c.secondaryLabel),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              for (final friend in authState.circleFriends) ...[
                                Builder(
                                  builder: (_) {
                                    final blend =
                                        TasteBlendCalculator.computeBlend(
                                      myDramas,
                                      friend,
                                    );
                                    return _FriendActivityCard(
                                      friend: friend,
                                      blend: blend,
                                      onTap: () => _showFriendBlendDetailSheet(
                                        friend,
                                        blend,
                                        myDramas,
                                      ),
                                      onShowTap: (id) => widget.onDramaTap(id),
                                      onNudgeShow: (s) => _showSendNudgeSheet(
                                        toUid: friend.uid,
                                        friendName: friend.displayName,
                                        dramaId: s.id,
                                        dramaTitle: s.title,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MyPassCard extends StatelessWidget {
  final String displayName;
  final String photoBase64;
  final String photoUrl;
  final String inviteCode;
  final bool sharingEnabled;
  final List<Drama> topFourDramas;
  final ValueChanged<String> onCopyCode;
  final VoidCallback onRotateCode;
  final ValueChanged<String> onShareCode;
  final VoidCallback onEnterFriendCode;
  final ValueChanged<bool> onToggleSharing;
  final VoidCallback onPickTopFour;
  final ValueChanged<Drama> onTopFourTap;
  final ValueChanged<Drama> onTopFourLongPress;

  const _MyPassCard({
    required this.displayName,
    required this.photoBase64,
    required this.photoUrl,
    required this.inviteCode,
    required this.sharingEnabled,
    required this.topFourDramas,
    required this.onCopyCode,
    required this.onRotateCode,
    required this.onShareCode,
    required this.onEnterFriendCode,
    required this.onToggleSharing,
    required this.onPickTopFour,
    required this.onTopFourTap,
    required this.onTopFourLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AvatarCircle(
                    photoBase64: photoBase64,
                    photoUrl: photoUrl,
                    name: displayName,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.headline.copyWith(color: c.label),
                        ),
                        Text(
                          sharingEnabled
                              ? 'Sharing activity with circle'
                              : 'Activity sharing paused',
                          style: t.caption.copyWith(color: c.secondaryLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IosPressable(
                semanticLabel:
                    'Circle Code ${inviteCode.isNotEmpty ? inviteCode : "unavailable"}. Tap to copy, long press to rotate.',
                onTap: () => onCopyCode(inviteCode),
                onLongPress: onRotateCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: ShapeDecoration(
                    color: c.accentSubtle,
                    shape: MoglogShapes.smooth(
                      11,
                      side: BorderSide(
                        color: c.accent.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    inviteCode.isNotEmpty ? inviteCode : '------',
                    style: t.subhead.copyWith(
                      color: c.accentText,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap code to copy · Long-press to rotate to a fresh code',
            style: t.caption2.copyWith(color: c.secondaryLabel),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: IosPrimaryButton(
                  text: 'Share Group Link',
                  leadingIcon: MoglogIcons.share,
                  size: MoglogButtonSize.medium,
                  singleLine: true,
                  onTap: () => onShareCode(inviteCode),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IosSecondaryButton(
                  text: 'Enter Code',
                  leadingIcon: MoglogIcons.plus,
                  size: MoglogButtonSize.medium,
                  singleLine: true,
                  onTap: onEnterFriendCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'My Top 4 All-Time Favorites',
                  style: t.subhead.copyWith(
                    color: c.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IosTertiaryButton(
                text: '+ Add',
                size: MoglogButtonSize.small,
                onTap: onPickTopFour,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final d = i < topFourDramas.length ? topFourDramas[i] : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  child: AspectRatio(
                    aspectRatio: 0.68,
                    child: d != null
                        ? IosPressable(
                            semanticLabel:
                                '${d.title}, pinned in Top 4 slot ${i + 1}',
                            onTap: () => onTopFourTap(d),
                            onLongPress: () => onTopFourLongPress(d),
                            child: PosterImage(
                              url: d.posterPath,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(11)),
                            ),
                          )
                        : IosPressable(
                            semanticLabel:
                                'Add show to Top 4 Favorites slot ${i + 1}',
                            onTap: onPickTopFour,
                            child: Container(
                              decoration: ShapeDecoration(
                                color: c.tertiaryBackground,
                                shape: MoglogShapes.smooth(
                                  11,
                                  side: BorderSide(
                                    color: c.glassBorder,
                                    width: c.hairlineWidth,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                MoglogIcons.plus,
                                size: 20,
                                color: c.secondaryLabel,
                              ),
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          IosSwitchRow(
            title: 'Share My Watch Activity',
            value: sharingEnabled,
            showDivider: false,
            onChanged: onToggleSharing,
          ),
        ],
      ),
    );
  }
}

class _FriendActivityCard extends StatelessWidget {
  final FriendProfile friend;
  final TasteBlendResult blend;
  final VoidCallback onTap;
  final ValueChanged<int> onShowTap;
  final ValueChanged<SharedShowItem> onNudgeShow;

  const _FriendActivityCard({
    required this.friend,
    required this.blend,
    required this.onTap,
    required this.onShowTap,
    required this.onNudgeShow,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final shelf = friend.currentlyWatching.isNotEmpty
        ? friend.currentlyWatching
        : friend.recentlyCompleted;

    return IosCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarCircle(
                photoBase64: friend.photoBase64,
                photoUrl: friend.photoUrl,
                name: friend.displayName,
                radius: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.callout.copyWith(
                        color: c.label,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${blend.badgeTitle} · ${blend.sharedShows.length} shared',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: c.secondaryLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.accentSubtle,
                  borderRadius: MoglogShapes.pill,
                ),
                child: Text(
                  '${blend.compatibilityPercent}% Match',
                  style: t.caption2.copyWith(
                    color: c.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (shelf.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 114,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: min(shelf.length, 8),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final s = shelf[idx];
                  return IosPressable(
                    semanticLabel: '${s.title}, Episode ${s.episodesWatched}',
                    onTap: () => onShowTap(s.id),
                    onLongPress: () => onNudgeShow(s),
                    child: SizedBox(
                      width: 74,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PosterImage(
                            url: s.posterPath,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(10)),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: ShapeDecoration(
                                color: c.mediaScrim,
                                shape: MoglogShapes.smooth(6),
                              ),
                              child: Text(
                                s.totalEpisodes > 0
                                    ? 'E${s.episodesWatched}/${s.totalEpisodes}'
                                    : 'E${s.episodesWatched}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: t.microBadge.copyWith(
                                  color: c.onMedia,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String photoBase64;
  final String photoUrl;
  final String name;
  final double radius;

  const _AvatarCircle({
    required this.photoBase64,
    required this.photoUrl,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    ImageProvider? imgProvider;
    if (photoBase64.trim().isNotEmpty) {
      try {
        imgProvider = MemoryImage(base64Decode(photoBase64));
      } catch (_) {}
    } else if (photoUrl.trim().isNotEmpty) {
      imgProvider = CachedNetworkImageProvider(
        photoUrl,
        cacheManager: MoglogImageCacheManager.instance,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: c.tertiaryBackground,
      backgroundImage: imgProvider,
      child: imgProvider == null
          ? Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'M',
              style: context.typo.headline.copyWith(color: c.accentText),
            )
          : null,
    );
  }
}
