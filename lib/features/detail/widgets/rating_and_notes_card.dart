import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../domain/model/drama_extra_details.dart';

class RatingAndNotesCard extends StatefulWidget {
  final String dramaTitle;
  final double myRating;
  final TextEditingController notesController;
  final TextEditingController tagsController;
  final List<DramaReview> reviews;
  final Color accentColor;
  final ValueChanged<double> onRatingChanged;
  final VoidCallback onNotesOrTagsChanged;

  const RatingAndNotesCard({
    super.key,
    required this.dramaTitle,
    required this.myRating,
    required this.notesController,
    required this.tagsController,
    required this.reviews,
    required this.accentColor,
    required this.onRatingChanged,
    required this.onNotesOrTagsChanged,
  });

  @override
  State<RatingAndNotesCard> createState() => _RatingAndNotesCardState();
}

class _RatingAndNotesCardState extends State<RatingAndNotesCard> {
  final Set<String> _expandedReviewIds = {};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // My Rating Slider Card
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Rating', style: t.headline.copyWith(color: c.label)),
                  Row(
                    children: [
                      Icon(MoglogIcons.starFilled, size: 16, color: c.starGold),
                      const SizedBox(width: 4),
                      Text(
                        widget.myRating > 0
                            ? '${widget.myRating.toStringAsFixed(1)} / 10'
                            : 'Not rated',
                        style: t.subhead.copyWith(
                          color: widget.myRating > 0 ? c.label : c.secondaryLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: widget.accentColor,
                  inactiveTrackColor: c.tertiaryBackground,
                  thumbColor: widget.accentColor,
                  overlayColor: widget.accentColor.withValues(alpha: 0.18),
                ),
                child: Slider(
                  value: widget.myRating.clamp(0.0, 10.0),
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  onChanged: (v) {
                    final rounded = (v * 2).round() / 2.0;
                    widget.onRatingChanged(rounded);
                  },
                ),
              ),
              Divider(
                height: c.hairlineWidth,
                thickness: c.hairlineWidth,
                color: c.separator,
              ),
              const SizedBox(height: 12),
              Text(
                'Personal Notes & Tags',
                style: t.headline.copyWith(color: c.label, fontSize: 15.5),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.tertiaryBackground,
                  borderRadius: MoglogShapes.control,
                ),
                child: TextField(
                  controller: widget.notesController,
                  onChanged: (_) => widget.onNotesOrTagsChanged(),
                  maxLines: 4,
                  minLines: 2,
                  style: t.subhead.copyWith(color: c.label),
                  cursorColor: widget.accentColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Write episode thoughts, quotes, or reminders…',
                    hintStyle: t.footnote.copyWith(color: c.tertiaryLabel),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: c.tertiaryBackground,
                  borderRadius: MoglogShapes.control,
                ),
                child: TextField(
                  controller: widget.tagsController,
                  onChanged: (_) => widget.onNotesOrTagsChanged(),
                  style: t.footnote.copyWith(color: c.label),
                  cursorColor: widget.accentColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Tags / Shelves (comma separated, e.g. sci-fi, comfort)',
                    hintStyle: t.footnote.copyWith(color: c.tertiaryLabel),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // TMDB Audience Reviews + Google Reviews Shortcut
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audience Reviews',
                    style: t.headline.copyWith(color: c.label),
                  ),
                  IosPressable(
                    onTap: () {
                      final q = Uri.encodeComponent('${widget.dramaTitle} tv show reviews');
                      launchUrl(
                        Uri.parse('https://www.google.com/search?q=$q'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Google Reviews',
                          style: t.caption.copyWith(
                            color: widget.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          MoglogIcons.externalLink,
                          size: 13,
                          color: widget.accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.reviews.isEmpty)
                Text(
                  'No TMDB audience reviews available yet. Tap Google Reviews to browse critic and viewer discussions.',
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < widget.reviews.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _ReviewTile(
                        review: widget.reviews[i],
                        expanded: _expandedReviewIds.contains(widget.reviews[i].id),
                        accentColor: widget.accentColor,
                        onToggle: () {
                          setState(() {
                            final id = widget.reviews[i].id;
                            if (_expandedReviewIds.contains(id)) {
                              _expandedReviewIds.remove(id);
                            } else {
                              _expandedReviewIds.add(id);
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final DramaReview review;
  final bool expanded;
  final Color accentColor;
  final VoidCallback onToggle;

  const _ReviewTile({
    required this.review,
    required this.expanded,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final isLong = review.content.length > 220;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.tertiaryBackground,
        borderRadius: MoglogShapes.control,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: c.secondaryBackground,
                backgroundImage: (review.avatarUrl ?? '').isNotEmpty
                    ? NetworkImage(review.avatarUrl!)
                    : null,
                child: (review.avatarUrl ?? '').isEmpty
                    ? Text(
                        review.author.isNotEmpty
                            ? review.author[0].toUpperCase()
                            : 'A',
                        style: t.caption2.copyWith(color: c.label),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.footnote.copyWith(
                    color: c.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (review.rating != null && review.rating! > 0) ...[
                Icon(MoglogIcons.starFilled, size: 12, color: c.starGold),
                const SizedBox(width: 3),
                Text(
                  review.rating!.toStringAsFixed(1),
                  style: t.caption2.copyWith(
                    color: c.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.content,
            maxLines: expanded ? null : 4,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: t.footnote.copyWith(color: c.secondaryLabel, height: 1.4),
          ),
          if (isLong) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onToggle,
              child: Text(
                expanded ? 'Show less' : 'Read more',
                style: t.caption.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
