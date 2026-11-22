import 'package:flutter/material.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../domain/model/drama.dart';

/// Compact list row with swipe-right (`+1 Ep`) and swipe-left (`Move to Recycle Bin`).
class CompactDramaRow extends StatelessWidget {
  final Drama drama;
  final bool isTopFour;
  final bool multiSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onIncrementEpisode;
  final VoidCallback onMoveToBin;

  const CompactDramaRow({
    super.key,
    required this.drama,
    required this.isTopFour,
    required this.multiSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onIncrementEpisode,
    required this.onMoveToBin,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final statusColor = c.statusColor(drama.status);
    final score = drama.effectiveRating;

    final card = IosPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: c.secondaryBackground,
          shape: MoglogShapes.smooth(
            MoglogShapes.cardRadius,
            side: BorderSide(
              color: isSelected ? c.accent : c.separator.withValues(alpha: 0.4),
              width: isSelected ? 1.8 : 0.6,
            ),
          ),
        ),
        child: Row(
          children: [
            if (multiSelectMode) ...[
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSelected ? c.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? c.accent : c.secondaryLabel,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? Icon(MoglogIcons.check, size: 13, color: c.onAccent)
                    : null,
              ),
            ],
            PosterImage(
              url: drama.posterPath,
              width: 48,
              height: 68,
              borderRadius: BorderRadius.circular(9),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          drama.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.headline.copyWith(
                            color: c.label,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      if (isTopFour)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            MoglogIcons.starFilled,
                            size: 13,
                            color: c.starGold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          drama.status,
                          style: t.caption2.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        drama.totalEpisodes > 0
                            ? 'Ep ${drama.episodesWatched}/${drama.totalEpisodes}'
                            : '${drama.episodesWatched} eps',
                        style: t.footnote.copyWith(color: c.secondaryLabel),
                      ),
                      if (score > 0) ...[
                        const SizedBox(width: 8),
                        Icon(MoglogIcons.starFilled, size: 12, color: c.starGold),
                        const SizedBox(width: 2),
                        Text(
                          score.toStringAsFixed(1),
                          style: t.footnote.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (drama.totalEpisodes > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: MoglogShapes.pill,
                      child: LinearProgressIndicator(
                        value: drama.progressFraction,
                        minHeight: 3.5,
                        backgroundColor: c.tertiaryBackground,
                        color: statusColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!multiSelectMode) ...[
              const SizedBox(width: 8),
              Icon(MoglogIcons.chevronRight, size: 17, color: c.tertiaryLabel),
            ],
          ],
        ),
      ),
    );

    if (multiSelectMode) return card;

    return Dismissible(
      key: ValueKey('compact_row_${drama.id}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          MoglogHaptics.success();
          onIncrementEpisode();
          return false; // Keep row visible after +1
        } else {
          MoglogHaptics.warning();
          onMoveToBin();
          return true;
        }
      },
      background: Container(
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: MoglogShapes.card,
        ),
        padding: const EdgeInsets.only(left: 18),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(MoglogIcons.plus, color: c.onAccent, size: 18),
            const SizedBox(width: 6),
            Text(
              '+1 Ep',
              style: t.subhead.copyWith(
                color: c.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: c.destructive,
          borderRadius: MoglogShapes.card,
        ),
        padding: const EdgeInsets.only(right: 18),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Recycle Bin',
              style: t.subhead.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(MoglogIcons.trash, color: Colors.white, size: 18),
          ],
        ),
      ),
      child: card,
    );
  }
}
