import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../domain/model/drama_extra_details.dart';

/// Native Personal Rating (0-10 in 0.5 increments) and Audience / Google Reviews card.
/// Matches Kotlin `RatingAndNotesCard` 1:1 (no personal notes or personal tags UI).
class RatingAndNotesCard extends StatefulWidget {
  final String dramaTitle;
  final double myRating;
  final List<DramaReview> reviews;
  final Color accentColor;
  final ValueChanged<double> onRatingChanged;

  const RatingAndNotesCard({
    super.key,
    required this.dramaTitle,
    required this.myRating,
    required this.reviews,
    required this.accentColor,
    required this.onRatingChanged,
  });

  @override
  State<RatingAndNotesCard> createState() => _RatingAndNotesCardState();
}

class _RatingAndNotesCardState extends State<RatingAndNotesCard> {
  final Set<String> _expandedReviewIds = {};

  void _openGoogleReviews() {
    MoglogHaptics.selectionChanged();
    final q = Uri.encodeComponent(
      '${widget.dramaTitle.trim().isEmpty ? "TV show" : widget.dramaTitle} audience reviews ratings',
    );
    launchUrl(
      Uri.parse('https://www.google.com/search?q=$q'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Personal Rating Card
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
                  Row(
                    children: [
                      Icon(MoglogIcons.starFilled, size: 18, color: c.starGold),
                      const SizedBox(width: 8),
                      Text('My Rating', style: t.headline.copyWith(color: c.label)),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        widget.myRating > 0
                            ? '${widget.myRating.toStringAsFixed(1)} / 10'
                            : 'Not rated',
                        style: t.callout.copyWith(
                          color: widget.myRating > 0
                              ? widget.accentColor
                              : c.secondaryLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.myRating > 0) ...[
                        const SizedBox(width: 8),
                        IosPressable(
                          onTap: () {
                            MoglogHaptics.tickMinus();
                            widget.onRatingChanged(0.0);
                          },
                          child: Text(
                            'Clear',
                            style: t.caption.copyWith(color: c.secondaryLabel),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: widget.accentColor,
                  inactiveTrackColor: c.tertiaryBackground,
                  thumbColor: Colors.white,
                  overlayColor: widget.accentColor.withValues(alpha: 0.18),
                ),
                child: Slider(
                  value: widget.myRating.clamp(0.0, 10.0),
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  onChanged: (v) {
                    final rounded = (v * 2).round() / 2.0;
                    if (rounded != widget.myRating) {
                      MoglogHaptics.selectionChanged();
                      widget.onRatingChanged(rounded);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Audience & Google Reviews Card
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
                  Row(
                    children: [
                      Icon(
                        MoglogIcons.starOutline,
                        size: 18,
                        color: widget.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Audience Reviews',
                        style: t.headline.copyWith(color: c.label),
                      ),
                    ],
                  ),
                  IosPressable(
                    onTap: _openGoogleReviews,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MoglogIcons.externalLink,
                            size: 12,
                            color: widget.accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Google Reviews',
                            style: t.caption.copyWith(
                              color: widget.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.reviews.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.tertiaryBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'No community reviews found on TMDB yet.',
                        style: t.subhead.copyWith(color: c.secondaryLabel),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check Google Reviews to read viewer opinions & critic ratings.',
                        style: t.footnote.copyWith(color: c.tertiaryLabel),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      IosPressable(
                        onTap: _openGoogleReviews,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                MoglogIcons.search,
                                size: 14,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Search Google Reviews',
                                style: t.callout.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < widget.reviews.take(5).length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
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
    final isLong = review.content.length > 200;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.tertiaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: accentColor.withValues(alpha: 0.2),
                        backgroundImage: (review.avatarUrl ?? '').isNotEmpty
                            ? NetworkImage(review.avatarUrl!)
                            : null,
                        child: (review.avatarUrl ?? '').isEmpty
                            ? Text(
                                review.author.isNotEmpty
                                    ? review.author[0].toUpperCase()
                                    : 'A',
                                style: t.subhead.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          review.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.subhead.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (review.rating != null && review.rating! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.starGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MoglogIcons.starFilled, size: 11, color: c.starGold),
                        const SizedBox(width: 3),
                        Text(
                          '${review.rating!.toStringAsFixed(0)}/10',
                          style: t.caption.copyWith(
                            color: c.starGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.content,
              maxLines: expanded ? null : 4,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: t.footnote.copyWith(
                color: c.label.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            if (isLong) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IosPressable(
                    onTap: onToggle,
                    child: Text(
                      expanded ? 'Show less' : 'Read more',
                      style: t.caption.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if ((review.url ?? '').isNotEmpty)
                    IosPressable(
                      onTap: () => launchUrl(
                        Uri.parse(review.url!),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TMDB',
                            style: t.caption.copyWith(color: c.secondaryLabel),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            MoglogIcons.externalLink,
                            size: 10,
                            color: c.secondaryLabel,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
