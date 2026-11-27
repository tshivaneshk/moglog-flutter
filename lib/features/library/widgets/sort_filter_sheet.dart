import 'package:flutter/material.dart';

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/motion_haptics.dart';
import '../../../core/design_system/shapes.dart';
import '../../../core/design_system/theme.dart';
import '../../../core/design_system/tokens.dart';
import '../../../domain/model/app_settings.dart';

Future<void> showSortFilterSheet({
  required BuildContext context,
  required LibraryFilterState currentState,
  required List<String> availableGenres,
  required ValueChanged<LibraryFilterState> onApply,
  required VoidCallback onReset,
}) {
  return showIosBottomSheet<void>(
    context: context,
    builder: (ctx) => _SortFilterSheetContent(
      currentState: currentState,
      availableGenres: availableGenres,
      onApply: onApply,
      onReset: onReset,
    ),
  );
}

class _SortFilterSheetContent extends StatefulWidget {
  final LibraryFilterState currentState;
  final List<String> availableGenres;
  final ValueChanged<LibraryFilterState> onApply;
  final VoidCallback onReset;

  const _SortFilterSheetContent({
    required this.currentState,
    required this.availableGenres,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_SortFilterSheetContent> createState() =>
      _SortFilterSheetContentState();
}

class _SortFilterSheetContentState extends State<_SortFilterSheetContent> {
  late LibrarySortOption _sortOption;
  late Set<String> _selectedGenres;
  late double _minRating;
  late bool _onlyPartiallyDone;

  @override
  void initState() {
    super.initState();
    _sortOption = widget.currentState.sortOption;
    _selectedGenres = Set<String>.from(widget.currentState.selectedGenres);
    _minRating = widget.currentState.minRating;
    _onlyPartiallyDone = widget.currentState.onlyPartiallyDone;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return SingleChildScrollView(
      padding: MoglogSpacing.sheetPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sort & Filter',
                  style: t.title2.copyWith(color: c.label),
                ),
              ),
              IosTertiaryButton(
                text: 'Reset',
                textColor: c.destructive,
                size: MoglogButtonSize.small,
                onTap: () {
                  widget.onReset();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          IosGroupedSection(
            header: 'Sort By',
            children: [
              for (var i = 0; i < LibrarySortOption.values.length; i++) ...[
                Builder(
                  builder: (_) {
                    final opt = LibrarySortOption.values[i];
                    final selected = _sortOption == opt;
                    return IosGroupedRow(
                      title: opt.label,
                      titleColor: selected ? c.accentText : c.label,
                      showDivider: i < LibrarySortOption.values.length - 1,
                      onTap: () {
                        MoglogHaptics.selectionChanged();
                        setState(() => _sortOption = opt);
                      },
                      trailing: selected
                          ? Icon(
                              MoglogIcons.check,
                              size: 18,
                              color: c.accentText,
                            )
                          : null,
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          IosGroupedSection(
            header: 'Season Progress',
            footer: 'Shows with completed seasons and more left.',
            children: [
              IosSwitchRow(
                title: 'Partially Done Series',
                subtitle: '1+ seasons finished, more left',
                value: _onlyPartiallyDone,
                showDivider: false,
                onChanged: (v) => setState(() => _onlyPartiallyDone = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'MINIMUM RATING',
              style: t.caption.copyWith(
                color: c.secondaryLabel,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Row(
            children: [
              for (final pair in const [
                (0.0, 'Any'),
                (7.0, '7.0+'),
                (8.0, '8.0+'),
                (9.0, '9.0+'),
              ]) ...[
                if (pair.$1 > 0.0) const SizedBox(width: 8),
                Expanded(
                  child: IosPressable(
                    semanticSelected: _minRating == pair.$1,
                    onTap: () {
                      MoglogHaptics.selectionChanged();
                      setState(() => _minRating = pair.$1);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: _minRating == pair.$1
                              ? c.accent
                              : c.tertiaryBackground,
                          shape: MoglogShapes.smooth(
                            MoglogShapes.controlRadius,
                            side: BorderSide(
                              color: _minRating == pair.$1
                                  ? c.accent
                                  : c.glassBorder,
                              width: c.hairlineWidth,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Text(
                              pair.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.footnote.copyWith(
                                color: _minRating == pair.$1
                                    ? c.onAccent
                                    : c.label,
                                fontWeight: _minRating == pair.$1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.availableGenres.isNotEmpty) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'GENRES',
                style: t.caption.copyWith(
                  color: c.secondaryLabel,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.availableGenres.map((genre) {
                final selected = _selectedGenres.contains(genre);
                return IosPressable(
                  semanticSelected: selected,
                  onTap: () {
                    MoglogHaptics.selectionChanged();
                    setState(() {
                      if (selected) {
                        _selectedGenres.remove(genre);
                      } else {
                        _selectedGenres.add(genre);
                      }
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: ShapeDecoration(
                      color: selected ? c.accent : c.tertiaryBackground,
                      shape: MoglogShapes.smooth(
                        11,
                        side: BorderSide(
                          color: selected ? c.accent : c.glassBorder,
                          width: c.hairlineWidth,
                        ),
                      ),
                    ),
                    child: Text(
                      genre,
                      style: t.footnote.copyWith(
                        color: selected ? c.onAccent : c.label,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          IosPrimaryButton(
            text: 'Apply',
            onTap: () {
              widget.onApply(
                LibraryFilterState(
                  sortOption: _sortOption,
                  selectedGenres: _selectedGenres,
                  minRating: _minRating,
                  onlyPartiallyDone: _onlyPartiallyDone,
                ),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
