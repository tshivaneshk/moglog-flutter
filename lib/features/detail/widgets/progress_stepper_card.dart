import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../domain/logic/season_progress.dart';
import '../../../domain/model/drama_extra_details.dart';

/// 1:1 port of Kotlin `ProgressStepperCard.kt`.
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

    final seasonTotalEpisodes =
        (isMultiSeason && activeSeasonInfo != null && activeSeasonInfo.episodeCount > 0)
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
        final isCompact = constraints.maxWidth < 290;

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

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            color: c.secondaryBackground,
            shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMultiSeason
                              ? 'Episode Progress · S$currentSeason'
                              : 'Episode Progress',
                          style: t.headline.copyWith(
                            color: c.label,
                            fontSize: isCompact ? 15 : 17,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: t.footnote.copyWith(
                            color: c.secondaryLabel,
                            fontSize: isCompact ? 11.5 : 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // - / count / + stepper pill
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.tertiaryBackground,
                      borderRadius: MoglogShapes.control,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IosPressable(
                          enabled: canDecrement,
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
                          child: Container(
                            width: isCompact ? 34 : 40,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.secondaryBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              MoglogIcons.minus,
                              size: 16,
                              color: canDecrement ? c.label : c.tertiaryLabel,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 8 : 12,
                          ),
                          child: Text(
                            '$displayedWatched',
                            style: t.headline.copyWith(
                              color: c.label,
                              fontSize: isCompact ? 15 : 17,
                            ),
                          ),
                        ),
                        IosPressable(
                          enabled: canIncrement,
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
                          child: Container(
                            width: isCompact ? 34 : 40,
                            height: 32,
                            decoration: BoxDecoration(
                              color: canIncrement
                                  ? accentColor
                                  : c.secondaryBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              MoglogIcons.plus,
                              size: 16,
                              color: canIncrement ? c.onAccent : c.tertiaryLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          : List<int>.generate(min(seasonCount, 20), (i) => i + 1))
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
                      onTap: () {
                        MoglogHaptics.selectionChanged();
                        onSeasonChange(sNum);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor
                              : (isSeasonDone
                                  ? accentColor.withValues(alpha: 0.16)
                                  : c.tertiaryBackground),
                          borderRadius: BorderRadius.circular(8),
                          border: (!isSelected && isSeasonDone)
                              ? Border.all(
                                  color: accentColor.withValues(alpha: 0.55),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Text(
                          isSeasonDone ? '✓ S$sNum' : 'S$sNum',
                          style: t.caption.copyWith(
                            fontWeight: (isSelected || isSeasonDone)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? c.onAccent
                                : (isSeasonDone
                                    ? accentColor
                                    : c.secondaryLabel),
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
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: c.tertiaryBackground,
                    borderRadius: MoglogShapes.control,
                  ),
                  child: Row(
                    children: [
                      Icon(MoglogIcons.bell, size: 16, color: accentColor),
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
