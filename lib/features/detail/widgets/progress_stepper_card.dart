import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../core/design_system/tokens.dart';
import '../../../domain/logic/season_progress.dart';
import '../../../domain/model/drama_extra_details.dart';

/// Multi-season episode progress stepper card wrapped in `IosCard` (squircle 20).
class ProgressStepperCard extends StatelessWidget {
  final int episodesWatched;
  final int totalEpisodes;
  final int currentSeason;
  final int totalSeasons;
  final List<SeasonInfo> seasons;
  final String? nextEpisodeAirDate;
  final int nextSeasonNumber;
  final int nextEpisodeNumber;
  final Color accentColor;
  final ValueChanged<int> onSeasonChange;
  final ValueChanged<int> onEpisodesWatchedChange;

  const ProgressStepperCard({
    super.key,
    required this.episodesWatched,
    required this.totalEpisodes,
    required this.currentSeason,
    required this.totalSeasons,
    required this.seasons,
    required this.nextEpisodeAirDate,
    required this.nextSeasonNumber,
    required this.nextEpisodeNumber,
    required this.accentColor,
    required this.onSeasonChange,
    required this.onEpisodesWatchedChange,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final onAccentSafe =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
            ? c.onMedia
            : MoglogColors.light.onAccent;
    final readableAccent = (!c.isDark &&
            HSLColor.fromColor(accentColor).lightness > 0.36)
        ? HSLColor.fromColor(accentColor).withLightness(0.32).toColor()
        : accentColor;

    final resolvedSeasons = resolveSeasonBreakdown(
      seasons: seasons,
      totalSeasons: totalSeasons,
      totalEpisodes: totalEpisodes,
    );
    final isMultiSeason = resolvedSeasons.length > 1;
    final activeSeasonInfo = resolvedSeasons
            .where((s) => s.seasonNumber == currentSeason)
            .firstOrNull ??
        resolvedSeasons.firstOrNull;

    final seasonOffset = !isMultiSeason
        ? 0
        : resolvedSeasons
            .where((s) => s.seasonNumber < currentSeason)
            .fold<int>(0, (sum, s) => sum + s.episodeCount);

    final seasonTotalEpisodes = (isMultiSeason &&
            activeSeasonInfo != null &&
            activeSeasonInfo.episodeCount > 0)
        ? activeSeasonInfo.episodeCount
        : totalEpisodes;

    final displayedWatched = (isMultiSeason && seasonTotalEpisodes > 0)
        ? (episodesWatched - seasonOffset).clamp(0, seasonTotalEpisodes)
        : episodesWatched;

    final canDecrement = isMultiSeason && seasonTotalEpisodes > 0
        ? (displayedWatched > 0 || episodesWatched > 0)
        : episodesWatched > 0;
    final canIncrement = isMultiSeason && seasonTotalEpisodes > 0
        ? (displayedWatched < seasonTotalEpisodes ||
            (totalEpisodes > 0 && episodesWatched < totalEpisodes))
        : (totalEpisodes <= 0 || episodesWatched < totalEpisodes);

    final fraction = seasonTotalEpisodes > 0
        ? (displayedWatched / seasonTotalEpisodes).clamp(0.0, 1.0)
        : (displayedWatched > 0
            ? max(0.08, (displayedWatched % 12) / 12.0)
            : 0.0);

    final seasonCount =
        resolvedSeasons.isNotEmpty ? resolvedSeasons.length : totalSeasons;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 300;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final stackStepper = isCompact || textScale > 1.45;

        String subtitle;
        if (isMultiSeason && seasonTotalEpisodes > 0) {
          subtitle = (totalEpisodes > 0 && !isCompact)
              ? '$displayedWatched of $seasonTotalEpisodes in S$currentSeason ($episodesWatched/$totalEpisodes total)'
              : '$displayedWatched of $seasonTotalEpisodes episodes watched';
        } else if (totalEpisodes > 0) {
          subtitle = '$episodesWatched of $totalEpisodes episodes watched';
        } else {
          subtitle = '$episodesWatched episodes watched';
        }

        final headerLabels = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMultiSeason
                  ? 'Episode Progress · S$currentSeason'
                  : 'Episode Progress',
              style: (isCompact ? t.subhead : t.headline).copyWith(
                color: c.label,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: (isCompact ? t.caption : t.footnote).copyWith(
                color: c.secondaryLabel,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        final stepperControl = Container(
          padding: const EdgeInsets.all(4),
          decoration: ShapeDecoration(
            color: c.tertiaryBackground,
            shape: MoglogShapes.smooth(
              MoglogShapes.controlRadius,
              side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IosPressable(
                enabled: canDecrement,
                semanticLabel: 'Decrease watched episodes',
                onTap: () {
                  MoglogHaptics.tickMinus();
                  if (isMultiSeason && seasonTotalEpisodes > 0) {
                    final nextInSeason = max(0, displayedWatched - 1);
                    onEpisodesWatchedChange(
                      max(0, seasonOffset + nextInSeason),
                    );
                  } else {
                    onEpisodesWatchedChange(max(0, episodesWatched - 1));
                  }
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 42, minHeight: 38),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: c.secondaryBackground,
                      shape: MoglogShapes.smooth(9),
                    ),
                    child: Center(
                      child: Icon(
                        MoglogIcons.minus,
                        size: 17,
                        color: canDecrement ? c.label : c.tertiaryLabel,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14),
                child: Text(
                  '$displayedWatched',
                  style: t.headline.copyWith(color: c.label),
                ),
              ),
              IosPressable(
                enabled: canIncrement,
                semanticLabel: 'Increase watched episodes',
                onTap: () {
                  MoglogHaptics.clickPlus();
                  if (isMultiSeason && seasonTotalEpisodes > 0) {
                    final nextInSeason =
                        min(seasonTotalEpisodes, displayedWatched + 1);
                    final newGlobal = seasonOffset + nextInSeason;
                    onEpisodesWatchedChange(
                      totalEpisodes > 0
                          ? min(totalEpisodes, newGlobal)
                          : newGlobal,
                    );
                  } else {
                    final next = episodesWatched + 1;
                    onEpisodesWatchedChange(
                      totalEpisodes > 0 ? min(totalEpisodes, next) : next,
                    );
                  }
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 42, minHeight: 38),
                  child: canIncrement
                      ? GlossSurface(
                          baseColor: accentColor,
                          cornerRadius: 9,
                          minHeight: 38,
                          showGlow: false,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            MoglogIcons.plus,
                            size: 17,
                            color: onAccentSafe,
                          ),
                        )
                      : DecoratedBox(
                          decoration: ShapeDecoration(
                            color: c.secondaryBackground,
                            shape: MoglogShapes.smooth(9),
                          ),
                          child: Center(
                            child: Icon(
                              MoglogIcons.plus,
                              size: 17,
                              color: c.tertiaryLabel,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );

        return IosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stackStepper) ...[
                headerLabels,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: stepperControl,
                ),
              ] else
                Row(
                  children: [
                    Expanded(child: headerLabels),
                    const SizedBox(width: 10),
                    stepperControl,
                  ],
                ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: MoglogShapes.pill,
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: c.tertiaryBackground,
                  color: accentColor,
                ),
              ),
              if (seasonCount > 1) ...[
                const SizedBox(height: 14),
                Divider(
                  height: c.hairlineWidth,
                  thickness: c.hairlineWidth,
                  color: c.separator,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (resolvedSeasons.isNotEmpty
                          ? resolvedSeasons.map((s) => s.seasonNumber).toList()
                          : List<int>.generate(
                              min(seasonCount, 20),
                              (i) => i + 1,
                            ))
                      .map((sNum) {
                    final isSelected = currentSeason == sNum;
                    final sOffset = resolvedSeasons
                        .where((s) => s.seasonNumber < sNum)
                        .fold<int>(0, (sum, s) => sum + s.episodeCount);
                    final sCount = resolvedSeasons
                            .where((s) => s.seasonNumber == sNum)
                            .firstOrNull
                            ?.episodeCount ??
                        0;
                    final isSeasonDone =
                        sCount > 0 && episodesWatched >= (sOffset + sCount);

                    return IosPressable(
                      semanticSelected: isSelected,
                      semanticLabel: isSeasonDone
                          ? 'Season $sNum, completed'
                          : 'Season $sNum',
                      onTap: () {
                        MoglogHaptics.selectionChanged();
                        onSeasonChange(sNum);
                      },
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 34),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: ShapeDecoration(
                            color: isSelected
                                ? accentColor
                                : (isSeasonDone
                                    ? accentColor.withValues(alpha: 0.15)
                                    : c.tertiaryBackground),
                            shape: MoglogShapes.smooth(
                              9,
                              side: (!isSelected && isSeasonDone)
                                  ? BorderSide(
                                      color:
                                          accentColor.withValues(alpha: 0.55),
                                      width: 1,
                                    )
                                  : BorderSide(
                                      color: c.glassBorder,
                                      width: c.hairlineWidth,
                                    ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isSeasonDone ? '✓ S$sNum' : 'S$sNum',
                            style: t.caption.copyWith(
                              fontWeight: (isSelected || isSeasonDone)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? onAccentSafe
                                  : (isSeasonDone
                                      ? readableAccent
                                      : c.secondaryLabel),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if ((nextEpisodeAirDate ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: ShapeDecoration(
                    color: c.tertiaryBackground,
                    shape: MoglogShapes.smooth(
                      MoglogShapes.controlRadius,
                      side: BorderSide(
                        color: c.glassBorder,
                        width: c.hairlineWidth,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(MoglogIcons.bell, size: 16, color: readableAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (nextSeasonNumber > 0 && nextEpisodeNumber > 0)
                              ? 'Next episode (S${nextSeasonNumber.toString().padLeft(2, "0")}E${nextEpisodeNumber.toString().padLeft(2, "0")}) airs $nextEpisodeAirDate'
                              : 'Next episode airs $nextEpisodeAirDate',
                          style: t.footnote.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
