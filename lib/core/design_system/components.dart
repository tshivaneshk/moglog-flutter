import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'icons.dart';
import 'motion_haptics.dart';
import 'shapes.dart';
import 'theme.dart';

/// Translucent frosted iOS navigation/tab bar matching Kotlin `IosFrostedBar`.
/// Uses pure translucent surface without expensive live BackdropFilter overdraw so 120Hz scrolling stays locked.
class IosFrostedBar extends StatelessWidget {
  final Widget child;
  final bool showTopBorder;
  final bool showBottomBorder;

  const IosFrostedBar({
    super.key,
    required this.child,
    this.showTopBorder = false,
    this.showBottomBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.frostedBarSurface,
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

  const IosLargeTitleHeader({
    super.key,
    required this.title,
    this.collapsed = false,
    this.leadingActions,
    this.trailingActions,
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

    return IosFrostedBar(
      showBottomBorder: effectiveCollapsed,
      child: SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            hPad,
            effectiveCollapsed ? 6 : 10,
            hPad,
            effectiveCollapsed ? 8 : 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: (isLandscape || isCompactWindow) ? 40 : 44,
                child: Row(
                  children: [
                    if (leadingActions != null) ...[
                      leadingActions!,
                      const SizedBox(width: 8),
                    ],
                    if (inlineNoLeading)
                      Expanded(
                        child: Text(
                          title,
                          style: (size.width < 300 ? t.headline : t.title3)
                              .copyWith(color: c.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: effectiveCollapsed ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: effectiveCollapsed
                              ? Text(
                                  title,
                                  style: t.headline.copyWith(color: c.label),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    if (trailingActions != null && trailingActions!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < trailingActions!.length; i++) ...[
                            if (i > 0) SizedBox(width: size.width < 320 ? 6 : 8),
                            trailingActions![i],
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: effectiveCollapsed
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          title,
                          style: t.largeTitle.copyWith(color: c.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
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
    return IosPressable(
      onTap: onTap,
      hapticOnTap: true,
      pressedScale: 0.92,
      child: Tooltip(
        message: tooltip ?? '',
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
              style: t.footnote.copyWith(color: c.secondaryLabel),
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
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Text(
                  title,
                  style: t.body.copyWith(
                    color: titleColor ?? c.label,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: t.footnote.copyWith(color: c.secondaryLabel),
                    maxLines: 2,
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

  const IosSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackground,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
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
                      ? (activeColor ?? (c.isDark ? c.elevatedSurface : Colors.white))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: c.isDark ? 0.25 : 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.footnote.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (activeColor != null ? c.onAccent : c.label)
                          : c.secondaryLabel,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
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

  const ActionSheetItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
    this.isSelected = false,
  });
}

Future<T?> showIosBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final c = context.colors;
  final maxH = MediaQuery.sizeOf(context).height * 0.84;
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
                        style: t.footnote.copyWith(color: c.secondaryLabel),
                        textAlign: TextAlign.center,
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
                                style: t.callout.copyWith(
                                  fontWeight: actions[i].isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: actions[i].isDestructive
                                      ? c.destructive
                                      : (actions[i].isSelected ? c.accent : c.label),
                                ),
                              ),
                            ),
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

class PosterImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const PosterImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius = MoglogShapes.poster,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final cacheW =
        width != null && width!.isFinite ? (width! * dpr).round().clamp(96, 720) : 540;
    final cacheH =
        height != null && height!.isFinite ? (height! * dpr).round().clamp(96, 1080) : null;

    final placeholder = Container(
      width: width,
      height: height,
      color: c.tertiaryBackground,
      alignment: Alignment.center,
      child: Icon(MoglogIcons.library, size: 22, color: c.tertiaryLabel),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: url.trim().isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: fit,
              memCacheWidth: cacheW,
              memCacheHeight: cacheH,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => Container(
                width: width,
                height: height,
                color: c.tertiaryBackground,
              ),
              errorWidget: (_, __, ___) => placeholder,
            ),
    );
  }
}
