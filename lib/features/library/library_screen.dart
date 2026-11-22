import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../domain/logic/library_filter.dart';
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
    if (!_headerCollapsed && offset > 60) {
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
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.secondaryBackground,
        title: Text('New Collection Shelf', style: context.typo.headline.copyWith(color: c.label)),
        content: TextField(
          controller: ctrl,
          maxLength: 28,
          autofocus: true,
          style: context.typo.body.copyWith(color: c.label),
          decoration: InputDecoration(
            hintText: 'e.g. Comfort Rewatch',
            hintStyle: context.typo.subhead.copyWith(color: c.tertiaryLabel),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.secondaryLabel)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (name.isNotEmpty) {
                await ref.read(dramaControllerProvider).addCustomCollection(name);
                ref.read(toastProvider.notifier).show('Created shelf "$name"');
              }
            },
            child: Text('Create', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.secondaryBackground,
        title: Text('Rename Shelf', style: context.typo.headline.copyWith(color: c.label)),
        content: TextField(
          controller: ctrl,
          maxLength: 28,
          autofocus: true,
          style: context.typo.body.copyWith(color: c.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.secondaryLabel)),
          ),
          TextButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (newName.isNotEmpty && newName != oldName) {
                await ref.read(dramaControllerProvider).renameShelf(oldName, newName);
                if (ref.read(librarySelectedShelfProvider) == oldName) {
                  ref.read(librarySelectedShelfProvider.notifier).state = newName;
                }
                ref.read(toastProvider.notifier).show('Renamed to "$newName"');
              }
            },
            child: Text('Save', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteShelfDialog(String shelfName) {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.secondaryBackground,
        title: Text('Delete "$shelfName"?', style: context.typo.headline.copyWith(color: c.label)),
        content: Text(
          'Shows in this shelf remain in your library; only the shelf tag is removed.',
          style: context.typo.subhead.copyWith(color: c.secondaryLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.secondaryLabel)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(dramaControllerProvider).deleteShelf(shelfName);
              if (ref.read(librarySelectedShelfProvider) == shelfName) {
                ref.read(librarySelectedShelfProvider.notifier).state = null;
              }
              ref.read(toastProvider.notifier).show('Deleted shelf "$shelfName"');
            },
            child: Text('Delete', style: TextStyle(color: c.destructive, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
              final ctrl = ref.read(dramaControllerProvider);
              for (final id in ids) {
                ctrl.updateDramaStatus(id, st);
              }
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
    for (final d in targets) {
      ctrl.moveToRecycleBin(d);
    }
    _exitMultiSelect();
    ref.read(toastProvider.notifier).show(
      'Moved ${targets.length} shows to Recycle Bin',
      actionLabel: 'Undo',
      onAction: () {
        for (final d in targets) {
          ctrl.restoreDrama(d);
        }
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
        final score = drama.effectiveRating;
        Share.share(
          '${drama.title} (${drama.status})'
          '${score > 0 ? " — ${score.toStringAsFixed(1)}/10" : ""}\n'
          'https://www.themoviedb.org/tv/${drama.id}',
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
    final t = context.typo;
    final allDramas = ref.watch(currentDramasProvider);
    final settings = ref.watch(currentSettingsProvider);
    final selectedStatus = ref.watch(librarySelectedStatusProvider);
    final searchQuery = ref.watch(librarySearchQueryProvider);
    final selectedShelf = ref.watch(librarySelectedShelfProvider);
    final filterState = ref.watch(libraryFilterStateProvider);

    final activeDramas = allDramas.where((d) => !d.isDeleted).toList();
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

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final effectiveColumns = isLandscape
        ? (settings.gridColumns + 2).clamp(4, 6)
        : settings.gridColumns;

    final statusLabels = _statuses.map((s) {
      if (s == selectedStatus) {
        return '$s (${filtered.length})';
      }
      return s;
    }).toList();

    final showContinueWatching = selectedStatus == 'All' &&
        searchQuery.trim().isEmpty &&
        selectedShelf == null &&
        watchingDramas.isNotEmpty;

    return Scaffold(
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
                  tint: c.accent,
                  onTap: _showBulkStatusSheet,
                ),
                IosCircleIconButton(
                  icon: MoglogIcons.trash,
                  tooltip: 'Move to Recycle Bin',
                  tint: c.destructive,
                  onTap: () => _bulkMoveToBin(allDramas),
                ),
                IosPressable(
                  onTap: _exitMultiSelect,
                  hapticOnTap: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Done',
                      style: t.callout.copyWith(
                        color: c.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            IosLargeTitleHeader(
              title: 'Library',
              collapsed: _headerCollapsed,
              trailingActions: [
                IosCircleIconButton(
                  icon: settings.layoutMode == LibraryLayoutMode.grid
                      ? MoglogIcons.listRows
                      : MoglogIcons.grid,
                  tooltip: 'Toggle grid or list view',
                  onTap: () {
                    final next = settings.layoutMode == LibraryLayoutMode.grid
                        ? LibraryLayoutMode.list
                        : LibraryLayoutMode.grid;
                    ref.read(settingsStoreProvider).setLayoutMode(next);
                  },
                ),
                IosCircleIconButton(
                  icon: MoglogIcons.filter,
                  tooltip: 'Sort & Filter',
                  showBadgeDot: !filterState.isDefault,
                  tint: filterState.isDefault ? c.label : c.accent,
                  onTap: () => showSortFilterSheet(
                    context: context,
                    currentState: filterState,
                    availableGenres: availableGenres,
                    onApply: (next) =>
                        ref.read(libraryFilterStateProvider.notifier).state = next,
                    onReset: () => ref.read(libraryFilterStateProvider.notifier).state =
                        const LibraryFilterState(),
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
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 72),
                      child: IosEmptyState(
                        icon: MoglogIcons.library,
                        title: 'Your Library is Empty',
                        subtitle:
                            'Track your favorite series, episode progress, ratings, and personal notes in one clean place.',
                        actionLabel: 'Discover Shows',
                        onAction: widget.onNavigateToDiscover,
                      ),
                    ),
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Search bar + Status segmented control + Collection Shelves
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                          child: Column(
                            children: [
                              IosSearchBar(
                                controller: _searchController,
                                placeholder: 'Search your library',
                                onChanged: (v) {
                                  ref
                                      .read(librarySearchQueryProvider.notifier)
                                      .state = v;
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 10),
                              IosSegmentedControl(
                                labels: statusLabels,
                                selectedIndex:
                                    _statuses.indexOf(selectedStatus).clamp(0, 3),
                                onSelected: (i) {
                                  ref
                                      .read(librarySelectedStatusProvider.notifier)
                                      .state = _statuses[i];
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Collection Shelves + Top 4 Horizontal Chip Row
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
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
                      ),

                      // Continue Watching Rail
                      if (showContinueWatching)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 10),
                            child: ContinueWatchingSection(
                              watchingDramas: watchingDramas,
                              onDramaTap: (d) => widget.onDramaTap(d.id),
                              onIncrementEpisode: (d) => ref
                                  .read(dramaControllerProvider)
                                  .incrementEpisodeQuick(d),
                            ),
                          ),
                        ),

                      // Empty filter results vs Grid / List
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 90),
                              child: IosEmptyState(
                                icon: MoglogIcons.search,
                                title: 'No Matching Shows',
                                subtitle:
                                    'Try adjusting your search query or clearing active filters.',
                                actionLabel: 'Clear Filters',
                                onAction: () {
                                  _searchController.clear();
                                  ref.read(librarySearchQueryProvider.notifier).state = '';
                                  ref.read(librarySelectedStatusProvider.notifier).state = 'All';
                                  ref.read(librarySelectedShelfProvider.notifier).state = null;
                                  ref.read(libraryFilterStateProvider.notifier).state =
                                      const LibraryFilterState();
                                },
                              ),
                            ),
                          ),
                        )
                      else if (settings.layoutMode == LibraryLayoutMode.grid)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 104),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: effectiveColumns,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 11,
                              childAspectRatio: 0.58,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final drama = filtered[index];
                                return PosterGridItem(
                                  drama: drama,
                                  isTopFour: settings.topFourFavoriteIds
                                      .contains(drama.id),
                                  multiSelectMode: _multiSelectMode,
                                  isSelected: _selectedIds.contains(drama.id),
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
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 104),
                          sliver: SliverList.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final drama = filtered[index];
                              return CompactDramaRow(
                                drama: drama,
                                isTopFour: settings.topFourFavoriteIds
                                    .contains(drama.id),
                                multiSelectMode: _multiSelectMode,
                                isSelected: _selectedIds.contains(drama.id),
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
                                  final ctrl = ref.read(dramaControllerProvider);
                                  ctrl.moveToRecycleBin(drama);
                                  ref.read(toastProvider.notifier).show(
                                    'Moved "${drama.title}" to Recycle Bin',
                                    actionLabel: 'Undo',
                                    onAction: () => ctrl.restoreDrama(drama),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        ],
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
    return IosPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      hapticOnTap: true,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? c.accent
              : (isAction ? Colors.transparent : c.secondaryBackground),
          borderRadius: MoglogShapes.pill,
          border: Border.all(
            color: selected
                ? c.accent
                : (isAction ? c.accent.withValues(alpha: 0.6) : c.separator),
            width: 0.8,
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
                    : (iconColor ?? (isAction ? c.accent : c.label)),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: t.caption.copyWith(
                color: selected
                    ? c.onAccent
                    : (isAction ? c.accent : c.label),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
