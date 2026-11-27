import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const RecycleBinScreen({super.key, required this.onBack});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (!_headerCollapsed && offset > 48) {
      setState(() => _headerCollapsed = true);
    } else if (_headerCollapsed && offset < 14) {
      setState(() => _headerCollapsed = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final deletedShows = ref
        .watch(currentDramasProvider)
        .where((d) => d.isDeleted)
        .toList()
      ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'Recycle Bin',
            collapsed: deletedShows.isEmpty ? true : _headerCollapsed,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              tooltip: 'Back',
              onTap: widget.onBack,
            ),
            trailingActions: deletedShows.isNotEmpty
                ? [
                    if (deletedShows.length > 1)
                      IosTertiaryButton(
                        text: 'Restore All',
                        size: MoglogButtonSize.small,
                        onTap: () async {
                          final ctrl = ref.read(dramaControllerProvider);
                          await ctrl.restoreDramasBatch(deletedShows);
                          ref.read(toastProvider.notifier).show(
                                'Restored ${deletedShows.length} shows to library',
                              );
                        },
                      ),
                    IosTertiaryButton(
                      text: 'Empty',
                      size: MoglogButtonSize.small,
                      textColor: c.destructive,
                      onTap: () {
                        showIosActionSheet(
                          context: context,
                          title: 'Empty Recycle Bin?',
                          message:
                              'Permanently delete ${deletedShows.length} show${deletedShows.length == 1 ? "" : "s"}? This cannot be undone.',
                          actions: [
                            ActionSheetItem(
                              label: 'Empty Recycle Bin',
                              isDestructive: true,
                              onTap: () async {
                                await ref
                                    .read(dramaControllerProvider)
                                    .emptyRecycleBin();
                                ref
                                    .read(toastProvider.notifier)
                                    .show('Recycle Bin emptied');
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ]
                : null,
          ),
          Expanded(
            child: deletedShows.isEmpty
                ? const Center(
                    child: IosEmptyState(
                      icon: MoglogIcons.trash,
                      title: 'Recycle Bin is Empty',
                      subtitle:
                          'Deleted shows stay here for 30 days before being permanently removed.',
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      MoglogSpacing.md,
                      MoglogSpacing.sm,
                      MoglogSpacing.md,
                      48,
                    ),
                    itemCount: deletedShows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final drama = deletedShows[idx];
                      final elapsedDays = drama.deletedAt > 0
                          ? ((nowMs - drama.deletedAt) ~/
                              const Duration(days: 1).inMilliseconds)
                          : 0;
                      final daysLeft = max(1, 30 - elapsedDays);

                      return Dismissible(
                        key: ValueKey('bin_${drama.id}'),
                        confirmDismiss: (direction) async {
                          final ctrl = ref.read(dramaControllerProvider);
                          if (direction == DismissDirection.startToEnd) {
                            await ctrl.restoreDrama(drama);
                            ref
                                .read(toastProvider.notifier)
                                .show('Restored "${drama.title}"');
                            return true;
                          } else {
                            var confirmed = false;
                            await showIosActionSheet(
                              context: context,
                              title: 'Delete "${drama.title}" Forever?',
                              message:
                                  'This show will be permanently removed and cannot be recovered.',
                              actions: [
                                ActionSheetItem(
                                  label: 'Delete Forever',
                                  icon: MoglogIcons.trash,
                                  isDestructive: true,
                                  onTap: () => confirmed = true,
                                ),
                              ],
                            );
                            if (!confirmed) return false;
                            await ctrl.deleteDramaPermanently(drama);
                            ref
                                .read(toastProvider.notifier)
                                .show('Permanently deleted "${drama.title}"');
                            return true;
                          }
                        },
                        background: Container(
                          decoration: ShapeDecoration(
                            color: c.accent,
                            shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
                          ),
                          padding: const EdgeInsets.only(left: 18),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(MoglogIcons.rotateCcw, color: c.onAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Restore',
                                style: t.subhead.copyWith(
                                  color: c.onAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          decoration: ShapeDecoration(
                            color: c.destructive,
                            shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
                          ),
                          padding: const EdgeInsets.only(right: 18),
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Delete Forever',
                                style: t.subhead.copyWith(
                                  color: c.onDestructive,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(MoglogIcons.trash, color: c.onDestructive),
                            ],
                          ),
                        ),
                        child: IosCard(
                          padding: const EdgeInsets.all(11),
                          child: Row(
                            children: [
                              PosterImage(
                                url: drama.posterPath,
                                width: 46,
                                height: 66,
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(9)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      drama.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.callout.copyWith(
                                        color: c.label,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Deletes permanently in $daysLeft day${daysLeft == 1 ? "" : "s"}',
                                      style: t.caption.copyWith(
                                        color: c.secondaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IosCircleIconButton(
                                icon: MoglogIcons.rotateCcw,
                                size: 34,
                                iconSize: 16,
                                tint: c.accentText,
                                tooltip: 'Restore ${drama.title}',
                                onTap: () async {
                                  await ref
                                      .read(dramaControllerProvider)
                                      .restoreDrama(drama);
                                  ref
                                      .read(toastProvider.notifier)
                                      .show('Restored "${drama.title}"');
                                },
                              ),
                              const SizedBox(width: 2),
                              IosCircleIconButton(
                                icon: MoglogIcons.trash,
                                size: 34,
                                iconSize: 16,
                                tint: c.destructive,
                                tooltip: 'Delete ${drama.title} permanently',
                                onTap: () {
                                  showIosActionSheet(
                                    context: context,
                                    title: 'Delete "${drama.title}" Forever?',
                                    message:
                                        'This show will be permanently removed and cannot be recovered.',
                                    actions: [
                                      ActionSheetItem(
                                        label: 'Delete Forever',
                                        icon: MoglogIcons.trash,
                                        isDestructive: true,
                                        onTap: () async {
                                          await ref
                                              .read(dramaControllerProvider)
                                              .deleteDramaPermanently(drama);
                                          ref.read(toastProvider.notifier).show(
                                                'Permanently deleted "${drama.title}"',
                                              );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
