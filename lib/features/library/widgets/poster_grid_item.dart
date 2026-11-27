import 'package:flutter/material.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../domain/model/drama.dart';

class PosterGridItem extends StatelessWidget {
  final Drama drama;
  final bool isTopFour;
  final bool multiSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PosterGridItem({
    super.key,
    required this.drama,
    required this.isTopFour,
    required this.multiSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final statusColor = c.statusColor(drama.status);
    final score = drama.effectiveRating;
    final posterShape = MoglogShapes.smooth(MoglogShapes.posterRadius);

    return IosPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.96,
      semanticLabel: '${drama.title}, ${drama.status}',
      semanticSelected: multiSelectMode ? isSelected : null,
      focusRadius: MoglogShapes.posterRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: MoglogShapes.smooth(
                  MoglogShapes.posterRadius,
                  side: isSelected
                      ? BorderSide(color: c.accent, width: 2.2)
                      : BorderSide.none,
                ),
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: posterShape),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(
                      url: drama.posterPath,
                      borderRadius: MoglogShapes.poster,
                    ),
                    // Soft bottom gradient scrim for episode progress legibility
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 54,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                c.mediaScrim.withValues(alpha: 0.0),
                                c.mediaScrim,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Top-left status dot pill
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.mediaScrim,
                          borderRadius: MoglogShapes.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (isTopFour) ...[
                              const SizedBox(width: 4),
                              Icon(
                                MoglogIcons.starFilled,
                                size: 10,
                                color: c.starGold,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Top-right rating or selection checkmark
                    Positioned(
                      top: 6,
                      right: 6,
                      child: multiSelectMode
                          ? Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isSelected ? c.accent : c.mediaScrim,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? c.accent
                                      : c.onMediaSecondary,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: isSelected
                                  ? Icon(
                                      MoglogIcons.check,
                                      size: 13,
                                      color: c.onAccent,
                                    )
                                  : null,
                            )
                          : score > 0
                              ? Container(
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
                                        score.toStringAsFixed(1),
                                        style: t.microBadge.copyWith(
                                          color: c.onMedia,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),
                    // Bottom episode label & thin progress bar
                    Positioned(
                      left: 7,
                      right: 7,
                      bottom: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (drama.episodesWatched > 0 ||
                              drama.totalEpisodes > 0)
                            Text(
                              drama.totalEpisodes > 0
                                  ? '${drama.episodesWatched}/${drama.totalEpisodes} ep'
                                  : '${drama.episodesWatched} ep',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.microBadge.copyWith(
                                color: c.onMedia,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (drama.totalEpisodes > 0 &&
                              drama.episodesWatched > 0) ...[
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: MoglogShapes.pill,
                              child: LinearProgressIndicator(
                                value: drama.progressFraction,
                                minHeight: 3,
                                backgroundColor:
                                    c.onMedia.withValues(alpha: 0.24),
                                color: statusColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
        ],
      ),
    );
  }
}
