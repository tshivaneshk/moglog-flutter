import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';

class RecycleBinScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const RecycleBinScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            collapsed: true,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              onTap: onBack,
            ),
            trailingActions: deletedShows.isNotEmpty
                ? [
                    if (deletedShows.length > 1)
                      IosPressable(
                        onTap: () async {
                          final ctrl = ref.read(dramaControllerProvider);
                          await ctrl.restoreDramasBatch(deletedShows);
                          ref.read(toastProvider.notifier).show(
                                'Restored ${deletedShows.length} shows to library',
                              );
                        },
                        hapticOnTap: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'Restore All',
                            style: t.callout.copyWith(
                              color: c.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    IosPressable(
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
                      hapticOnTap: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          'Empty',
                          style: t.callout.copyWith(
                            color: c.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
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
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: MoglogShapes.card,
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
                                'Delete Forever',
                                style: t.subhead.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(MoglogIcons.trash, color: Colors.white),
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: ShapeDecoration(
                            color: c.secondaryBackground,
                            shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
                          ),
                          child: Row(
                            children: [
                              PosterImage(
                                url: drama.posterPath,
                                width: 44,
                                height: 64,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      drama.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.headline.copyWith(
                                        color: c.label,
                                        fontSize: 15.5,
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
                                size: 32,
                                iconSize: 15,
                                tint: c.accent,
                                tooltip: 'Restore',
                                onTap: () async {
                                  await ref
                                      .read(dramaControllerProvider)
                                      .restoreDrama(drama);
                                  ref
                                      .read(toastProvider.notifier)
                                      .show('Restored "${drama.title}"');
                                },
                              ),
                              const SizedBox(width: 6),
                              IosCircleIconButton(
                                icon: MoglogIcons.trash,
                                size: 32,
                                iconSize: 15,
                                tint: c.destructive,
                                tooltip: 'Delete Permanently',
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
