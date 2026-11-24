import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/model/drama.dart';
import '../network/image_cache_manager.dart';
import 'icons.dart';
import 'motion_haptics.dart';
import 'shapes.dart';
import 'theme.dart';
import 'tokens.dart';

/// Translucent frosted iOS navigation/tab bar matching Kotlin `IosFrostedBar`.
/// Uses pure translucent surface without expensive live BackdropFilter overdraw so 120Hz scrolling stays locked.
class IosFrostedBar extends StatelessWidget {
  final Widget child;
  final bool showTopBorder;
  final bool showBottomBorder;
  final Color? backgroundColor;

  const IosFrostedBar({
    super.key,
    required this.child,
    this.showTopBorder = false,
    this.showBottomBorder = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? c.frostedBarSurface,
          border: Border(
            top: showTopBorder
                ? BorderSide(color: c.separator, width: c.hairlineWidth)
                : BorderSide.none,
            bottom: showBottomBorder
                ? BorderSide(color: c.separator, width: c.hairlineWidth)
                : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Collapsing iOS Large Title Header matching Kotlin `IosLargeTitleHeader`.
/// Automatically collapses to an inline compact bar in landscape or pop-up multi-window mode.
class IosLargeTitleHeader extends StatelessWidget {
  final String title;
  final bool collapsed;
  final Widget? leadingActions;
  final List<Widget>? trailingActions;
  final Widget? bottomContent;

  const IosLargeTitleHeader({
    super.key,
    required this.title,
    this.collapsed = false,
    this.leadingActions,
    this.trailingActions,
    this.bottomContent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final size = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompactWindow = size.height < 460 || size.width < 280;
    final effectiveCollapsed = collapsed || isLandscape || isCompactWindow;
    final hPad = size.width < 320 ? 12.0 : 16.0;
    final inlineNoLeading =
        (isLandscape || isCompactWindow) && leadingActions == null;
    final trailingCount = trailingActions?.length ?? 0;
    final safeCenterPad = inlineNoLeading
        ? 0.0
        : trailingCount >= 3
            ? 96.0
            : trailingCount == 2
                ? 76.0
                : (leadingActions != null || trailingCount == 1)
                    ? 46.0
                    : 8.0;

    return IosFrostedBar(
      showBottomBorder: effectiveCollapsed,
      backgroundColor: effectiveCollapsed ? c.frostedBarSurface : c.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            hPad,
            effectiveCollapsed ? 4 : 6,
            hPad,
            bottomContent != null ? (isLandscape || isCompactWindow ? 6 : 8) : 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: (isLandscape || isCompactWindow) ? 40 : 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (leadingActions != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: leadingActions!,
                      ),
                    if (inlineNoLeading)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: trailingCount > 0
                                ? (trailingCount * 42.0)
                                : 0.0,
                          ),
                          child: Text(
                            title,
                            style: (size.width < 300 ? t.headline : t.title3)
                                .copyWith(color: c.label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      AnimatedOpacity(
                        opacity: effectiveCollapsed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 140),
                        child: IgnorePointer(
                          ignoring: !effectiveCollapsed,
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: safeCenterPad),
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: t.headline.copyWith(color: c.label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    if (trailingActions != null && trailingActions!.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0;
                                i < trailingActions!.length;
                                i++) ...[
                              if (i > 0)
                                SizedBox(width: size.width < 320 ? 6 : 8),
                              trailingActions![i],
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: effectiveCollapsed
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 6),
                        child: Text(
                          title,
                          style: t.largeTitle.copyWith(color: c.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
              if (bottomContent != null) bottomContent!,
            ],
          ),
        ),
      ),
    );
  }
}

class IosCircleIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final Color? tint;
  final Color? backgroundColor;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool showBadgeDot;

  const IosCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.tint,
    this.backgroundColor,
    this.size = 36,
    this.iconSize = 18,
    this.showBadgeDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: tooltip,
      child: IosPressable(
        onTap: onTap,
        hapticOnTap: true,
        pressedScale: 0.92,
        child: Tooltip(
          message: tooltip ?? '',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: backgroundColor ?? c.secondaryBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.separator.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: iconSize, color: tint ?? c.label),
                  ),
                  if (showBadgeDot)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: c.destructive,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.background, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showIosInfoSheet({
  required BuildContext context,
  required String title,
  required String description,
}) {
  final c = context.colors;
  final t = context.typo;
  showIosBottomSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MoglogIcons.info, size: 19, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: t.headline.copyWith(color: c.label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: t.subhead.copyWith(color: c.secondaryLabel, height: 1.45),
          ),
          const SizedBox(height: 18),
          IosSecondaryButton(
            text: 'Got it',
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}

class IosInfoButton extends StatelessWidget {
  final String title;
  final String description;
  final double iconSize;

  const IosInfoButton({
    super.key,
    required this.title,
    required this.description,
    this.iconSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MoglogHaptics.selectionChanged();
        showIosInfoSheet(
          context: context,
          title: title,
          description: description,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          MoglogIcons.info,
          size: iconSize,
          color: c.tertiaryLabel,
        ),
      ),
    );
  }
}

class IosGroupedSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const IosGroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null && header!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 7, right: 16),
            child: Text(
              header!.toUpperCase(),
              style: t.caption.copyWith(
                color: c.secondaryLabel,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        Material(
          color: c.secondaryBackground,
          shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
        if (footer != null && footer!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 7, right: 16),
            child: Text(
              footer!,
              style: t.caption.copyWith(
                color: c.secondaryLabel,
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }
}

class IosGroupedRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconBackground;
  final Color? titleColor;
  final Widget? trailing;
  final bool showChevron;
  final bool showDivider;
  final VoidCallback? onTap;
  final String? infoDescription;

  const IosGroupedRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackground,
    this.titleColor,
    this.trailing,
    this.showChevron = false,
    this.showDivider = true,
    this.onTap,
    this.infoDescription,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBackground ?? c.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(
                          color: titleColor ?? c.label,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    if (infoDescription != null &&
                        infoDescription!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      IosInfoButton(
                        title: title,
                        description: infoDescription!,
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle!,
                    style: t.caption.copyWith(
                      color: c.secondaryLabel,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: 6),
            Icon(MoglogIcons.chevronRight, size: 18, color: c.tertiaryLabel),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap != null)
          IosPressable(
            onTap: onTap,
            hapticOnTap: true,
            pressedScale: 0.99,
            child: rowContent,
          )
        else
          rowContent,
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 59 : 16),
            child: Divider(
              height: c.hairlineWidth,
              thickness: c.hairlineWidth,
              color: c.separator,
            ),
          ),
      ],
    );
  }
}

class IosSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconBackground;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  final String? infoDescription;

  const IosSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackground,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
    this.infoDescription,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IosGroupedRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconBackground: iconBackground,
      showDivider: showDivider,
      infoDescription: infoDescription,
      onTap: () => onChanged(!value),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: c.accent,
        onChanged: (v) {
          MoglogHaptics.selectionChanged();
          onChanged(v);
        },
      ),
    );
  }
}

class IosSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? activeColor;

  const IosSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = labels.isNotEmpty
            ? (constraints.maxWidth - 6) / labels.length
            : constraints.maxWidth;
        final double labelFontSize;
        if (segmentWidth < 58) {
          labelFontSize = 9.5;
        } else if (segmentWidth < 74) {
          labelFontSize = 10.5;
        } else if (segmentWidth < 92) {
          labelFontSize = 11.5;
        } else {
          labelFontSize = 13.0;
        }

        return Container(
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: c.tertiaryBackground,
            borderRadius: MoglogShapes.control,
          ),
          child: Row(
            children: List.generate(labels.length, (i) {
              final isSelected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!isSelected) {
                      MoglogHaptics.selectionChanged();
                      onSelected(i);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (activeColor ??
                              (c.isDark ? c.elevatedSurface : Colors.white))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: c.isDark ? 0.25 : 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          softWrap: false,
                          style: t.footnote.copyWith(
                            fontSize: labelFontSize,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? (activeColor != null ? c.onAccent : c.label)
                                : c.secondaryLabel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class IosSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final FocusNode? focusNode;

  const IosSearchBar({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    this.onClear,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.tertiaryBackground,
        borderRadius: MoglogShapes.control,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: Row(
        children: [
          Icon(MoglogIcons.search, size: 17, color: c.secondaryLabel),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: t.subhead.copyWith(color: c.label),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: t.subhead.copyWith(color: c.secondaryLabel),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
                onClear?.call();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(MoglogIcons.close, size: 16, color: c.secondaryLabel),
              ),
            ),
        ],
      ),
    );
  }
}

class IosPrimaryButton extends StatelessWidget {
  final String text;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool loading;

  const IosPrimaryButton({
    super.key,
    required this.text,
    this.leadingIcon,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final enabled = onTap != null && !loading;
    return IosPressable(
      enabled: enabled,
      onTap: onTap,
      hapticOnTap: true,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: ShapeDecoration(
          color: (backgroundColor ?? c.accent).withValues(alpha: enabled ? 1.0 : 0.45),
          shape: MoglogShapes.smooth(12),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foregroundColor ?? c.onAccent,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 18, color: foregroundColor ?? c.onAccent),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.callout.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foregroundColor ?? c.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class IosSecondaryButton extends StatelessWidget {
  final String text;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final Color? textColor;

  const IosSecondaryButton({
    super.key,
    required this.text,
    this.leadingIcon,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return IosPressable(
      enabled: onTap != null,
      onTap: onTap,
      hapticOnTap: true,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: ShapeDecoration(
          color: c.tertiaryBackground,
          shape: MoglogShapes.smooth(12),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: textColor ?? c.label),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.callout.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor ?? c.label,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionSheetItem {
  final String label;
  final IconData? icon;
  final bool isDestructive;
  final bool isSelected;
  final VoidCallback onTap;
  final String? infoDescription;

  const ActionSheetItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
    this.isSelected = false,
    this.infoDescription,
  });
}

Future<T?> showIosBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  List<ChangeNotifier> disposeAfter = const [],
}) {
  final c = context.colors;
  final maxH = MediaQuery.sizeOf(context).height * 0.84;
  return _showIosBottomSheetImpl<T>(
    context: context,
    c: c,
    maxH: maxH,
    builder: builder,
    isScrollControlled: isScrollControlled,
  ).whenComplete(() {
    if (disposeAfter.isEmpty) return;
    // Dispose after the dismiss animation finishes to avoid use-after-dispose.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      for (final n in disposeAfter) {
        n.dispose();
      }
    });
  });
}

Future<T?> _showIosBottomSheetImpl<T>({
  required BuildContext context,
  required MoglogColors c,
  required double maxH,
  required WidgetBuilder builder,
  required bool isScrollControlled,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    constraints: BoxConstraints(maxHeight: maxH),
    backgroundColor: c.secondaryBackground,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(borderRadius: MoglogShapes.topSheet),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: c.separator,
                  borderRadius: MoglogShapes.pill,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showIosActionSheet({
  required BuildContext context,
  String? title,
  String? message,
  required List<ActionSheetItem> actions,
  String cancelLabel = 'Cancel',
}) {
  final c = context.colors;
  final t = context.typo;
  return showIosBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: t.headline.copyWith(color: c.label),
                        textAlign: TextAlign.center,
                      ),
                    if (message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: t.caption.copyWith(
                          color: c.secondaryLabel,
                          fontSize: 11.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            Material(
              color: c.tertiaryBackground,
              shape: MoglogShapes.smooth(14),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    IosPressable(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        actions[i].onTap();
                      },
                      hapticOnTap: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            if (actions[i].icon != null) ...[
                              Icon(
                                actions[i].icon,
                                size: 19,
                                color: actions[i].isDestructive
                                    ? c.destructive
                                    : (actions[i].isSelected ? c.accent : c.label),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                actions[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.callout.copyWith(
                                  fontSize: 15,
                                  fontWeight: actions[i].isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: actions[i].isDestructive
                                      ? c.destructive
                                      : (actions[i].isSelected ? c.accent : c.label),
                                ),
                              ),
                            ),
                            if (actions[i].infoDescription != null &&
                                actions[i].infoDescription!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              IosInfoButton(
                                title: actions[i].label,
                                description: actions[i].infoDescription!,
                              ),
                            ],
                            if (actions[i].isSelected)
                              Icon(MoglogIcons.check, size: 18, color: c.accent),
                          ],
                        ),
                      ),
                    ),
                    if (i < actions.length - 1)
                      Divider(
                        height: c.hairlineWidth,
                        thickness: c.hairlineWidth,
                        color: c.separator,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            IosSecondaryButton(
              text: cancelLabel,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    },
  );
}

class IosEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const IosEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.secondaryBackground,
              shape: BoxShape.circle,
              border: Border.all(color: c.separator, width: 0.75),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: c.accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: t.title3.copyWith(color: c.label),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: t.subhead.copyWith(color: c.secondaryLabel),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 210,
              child: IosPrimaryButton(text: actionLabel!, onTap: onAction),
            ),
          ],
        ],
      ),
    );
  }
}

class IosToastBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const IosToastBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Material(
      color: c.elevatedSurface,
      elevation: 8,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: MoglogShapes.pill,
        side: BorderSide(color: c.separator, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message,
                style: t.footnote.copyWith(
                  color: c.label,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: t.footnote.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = MoglogShapes.poster,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final color = Color.lerp(
          c.secondaryBackground,
          c.tertiaryBackground,
          _ctrl.value,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

class PosterImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final bool isCircular;

  const PosterImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius = MoglogShapes.poster,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.isCircular = false,
  });

  @override
  State<PosterImage> createState() => _PosterImageState();
}

class _PosterImageState extends State<PosterImage> {
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant PosterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();
      _retryCount = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryCount >= 2 || (_retryTimer?.isActive ?? false)) return;
    _retryTimer = Timer(Duration(milliseconds: 700 * (_retryCount + 1)), () {
      if (!mounted) return;
      setState(() => _retryCount++);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.width != null && widget.width!.isFinite) {
      return _buildWithWidth(context, widget.width);
    }
    if (widget.isCircular) {
      return _buildWithWidth(context, widget.height ?? 64);
    }
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final measuredW =
            constraints.hasBoundedWidth && constraints.maxWidth > 0
                ? constraints.maxWidth
                : null;
        return _buildWithWidth(ctx, measuredW);
      },
    );
  }

  Widget _buildWithWidth(BuildContext context, double? effectiveWidth) {
    final c = context.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final cacheW = effectiveWidth != null
        ? (effectiveWidth * dpr).round().clamp(96, 680)
        : 540;
    final optimizedUrl = optimizeTmdbImageUrl(
      widget.url,
      targetWidthDp: effectiveWidth,
      dpr: dpr,
    );

    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: c.tertiaryBackground,
      alignment: Alignment.center,
      child: Icon(
        widget.isCircular ? MoglogIcons.person : MoglogIcons.library,
        size: widget.isCircular ? 24 : 22,
        color: c.tertiaryLabel,
      ),
    );

    final Widget imageWidget = optimizedUrl.isEmpty
        ? placeholder
        : CachedNetworkImage(
            key: ValueKey('${optimizedUrl}_r$_retryCount'),
            cacheManager: MoglogImageCacheManager.instance,
            imageUrl: optimizedUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment is Alignment
                ? widget.alignment as Alignment
                : Alignment.center,
            memCacheWidth: cacheW,
            maxWidthDiskCache: cacheW,
            fadeInDuration: const Duration(milliseconds: 90),
            fadeOutDuration: const Duration(milliseconds: 60),
            placeholder: (_, __) => Container(
              width: widget.width,
              height: widget.height,
              color: c.tertiaryBackground,
            ),
            errorWidget: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleRetry());
              return placeholder;
            },
          );

    if (widget.isCircular) {
      return SizedBox.square(
        dimension: widget.width ?? widget.height ?? 64,
        child: ClipOval(child: imageWidget),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: imageWidget,
    );
  }
}
