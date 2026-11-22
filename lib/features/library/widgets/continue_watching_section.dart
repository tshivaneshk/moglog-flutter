import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../domain/logic/library_filter.dart';
import '../../../domain/model/drama.dart';

/// Persistent "Up Next" horizontal rail matching Kotlin `ContinueWatchingSection.kt` 1:1.
class ContinueWatchingSection extends StatelessWidget {
  final List<Drama> watchingDramas;
  final ValueChanged<Drama> onDramaTap;
  final ValueChanged<Drama> onIncrementEpisode;

  const ContinueWatchingSection({
    super.key,
    required this.watchingDramas,
    required this.onDramaTap,
    required this.onIncrementEpisode,
  });

  @override
  Widget build(BuildContext context) {
    if (watchingDramas.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final t = context.typo;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenW - 36).clamp(220.0, 286.0);
    final items = watchingDramas.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(MoglogIcons.play, size: 15, color: c.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Continue Watching',
                    style: t.headline.copyWith(color: c.label),
                  ),
                ],
              ),
              Text(
                '${watchingDramas.length} ACTIVE',
                style: t.caption2.copyWith(
                  color: c.secondaryLabel,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final drama = items[index];
              final countdownBadge =
                  computeAiringCountdownLabel(drama.nextEpisodeAirDate);
              final seasonCode = max(1, drama.currentSeason);
              final nextEpCode = drama.episodesWatched + 1;
              final upNextTag =
                  'S${seasonCode.toString().padLeft(2, '0')}E${nextEpCode.toString().padLeft(2, '0')}';

              String? remainingText;
              if (drama.totalEpisodes > drama.episodesWatched &&
                  drama.totalEpisodes > 0) {
                final remMins = (drama.totalEpisodes - drama.episodesWatched) * 45;
                final hrs = remMins ~/ 60;
                final mins = remMins % 60;
                remainingText = hrs > 0 ? '~${hrs}h ${mins}m left' : '~${mins}m left';
              }

              final progressSub = drama.totalEpisodes > 0
                  ? 'Ep ${drama.episodesWatched}/${drama.totalEpisodes}${remainingText != null ? " · $remainingText" : ""}'
                  : 'Watched ${drama.episodesWatched} eps';

              final fraction = drama.totalEpisodes > 0
                  ? drama.progressFraction
                  : max(0.1, (drama.episodesWatched % 12) / 12.0);

              return IosPressable(
                onTap: () => onDramaTap(drama),
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(11),
                  decoration: ShapeDecoration(
                    color: c.secondaryBackground,
                    shape: MoglogShapes.smooth(
                      MoglogShapes.cardRadius,
                      side: BorderSide(
                        color: c.separator.withValues(alpha: 0.45),
                        width: 0.75,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      PosterImage(
                        url: drama.posterPath,
                        width: 50,
                        height: 74,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'UP NEXT · $upNextTag',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.caption2.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: c.accent,
                                      ),
                                    ),
                                  ),
                                ),
                                if (countdownBadge != null) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.starGold.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      countdownBadge,
                                      maxLines: 1,
                                      style: t.caption2.copyWith(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: c.starGold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              drama.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.subhead.copyWith(
                                color: c.label,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              progressSub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption2.copyWith(color: c.secondaryLabel),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: MoglogShapes.pill,
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 4,
                                backgroundColor: c.tertiaryBackground,
                                color: c.statusWatching,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IosPressable(
                        onTap: () {
                          MoglogHaptics.success();
                          onIncrementEpisode(drama);
                        },
                        pressedScale: 0.92,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 9,
                          ),
                          decoration: ShapeDecoration(
                            color: c.accent,
                            shape: MoglogShapes.smooth(11),
                          ),
                          child: Text(
                            '+1',
                            style: t.footnote.copyWith(
                              color: c.onAccent,
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
    );
  }
}
