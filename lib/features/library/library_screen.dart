import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/ios_bottom_tab_bar.dart';
import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';
import '../../domain/logic/library_filter.dart';
import '../../domain/logic/season_progress.dart';
import '../../domain/model/app_settings.dart';
import '../../domain/model/drama.dart';
import 'widgets/compact_drama_row.dart';
import 'widgets/continue_watching_section.dart';
import 'widgets/drama_context_menu_sheet.dart';
import 'widgets/poster_grid_item.dart';
import 'widgets/sort_filter_sheet.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onDramaTap;
  final VoidCallback onNavigateToDiscover;

  const LibraryScreen({
    super.key,
    required this.onDramaTap,
    required this.onNavigateToDiscover,
  });

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  bool _headerCollapsed = false;
  bool _multiSelectMode = false;
  final Set<int> _selectedIds = {};

  static const _statuses = ['All', 'Watching', 'Planned', 'Done'];

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: ref.read(librarySearchQueryProvider));
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (!_headerCollapsed && offset > 56) {
      setState(() => _headerCollapsed = true);
    } else if (_headerCollapsed && offset < 16) {
      setState(() => _headerCollapsed = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _multiSelectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
  }

  void _showNewShelfDialog() {
    final ctrl = TextEditingController();
    showIosBottomSheet<void>(
      context: context,
      disposeAfter: [ctrl],
      builder: (ctx) {
        final c = ctx.colors;
        final t = ctx.typo;
        return SingleChildScrollView(
          padding: MoglogSpacing.sheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Collection Shelf',
                style: t.title3.copyWith(color: c.label),
              ),
              const SizedBox(height: 6),
              Text(
                'Group favorite dramas or themed watchlists into a custom shelf.',
                style: t.footnote.copyWith(color: c.secondaryLabel),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: ctrl,
                  maxLength: 28,
                  autofocus: true,
                  style: t.body.copyWith(color: c.label),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'e.g. Comfort Rewatch',
                    hintStyle: t.subhead.copyWith(color: c.tertiaryLabel),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              IosPrimaryButton(
                text: 'Create Shelf',
                onTap: () async {
                  final name = ctrl.text.trim();
                  Navigator.of(ctx).pop();
                  if (name.isNotEmpty) {
                    await ref
                        .read(dramaControllerProvider)
                        .addCustomCollection(name);
                    ref
                        .read(toastProvider.notifier)
                        .show('Created shelf "$name"');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShelfOptionsSheet(String shelfName) {
    showIosActionSheet(
      context: context,
      title: shelfName,
      message: 'Manage this custom collection shelf',
      actions: [
        ActionSheetItem(
          label: 'Rename Shelf',
          icon: MoglogIcons.note,
          onTap: () => _showRenameShelfDialog(shelfName),
        ),
        ActionSheetItem(
          label: 'Delete Shelf',
          icon: MoglogIcons.trash,
          isDestructive: true,
          onTap: () => _showDeleteShelfDialog(shelfName),
        ),
      ],
    );
  }

  void _showRenameShelfDialog(String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showIosBottomSheet<void>(
      context: context,
      disposeAfter: [ctrl],
      builder: (ctx) {
        final c = ctx.colors;
        final t = ctx.typo;
        return SingleChildScrollView(
          padding: MoglogSpacing.sheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rename Shelf', style: t.title3.copyWith(color: c.label)),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: ctrl,
                  maxLength: 28,
                  autofocus: true,
                  style: t.body.copyWith(color: c.label),
                  cursorColor: c.accent,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              IosPrimaryButton(
                text: 'Save Changes',
                onTap: () async {
                  final newName = ctrl.text.trim();
                  Navigator.of(ctx).pop();
                  if (newName.isNotEmpty && newName != oldName) {
                    await ref
                        .read(dramaControllerProvider)
                        .renameShelf(oldName, newName);
                    if (ref.read(librarySelectedShelfProvider) == oldName) {
                      ref.read(librarySelectedShelfProvider.notifier).state =
                          newName;
                    }
                    ref
                        .read(toastProvider.notifier)
                        .show('Renamed to "$newName"');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteShelfDialog(String shelfName) {
    showIosActionSheet(
      context: context,
      title: 'Delete "$shelfName"?',
      message:
          'Shows in this shelf remain in your library; only the shelf tag is removed.',
      actions: [
        ActionSheetItem(
          label: 'Delete Shelf',
          icon: MoglogIcons.trash,
          isDestructive: true,
          onTap: () async {
            await ref.read(dramaControllerProvider).deleteShelf(shelfName);
            if (ref.read(librarySelectedShelfProvider) == shelfName) {
              ref.read(librarySelectedShelfProvider.notifier).state = null;
            }
            ref
                .read(toastProvider.notifier)
                .show('Deleted shelf "$shelfName"');
          },
        ),
      ],
    );
  }

  void _showBulkStatusSheet() {
    final ids = Set<int>.from(_selectedIds);
    showIosActionSheet(
      context: context,
      title: 'Change Status for ${ids.length} Shows',
      actions: [
        for (final st in const ['Watching', 'Planned', 'Done'])
          ActionSheetItem(
            label: st,
            onTap: () {
              ref
                  .read(dramaControllerProvider)
                  .updateDramasStatusBatch(ids, st);
              _exitMultiSelect();
              ref.read(toastProvider.notifier).show(
                    'Updated ${ids.length} shows to $st',
                  );
            },
          ),
      ],
    );
  }

  void _bulkMoveToBin(List<Drama> allDramas) {
    final ids = Set<int>.from(_selectedIds);
    final targets = allDramas.where((d) => ids.contains(d.id)).toList();
    final ctrl = ref.read(dramaControllerProvider);
    ctrl.moveDramasToRecycleBin(targets);
    _exitMultiSelect();
    ref.read(toastProvider.notifier).show(
          'Moved ${targets.length} shows to Recycle Bin',
          actionLabel: 'Undo',
          onAction: () {
            ctrl.restoreDramasBatch(targets);
          },
        );
  }

  void _openContextMenu(Drama drama) {
    final ctrl = ref.read(dramaControllerProvider);
    showDramaContextMenuSheet(
      context: context,
      drama: drama,
      onChangeStatus: (st) {
        ctrl.updateDramaStatus(drama.id, st);
        ref.read(toastProvider.notifier).show('Marked "${drama.title}" as $st');
      },
      onQuickRate: (r) {
        ctrl.saveDrama(drama.copyWith(myRating: r));
        ref.read(toastProvider.notifier).show(
              'Rated "${drama.title}" ${r.toStringAsFixed(1)}/10',
            );
      },
      onIncrementEpisode: () => ctrl.incrementEpisodeQuick(drama),
      onShare: () {
        SharePlus.instance.share(
          ShareParams(
            text: buildShowShareText(
              drama: drama,
              isInLibrary: true,
            ),
          ),
        );
      },
      onEnterMultiSelect: () {
        setState(() {
          _multiSelectMode = true;
          _selectedIds.add(drama.id);
        });
      },
      onMoveToBin: () {
        ctrl.moveToRecycleBin(drama);
        ref.read(toastProvider.notifier).show(
              'Moved "${drama.title}" to Recycle Bin',
              actionLabel: 'Undo',
              onAction: () => ctrl.restoreDrama(drama),
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final allDramas = ref.watch(currentDramasProvider);
    final settings = ref.watch(currentSettingsProvider);
    final selectedStatus = ref.watch(librarySelectedStatusProvider);
    final searchQuery = ref.watch(librarySearchQueryProvider);
    final selectedShelf = ref.watch(librarySelectedShelfProvider);
    final filterState = ref.watch(libraryFilterStateProvider);

    final activeDramas = allDramas.where((d) => !d.isDeleted).toList();
    final plannedDramas =
        activeDramas.where((d) => d.status == 'Planned').toList();
    final doneDramas = activeDramas.where((d) => d.status == 'Done').toList();
    final randomPool = selectedStatus == 'Planned'
        ? plannedDramas
        : (selectedStatus == 'Done' ? doneDramas : const <Drama>[]);
    final watchingDramas = activeDramas
        .where((d) => d.status == 'Watching')
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final filtered = filterAndSortLibrary(
      allDramas: allDramas,
      selectedStatus: selectedStatus,
      selectedShelf: selectedShelf,
      topFourFavoriteIds: settings.topFourFavoriteIds,
      searchQuery: searchQuery,
      filterState: filterState,
    );

    final availableGenres = <String>{
      ...kPresetGenres,
      for (final d in activeDramas) ...d.genreList,
    }.toList()
      ..sort();

    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final screenWidthDp = size.width;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final effectiveColumns = screenWidthDp < 240
        ? 2
        : screenWidthDp < 320
            ? settings.gridColumns.clamp(2, 3)
            : settings.gridColumns.clamp(2, 4);

    final statusLabels = _statuses.map((s) {
      final count = s == 'All'
          ? activeDramas.length
          : activeDramas.where((d) => d.status == s).length;
      if (count > 0 && s == selectedStatus && screenWidthDp >= 290) {
        return '$s ($count)';
      }
      return s;
    }).toList();

    final showContinueWatching = selectedStatus == 'All' &&
        searchQuery.trim().isEmpty &&
        selectedShelf == null &&
        watchingDramas.isNotEmpty;

    final shelfRailHeight = 38.0 * textScale.clamp(1.0, 1.75);
    final shellBottomPad = MoglogLayout.shellScrollBottomPadding(context);
    final gridAspectRatio =
        textScale > 1.3 ? (0.58 / textScale.clamp(1.0, 1.32)) : 0.58;

    final pinnedControls = activeDramas.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLandscape && screenWidthDp >= 500)
                Row(
                  children: [
                    Expanded(
                      flex: 45,
                      child: IosSearchBar(
                        controller: _searchController,
                        placeholder: 'Search your library',
                        onChanged: (v) {
                          ref
                              .read(librarySearchQueryProvider.notifier)
                              .state = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 55,
                      child: IosSegmentedControl(
                        labels: statusLabels,
                        selectedIndex:
                            _statuses.indexOf(selectedStatus).clamp(0, 3),
                        onSelected: (i) {
                          ref
                              .read(librarySelectedStatusProvider.notifier)
                              .state = _statuses[i];
                          if (_scrollController.hasClients &&
                              _scrollController.offset > 0) {
                            _scrollController.jumpTo(0);
                          }
                        },
                      ),
                    ),
                  ],
                )
              else ...[
                IosSearchBar(
                  controller: _searchController,
                  placeholder: 'Search your library',
                  onChanged: (v) {
                    ref.read(librarySearchQueryProvider.notifier).state = v;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                IosSegmentedControl(
                  labels: statusLabels,
                  selectedIndex: _statuses.indexOf(selectedStatus).clamp(0, 3),
                  onSelected: (i) {
                    ref.read(librarySelectedStatusProvider.notifier).state =
                        _statuses[i];
                    if (_scrollController.hasClients &&
                        _scrollController.offset > 0) {
                      _scrollController.jumpTo(0);
                    }
                  },
                ),
              ],
              if (!_headerCollapsed || selectedShelf != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: shelfRailHeight,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ShelfChip(
                        label: 'All Shelves',
                        selected: selectedShelf == null,
                        onTap: () => ref
                            .read(librarySelectedShelfProvider.notifier)
                            .state = null,
                      ),
                      const SizedBox(width: 8),
                      _ShelfChip(
                        label: 'Top 4 Favorites',
                        icon: MoglogIcons.starFilled,
                        iconColor: c.starGold,
                        selected: selectedShelf == kTopFourShelfKey,
                        onTap: () => ref
                            .read(librarySelectedShelfProvider.notifier)
                            .state = selectedShelf == kTopFourShelfKey
                                ? null
                                : kTopFourShelfKey,
                      ),
                      for (final shelf in settings.customCollections) ...[
                        const SizedBox(width: 8),
                        _ShelfChip(
                          label: shelf,
                          selected: selectedShelf == shelf,
                          onTap: () => ref
                              .read(librarySelectedShelfProvider.notifier)
                              .state = selectedShelf == shelf ? null : shelf,
                          onLongPress: () => _showShelfOptionsSheet(shelf),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _ShelfChip(
                        label: 'New Shelf',
                        icon: MoglogIcons.plus,
                        selected: false,
                        isAction: true,
                        onTap: _showNewShelfDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );

    return TabRetapListener(
      branchIndex: 0,
      scrollController: _scrollController,
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            if (_multiSelectMode)
              IosLargeTitleHeader(
                title: '${_selectedIds.length} Selected',
                collapsed: true,
                trailingActions: [
                  IosCircleIconButton(
                    icon: MoglogIcons.filter,
                    tooltip: 'Bulk Status',
                    tint: c.accentText,
                    onTap: _showBulkStatusSheet,
                  ),
                  IosCircleIconButton(
                    icon: MoglogIcons.trash,
                    tooltip: 'Move to Recycle Bin',
                    tint: c.destructive,
                    onTap: () => _bulkMoveToBin(allDramas),
                  ),
                  IosTertiaryButton(
                    text: 'Done',
                    size: MoglogButtonSize.small,
                    onTap: _exitMultiSelect,
                  ),
                ],
              )
            else
              IosLargeTitleHeader(
                title: 'Library',
                collapsed: _headerCollapsed,
                bottomContent: pinnedControls,
                trailingActions: [
                  if ((selectedStatus == 'Planned' ||
                          selectedStatus == 'Done') &&
                      randomPool.length >= 2)
                    IosCircleIconButton(
                      icon: MoglogIcons.dices,
                      tooltip: 'Random Picker ($selectedStatus)',
                      tint: c.accentText,
                      onTap: () {
                        final pick = randomPool[
                            Random.secure().nextInt(randomPool.length)];
                        ref.read(toastProvider.notifier).show(
                              'Random pick: "${pick.title}"',
                            );
                        widget.onDramaTap(pick.id);
                      },
                    ),
                  if (settings.showLayoutSwitchInHome)
                    IosCircleIconButton(
                      icon: settings.layoutMode == LibraryLayoutMode.grid
                          ? MoglogIcons.listRows
                          : MoglogIcons.grid,
                      tooltip: 'Toggle grid or list view',
                      onTap: () {
                        final next =
                            settings.layoutMode == LibraryLayoutMode.grid
                                ? LibraryLayoutMode.list
                                : LibraryLayoutMode.grid;
                        ref.read(settingsStoreProvider).setLayoutMode(next);
                      },
                    ),
                  IosCircleIconButton(
                    icon: MoglogIcons.filter,
                    tooltip: 'Sort & Filter',
                    showBadgeDot: !filterState.isDefault,
                    tint: filterState.isDefault ? c.label : c.accentText,
                    onTap: () => showSortFilterSheet(
                      context: context,
                      currentState: filterState,
                      availableGenres: availableGenres,
                      onApply: (next) => ref
                          .read(libraryFilterStateProvider.notifier)
                          .state = next,
                      onReset: () => ref
                          .read(libraryFilterStateProvider.notifier)
                          .state = const LibraryFilterState(),
                    ),
                  ),
                  IosCircleIconButton(
                    icon: MoglogIcons.plus,
                    tooltip: 'Add show',
                    tint: c.onAccent,
                    backgroundColor: c.accent,
                    onTap: widget.onNavigateToDiscover,
                  ),
                ],
              ),
            Expanded(
              child: activeDramas.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: shellBottomPad * 0.65),
                        child: IosEmptyState(
                          icon: MoglogIcons.library,
                          title: 'Your Library is Empty',
                          subtitle:
                              'Track your favorite series, episode progress, ratings, and collections in one calm place.',
                          actionLabel: 'Discover Shows',
                          onAction: widget.onNavigateToDiscover,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: c.accent,
                      backgroundColor: c.elevatedSurface,
                      displacement: 28,
                      strokeWidth: 2.2,
                      onRefresh: () async {
                        MoglogHaptics.lightImpact();
                        await ref
                            .read(dramaControllerProvider)
                            .reconcileCloudAndLocal();
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          if (showContinueWatching)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: MoglogSpacing.sm,
                                  bottom: MoglogSpacing.xs,
                                ),
                                child: ContinueWatchingSection(
                                  watchingDramas: watchingDramas,
                                  onDramaTap: (d) => widget.onDramaTap(d.id),
                                  onIncrementEpisode: (d) => ref
                                      .read(dramaControllerProvider)
                                      .incrementEpisodeQuick(d),
                                ),
                              ),
                            ),
                          if (filtered.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: shellBottomPad * 0.75,
                                  ),
                                  child: IosEmptyState(
                                    icon: MoglogIcons.search,
                                    title: 'No Matching Shows',
                                    subtitle:
                                        'Try adjusting your search query or clearing active filters.',
                                    actionLabel: 'Clear Filters',
                                    onAction: () {
                                      _searchController.clear();
                                      ref
                                          .read(librarySearchQueryProvider
                                              .notifier)
                                          .state = '';
                                      ref
                                          .read(librarySelectedStatusProvider
                                              .notifier)
                                          .state = 'All';
                                      ref
                                          .read(librarySelectedShelfProvider
                                              .notifier)
                                          .state = null;
                                      ref
                                          .read(
                                              libraryFilterStateProvider.notifier)
                                          .state = const LibraryFilterState();
                                    },
                                  ),
                                ),
                              ),
                            )
                          else if (settings.layoutMode ==
                              LibraryLayoutMode.grid)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                (effectiveColumns >= 4 || screenWidthDp < 340)
                                    ? MoglogSpacing.sm
                                    : MoglogSpacing.md,
                                MoglogSpacing.sm,
                                (effectiveColumns >= 4 || screenWidthDp < 340)
                                    ? MoglogSpacing.sm
                                    : MoglogSpacing.md,
                                shellBottomPad,
                              ),
                              sliver: SliverGrid(
                                gridDelegate: isLandscape
                                    ? SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent:
                                            screenWidthDp < 480 ? 118 : 144,
                                        mainAxisSpacing:
                                            screenWidthDp < 340 ? 12 : 16,
                                        crossAxisSpacing:
                                            screenWidthDp < 340 ? 8 : 12,
                                        childAspectRatio: gridAspectRatio,
                                      )
                                    : SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: effectiveColumns,
                                        mainAxisSpacing:
                                            (effectiveColumns >= 4 ||
                                                    screenWidthDp < 340)
                                                ? 12
                                                : 16,
                                        crossAxisSpacing:
                                            (effectiveColumns >= 4 ||
                                                    screenWidthDp < 340)
                                                ? 8
                                                : 12,
                                        childAspectRatio: gridAspectRatio,
                                      ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final drama = filtered[index];
                                    return PosterGridItem(
                                      drama: drama,
                                      isTopFour: settings.topFourFavoriteIds
                                          .contains(drama.id),
                                      multiSelectMode: _multiSelectMode,
                                      isSelected:
                                          _selectedIds.contains(drama.id),
                                      onTap: () {
                                        if (_multiSelectMode) {
                                          _toggleSelection(drama.id);
                                        } else {
                                          widget.onDramaTap(drama.id);
                                        }
                                      },
                                      onLongPress: () {
                                        if (_multiSelectMode) {
                                          _toggleSelection(drama.id);
                                        } else {
                                          _openContextMenu(drama);
                                        }
                                      },
                                    );
                                  },
                                  childCount: filtered.length,
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                MoglogSpacing.md,
                                MoglogSpacing.sm,
                                MoglogSpacing.md,
                                shellBottomPad,
                              ),
                              sliver: SliverList.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final drama = filtered[index];
                                  return CompactDramaRow(
                                    drama: drama,
                                    isTopFour: settings.topFourFavoriteIds
                                        .contains(drama.id),
                                    multiSelectMode: _multiSelectMode,
                                    isSelected:
                                        _selectedIds.contains(drama.id),
                                    onTap: () {
                                      if (_multiSelectMode) {
                                        _toggleSelection(drama.id);
                                      } else {
                                        widget.onDramaTap(drama.id);
                                      }
                                    },
                                    onLongPress: () {
                                      if (_multiSelectMode) {
                                        _toggleSelection(drama.id);
                                      } else {
                                        _openContextMenu(drama);
                                      }
                                    },
                                    onIncrementEpisode: () => ref
                                        .read(dramaControllerProvider)
                                        .incrementEpisodeQuick(drama),
                                    onMoveToBin: () {
                                      final ctrl =
                                          ref.read(dramaControllerProvider);
                                      ctrl.moveToRecycleBin(drama);
                                      ref.read(toastProvider.notifier).show(
                                            'Moved "${drama.title}" to Recycle Bin',
                                            actionLabel: 'Undo',
                                            onAction: () =>
                                                ctrl.restoreDrama(drama),
                                          );
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;
  final bool isAction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ShelfChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.isAction = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final reduceMotion = context.reduceMotion;

    return IosPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      hapticOnTap: true,
      hapticType: MoglogTapHaptic.selection,
      pressedScale: 0.95,
      semanticSelected: isAction ? null : selected,
      focusRadius: MoglogShapes.pillRadius,
      child: Center(
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : MoglogMotion.fast,
          curve: MoglogMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? c.accent
                : (isAction ? c.accentSubtle : c.secondaryBackground),
            borderRadius: MoglogShapes.pill,
            border: Border.all(
              color: selected
                  ? c.accent
                  : (isAction
                      ? c.accent.withValues(alpha: 0.45)
                      : c.glassBorder),
              width: c.hairlineWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? c.onAccent
                      : (iconColor ?? (isAction ? c.accentText : c.label)),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: t.caption.copyWith(
                  color: selected
                      ? c.onAccent
                      : (isAction ? c.accentText : c.label),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
