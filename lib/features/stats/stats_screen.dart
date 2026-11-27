import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/ios_bottom_tab_bar.dart';
import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';
import '../../core/platform/platform_bridge.dart';
import '../../domain/logic/library_filter.dart';
import '../../domain/logic/stats_calculator.dart';
import '../../domain/model/drama.dart';

Color _readableTierInk(Color raw, MoglogColors c) {
  if (c.isDark) return raw;
  final hsl = HSLColor.fromColor(raw);
  if (hsl.lightness > 0.36) {
    return hsl.withLightness(0.32).toColor();
  }
  return raw;
}

Color _onTierBadgeColor(Color raw, MoglogColors c) {
  final est = ThemeData.estimateBrightnessForColor(raw);
  return est == Brightness.dark ? c.onMedia : MoglogColors.light.onAccent;
}

class StatsScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onDramaTap;

  const StatsScreen({super.key, required this.onDramaTap});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _chartAnimCtrl;
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _chartAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
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
    _chartAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveWrappedToGallery(StatsSnapshot snap) async {
    try {
      final png = await renderWrappedCardPng(
        totalShows: snap.activeDramas.length,
        doneShows: snap.doneCount,
        episodesWatched: snap.totalEpisodesWatched,
        hoursWatched: snap.estimatedHours,
        topGenre: snap.topGenreName,
        persona: snap.bingePersona,
        topShows: snap.topRatedShows.take(4).toList(),
      );
      final name =
          'Moglog_Wrapped_${DateTime.now().millisecondsSinceEpoch}.png';
      if (Platform.isIOS) {
        final dir = await getTemporaryDirectory();
        final outFile = File('${dir.path}/$name');
        await outFile.writeAsBytes(png);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(outFile.path, mimeType: 'image/png')],
            subject: 'Moglog Wrapped',
          ),
        );
        return;
      }
      final ok = await PlatformBridge.saveImageToGallery(png, name);
      ref.read(toastProvider.notifier).show(
            ok
                ? 'Saved Wrapped Card to Gallery (Pictures/Moglog)'
                : 'Unable to save image to Gallery',
          );
    } catch (_) {
      ref.read(toastProvider.notifier).show('Unable to save image to Gallery');
    }
  }

  Future<void> _shareWrappedCard(StatsSnapshot snap) async {
    try {
      final png = await renderWrappedCardPng(
        totalShows: snap.activeDramas.length,
        doneShows: snap.doneCount,
        episodesWatched: snap.totalEpisodesWatched,
        hoursWatched: snap.estimatedHours,
        topGenre: snap.topGenreName,
        persona: snap.bingePersona,
        topShows: snap.topRatedShows.take(4).toList(),
      );
      final dir = await getTemporaryDirectory();
      final outFile = File('${dir.path}/moglog_wrapped_card.png');
      await outFile.writeAsBytes(png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(outFile.path, mimeType: 'image/png')],
          text:
              'My Moglog Wrapped: ${snap.bingePersona.title} (${snap.bingePersona.rankBadge}) — ${snap.estimatedHours}h watched across ${snap.totalEpisodesWatched} episodes!',
        ),
      );
    } catch (_) {}
  }

  void _showPrestigeTiersSheet(StatsSnapshot snap) {
    final catalog = getPrestigeTiersCatalog(snap.topGenreName);
    final effectiveHours = max(snap.estimatedHours, snap.doneCount * 10);

    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        final t = ctx.typo;
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: MoglogSpacing.sheetPadding,
              children: [
                Text(
                  '13 Prestige Tiers',
                  style: t.title2.copyWith(color: c.label),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your current rank: ${snap.bingePersona.rankBadge} (${effectiveHours}h effective)',
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 16),
                for (final tier in catalog) ...[
                  Builder(
                    builder: (_) {
                      final tierColor = Color(tier.colorHex);
                      final tierInk = _readableTierInk(tierColor, c);
                      final isCurrent =
                          tier.level == snap.bingePersona.tierLevel;
                      final isUnlocked = effectiveHours >= tier.minHours;
                      final hoursNeeded =
                          max(0, tier.minHours - effectiveHours);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: ShapeDecoration(
                          color: isCurrent
                              ? tierColor.withValues(alpha: 0.16)
                              : c.tertiaryBackground
                                  .withValues(alpha: isUnlocked ? 0.92 : 0.6),
                          shape: MoglogShapes.smooth(
                            16,
                            side: BorderSide(
                              color: isCurrent
                                  ? tierColor
                                  : tierColor.withValues(alpha: 0.28),
                              width: isCurrent ? 1.5 : 0.75,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: tierColor.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: tierColor, width: 1.2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${tier.level}',
                                style: t.subhead.copyWith(
                                  color: tierInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        tier.badge,
                                        style: t.caption2.copyWith(
                                          color: tierInk,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tierColor,
                                            borderRadius: MoglogShapes.pill,
                                          ),
                                          child: Text(
                                            'CURRENT',
                                            style: t.microBadge.copyWith(
                                              color: _onTierBadgeColor(
                                                tierColor,
                                                c,
                                              ),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tier.sampleTitle,
                                    style: t.subhead.copyWith(
                                      color: isUnlocked
                                          ? c.label
                                          : c.secondaryLabel,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tier.unlockCriteria,
                                    style: t.caption2.copyWith(
                                      color: c.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: tierColor.withValues(alpha: 0.16),
                                    shape: MoglogShapes.smooth(8),
                                  ),
                                  child: Text(
                                    tier.hoursRangeLabel,
                                    style: t.caption2.copyWith(
                                      color: tierInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isCurrent
                                      ? 'Active Rank'
                                      : (isUnlocked
                                          ? 'Unlocked'
                                          : '${hoursNeeded}h more'),
                                  style: t.caption2.copyWith(
                                    color: isUnlocked
                                        ? tierInk
                                        : c.tertiaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion = context.reduceMotion;
    final dramas = ref.watch(currentDramasProvider);
    final snap = computeStatsSnapshot(dramas);
    final personaColor = Color(snap.bingePersona.accentColorHex);
    final personaInk = _readableTierInk(personaColor, c);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final shellBottomPad = MoglogLayout.shellScrollBottomPadding(context);

    return TabRetapListener(
      branchIndex: 2,
      scrollController: _scrollController,
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            IosLargeTitleHeader(
              title: 'Statistics',
              collapsed: _headerCollapsed,
              trailingActions: snap.activeDramas.isNotEmpty
                  ? [
                      IosCircleIconButton(
                        icon: MoglogIcons.download,
                        tooltip: 'Save Wrapped Card to Gallery',
                        tint: personaInk,
                        onTap: () => _saveWrappedToGallery(snap),
                      ),
                      IosCircleIconButton(
                        icon: MoglogIcons.share,
                        tooltip: 'Share Moglog Wrapped',
                        tint: personaInk,
                        onTap: () => _shareWrappedCard(snap),
                      ),
                    ]
                  : null,
            ),
            Expanded(
              child: snap.activeDramas.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: shellBottomPad * 0.65),
                        child: const IosEmptyState(
                          icon: MoglogIcons.stats,
                          title: 'Statistics',
                          subtitle:
                              'Add shows and log episodes to unlock visual insights into your watching habits.',
                        ),
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _chartAnimCtrl,
                      builder: (context, _) {
                        final progress = reduceMotion
                            ? 1.0
                            : Curves.fastOutSlowIn
                                .transform(_chartAnimCtrl.value);

                        final statusCard = _StatusBreakdownCard(
                          watching: snap.watchingCount,
                          planned: snap.plannedCount,
                          done: snap.doneCount,
                          animProgress: progress,
                        );
                        final genreCard = _GenreBreakdownCard(
                          genres: snap.genreBreakdown,
                          animProgress: progress,
                        );

                        return ListView(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            MoglogSpacing.md,
                            MoglogSpacing.sm,
                            MoglogSpacing.md,
                            shellBottomPad,
                          ),
                          children: [
                            // 1. Moglog Wrapped Hero Card
                            _WrappedHeroCard(
                              persona: snap.bingePersona,
                              topGenre: snap.topGenreName,
                              hoursWatched: snap.estimatedHours,
                              onTap: () => _showPrestigeTiersSheet(snap),
                            ),
                            const SizedBox(height: 16),

                            // 2. 4 Summary Metric Cards
                            if (isLandscape)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Total Shows',
                                      value: '${snap.activeDramas.length}',
                                      sub: '${snap.doneCount} completed',
                                      color: c.accentText,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Episodes',
                                      value: '${snap.totalEpisodesWatched}',
                                      sub: 'logged',
                                      color: c.statusTextColor('Watching'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Est. Hours',
                                      value: '${snap.estimatedHours}h',
                                      sub:
                                          '~${(snap.estimatedHours / 24.0).toStringAsFixed(1)} days',
                                      color: c.statusTextColor('Planned'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Monthly Streak',
                                      value: '${snap.currentStreakMonths}m',
                                      sub: 'consecutive',
                                      color: c.starGold,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Total Shows',
                                      value: '${snap.activeDramas.length}',
                                      sub: '${snap.doneCount} completed',
                                      color: c.accentText,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Episodes',
                                      value: '${snap.totalEpisodesWatched}',
                                      sub: 'logged',
                                      color: c.statusTextColor('Watching'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Est. Hours',
                                      value: '${snap.estimatedHours}h',
                                      sub:
                                          '~${(snap.estimatedHours / 24.0).toStringAsFixed(1)} days',
                                      color: c.statusTextColor('Planned'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Monthly Streak',
                                      value: '${snap.currentStreakMonths}m',
                                      sub: 'consecutive',
                                      color: c.starGold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            // 3. Status Breakdown & Top Genres
                            if (isLandscape)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: statusCard),
                                  const SizedBox(width: 12),
                                  Expanded(child: genreCard),
                                ],
                              )
                            else ...[
                              statusCard,
                              if (snap.genreBreakdown.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                genreCard,
                              ],
                            ],
                            const SizedBox(height: 16),

                            // 4. 12-Month Activity Bar Chart
                            _MonthlyActivityCard(
                              buckets: snap.monthlyActivity,
                              animProgress: progress,
                            ),
                            const SizedBox(height: 16),

                            // 5. Your Highest Rated Top 5
                            if (snap.topRatedShows.isNotEmpty) ...[
                              _TopRatedCard(
                                shows: snap.topRatedShows,
                                onDramaTap: widget.onDramaTap,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 6. Release Radar · Airing Schedule
                            if (snap.releaseRadarShows.isNotEmpty) ...[
                              _ReleaseRadarCard(
                                shows: snap.releaseRadarShows,
                                onDramaTap: widget.onDramaTap,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 7. TV Diary Timeline
                            if (snap.diaryEntries.isNotEmpty)
                              _TvDiaryTimelineCard(
                                entries: snap.diaryEntries,
                                onDramaTap: widget.onDramaTap,
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrappedHeroCard extends StatelessWidget {
  final BingePersona persona;
  final String topGenre;
  final int hoursWatched;
  final VoidCallback onTap;

  const _WrappedHeroCard({
    required this.persona,
    required this.topGenre,
    required this.hoursWatched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final tierColor = Color(persona.accentColorHex);
    final tierInk = _readableTierInk(tierColor, c);
    final days = (hoursWatched / 24.0).toStringAsFixed(1);

    return IosPressable(
      onTap: onTap,
      hapticOnTap: true,
      focusRadius: MoglogShapes.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                tierColor.withValues(alpha: c.isDark ? 0.24 : 0.16),
                c.secondaryBackground,
              ),
              c.secondaryBackground,
            ],
          ),
          shape: MoglogShapes.smooth(
            MoglogShapes.cardRadius,
            side: BorderSide(
              color: tierColor.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          shadows: c.isDark
              ? null
              : [
                  BoxShadow(
                    color: c.shadowSoft,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.18),
                    borderRadius: MoglogShapes.pill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MoglogIcons.award, size: 13, color: tierInk),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          persona.rankBadge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption2.copyWith(
                            color: tierInk,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rank ${persona.tierLevel}/13 ›',
                  style: t.caption.copyWith(
                    color: tierInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              persona.title,
              style: t.title2.copyWith(color: c.label),
            ),
            const SizedBox(height: 4),
            Text(
              'Top Genre: $topGenre · ~$days full days streamed',
              style: t.footnote.copyWith(color: c.secondaryLabel),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: MoglogShapes.pill,
              child: LinearProgressIndicator(
                value: persona.progressFraction,
                minHeight: 7,
                backgroundColor: c.tertiaryBackground,
                color: tierColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Next Rank: ${persona.nextRankTitle} · Tap to view all 13 tiers',
              style: t.caption2.copyWith(color: c.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Semantics(
      container: true,
      label: '$label: $value, $sub',
      child: IosCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.caption2.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.title1.copyWith(
                color: c.label,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.caption2.copyWith(color: c.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  final int watching;
  final int planned;
  final int done;
  final double animProgress;

  const _StatusBreakdownCard({
    required this.watching,
    required this.planned,
    required this.done,
    required this.animProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final totalRaw = watching + planned + done;
    final total = max(1, totalRaw);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final donutDim = 114.0 * textScale.clamp(1.0, 1.25);

    final donutWidget = SizedBox(
      width: donutDim,
      height: donutDim,
      child: CustomPaint(
        painter: _DonutPainter(
          segments: [
            (watching / total, c.statusWatching),
            (planned / total, c.statusPlanned),
            (done / total, c.statusDone),
          ],
          trackColor: c.tertiaryBackground,
          animProgress: animProgress,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$totalRaw',
                    style: t.title2.copyWith(color: c.label),
                  ),
                  Text(
                    'Shows',
                    style: t.caption2.copyWith(color: c.secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final legendColumn = Column(
      children: [
        _LegendRow('Watching', watching, c.statusWatching),
        const SizedBox(height: 10),
        _LegendRow('Planned', planned, c.statusPlanned),
        const SizedBox(height: 10),
        _LegendRow('Done', done, c.statusDone),
      ],
    );

    return Semantics(
      container: true,
      label:
          'Status Breakdown chart: $totalRaw total shows. Watching $watching, Planned $planned, Done $done.',
      child: IosCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackVertical =
                constraints.maxWidth < 290 || textScale > 1.6;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Breakdown',
                  style: t.headline.copyWith(color: c.label),
                ),
                const SizedBox(height: 16),
                if (stackVertical) ...[
                  Center(child: donutWidget),
                  const SizedBox(height: 16),
                  legendColumn,
                ] else
                  Row(
                    children: [
                      donutWidget,
                      const SizedBox(width: 22),
                      Expanded(child: legendColumn),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _LegendRow(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.subhead.copyWith(color: c.label),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: t.subhead.copyWith(
            color: c.label,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments;
  final Color trackColor;
  final double animProgress;

  const _DonutPainter({
    required this.segments,
    required this.trackColor,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (min(size.width, size.height) / 2) - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );

    var startAngle = -pi / 2;
    for (final (fraction, color) in segments) {
      if (fraction <= 0) continue;
      final sweep = 2 * pi * fraction * animProgress;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.animProgress != animProgress || old.segments != segments;
}

class _GenreBreakdownCard extends StatelessWidget {
  final List<MapEntry<String, int>> genres;
  final double animProgress;

  const _GenreBreakdownCard({
    required this.genres,
    required this.animProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final maxCount = genres.isEmpty ? 1 : max(1, genres.first.value);
    final summary = genres.map((e) => '${e.key}: ${e.value}').join(', ');

    return Semantics(
      container: true,
      label: 'Top Genres breakdown: $summary',
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Genres', style: t.headline.copyWith(color: c.label)),
            const SizedBox(height: 12),
            for (final entry in genres) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.footnote.copyWith(color: c.label),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value}',
                    style: t.footnote.copyWith(
                      color: c.secondaryLabel,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: MoglogShapes.pill,
                child: LinearProgressIndicator(
                  value: (entry.value / maxCount) * animProgress,
                  minHeight: 7,
                  backgroundColor: c.tertiaryBackground,
                  color: c.accent,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlyActivityCard extends StatelessWidget {
  final List<MonthlyActivityBucket> buckets;
  final double animProgress;

  const _MonthlyActivityCard({
    required this.buckets,
    required this.animProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final maxVal = buckets.fold<int>(1, (acc, b) => max(acc, b.count));
    final totalLogged = buckets.fold<int>(0, (acc, b) => acc + b.count);
    final activeMonths = buckets.where((b) => b.count > 0).length;
    final chartHeight =
        120.0 + ((textScale - 1.0).clamp(0.0, 1.0) * 48.0);

    return Semantics(
      container: true,
      label:
          'Completions and Activity over the last 12 months: $totalLogged shows updated or completed across $activeMonths active months.',
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completions & Activity (Last 12 Months)',
              style: t.headline.copyWith(color: c.label),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((b) {
                  final hFrac = b.count == 0 ? 0.05 : (b.count / maxVal);
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (b.count > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${b.count}',
                              style: t.microBadge.copyWith(
                                color: c.secondaryLabel,
                              ),
                            ),
                          ),
                        const SizedBox(height: 3),
                        Container(
                          width: 13,
                          height: max(4.0, 72.0 * hFrac * animProgress),
                          decoration: ShapeDecoration(
                            color: b.count > 0
                                ? c.accent
                                : c.tertiaryBackground,
                            shape: MoglogShapes.smooth(5),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            b.monthLabel[0],
                            style: t.microBadge.copyWith(
                              color: c.secondaryLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRatedCard extends StatelessWidget {
  final List<Drama> shows;
  final ValueChanged<int> onDramaTap;

  const _TopRatedCard({required this.shows, required this.onDramaTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return IosCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Your Highest Rated',
              style: t.headline.copyWith(color: c.label),
            ),
          ),
          for (var i = 0; i < shows.length; i++) ...[
            IosPressable(
              onTap: () => onDramaTap(shows[i].id),
              hapticOnTap: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: t.headline.copyWith(color: c.accentText),
                        ),
                      ),
                      PosterImage(
                        url: shows[i]
                            .posterPath
                            .replaceFirst('/w500/', '/w185/'),
                        width: 36,
                        height: 50,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(7)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          shows[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.subhead.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(MoglogIcons.starFilled, size: 14, color: c.starGold),
                      const SizedBox(width: 4),
                      Text(
                        shows[i].effectiveRating.toStringAsFixed(1),
                        style: t.subhead.copyWith(
                          color: c.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i < shows.length - 1)
              Divider(
                height: c.hairlineWidth,
                thickness: c.hairlineWidth,
                color: c.separator,
                indent: 68,
              ),
          ],
        ],
      ),
    );
  }
}

class _ReleaseRadarCard extends StatelessWidget {
  final List<Drama> shows;
  final ValueChanged<int> onDramaTap;

  const _ReleaseRadarCard({required this.shows, required this.onDramaTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return IosCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(MoglogIcons.calendar, size: 18, color: c.accentText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Release Radar · Airing Schedule',
                    style: t.headline.copyWith(color: c.label),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < shows.length; i++) ...[
            Builder(
              builder: (_) {
                final d = shows[i];
                final countdown =
                    computeAiringCountdownLabel(d.nextEpisodeAirDate) ??
                        (d.nextEpisodeAirDate ?? '');
                final epLabel =
                    (d.nextSeasonNumber > 0 && d.nextEpisodeNumber > 0)
                        ? 'S${d.nextSeasonNumber.toString().padLeft(2, "0")}E${d.nextEpisodeNumber.toString().padLeft(2, "0")}'
                        : 'Next Episode';

                return IosPressable(
                  onTap: () => onDramaTap(d.id),
                  hapticOnTap: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 58),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          PosterImage(
                            url: d.posterPath.replaceFirst('/w500/', '/w185/'),
                            width: 36,
                            height: 50,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(7)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.subhead.copyWith(
                                    color: c.label,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$epLabel · Airs ${d.nextEpisodeAirDate}',
                                  style: t.caption
                                      .copyWith(color: c.secondaryLabel),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 112),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: ShapeDecoration(
                                color: c.accentSubtle,
                                shape: MoglogShapes.smooth(8),
                              ),
                              child: Text(
                                countdown,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption2.copyWith(
                                  color: c.accentText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (i < shows.length - 1)
              Divider(
                height: c.hairlineWidth,
                thickness: c.hairlineWidth,
                color: c.separator,
                indent: 64,
              ),
          ],
        ],
      ),
    );
  }
}

class _TvDiaryTimelineCard extends StatelessWidget {
  final List<Drama> entries;
  final ValueChanged<int> onDramaTap;

  const _TvDiaryTimelineCard({
    required this.entries,
    required this.onDramaTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final fmt = DateFormat('MMM d, yyyy', 'en_US');

    return IosCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MoglogIcons.clock,
                      size: 18,
                      color: c.statusTextColor('Watching'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'TV Diary Timeline',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.headline.copyWith(color: c.label),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Recent ${entries.length}',
                  style: t.caption2.copyWith(
                    color: c.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < entries.length; i++) ...[
            Builder(
              builder: (_) {
                final d = entries[i];
                final ts = max(d.completedAt, max(d.updatedAt, d.addedAt));
                final dateStr = ts > 0
                    ? fmt.format(DateTime.fromMillisecondsSinceEpoch(ts))
                    : 'Recent';
                final desc = d.status == 'Done'
                    ? 'Completed series (${max(d.totalEpisodes, d.episodesWatched)} eps)'
                    : (d.status == 'Watching' && d.episodesWatched > 0
                        ? 'Watched up to S${max(1, d.currentSeason)} · Ep ${d.episodesWatched}'
                        : 'Added to ${d.status}');

                return IosPressable(
                  onTap: () => onDramaTap(d.id),
                  hapticOnTap: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 54),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: c.statusColor(d.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.subhead.copyWith(
                                    color: c.label,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: t.caption
                                      .copyWith(color: c.secondaryLabel),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: t.caption2.copyWith(color: c.secondaryLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (i < entries.length - 1)
              Divider(
                height: c.hairlineWidth,
                thickness: c.hairlineWidth,
                color: c.separator,
                indent: 37,
              ),
          ],
        ],
      ),
    );
  }
}
