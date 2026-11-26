import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/network/image_cache_manager.dart';
import '../../domain/logic/season_progress.dart';
import '../../domain/model/drama.dart';
import '../../domain/model/drama_extra_details.dart';
import 'widgets/progress_stepper_card.dart';
import 'widgets/rating_and_notes_card.dart';
import 'widgets/watch_providers_section.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final int dramaId;
  final VoidCallback onBack;
  final ValueChanged<int> onOpenRecommendation;

  const DetailScreen({
    super.key,
    required this.dramaId,
    required this.onBack,
    required this.onOpenRecommendation,
  });

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  final ScrollController _scrollController = ScrollController();

  Drama? _drama;
  DramaExtraDetails? _extra;
  bool _loading = true;
  bool _isSaved = false;
  bool _synopsisExpanded = false;
  Color? _dynamicAccent;
  Timer? _autosaveDebounce;

  static const _statuses = ['Watching', 'Planned', 'Done'];
  static final Map<String, Color> _posterTintCache = {};

  @override
  void initState() {
    super.initState();
    final ctrl = ref.read(dramaControllerProvider);
    final local = ref.read(dramaRepositoryProvider).getLocalDramaById(widget.dramaId);
    final immediate = local ?? ctrl.getImmediateDramaById(widget.dramaId);
    final immediateExtra = ctrl.getImmediateExtraDetails(widget.dramaId);
    if (immediateExtra != null) {
      _extra = immediateExtra;
      _prewarmDetailMedia(immediateExtra);
    }
    if (immediate != null) {
      _drama = immediate;
      _isSaved = local != null && !local.isDeleted;
      _loading = false;
      final cachedTint = _posterTintCache[immediate.posterPath];
      if (cachedTint != null &&
          ref.read(currentSettingsProvider).dynamicPosterTint) {
        _dynamicAccent = cachedTint;
      } else if (ref.read(currentSettingsProvider).dynamicPosterTint) {
        unawaited(_extractPosterAccent(immediate.posterPath));
      }
    }
    _loadData();
  }

  void _prewarmDetailMedia(DramaExtraDetails extra) {
    final castUrls = extra.cast
        .take(10)
        .map((c) => c.profilePath ?? '')
        .where((u) => u.isNotEmpty);
    final recUrls = extra.recommendations
        .take(8)
        .map((r) => r.posterPath)
        .where((u) => u.isNotEmpty);
    if (castUrls.isNotEmpty) {
      unawaited(
        MoglogImageCacheManager.prewarmUrls(
          castUrls,
          targetWidthDp: 64,
          maxConcurrent: 6,
        ),
      );
    }
    if (recUrls.isNotEmpty) {
      unawaited(
        MoglogImageCacheManager.prewarmUrls(
          recUrls,
          targetWidthDp: 108,
          maxConcurrent: 6,
        ),
      );
    }
  }

  Future<void> _loadData() async {
    final ctrl = ref.read(dramaControllerProvider);
    final local = ref.read(dramaRepositoryProvider).getLocalDramaById(widget.dramaId);

    // If both drama summary and extra details are already hydrated from local cache, skip redundant fetch.
    if (_drama != null &&
        _extra != null &&
        _drama!.overview.isNotEmpty &&
        _drama!.posterPath.isNotEmpty) {
      return;
    }

    final bundle = await ctrl.fetchFullDrama(widget.dramaId);
    if (!mounted) return;

    final resolved = bundle.drama ?? _drama;
    final extra = bundle.extra ?? _extra;
    final posterChanged =
        resolved != null && _drama?.posterPath != resolved.posterPath;

    if (extra != null) {
      _prewarmDetailMedia(extra);
    }

    setState(() {
      _loading = false;
      if (resolved != null) {
        _drama = resolved;
        _isSaved = local != null && !local.isDeleted;
        final cachedTint = _posterTintCache[resolved.posterPath];
        if (cachedTint != null &&
            ref.read(currentSettingsProvider).dynamicPosterTint) {
          _dynamicAccent = cachedTint;
        }
      }
      _extra = extra;
      if (_drama != null && extra != null) {
        _drama = _drama!.copyWith(
          genres: _drama!.genres.isNotEmpty
              ? _drama!.genres
              : extra.genres.join(', '),
          releaseYear:
              _drama!.releaseYear > 0 ? _drama!.releaseYear : extra.releaseYear,
          totalSeasons:
              _drama!.totalSeasons > 0 ? _drama!.totalSeasons : extra.totalSeasons,
          totalEpisodes: _drama!.totalEpisodes > 0
              ? _drama!.totalEpisodes
              : extra.totalEpisodes,
          nextEpisodeAirDate:
              extra.nextEpisodeAirDate ?? _drama!.nextEpisodeAirDate,
          nextEpisodeNumber: extra.nextEpisodeNumber > 0
              ? extra.nextEpisodeNumber
              : _drama!.nextEpisodeNumber,
          nextSeasonNumber: extra.nextSeasonNumber > 0
              ? extra.nextSeasonNumber
              : _drama!.nextSeasonNumber,
        );
      }
    });

    if (resolved != null &&
        (posterChanged || _dynamicAccent == null) &&
        _posterTintCache[resolved.posterPath] == null &&
        ref.read(currentSettingsProvider).dynamicPosterTint) {
      unawaited(_extractPosterAccent(resolved.posterPath));
    }
  }

  /// Fast native image-codec tint extraction using w185 thumbnail via pooled cache.
  Future<void> _extractPosterAccent(String posterUrl) async {
    final trimmed = posterUrl.trim();
    if (trimmed.isEmpty) return;
    final cached = _posterTintCache[trimmed];
    if (cached != null) {
      if (mounted) setState(() => _dynamicAccent = cached);
      return;
    }

    final tintUrl = optimizeTmdbImageUrl(trimmed, targetWidthDp: 48, dpr: 2.0);
    final completer = Completer<ui.Image?>();
    final provider = ResizeImage(
      CachedNetworkImageProvider(
        tintUrl,
        cacheManager: MoglogImageCacheManager.instance,
      ),
      width: 24,
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(info.image.clone());
        }
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);

    try {
      final image = await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          stream.removeListener(listener);
          return null;
        },
      );
      if (image == null) return;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (byteData == null) return;

      final pixels = byteData.buffer.asUint8List();
      HSLColor? bestVibrant;
      double bestVibrantScore = -1;
      HSLColor? bestFallback;
      double bestFallbackScore = -1;

      for (var i = 0; i + 3 < pixels.length; i += 4) {
        final a = pixels[i + 3];
        if (a < 128) continue;
        final color = Color.fromARGB(255, pixels[i], pixels[i + 1], pixels[i + 2]);
        final hsl = HSLColor.fromColor(color);
        if (hsl.lightness >= 0.16 &&
            hsl.lightness <= 0.84 &&
            hsl.saturation >= 0.14) {
          final fbScore = hsl.saturation * (1.0 - (hsl.lightness - 0.5).abs() * 0.7);
          if (fbScore > bestFallbackScore) {
            bestFallbackScore = fbScore;
            bestFallback = hsl;
          }
        }
        if (hsl.saturation >= 0.28 &&
            hsl.lightness >= 0.20 &&
            hsl.lightness <= 0.78) {
          final vScore = hsl.saturation * (1.0 - (hsl.lightness - 0.5).abs());
          if (vScore > bestVibrantScore) {
            bestVibrantScore = vScore;
            bestVibrant = hsl;
          }
        }
      }

      final chosen = bestVibrant ?? bestFallback;
      if (chosen == null) return;
      final vibrant = chosen
          .withSaturation(chosen.saturation.clamp(0.42, 0.85))
          .withLightness(chosen.lightness.clamp(0.42, 0.58))
          .toColor();

      if (_posterTintCache.length > 96) {
        _posterTintCache.remove(_posterTintCache.keys.first);
      }
      _posterTintCache[trimmed] = vibrant;
      if (mounted) {
        setState(() => _dynamicAccent = vibrant);
      }
    } catch (_) {}
  }

  void _scheduleAutosave() {
    if (!_isSaved || _drama == null) return;
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 350), () {
      if (_drama != null && _isSaved) {
        ref.read(dramaControllerProvider).saveDrama(_drama!);
      }
    });
  }

  void _updateDrama(Drama next, {bool immediateSave = false}) {
    setState(() => _drama = next);
    if (_isSaved) {
      if (immediateSave) {
        ref.read(dramaControllerProvider).saveDrama(next);
      } else {
        _scheduleAutosave();
      }
    }
  }

  void _addToLibrary() {
    final d = _drama;
    if (d == null) return;
    final toSave = d.copyWith(
      isDeleted: false,
      deletedAt: 0,
    );
    ref.read(dramaControllerProvider).saveDrama(toSave);
    setState(() {
      _drama = toSave;
      _isSaved = true;
    });
    ref.read(toastProvider.notifier).show('Added "${d.title}" to Library');
  }

  void _handleEpisodesChanged(int newEps) {
    final d = _drama;
    if (d == null) return;

    final resolvedSeasons = resolveSeasonBreakdown(
      seasons: _extra?.seasons ?? const [],
      totalSeasons: d.totalSeasons,
      totalEpisodes: d.totalEpisodes,
    );

    var nextSeason = d.currentSeason;
    var nextStatus = d.status;
    final prevEps = d.episodesWatched;

    // Auto-promote Planned -> Watching on first watched episode
    if (prevEps == 0 && newEps > 0 && nextStatus == 'Planned') {
      nextStatus = 'Watching';
    }

    // Auto-advance season if user finished current non-final season
    if (resolvedSeasons.length > 1 && newEps > prevEps) {
      var cumulative = 0;
      for (final s in resolvedSeasons) {
        cumulative += s.episodeCount;
        if (s.seasonNumber == d.currentSeason &&
            newEps >= cumulative &&
            s.seasonNumber < resolvedSeasons.last.seasonNumber) {
          nextSeason = s.seasonNumber + 1;
          nextStatus = 'Watching';
          break;
        }
      }
    }

    final reachedFinal = d.totalEpisodes > 0 && newEps >= d.totalEpisodes;
    if (reachedFinal && d.status != 'Done') {
      nextStatus = 'Done';
      _updateDrama(
        d.copyWith(
          episodesWatched: newEps,
          currentEpisode: newEps,
          currentSeason: nextSeason,
          status: nextStatus,
        ),
        immediateSave: true,
      );
      ref.read(dramaControllerProvider).triggerCompletionCelebration();
      ref.read(toastProvider.notifier).show('Completed "${d.title}"!');
      return;
    }

    _updateDrama(
      d.copyWith(
        episodesWatched: newEps,
        currentEpisode: newEps,
        currentSeason: nextSeason,
        status: nextStatus,
      ),
      immediateSave: true,
    );
  }

  void _showAssignShelfSheet() {
    final d = _drama;
    if (d == null) return;
    final collections = ref.read(currentSettingsProvider).customCollections;
    final currentTags = d.tagList.toList();

    showIosActionSheet(
      context: context,
      title: 'Assign to Collection Shelf',
      message: 'Tap a shelf to add or remove "${d.title}"',
      actions: [
        for (final shelf in collections)
          ActionSheetItem(
            label: shelf,
            icon: MoglogIcons.bookmark,
            isSelected:
                currentTags.any((t) => t.toLowerCase() == shelf.toLowerCase()),
            onTap: () {
              final nextTags = List<String>.from(currentTags);
              final existingIdx = nextTags
                  .indexWhere((t) => t.toLowerCase() == shelf.toLowerCase());
              if (existingIdx >= 0) {
                nextTags.removeAt(existingIdx);
              } else {
                nextTags.add(shelf);
              }
              _updateDrama(
                d.copyWith(tags: nextTags.join(', ')),
                immediateSave: true,
              );
            },
          ),
      ],
    );
  }

  void _showMoreSheet() {
    final d = _drama;
    if (d == null) return;
    final hiddenIds = ref.read(currentSettingsProvider).hiddenFromCircleDramaIds;
    final isHidden = hiddenIds.contains(d.id);

    showIosActionSheet(
      context: context,
      title: d.title,
      actions: [
        ActionSheetItem(
          label: 'Share Show',
          icon: MoglogIcons.share,
          onTap: () {
            final watch = resolvePrimaryWatchLinkForShare(
              dramaId: d.id,
              dramaTitle: d.title,
              watchProviders: _extra?.watchProviders ?? const [],
            );
            Share.share(
              buildShowShareText(
                drama: d,
                isInLibrary: _isSaved,
                primaryWatch: watch,
              ),
            );
          },
        ),
        ActionSheetItem(
          label: 'Open on TMDB',
          icon: MoglogIcons.externalLink,
          onTap: () => launchUrl(
            Uri.parse('https://www.themoviedb.org/tv/${d.id}'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        if (_isSaved)
          ActionSheetItem(
            label: isHidden
                ? 'Unhide from Watch Circle'
                : 'Hide from Watch Circle',
            icon: isHidden ? MoglogIcons.eye : MoglogIcons.eyeOff,
            onTap: () async {
              await ref
                  .read(dramaControllerProvider)
                  .setDramaHiddenFromCircle(d.id, !isHidden);
              ref.read(toastProvider.notifier).show(
                !isHidden
                    ? 'Hidden "${d.title}" from Watch Circle'
                    : 'Visible in Watch Circle again',
              );
            },
          ),
        if (_isSaved)
          ActionSheetItem(
            label: 'Move to Recycle Bin',
            icon: MoglogIcons.trash,
            isDestructive: true,
            onTap: () async {
              await ref.read(dramaControllerProvider).moveToRecycleBin(d);
              ref.read(toastProvider.notifier).show(
                'Moved "${d.title}" to Recycle Bin',
                actionLabel: 'Undo',
                onAction: () => ref.read(dramaControllerProvider).restoreDrama(d),
              );
              widget.onBack();
            },
          ),
      ],
    );
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final settings = ref.watch(currentSettingsProvider);
    final accent =
        (settings.dynamicPosterTint && _dynamicAccent != null)
            ? _dynamicAccent!
            : c.accent;

    if (_loading) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    final drama = _drama;
    if (drama == null) {
      return Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            IosLargeTitleHeader(
              title: 'Show Details',
              collapsed: true,
              leadingActions: IosCircleIconButton(
                icon: MoglogIcons.chevronLeft,
                onTap: widget.onBack,
              ),
            ),
            const Expanded(
              child: Center(
                child: IosEmptyState(
                  icon: MoglogIcons.library,
                  title: 'Show Not Found',
                  subtitle: 'Unable to load details for this series.',
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isTopFour = settings.topFourFavoriteIds.contains(drama.id);
    final isHiddenFromCircle = settings.hiddenFromCircleDramaIds.contains(drama.id);
    final matchingShelves = drama.tagList
        .where(
          (tag) => settings.customCollections
              .any((s) => s.toLowerCase() == tag.toLowerCase()),
        )
        .length;

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final headerHeight = (screenHeight * 0.48).clamp(190.0, 440.0);

    final statusLabels = drama.totalSeasons > 1
        ? _statuses.map((s) => 'S${drama.currentSeason} $s').toList()
        : _statuses;

    final bingeEstimate = computeBingeEstimate(
      episodesWatched: drama.episodesWatched,
      totalEpisodes: drama.totalEpisodes,
      episodeRuntimeMinutes: _extra?.episodeRuntime ?? 45,
    );

    final detailBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badges (In Library / Hidden from Circle)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (_isSaved)
              _PillBadge(
                label: 'In Library',
                icon: MoglogIcons.check,
                color: accent,
              ),
            if (isHiddenFromCircle)
              _PillBadge(
                label: 'Hidden from Circle',
                icon: MoglogIcons.eyeOff,
                color: c.secondaryLabel,
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Title & metadata
        Text(drama.title, style: t.title1.copyWith(color: c.label)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (drama.rating > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MoglogIcons.starFilled, size: 15, color: c.starGold),
                  const SizedBox(width: 4),
                  Text(
                    drama.rating.toStringAsFixed(1),
                    style: t.subhead.copyWith(
                      color: c.label,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            if (drama.releaseYear > 0)
              Text(
                '${drama.releaseYear}',
                style: t.subhead.copyWith(color: c.secondaryLabel),
              ),
            if (drama.totalSeasons > 0)
              Text(
                '${drama.totalSeasons} Season${drama.totalSeasons == 1 ? "" : "s"}',
                style: t.subhead.copyWith(color: c.secondaryLabel),
              ),
            if (drama.totalEpisodes > 0)
              Text(
                '${drama.totalEpisodes} Eps',
                style: t.subhead.copyWith(color: c.secondaryLabel),
              ),
          ],
        ),

        if (drama.genreList.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: drama.genreList
                .map(
                  (g) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.secondaryBackground,
                      borderRadius: MoglogShapes.pill,
                      border: Border.all(color: c.separator, width: 0.6),
                    ),
                    child: Text(
                      g,
                      style: t.caption2.copyWith(color: c.secondaryLabel),
                    ),
                  ),
                )
                .toList(),
          ),
        ],

        // Quick action pills (Pin to Top 4 + Add to Shelf)
        if (_isSaved) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickActionPill(
                  icon: isTopFour ? MoglogIcons.starFilled : MoglogIcons.starOutline,
                  label: isTopFour ? 'Pinned in Top 4' : 'Pin to Top 4',
                  active: isTopFour,
                  activeColor: c.starGold,
                  onTap: () async {
                    final added = await ref
                        .read(dramaControllerProvider)
                        .toggleTopFourFavorite(drama.id);
                    ref.read(toastProvider.notifier).show(
                      added
                          ? 'Pinned "${drama.title}" to Top 4 Favorites'
                          : 'Removed from Top 4 Favorites',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionPill(
                  icon: matchingShelves > 0
                      ? MoglogIcons.bookmarkFilled
                      : MoglogIcons.bookmark,
                  label: matchingShelves > 0
                      ? 'Shelves ($matchingShelves)'
                      : 'Add to Shelf',
                  active: matchingShelves > 0,
                  activeColor: accent,
                  onTap: _showAssignShelfSheet,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Status Segmented Control (matching Kotlin IosSegmentedControl)
        IosSegmentedControl(
          labels: statusLabels,
          selectedIndex: _statuses.indexOf(drama.status).clamp(0, 2),
          onSelected: (idx) {
            final newStatus = _statuses[idx];
            final prevStatus = drama.status;
            var nextEps = drama.episodesWatched;
            if (newStatus == 'Done' && drama.totalEpisodes > 0) {
              nextEps = drama.totalEpisodes;
            }
            _updateDrama(
              drama.copyWith(
                status: newStatus,
                episodesWatched: nextEps,
                currentEpisode: nextEps,
              ),
              immediateSave: true,
            );
            if (newStatus == 'Done' && prevStatus != 'Done') {
              ref.read(dramaControllerProvider).triggerCompletionCelebration();
            }
          },
        ),

        const SizedBox(height: 16),

        // Multi-Season Progress Stepper Card
        ProgressStepperCard(
          episodesWatched: drama.episodesWatched,
          totalEpisodes: drama.totalEpisodes,
          currentSeason: max(1, drama.currentSeason),
          totalSeasons: drama.totalSeasons,
          seasons: _extra?.seasons ?? const [],
          nextEpisodeAirDate: drama.nextEpisodeAirDate,
          nextSeasonNumber: drama.nextSeasonNumber,
          nextEpisodeNumber: drama.nextEpisodeNumber,
          accentColor: accent,
          onSeasonChange: (s) => _updateDrama(
            drama.copyWith(currentSeason: s),
            immediateSave: true,
          ),
          onEpisodesWatchedChange: _handleEpisodesChanged,
        ),

        // Binge & Catch-Up Calculator Card (hidden once completed)
        if (drama.status != 'Done' &&
            drama.totalEpisodes > 0 &&
            bingeEstimate.remainingEpisodes > 0) ...[
          const SizedBox(height: 16),
          _BingeCalculatorCard(
            estimate: bingeEstimate,
            runtimeMinutes: _extra?.episodeRuntime ?? 45,
            accentColor: accent,
          ),
        ],

        const SizedBox(height: 16),

        // Synopsis / Overview + Watch Trailer + Search Web
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
              Text('Overview', style: t.headline.copyWith(color: c.label)),
              const SizedBox(height: 8),
              Text(
                drama.overview.trim().isNotEmpty
                    ? drama.overview
                    : 'No overview available.',
                maxLines: _synopsisExpanded ? null : 4,
                overflow: _synopsisExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: t.subhead.copyWith(color: c.secondaryLabel, height: 1.45),
              ),
              if (drama.overview.length > 180) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () =>
                      setState(() => _synopsisExpanded = !_synopsisExpanded),
                  child: Text(
                    _synopsisExpanded ? 'less' : 'more',
                    style: t.footnote.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if ((_extra?.trailerKey ?? '').isNotEmpty) ...[
                    Expanded(
                      child: IosPrimaryButton(
                        text: 'Watch Trailer',
                        leadingIcon: MoglogIcons.play,
                        backgroundColor: accent,
                        onTap: () => launchUrl(
                          Uri.parse(
                            'https://www.youtube.com/watch?v=${_extra!.trailerKey}',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: IosSecondaryButton(
                      text: 'Search Web',
                      leadingIcon: MoglogIcons.externalLink,
                      onTap: () {
                        final q = Uri.encodeComponent('${drama.title} tv series');
                        launchUrl(
                          Uri.parse('https://www.google.com/search?q=$q'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Personal Rating & Audience / Google Reviews
        RatingAndNotesCard(
          dramaId: drama.id,
          dramaTitle: drama.title,
          myRating: drama.myRating,
          reviews: _extra?.reviews ?? const [],
          accentColor: accent,
          onRatingChanged: (r) =>
              _updateDrama(drama.copyWith(myRating: r), immediateSave: true),
        ),

        // Regional Watch Providers ("Where to Watch")
        if ((_extra?.watchProviders ?? const []).isNotEmpty) ...[
          const SizedBox(height: 16),
          WatchProvidersSection(
            dramaId: drama.id,
            dramaTitle: drama.title,
            watchProviders: _extra?.watchProviders ?? const [],
            accentColor: accent,
          ),
        ],

        // Cast Horizontal Rail
        if ((_extra?.cast ?? const []).isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Cast', style: t.title3.copyWith(color: c.label)),
          const SizedBox(height: 10),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _extra!.cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, idx) {
                final member = _extra!.cast[idx];
                return SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      PosterImage(
                        url: member.profilePath ?? '',
                        width: 64,
                        height: 64,
                        isCircular: true,
                        alignment: const Alignment(0, -0.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: t.caption2.copyWith(
                          color: c.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        member.character,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: t.caption2.copyWith(
                          color: c.secondaryLabel,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        // Similar / Recommended Shows Rail
        if ((_extra?.recommendations ?? const []).isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Similar Shows', style: t.title3.copyWith(color: c.label)),
          const SizedBox(height: 10),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _extra!.recommendations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 11),
              itemBuilder: (_, idx) {
                final rec = _extra!.recommendations[idx];
                return IosPressable(
                  onTap: () {
                    ref.read(dramaControllerProvider).cacheTransientDrama(rec);
                    widget.onOpenRecommendation(rec.id);
                  },
                  child: SizedBox(
                    width: 108,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PosterImage(
                            url: rec.posterPath,
                            width: 108,
                            borderRadius: MoglogShapes.poster,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rec.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w600,
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

        SizedBox(height: _isSaved ? 48 : 132),
      ],
    );

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          if (isLandscape)
            // Adaptive Landscape 2-Pane Split matching Kotlin DetailScreen (34% poster / 66% details)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 32) * 0.34,
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PosterImage(
                                  url: drama.posterPath,
                                  borderRadius: MoglogShapes.card,
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  right: 10,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IosCircleIconButton(
                                        icon: MoglogIcons.chevronLeft,
                                        tooltip: 'Back',
                                        backgroundColor:
                                            Colors.black.withValues(alpha: 0.55),
                                        tint: Colors.white,
                                        onTap: widget.onBack,
                                      ),
                                      IosCircleIconButton(
                                        icon: MoglogIcons.moreHorizontal,
                                        tooltip: 'More actions',
                                        backgroundColor:
                                            Colors.black.withValues(alpha: 0.55),
                                        tint: Colors.white,
                                        onTap: _showMoreSheet,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isSaved) ...[
                            const SizedBox(height: 10),
                            IosPrimaryButton(
                              text: 'Add to Library',
                              leadingIcon: MoglogIcons.plus,
                              backgroundColor: accent,
                              onTap: _addToLibrary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: detailBody,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Portrait full-bleed parallax poster header (120Hz AnimatedBuilder scoped to header)
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: headerHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: AnimatedBuilder(
                            animation: _scrollController,
                            builder: (_, child) {
                              final offset = _scrollController.hasClients
                                  ? _scrollController.offset
                                  : 0.0;
                              return Transform.translate(
                                offset: Offset(0, -offset * 0.35),
                                child: child,
                              );
                            },
                            child: PosterImage(
                              url: drama.posterPath,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (settings.dynamicPosterTint && _dynamicAccent != null)
                                    ? Color.alphaBlend(
                                        accent.withValues(alpha: 0.24),
                                        Colors.black.withValues(alpha: 0.42),
                                      )
                                    : Colors.black.withValues(alpha: 0.45),
                                (settings.dynamicPosterTint && _dynamicAccent != null)
                                    ? accent.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                (settings.dynamicPosterTint && _dynamicAccent != null)
                                    ? Color.alphaBlend(
                                        accent.withValues(alpha: 0.14),
                                        c.background.withValues(alpha: 0.86),
                                      )
                                    : c.background.withValues(alpha: 0.82),
                                c.background,
                              ],
                              stops: const [0.0, 0.35, 0.78, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: detailBody,
                  ),
                ],
              ),
            ),

            // Floating top navigation bar (Back + More)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IosCircleIconButton(
                        icon: MoglogIcons.chevronLeft,
                        tooltip: 'Back',
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        tint: Colors.white,
                        onTap: widget.onBack,
                      ),
                      IosCircleIconButton(
                        icon: MoglogIcons.moreHorizontal,
                        tooltip: 'More actions',
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        tint: Colors.white,
                        onTap: _showMoreSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky bottom Add to Library bar for unsaved shows
            if (!_isSaved)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IosFrostedBar(
                  showTopBorder: true,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: IosPrimaryButton(
                        text: 'Add to Library',
                        leadingIcon: MoglogIcons.plus,
                        backgroundColor: accent,
                        onTap: _addToLibrary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _PillBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.typo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: MoglogShapes.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: t.caption2.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return IosPressable(
      onTap: onTap,
      hapticOnTap: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: ShapeDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.16)
              : c.secondaryBackground,
          shape: MoglogShapes.smooth(
            11,
            side: BorderSide(
              color: active ? activeColor.withValues(alpha: 0.55) : c.separator,
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? activeColor : c.label),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.footnote.copyWith(
                  color: active ? activeColor : c.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BingeCalculatorCard extends StatelessWidget {
  final BingeEstimate estimate;
  final int runtimeMinutes;
  final Color accentColor;

  const _BingeCalculatorCard({
    required this.estimate,
    required this.runtimeMinutes,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(MoglogIcons.clock, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Binge Calculator',
                    style: t.headline.copyWith(color: c.label),
                  ),
                ],
              ),
              Text(
                '${estimate.formattedRemainingTime} left',
                style: t.footnote.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${estimate.remainingEpisodes} episodes remaining (~$runtimeMinutes min/ep)',
            style: t.caption.copyWith(color: c.secondaryLabel),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final pace in const [1, 2, 3, 5]) ...[
                if (pace != 1) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: c.tertiaryBackground,
                      borderRadius: MoglogShapes.control,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$pace/day',
                          style: t.caption2.copyWith(color: c.secondaryLabel),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${estimate.daysAtPace[pace]}d',
                          style: t.subhead.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
