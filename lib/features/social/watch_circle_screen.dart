import 'dart:convert';
import 'dart:math';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authControllerProvider).user != null) {
        ref.read(authControllerProvider.notifier).refreshWatchCircle();
      }
    });
  }

  void _showJoinCircleSheet() {
    final ctrl = TextEditingController();
    String? errorMsg;
    var submitting = false;

    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.tertiaryBackground,
                    borderRadius: MoglogShapes.control,
                    border: Border.all(
                      color: errorMsg != null ? c.destructive : c.separator,
                    ),
                  ),
                  child: TextField(
                    controller: ctrl,
                    textCapitalization: TextCapitalization.characters,
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
                  Text(errorMsg!, style: t.footnote.copyWith(color: c.destructive)),
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
                        errorMsg = e.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', '');
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
            height: MediaQuery.sizeOf(ctx).height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = matches[i];
                      final pinned = currentTop4.contains(d.id);
                      return IosPressable(
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
                            shape: MoglogShapes.smooth(12),
                          ),
                          child: Row(
                            children: [
                              PosterImage(
                                url: d.posterPath,
                                width: 38,
                                height: 54,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  d.title,
                                  maxLines: 1,
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
                                color: pinned ? c.starGold : c.secondaryLabel,
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
              final ok = await ref.read(authControllerProvider.notifier).sendNudge(
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
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
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
                          color: c.accent,
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
                    shape: MoglogShapes.smooth(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blend.badgeTitle,
                        style: t.headline.copyWith(color: c.accent),
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
                        shape: MoglogShapes.smooth(12),
                      ),
                      child: Row(
                        children: [
                          PosterImage(
                            url: s.posterPath,
                            width: 38,
                            height: 54,
                            borderRadius: BorderRadius.circular(7),
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
                                    maxLines: 1,
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
                            size: 32,
                            iconSize: 15,
                            tint: c.starGold,
                            onTap: () => _showSendNudgeSheet(
                              toUid: friend.uid,
                              friendName: friend.displayName,
                              dramaId: s.id,
                              dramaTitle: s.title,
                            ),
                          ),
                          if (!savedIds.contains(s.id)) ...[
                            const SizedBox(width: 6),
                            IosCircleIconButton(
                              icon: MoglogIcons.plus,
                              size: 32,
                              iconSize: 15,
                              tint: c.accent,
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
                IosSecondaryButton(
                  text: 'Remove Friend',
                  textColor: c.destructive,
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
            collapsed: true,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              tooltip: 'Back',
              onTap: widget.onBack,
            ),
            trailingActions: user != null
                ? [
                    IosCircleIconButton(
                      icon: MoglogIcons.refresh,
                      tooltip: 'Refresh Watch Circle',
                      onTap: () => ref
                          .read(authControllerProvider.notifier)
                          .refreshWatchCircle(),
                    ),
                  ]
                : null,
          ),
          Expanded(
            child: user == null
                ? Center(
                    child: Padding(
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
                    onRefresh: () => ref
                        .read(authControllerProvider.notifier)
                        .refreshWatchCircle(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isLandscape ? 780 : double.infinity,
                        ),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                      children: [
                        // 1. My Watch Circle Pass Card
                        _MyPassCard(
                          displayName: settings.customDisplayName.isNotEmpty
                              ? settings.customDisplayName
                              : (user.displayName ?? 'Moglog User'),
                          photoBase64: settings.customProfileImageBase64,
                          photoUrl: user.photoURL ?? '',
                          inviteCode: ref
                              .read(authControllerProvider.notifier)
                              .getMyInviteCode(),
                          sharingEnabled: settings.watchCircleSharingEnabled,
                          topFourDramas: topFourDramas,
                          onCopyCode: (code) {
                            Clipboard.setData(ClipboardData(text: code));
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
                          onShareCode: (code) => Share.share(
                            'Join my Moglog Watch Circle! Enter my Circle Code: $code (MOG-$code)',
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
                        const SizedBox(height: 16),

                        // 2. Incoming Nudges & Reactions
                        if (authState.circleNudges.isNotEmpty) ...[
                          Text(
                            'Incoming Nudges',
                            style: t.headline.copyWith(color: c.label),
                          ),
                          const SizedBox(height: 8),
                          for (final nudge in authState.circleNudges.take(4))
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: ShapeDecoration(
                                color: c.secondaryBackground,
                                shape: MoglogShapes.smooth(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: c.starGold.withValues(alpha: 0.16),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _nudgeIcon(nudge.emoji),
                                      size: 18,
                                      color: c.starGold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${nudge.fromName} · ${nudge.dramaTitle}',
                                          maxLines: 1,
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
                                    size: 28,
                                    iconSize: 14,
                                    onTap: () => ref
                                        .read(authControllerProvider.notifier)
                                        .dismissNudge(nudge.id),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],

                        // 3. Co-Watching Episode Race
                        if (coWatchPairs.isNotEmpty) ...[
                          Text(
                            'Co-Watching Episode Race',
                            style: t.headline.copyWith(color: c.label),
                          ),
                          const SizedBox(height: 8),
                          for (final pair in coWatchPairs.take(4))
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: ShapeDecoration(
                                color: c.secondaryBackground,
                                shape: MoglogShapes.smooth(14),
                              ),
                              child: Row(
                                children: [
                                  PosterImage(
                                    url: pair.posterPath,
                                    width: 44,
                                    height: 64,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pair.title,
                                          maxLines: 1,
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
                                  const SizedBox(width: 8),
                                  IosCircleIconButton(
                                    icon: MoglogIcons.zap,
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
                          const SizedBox(height: 10),
                        ],

                        // 4. Circle Members Feed
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Circle Members (${authState.circleFriends.length})',
                              style: t.headline.copyWith(color: c.label),
                            ),
                            if (authState.isLoadingCircle)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.accent,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (authState.circleFriends.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: ShapeDecoration(
                              color: c.secondaryBackground,
                              shape: MoglogShapes.smooth(14),
                            ),
                            child: Text(
                              'No friends in your circle yet. Share your Circle Code or enter a friend\'s code above!',
                              style: t.subhead.copyWith(color: c.secondaryLabel),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          for (final friend in authState.circleFriends) ...[
                            Builder(
                              builder: (_) {
                                final blend = TasteBlendCalculator.computeBlend(
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: c.secondaryBackground,
        shape: MoglogShapes.smooth(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarCircle(
                photoBase64: photoBase64,
                photoUrl: photoUrl,
                name: displayName,
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: t.headline.copyWith(color: c.label)),
                    Text(
                      sharingEnabled
                          ? 'Sharing activity with circle'
                          : 'Activity sharing paused',
                      style: t.caption.copyWith(color: c.secondaryLabel),
                    ),
                  ],
                ),
              ),
              IosPressable(
                onTap: () => onCopyCode(inviteCode),
                onLongPress: onRotateCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: c.accent.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    inviteCode.isNotEmpty ? inviteCode : '------',
                    style: t.subhead.copyWith(
                      color: c.accent,
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
            style: t.caption2.copyWith(color: c.tertiaryLabel),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: IosPrimaryButton(
                  text: 'Share Group Link',
                  leadingIcon: MoglogIcons.share,
                  onTap: () => onShareCode(inviteCode),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IosSecondaryButton(
                  text: 'Enter Code',
                  leadingIcon: MoglogIcons.plus,
                  onTap: onEnterFriendCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Top 4 All-Time Favorites',
                style: t.subhead.copyWith(
                  color: c.label,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IosPressable(
                onTap: onPickTopFour,
                child: Text(
                  '+ Add',
                  style: t.footnote.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                            onTap: () => onTopFourTap(d),
                            onLongPress: () => onTopFourLongPress(d),
                            child: PosterImage(
                              url: d.posterPath,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          )
                        : IosPressable(
                            onTap: onPickTopFour,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.tertiaryBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: c.separator),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                MoglogIcons.plus,
                                size: 18,
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

    return IosPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: ShapeDecoration(
          color: c.secondaryBackground,
          shape: MoglogShapes.smooth(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarCircle(
                  photoBase64: friend.photoBase64,
                  photoUrl: friend.photoUrl,
                  name: friend.displayName,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        style: t.headline.copyWith(color: c.label, fontSize: 15.5),
                      ),
                      Text(
                        '${blend.badgeTitle} · ${blend.sharedShows.length} shared',
                        style: t.caption.copyWith(color: c.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.accentSubtle,
                    borderRadius: MoglogShapes.pill,
                  ),
                  child: Text(
                    '${blend.compatibilityPercent}% Match',
                    style: t.caption2.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (shelf.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: min(shelf.length, 8),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    final s = shelf[idx];
                    return IosPressable(
                      onTap: () => onShowTap(s.id),
                      onLongPress: () => onNudgeShow(s),
                      child: SizedBox(
                        width: 72,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PosterImage(
                              url: s.posterPath,
                              borderRadius: BorderRadius.circular(9),
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
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.76),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  s.totalEpisodes > 0
                                      ? 'E${s.episodesWatched}/${s.totalEpisodes}'
                                      : 'E${s.episodesWatched}',
                                  textAlign: TextAlign.center,
                                  style: t.caption2.copyWith(
                                    color: Colors.white,
                                    fontSize: 9.5,
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
      imgProvider = NetworkImage(photoUrl);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: c.tertiaryBackground,
      backgroundImage: imgProvider,
      child: imgProvider == null
          ? Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'M',
              style: context.typo.headline.copyWith(color: c.accent),
            )
          : null,
    );
  }
}
