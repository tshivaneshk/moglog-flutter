import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../core/design_system/tokens.dart';
import '../../../domain/logic/library_filter.dart';
import '../../../domain/model/drama.dart';

/// Persistent "Continue Watching" horizontal rail with squircle-20 cards and
/// a prominent one-tap glossy `+1` episode button.
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
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cardWidth = (screenW - 36).clamp(236.0, 304.0);
    final railHeight =
        112.0 + ((textScale - 1.0).clamp(0.0, 1.0) * 62.0);
    final items = watchingDramas.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MoglogSpacing.md,
            vertical: 6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(MoglogIcons.play, size: 16, color: c.accentText),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Continue Watching',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.headline.copyWith(color: c.label),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${watchingDramas.length} ACTIVE',
                style: t.caption2.copyWith(
                  color: c.secondaryLabel,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MoglogSpacing.md),
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
                final remMins =
                    (drama.totalEpisodes - drama.episodesWatched) * 45;
                final hrs = remMins ~/ 60;
                final mins = remMins % 60;
                remainingText =
                    hrs > 0 ? '~${hrs}h ${mins}m left' : '~${mins}m left';
              }

              final progressSub = drama.totalEpisodes > 0
                  ? 'Ep ${drama.episodesWatched}/${drama.totalEpisodes}${remainingText != null ? " · $remainingText" : ""}'
                  : 'Watched ${drama.episodesWatched} eps';

              final fraction = drama.totalEpisodes > 0
                  ? drama.progressFraction
                  : max(0.1, (drama.episodesWatched % 12) / 12.0);

              return SizedBox(
                width: cardWidth,
                child: IosCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => onDramaTap(drama),
                  child: Row(
                    children: [
                      PosterImage(
                        url: drama.posterPath,
                        width: 54,
                        height: 80,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(11)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 5,
                              runSpacing: 3,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: c.accentSubtle,
                                    shape: MoglogShapes.smooth(6),
                                  ),
                                  child: Text(
                                    upNextTag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.microBadge.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: c.accentText,
                                    ),
                                  ),
                                ),
                                if (countdownBadge != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: ShapeDecoration(
                                      color: c.starGold.withValues(alpha: 0.16),
                                      shape: MoglogShapes.smooth(6),
                                    ),
                                    child: Text(
                                      countdownBadge,
                                      maxLines: 1,
                                      style: t.microBadge.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: c.starGold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
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
                              style: t.caption2.copyWith(
                                color: c.secondaryLabel,
                              ),
                            ),
                            const SizedBox(height: 7),
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
                      _OneTapGlossIncrementButton(
                        dramaTitle: drama.title,
                        onTap: () {
                          MoglogHaptics.success();
                          onIncrementEpisode(drama);
                        },
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

class _OneTapGlossIncrementButton extends StatefulWidget {
  final String dramaTitle;
  final VoidCallback onTap;

  const _OneTapGlossIncrementButton({
    required this.dramaTitle,
    required this.onTap,
  });

  @override
  State<_OneTapGlossIncrementButton> createState() =>
      _OneTapGlossIncrementButtonState();
}

class _OneTapGlossIncrementButtonState
    extends State<_OneTapGlossIncrementButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return IosPressable(
      onTap: widget.onTap,
      hapticOnTap: false,
      pressedScale: 0.93,
      semanticLabel: 'Watch next episode of ${widget.dramaTitle}',
      focusRadius: 14,
      onHighlightChanged: (v) {
        if (_pressed != v) setState(() => _pressed = v);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: MoglogLayout.minTouchTarget,
          minHeight: MoglogLayout.minTouchTarget,
        ),
        child: Center(
          child: GlossSurface(
            baseColor: c.accent,
            cornerRadius: 13,
            pressed: _pressed,
            minHeight: 38,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(MoglogIcons.plus, size: 13, color: c.onAccent),
                const SizedBox(width: 2),
                Text(
                  '+1',
                  style: t.footnote.copyWith(
                    color: c.onAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
