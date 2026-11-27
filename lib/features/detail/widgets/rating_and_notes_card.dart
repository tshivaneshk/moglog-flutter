import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/network/image_cache_manager.dart';
import '../../../domain/model/drama_extra_details.dart';
import '../../../domain/model/show_comment.dart';

/// Personal Rating slider (0-10 in 0.5 increments), community comment section
/// with encrypted-in-transit Write / Edit / Delete Review, and TMDB/Google reviews.
class RatingAndNotesCard extends StatefulWidget {
  final int dramaId;
  final String dramaTitle;
  final double myRating;
  final List<DramaReview> reviews;
  final List<ShowComment> communityComments;
  final String? currentUserUid;
  final bool isSignedIn;
  final Color accentColor;
  final ValueChanged<double> onRatingChanged;
  final Future<void> Function(String content, double rating)? onSubmitComment;
  final Future<void> Function()? onDeleteComment;
  final VoidCallback? onRequestSignIn;
  final ValueChanged<String>? onNotify;

  const RatingAndNotesCard({
    super.key,
    required this.dramaId,
    required this.dramaTitle,
    required this.myRating,
    required this.reviews,
    this.communityComments = const [],
    this.currentUserUid,
    this.isSignedIn = false,
    required this.accentColor,
    required this.onRatingChanged,
    this.onSubmitComment,
    this.onDeleteComment,
    this.onRequestSignIn,
    this.onNotify,
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

  void _openTmdbReviews() {
    MoglogHaptics.selectionChanged();
    final url = widget.dramaId > 0
        ? 'https://www.themoviedb.org/tv/${widget.dramaId}/reviews'
        : 'https://www.themoviedb.org/';
    launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  ShowComment? get _myComment {
    final uid = widget.currentUserUid;
    if (uid == null || uid.isEmpty) return null;
    for (final comment in widget.communityComments) {
      if (comment.uid == uid) return comment;
    }
    return null;
  }

  void _openReviewComposer({ShowComment? existing}) {
    if (!widget.isSignedIn) {
      showIosActionSheet(
        context: context,
        title: 'Sign In Required',
        message:
            'Sign in with Google to post, edit, or delete your review securely in the show\'s comment section.',
        actions: [
          if (widget.onRequestSignIn != null)
            ActionSheetItem(
              label: 'Sign In with Google',
              icon: MoglogIcons.person,
              onTap: widget.onRequestSignIn!,
            ),
        ],
      );
      return;
    }

    final ctrl = TextEditingController(text: existing?.content ?? '');
    var draftRating = (existing != null && existing.rating > 0)
        ? existing.rating
        : widget.myRating;
    var submitting = false;
    String? errorMsg;

    showIosBottomSheet<void>(
      context: context,
      disposeAfter: [ctrl],
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          final readableAccent = (!c.isDark &&
                  HSLColor.fromColor(widget.accentColor).lightness > 0.36)
              ? HSLColor.fromColor(widget.accentColor)
                  .withLightness(0.32)
                  .toColor()
              : widget.accentColor;

          return SingleChildScrollView(
            padding: MoglogSpacing.sheetPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing != null ? 'Edit Your Review' : 'Write a Review',
                  style: t.title2.copyWith(color: c.label),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.dramaTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rating (Optional)',
                      style: t.subhead.copyWith(
                        color: c.label,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      draftRating > 0
                          ? '${draftRating.toStringAsFixed(1)} / 10'
                          : 'No score',
                      style: t.subhead.copyWith(
                        color: draftRating > 0
                            ? readableAccent
                            : c.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    activeTrackColor: widget.accentColor,
                    inactiveTrackColor: c.tertiaryBackground,
                    thumbColor: c.onMedia,
                    overlayColor: widget.accentColor.withValues(alpha: 0.18),
                  ),
                  child: Slider(
                    value: draftRating.clamp(0.0, 10.0),
                    min: 0.0,
                    max: 10.0,
                    divisions: 20,
                    onChanged: (v) {
                      final rounded = (v * 2).round() / 2.0;
                      if (rounded != draftRating) {
                        MoglogHaptics.selectionChanged();
                        setSheetState(() => draftRating = rounded);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: ShapeDecoration(
                    color: c.tertiaryBackground,
                    shape: MoglogShapes.smooth(
                      MoglogShapes.cardRadius,
                      side: BorderSide(
                        color: errorMsg != null ? c.destructive : c.glassBorder,
                        width: errorMsg != null ? 1.2 : c.hairlineWidth,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: ctrl,
                    maxLines: 6,
                    minLines: 4,
                    maxLength: 2000,
                    autofocus: true,
                    cursorColor: widget.accentColor,
                    style: t.subhead.copyWith(color: c.label, height: 1.4),
                    onChanged: (_) {
                      if (errorMsg != null) {
                        setSheetState(() => errorMsg = null);
                      }
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          'Share your thoughts on "${widget.dramaTitle}"…',
                      hintStyle: t.subhead.copyWith(color: c.tertiaryLabel),
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: t.footnote.copyWith(color: c.destructive),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(MoglogIcons.lock, size: 13, color: c.secondaryLabel),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Encrypted in transit via TLS & authenticated by Firebase Auth.',
                        style: t.caption2.copyWith(color: c.secondaryLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                IosPrimaryButton(
                  text: existing != null ? 'Save Changes' : 'Post Review',
                  loading: submitting,
                  backgroundColor: widget.accentColor,
                  onTap: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) {
                      setSheetState(
                        () => errorMsg = 'Please enter your review before posting.',
                      );
                      return;
                    }
                    setSheetState(() {
                      submitting = true;
                      errorMsg = null;
                    });
                    try {
                      await widget.onSubmitComment?.call(text, draftRating);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      setSheetState(() {
                        submitting = false;
                        errorMsg = e
                            .toString()
                            .replaceFirst('Bad state: ', '')
                            .replaceFirst('Invalid argument(s): ', '');
                      });
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCommentActions(ShowComment comment, bool isMine) {
    showIosActionSheet(
      context: context,
      title: isMine ? 'Your Review' : 'Review by ${comment.author}',
      actions: [
        if (isMine)
          ActionSheetItem(
            label: 'Edit Review',
            icon: MoglogIcons.note,
            onTap: () => _openReviewComposer(existing: comment),
          ),
        ActionSheetItem(
          label: 'Copy Review Text',
          icon: MoglogIcons.copy,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: comment.content));
            widget.onNotify?.call('Copied review to clipboard');
          },
        ),
        ActionSheetItem(
          label: 'Share Review',
          icon: MoglogIcons.share,
          onTap: () {
            final scorePart = comment.rating > 0
                ? ' (${comment.rating.toStringAsFixed(1)}/10)'
                : '';
            SharePlus.instance.share(
              ShareParams(
                text:
                    '${widget.dramaTitle}$scorePart — "${comment.content}" (${comment.author} on Moglog)',
              ),
            );
          },
        ),
        if (isMine && widget.onDeleteComment != null)
          ActionSheetItem(
            label: 'Delete Review',
            icon: MoglogIcons.trash,
            isDestructive: true,
            onTap: () {
              showIosActionSheet(
                context: context,
                title: 'Delete Your Review?',
                message:
                    'Your review will be permanently removed from "${widget.dramaTitle}".',
                actions: [
                  ActionSheetItem(
                    label: 'Delete Forever',
                    icon: MoglogIcons.trash,
                    isDestructive: true,
                    onTap: () async {
                      await widget.onDeleteComment?.call();
                    },
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final readableAccent = (!c.isDark &&
            HSLColor.fromColor(widget.accentColor).lightness > 0.36)
        ? HSLColor.fromColor(widget.accentColor).withLightness(0.32).toColor()
        : widget.accentColor;
    final myComment = _myComment;
    final hasAnyReviews =
        widget.communityComments.isNotEmpty || widget.reviews.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Personal Rating Card (clean slider only)
        IosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MoglogIcons.starFilled, size: 18, color: c.starGold),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'My Rating',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.headline.copyWith(color: c.label),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.myRating > 0
                            ? '${widget.myRating.toStringAsFixed(1)} / 10'
                            : 'Not rated',
                        style: t.callout.copyWith(
                          color: widget.myRating > 0
                              ? readableAccent
                              : c.secondaryLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.myRating > 0) ...[
                        const SizedBox(width: 8),
                        IosPressable(
                          semanticLabel: 'Clear rating',
                          onTap: () {
                            MoglogHaptics.tickMinus();
                            widget.onRatingChanged(0.0);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              'Clear',
                              style: t.caption.copyWith(
                                color: c.secondaryLabel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                  thumbColor: c.onMedia,
                  overlayColor: widget.accentColor.withValues(alpha: 0.18),
                ),
                child: Slider(
                  value: widget.myRating.clamp(0.0, 10.0),
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  label: widget.myRating.toStringAsFixed(1),
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

        // 2. Audience & Community Reviews Card
        IosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        MoglogIcons.starOutline,
                        size: 18,
                        color: readableAccent,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Audience Reviews',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.headline.copyWith(color: c.label),
                        ),
                      ),
                    ],
                  ),
                  IosPressable(
                    onTap: _openGoogleReviews,
                    hapticOnTap: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: widget.accentColor.withValues(alpha: 0.14),
                        shape: MoglogShapes.smooth(9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MoglogIcons.externalLink,
                            size: 12,
                            color: readableAccent,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Google Reviews',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.copyWith(
                                color: readableAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!hasAnyReviews)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No community reviews yet · Be the first to write one below or tap Google Reviews.',
                    style: t.footnote.copyWith(color: c.secondaryLabel),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < widget.communityComments.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      Builder(
                        builder: (_) {
                          final comment = widget.communityComments[i];
                          final isMine = widget.currentUserUid != null &&
                              comment.uid == widget.currentUserUid;
                          final tileId = 'comment_${comment.id}';
                          return _ReviewTile(
                            review: DramaReview(
                              id: tileId,
                              author: comment.author,
                              content: comment.content,
                              rating: comment.rating > 0 ? comment.rating : null,
                              avatarUrl: comment.avatarUrl,
                            ),
                            isMine: isMine,
                            expanded: _expandedReviewIds.contains(tileId),
                            accentColor: readableAccent,
                            onToggle: () {
                              setState(() {
                                if (_expandedReviewIds.contains(tileId)) {
                                  _expandedReviewIds.remove(tileId);
                                } else {
                                  _expandedReviewIds.add(tileId);
                                }
                              });
                            },
                            onActionsTap: () =>
                                _showCommentActions(comment, isMine),
                          );
                        },
                      ),
                    ],
                    if (widget.communityComments.isNotEmpty &&
                        widget.reviews.isNotEmpty)
                      const SizedBox(height: 12),
                    for (var i = 0; i < widget.reviews.take(5).length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _ReviewTile(
                        review: widget.reviews[i],
                        expanded:
                            _expandedReviewIds.contains(widget.reviews[i].id),
                        accentColor: readableAccent,
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
                    if (widget.reviews.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      IosSecondaryButton(
                        text: 'Open in TMDB',
                        leadingIcon: MoglogIcons.externalLink,
                        size: MoglogButtonSize.medium,
                        textColor: readableAccent,
                        onTap: _openTmdbReviews,
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 12),
              IosPrimaryButton(
                text: myComment != null ? 'Edit Your Review' : 'Write a Review',
                leadingIcon: MoglogIcons.note,
                size: MoglogButtonSize.medium,
                backgroundColor: widget.accentColor,
                onTap: () => _openReviewComposer(existing: myComment),
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
  final bool isMine;
  final bool expanded;
  final Color accentColor;
  final VoidCallback onToggle;
  final VoidCallback? onActionsTap;

  const _ReviewTile({
    required this.review,
    this.isMine = false,
    required this.expanded,
    required this.accentColor,
    required this.onToggle,
    this.onActionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final reduceMotion = context.reduceMotion;
    final contentStyle = t.footnote.copyWith(
      color: c.label.withValues(alpha: 0.92),
      height: 1.42,
    );

    return AnimatedSize(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: IosPressable(
        onLongPress: onActionsTap,
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: ShapeDecoration(
            color: c.tertiaryBackground,
            shape: MoglogShapes.smooth(
              14,
              side: BorderSide(
                color: isMine
                    ? accentColor.withValues(alpha: 0.45)
                    : c.glassBorder,
                width: isMine ? 1.0 : c.hairlineWidth,
              ),
            ),
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
                              ? CachedNetworkImageProvider(
                                  review.avatarUrl!,
                                  cacheManager:
                                      MoglogImageCacheManager.instance,
                                )
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
                        Flexible(
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
                        if (isMine) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: ShapeDecoration(
                              color: accentColor.withValues(alpha: 0.16),
                              shape: MoglogShapes.smooth(6),
                            ),
                            child: Text(
                              'You',
                              style: t.microBadge.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (review.rating != null && review.rating! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: ShapeDecoration(
                        color: c.starGold.withValues(alpha: 0.15),
                        shape: MoglogShapes.smooth(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MoglogIcons.starFilled,
                            size: 11,
                            color: c.starGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${review.rating!.toStringAsFixed(1)}/10',
                            style: t.caption.copyWith(
                              color: c.starGold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (onActionsTap != null) ...[
                    const SizedBox(width: 4),
                    IosCircleIconButton(
                      icon: MoglogIcons.moreHorizontal,
                      tooltip: 'Review actions',
                      size: 30,
                      iconSize: 15,
                      onTap: onActionsTap,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textDirection = Directionality.of(context);
                  final textScaler = MediaQuery.textScalerOf(context);
                  final tp = TextPainter(
                    text: TextSpan(text: review.content, style: contentStyle),
                    maxLines: 4,
                    textDirection: textDirection,
                    textScaler: textScaler,
                  )..layout(maxWidth: constraints.maxWidth);
                  final exceeds = tp.didExceedMaxLines;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.content,
                        maxLines: expanded ? null : 4,
                        overflow:
                            expanded ? TextOverflow.visible : TextOverflow.clip,
                        style: contentStyle,
                      ),
                      if (exceeds || expanded) ...[
                        const SizedBox(height: 6),
                        IosPressable(
                          onTap: onToggle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              expanded ? 'Show less' : 'View more',
                              style: t.caption.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
