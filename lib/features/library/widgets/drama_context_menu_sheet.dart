import 'package:flutter/material.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../domain/model/drama.dart';

Future<void> showDramaContextMenuSheet({
  required BuildContext context,
  required Drama drama,
  required ValueChanged<String> onChangeStatus,
  required ValueChanged<double> onQuickRate,
  required VoidCallback onIncrementEpisode,
  required VoidCallback onShare,
  required VoidCallback onEnterMultiSelect,
  required VoidCallback onMoveToBin,
}) {
  return showIosBottomSheet<void>(
    context: context,
    builder: (ctx) => _DramaContextMenuContent(
      drama: drama,
      onChangeStatus: onChangeStatus,
      onQuickRate: onQuickRate,
      onIncrementEpisode: onIncrementEpisode,
      onShare: onShare,
      onEnterMultiSelect: onEnterMultiSelect,
      onMoveToBin: onMoveToBin,
    ),
  );
}

class _DramaContextMenuContent extends StatefulWidget {
  final Drama drama;
  final ValueChanged<String> onChangeStatus;
  final ValueChanged<double> onQuickRate;
  final VoidCallback onIncrementEpisode;
  final VoidCallback onShare;
  final VoidCallback onEnterMultiSelect;
  final VoidCallback onMoveToBin;

  const _DramaContextMenuContent({
    required this.drama,
    required this.onChangeStatus,
    required this.onQuickRate,
    required this.onIncrementEpisode,
    required this.onShare,
    required this.onEnterMultiSelect,
    required this.onMoveToBin,
  });

  @override
  State<_DramaContextMenuContent> createState() =>
      _DramaContextMenuContentState();
}

class _DramaContextMenuContentState extends State<_DramaContextMenuContent> {
  static const _statuses = ['Watching', 'Planned', 'Done'];
  late String _status;
  late double _rating;

  @override
  void initState() {
    super.initState();
    _status = widget.drama.status;
    _rating = widget.drama.myRating;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Preview
          Row(
            children: [
              PosterImage(
                url: widget.drama.posterPath,
                width: 50,
                height: 70,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.headline.copyWith(color: c.label),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.drama.totalEpisodes > 0
                          ? 'Ep ${widget.drama.episodesWatched}/${widget.drama.totalEpisodes} · $_status'
                          : '${widget.drama.episodesWatched} eps · $_status',
                      style: t.footnote.copyWith(color: c.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Inline status segmented control
          IosSegmentedControl(
            labels: _statuses,
            selectedIndex: _statuses.indexOf(_status).clamp(0, 2),
            onSelected: (idx) {
              setState(() => _status = _statuses[idx]);
              widget.onChangeStatus(_statuses[idx]);
            },
          ),
          const SizedBox(height: 14),

          // 5-Star Quick Rating (2.0..10.0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: ShapeDecoration(
              color: c.tertiaryBackground,
              shape: MoglogShapes.smooth(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Rate',
                  style: t.subhead.copyWith(
                    color: c.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: List.generate(5, (idx) {
                    final starScore = (idx + 1) * 2.0;
                    final filled = _rating >= starScore;
                    return IosPressable(
                      onTap: () {
                        MoglogHaptics.selectionChanged();
                        setState(() => _rating = starScore);
                        widget.onQuickRate(starScore);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          filled ? MoglogIcons.starFilled : MoglogIcons.starOutline,
                          size: 22,
                          color: filled ? c.starGold : c.secondaryLabel,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          IosGroupedSection(
            children: [
              IosGroupedRow(
                title: 'Watch Next Episode (+1)',
                icon: MoglogIcons.plus,
                iconBackground: c.accent,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onIncrementEpisode();
                },
              ),
              IosGroupedRow(
                title: 'Share Show',
                icon: MoglogIcons.share,
                iconBackground: c.statusPlanned,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onShare();
                },
              ),
              IosGroupedRow(
                title: 'Select Shows',
                icon: MoglogIcons.checkSquare,
                iconBackground: c.statusWatching,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onEnterMultiSelect();
                },
              ),
              IosGroupedRow(
                title: 'Move to Recycle Bin',
                titleColor: c.destructive,
                icon: MoglogIcons.trash,
                iconBackground: c.destructive,
                showDivider: false,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onMoveToBin();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
