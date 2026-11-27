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
import '../../core/design_system/tokens.dart';
import '../../core/network/image_cache_manager.dart';
import '../../domain/logic/season_progress.dart';
import '../../domain/model/drama.dart';
import '../../domain/model/drama_extra_details.dart';
import '../../domain/model/show_comment.dart';
import 'widgets/progress_stepper_card.dart';
import 'widgets/rating_and_notes_card.dart';
import 'widgets/watch_providers_section.dart';

Color _contrastInkForAccent(Color accent, MoglogColors c) {
  final est = ThemeData.estimateBrightnessForColor(accent);
  return est == Brightness.dark ? c.onMedia : MoglogColors.light.onAccent;
}

Color _readableTextAccent(Color accent, MoglogColors c) {
  if (c.isDark) return accent;
  final hsl = HSLColor.fromColor(accent);
  if (hsl.lightness > 0.36) {
    return hsl.withLightness(0.32).toColor();
  }
  return accent;
}

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
  final ValueNotifier<bool> _pinnedBarCollapsed = ValueNotifier<bool>(false);

  Drama? _drama;
  DramaExtraDetails? _extra;
  List<ShowComment> _communityComments = const [];
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
    _scrollController.addListener(_onScroll);
    final ctrl = ref.read(dramaControllerProvider);
    final local =
        ref.read(dramaRepositoryProvider).getLocalDramaById(widget.dramaId);
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
    _loadCommunityComments();
  }

  Future<void> _loadCommunityComments() async {
    final comments = await ref
        .read(showReviewsRepositoryProvider)
        .fetchComments(widget.dramaId);
    if (!mounted) return;
    setState(() => _communityComments = comments);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    if (!_pinnedBarCollapsed.value && offset > 220) {
      _pinnedBarCollapsed.value = true;
    } else if (_pinnedBarCollapsed.value && offset < 170) {
      _pinnedBarCollapsed.value = false;
    }
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
    final local =
        ref.read(dramaRepositoryProvider).getLocalDramaById(widget.dramaId);

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
          releaseYear: _drama!.releaseYear > 0
              ? _drama!.releaseYear
              : extra.releaseYear,
          totalSeasons: _drama!.totalSeasons > 0
              ? _drama!.totalSeasons
              : extra.totalSeasons,
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

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
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
        final color =
            Color.fromARGB(255, pixels[i], pixels[i + 1], pixels[i + 2]);
        final hsl = HSLColor.fromColor(color);
        if (hsl.lightness >= 0.16 &&
            hsl.lightness <= 0.84 &&
            hsl.saturation >= 0.14) {
          final fbScore =
              hsl.saturation * (1.0 - (hsl.lightness - 0.5).abs() * 0.7);
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

    if (prevEps == 0 && newEps > 0 && nextStatus == 'Planned') {
      nextStatus = 'Watching';
    }

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
    final hiddenIds =
        ref.read(currentSettingsProvider).hiddenFromCircleDramaIds;
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
            SharePlus.instance.share(
              ShareParams(
                text: buildShowShareText(
                  drama: d,
                  isInLibrary: _isSaved,
                  primaryWatch: watch,
                ),
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
                    onAction: () =>
                        ref.read(dramaControllerProvider).restoreDrama(d),
                  );
              widget.onBack();
            },
          ),
      ],
    );
  }

  @override
  void dispose() {
    if (_autosaveDebounce?.isActive == true) {
      _autosaveDebounce?.cancel();
      if (_drama != null && _isSaved) {
        ref.read(dramaControllerProvider).saveDrama(_drama!);
      }
    } else {
      _autosaveDebounce?.cancel();
    }
    _pinnedBarCollapsed.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final reduceMotion = context.reduceMotion;
    final settings = ref.watch(currentSettingsProvider);
    final authState = ref.watch(authControllerProvider);
    final accent = (settings.dynamicPosterTint && _dynamicAccent != null)
        ? _dynamicAccent!
        : c.accent;
    final accentInk = _readableTextAccent(accent, c);

    if (_loading) {
      return Scaffold(
        backgroundColor: c.background,
        body: _DetailLoadingSkeleton(onBack: widget.onBack),
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
                tooltip: 'Back',
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
    final isHiddenFromCircle =
        settings.hiddenFromCircleDramaIds.contains(drama.id);
    final matchingShelves = drama.tagList
        .where(
          (tag) => settings.customCollections
              .any((s) => s.toLowerCase() == tag.toLowerCase()),
        )
        .length;

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final headerHeight = (screenHeight * 0.48).clamp(200.0, 440.0);
    final castRailHeight =
        130.0 + ((textScale - 1.0).clamp(0.0, 1.0) * 56.0);
    final similarRailHeight =
        200.0 + ((textScale - 1.0).clamp(0.0, 1.0) * 32.0);

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
        if (_isSaved || isHiddenFromCircle) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_isSaved)
                _PillBadge(
                  label: 'In Library',
                  icon: MoglogIcons.check,
                  color: accent,
                  textColor: accentInk,
                ),
              if (isHiddenFromCircle)
                _PillBadge(
                  label: 'Hidden from Circle',
                  icon: MoglogIcons.eyeOff,
                  color: c.secondaryLabel,
                  textColor: c.secondaryLabel,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
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
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.secondaryBackground,
                      borderRadius: MoglogShapes.pill,
                      border: Border.all(
                        color: c.cardBorder,
                        width: c.hairlineWidth,
                      ),
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
        if (_isSaved) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickActionPill(
                  icon: isTopFour
                      ? MoglogIcons.starFilled
                      : MoglogIcons.starOutline,
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
                  activeColor: accentInk,
                  onTap: _showAssignShelfSheet,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
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
        if (drama.status != 'Done' &&
            drama.totalEpisodes > 0 &&
            bingeEstimate.remainingEpisodes > 0) ...[
          const SizedBox(height: 16),
          _BingeCalculatorCard(
            estimate: bingeEstimate,
            runtimeMinutes: _extra?.episodeRuntime ?? 45,
            accentColor: accentInk,
          ),
        ],
        const SizedBox(height: 16),
        IosCard(
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
                style:
                    t.subhead.copyWith(color: c.secondaryLabel, height: 1.48),
              ),
              if (drama.overview.length > 180) ...[
                const SizedBox(height: 6),
                IosPressable(
                  onTap: () =>
                      setState(() => _synopsisExpanded = !_synopsisExpanded),
                  hapticOnTap: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _synopsisExpanded ? 'Show less' : 'Read more',
                      style: t.footnote.copyWith(
                        color: accentInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if ((_extra?.trailerKey ?? '').isNotEmpty &&
                      RegExp(r'^[a-zA-Z0-9_-]{6,16}$')
                          .hasMatch(_extra!.trailerKey!)) ...[
                    Expanded(
                      child: IosPrimaryButton(
                        text: 'Watch Trailer',
                        leadingIcon: MoglogIcons.play,
                        size: MoglogButtonSize.medium,
                        singleLine: true,
                        backgroundColor: accent,
                        foregroundColor: _contrastInkForAccent(accent, c),
                        onTap: () => launchUrl(
                          Uri.https(
                            'www.youtube.com',
                            '/watch',
                            {'v': _extra!.trailerKey!},
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: IosSecondaryButton(
                      text: 'Open in TMDB',
                      leadingIcon: MoglogIcons.externalLink,
                      size: MoglogButtonSize.medium,
                      singleLine: true,
                      onTap: () {
                        launchUrl(
                          Uri.https('www.themoviedb.org', '/tv/${drama.id}'),
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
        RatingAndNotesCard(
          dramaId: drama.id,
          dramaTitle: drama.title,
          myRating: drama.myRating,
          reviews: _extra?.reviews ?? const [],
          communityComments: _communityComments,
          currentUserUid: authState.user?.uid,
          isSignedIn: authState.user != null,
          accentColor: accent,
          onRatingChanged: (r) =>
              _updateDrama(drama.copyWith(myRating: r), immediateSave: true),
          onSubmitComment: (content, rating) async {
            final existing = _communityComments
                .where((c) => c.uid == authState.user?.uid)
                .firstOrNull;
            final posted = await ref
                .read(showReviewsRepositoryProvider)
                .postOrUpdateComment(
                  dramaId: drama.id,
                  content: content,
                  rating: rating,
                  existingCreatedAt: existing?.createdAt,
                );
            if (!mounted) return;
            setState(() {
              _communityComments = [
                posted,
                ..._communityComments.where((c) => c.uid != posted.uid),
              ];
            });
            ref.read(toastProvider.notifier).show(
                  existing != null ? 'Review updated' : 'Review posted',
                );
          },
          onDeleteComment: () async {
            final uid = authState.user?.uid;
            await ref
                .read(showReviewsRepositoryProvider)
                .deleteComment(drama.id);
            if (!mounted) return;
            setState(() {
              _communityComments =
                  _communityComments.where((c) => c.uid != uid).toList();
            });
            ref.read(toastProvider.notifier).show('Review deleted');
          },
          onRequestSignIn: () async {
            final err = await ref
                .read(authControllerProvider.notifier)
                .signInWithGoogle();
            if (err != null && mounted) {
              ref.read(toastProvider.notifier).show(err);
            }
          },
          onNotify: (msg) => ref.read(toastProvider.notifier).show(msg),
        ),
        if ((_extra?.watchProviders ?? const []).isNotEmpty) ...[
          const SizedBox(height: 16),
          WatchProvidersSection(
            dramaId: drama.id,
            dramaTitle: drama.title,
            watchProviders: _extra?.watchProviders ?? const [],
            accentColor: accentInk,
          ),
        ],
        if ((_extra?.cast ?? const []).isNotEmpty) ...[
          const SizedBox(height: 22),
          const IosSectionHeader(
            title: 'Cast',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: castRailHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _extra!.cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, idx) {
                final member = _extra!.cast[idx];
                return SizedBox(
                  width: 82,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        style: t.microBadge.copyWith(color: c.secondaryLabel),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        if ((_extra?.recommendations ?? const []).isNotEmpty) ...[
          const SizedBox(height: 22),
          const IosSectionHeader(
            title: 'Similar Shows',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: similarRailHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _extra!.recommendations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, idx) {
                final rec = _extra!.recommendations[idx];
                return IosPressable(
                  semanticLabel: rec.title,
                  focusRadius: MoglogShapes.posterRadius,
                  onTap: () {
                    ref.read(dramaControllerProvider).cacheTransientDrama(rec);
                    widget.onOpenRecommendation(rec.id);
                  },
                  child: SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PosterImage(
                            url: rec.posterPath,
                            width: 112,
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
        SizedBox(height: _isSaved ? 56 : 138),
      ],
    );

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          if (isLandscape)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MoglogSpacing.md,
                  vertical: 10,
                ),
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
                                  top: 8,
                                  left: 8,
                                  right: 8,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IosCircleIconButton(
                                        icon: MoglogIcons.chevronLeft,
                                        tooltip: 'Back',
                                        backgroundColor: c.mediaScrim,
                                        tint: c.onMedia,
                                        onTap: widget.onBack,
                                      ),
                                      IosCircleIconButton(
                                        icon: MoglogIcons.moreHorizontal,
                                        tooltip: 'More actions',
                                        backgroundColor: c.mediaScrim,
                                        tint: c.onMedia,
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
                              foregroundColor: _contrastInkForAccent(accent, c),
                              onTap: _addToLibrary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: detailBody,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
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
                                offset: Offset(
                                  0,
                                  reduceMotion ? 0 : -offset * 0.35,
                                ),
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
                          duration:
                              reduceMotion ? Duration.zero : MoglogMotion.fast,
                          curve: MoglogMotion.curve,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (settings.dynamicPosterTint &&
                                        _dynamicAccent != null)
                                    ? Color.alphaBlend(
                                        accent.withValues(alpha: 0.24),
                                        c.mediaScrimLight,
                                      )
                                    : c.mediaScrimLight,
                                (settings.dynamicPosterTint &&
                                        _dynamicAccent != null)
                                    ? accent.withValues(alpha: 0.08)
                                    : c.background.withValues(alpha: 0.0),
                                (settings.dynamicPosterTint &&
                                        _dynamicAccent != null)
                                    ? Color.alphaBlend(
                                        accent.withValues(alpha: 0.14),
                                        c.background.withValues(alpha: 0.88),
                                      )
                                    : c.background.withValues(alpha: 0.84),
                                c.background,
                              ],
                              stops: const [0.0, 0.36, 0.78, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: MoglogSpacing.screenHorizontal,
                    child: detailBody,
                  ),
                ],
              ),
            ),

            // Collapsing inline top bar + floating Back & More controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _pinnedBarCollapsed,
                builder: (context, collapsedBar, _) {
                  return AnimatedContainer(
                    duration: reduceMotion ? Duration.zero : MoglogMotion.fast,
                    curve: MoglogMotion.curve,
                    decoration: BoxDecoration(
                      color: collapsedBar
                          ? c.frostedBarSurface
                          : c.frostedBarSurface.withValues(alpha: 0.0),
                      border: Border(
                        bottom: collapsedBar
                            ? BorderSide(
                                color: c.glassBorder,
                                width: c.hairlineWidth,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IosCircleIconButton(
                                icon: MoglogIcons.chevronLeft,
                                tooltip: 'Back',
                                backgroundColor:
                                    collapsedBar ? null : c.mediaScrim,
                                tint: collapsedBar ? c.label : c.onMedia,
                                onTap: widget.onBack,
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: collapsedBar ? 1.0 : 0.0,
                              duration: reduceMotion
                                  ? Duration.zero
                                  : MoglogMotion.fast,
                              child: IgnorePointer(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 56,
                                  ),
                                  child: Text(
                                    drama.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: t.headline.copyWith(color: c.label),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IosCircleIconButton(
                                icon: MoglogIcons.moreHorizontal,
                                tooltip: 'More actions',
                                backgroundColor:
                                    collapsedBar ? null : c.mediaScrim,
                                tint: collapsedBar ? c.label : c.onMedia,
                                onTap: _showMoreSheet,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Sticky bottom frosted bar for unsaved shows
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
                        foregroundColor: _contrastInkForAccent(accent, c),
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

class _DetailLoadingSkeleton extends StatelessWidget {
  final VoidCallback onBack;

  const _DetailLoadingSkeleton({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final headerH = (screenH * 0.44).clamp(200.0, 380.0);
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(
                width: double.infinity,
                height: headerH,
                borderRadius: BorderRadius.zero,
              ),
              const Padding(
                padding: EdgeInsets.all(MoglogSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 220, height: 32),
                    SizedBox(height: 10),
                    ShimmerBox(width: 160, height: 18),
                    SizedBox(height: 18),
                    ShimmerBox(
                      width: double.infinity,
                      height: 44,
                      borderRadius: MoglogShapes.control,
                    ),
                    SizedBox(height: 16),
                    ShimmerBox(
                      width: double.infinity,
                      height: 132,
                      borderRadius: MoglogShapes.card,
                    ),
                    SizedBox(height: 16),
                    ShimmerBox(
                      width: double.infinity,
                      height: 160,
                      borderRadius: MoglogShapes.card,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              tooltip: 'Back',
              onTap: onBack,
            ),
          ),
        ),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _PillBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.typo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: MoglogShapes.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption2.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
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
      semanticSelected: active,
      focusRadius: MoglogShapes.controlRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.15)
                : c.secondaryBackground,
            shape: MoglogShapes.smooth(
              MoglogShapes.controlRadius,
              side: BorderSide(
                color: active
                    ? activeColor.withValues(alpha: 0.55)
                    : c.cardBorder,
                width: active ? 1.0 : c.hairlineWidth,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: active ? activeColor : c.label),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
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
    return IosCard(
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
                  Icon(MoglogIcons.clock, size: 17, color: accentColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Binge Calculator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.headline.copyWith(color: c.label),
                    ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                    decoration: ShapeDecoration(
                      color: c.tertiaryBackground,
                      shape: MoglogShapes.smooth(
                        MoglogShapes.controlRadius,
                        side: BorderSide(
                          color: c.glassBorder,
                          width: c.hairlineWidth,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$pace/day',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption2.copyWith(color: c.secondaryLabel),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${estimate.daysAtPace[pace]}d',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
