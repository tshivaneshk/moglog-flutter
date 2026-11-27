import 'dart:async';
import 'dart:ui' as ui;

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

/// Translucent iOS navigation/sticky bar surface.
/// Intentionally omits `BackdropFilter` so `BackdropFilter` is strictly reserved
/// for the floating tab bar and modal sheets (120Hz scroll budget).
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
                ? BorderSide(color: c.glassBorder, width: c.hairlineWidth)
                : BorderSide.none,
            bottom: showBottomBorder
                ? BorderSide(color: c.glassBorder, width: c.hairlineWidth)
                : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Collapsing iOS 18 Large Title Header:
/// - Expands to crisp 34pt `largeTitle` at scroll top
/// - Collapses smoothly on scroll to a **centered inline title** (`17pt semibold`)
/// - Adapts automatically to landscape / compact multi-window and scales up to 2.0x text size.
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
    final reduceMotion = context.reduceMotion;
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompactWindow = size.height < 460 || size.width < 280;
    final effectiveCollapsed = collapsed || isLandscape || isCompactWindow;
    final hPad = size.width < 340 ? MoglogSpacing.sm : MoglogSpacing.md;
    final inlineCompactNoLeading =
        (isLandscape || isCompactWindow) && leadingActions == null;
    final trailingCount = trailingActions?.length ?? 0;
    final safeCenterPad = inlineCompactNoLeading
        ? 0.0
        : trailingCount >= 3
            ? 148.0
            : trailingCount == 2
                ? 100.0
                : (leadingActions != null || trailingCount == 1)
                    ? 52.0
                    : 12.0;

    final minBarHeight = (isLandscape || isCompactWindow) ? 44.0 : 48.0;

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
            bottomContent != null
                ? (isLandscape || isCompactWindow ? 6 : 8)
                : 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: minBarHeight),
                child: inlineCompactNoLeading
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: (size.width < 300 ? t.headline : t.title3)
                                  .copyWith(color: c.label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trailingActions != null &&
                              trailingActions!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0;
                                    i < trailingActions!.length;
                                    i++) ...[
                                  if (i > 0)
                                    SizedBox(width: size.width < 320 ? 2 : 4),
                                  trailingActions![i],
                                ],
                              ],
                            ),
                          ],
                        ],
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          if (leadingActions != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: leadingActions!,
                            ),
                          AnimatedOpacity(
                            opacity: effectiveCollapsed ? 1.0 : 0.0,
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            curve: MoglogMotion.curve,
                            child: IgnorePointer(
                              ignoring: !effectiveCollapsed,
                              child: ExcludeSemantics(
                                excluding: !effectiveCollapsed,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: safeCenterPad,
                                  ),
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
                          ),
                          if (trailingActions != null &&
                              trailingActions!.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0;
                                      i < trailingActions!.length;
                                      i++) ...[
                                    if (i > 0)
                                      SizedBox(width: size.width < 320 ? 2 : 4),
                                    trailingActions![i],
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              AnimatedSize(
                duration:
                    reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                curve: MoglogMotion.curve,
                alignment: Alignment.topLeft,
                child: effectiveCollapsed
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 6),
                        child: Text(
                          title,
                          style: t.largeTitle.copyWith(color: c.label),
                          maxLines: textScale > 1.35 ? 2 : 1,
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

/// Reusable iOS 18 squircle-20 surface card:
/// elevated/grouped fill, 0.5dp hairline border, optional subtle top sheen,
/// soft shadow in light mode, and optional tactile press feedback.
class IosCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double cornerRadius;
  final bool showTopSheen;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  const IosCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MoglogSpacing.md),
    this.backgroundColor,
    this.borderColor,
    this.cornerRadius = MoglogShapes.cardRadius,
    this.showTopSheen = true,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = backgroundColor ?? c.secondaryBackground;
    final shape = MoglogShapes.smooth(
      cornerRadius,
      side: BorderSide(
        color: borderColor ?? c.cardBorder,
        width: c.hairlineWidth,
      ),
    );

    Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: showTopSheen ? null : bg,
        gradient: showTopSheen
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.42],
                colors: [
                  Color.alphaBlend(c.cardSheenTop, bg),
                  bg,
                ],
              )
            : null,
        shadows: c.isDark
            ? null
            : [
                BoxShadow(
                  color: c.shadowSoft,
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: MoglogShapes.smooth(cornerRadius)),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      return IosPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        hapticOnTap: true,
        semanticLabel: semanticLabel,
        focusRadius: cornerRadius,
        child: card,
      );
    }
    return card;
  }
}

/// Unified section header used across Library, Discover, Detail, Stats, and Social.
class IosSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const IosSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: MoglogSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: t.title3.copyWith(color: c.label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          ] else if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            IosTertiaryButton(
              text: actionLabel!,
              size: MoglogButtonSize.small,
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class IosCircleIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final Color? tint;
  final Color? backgroundColor;
  final VoidCallback? onTap;
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
    this.size = 38,
    this.iconSize = 20,
    this.showBadgeDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final semanticLabel =
        (tooltip != null && tooltip!.trim().isNotEmpty) ? tooltip! : 'Action';
    final button = IosPressable(
      onTap: onTap,
      enabled: onTap != null,
      hapticOnTap: true,
      hapticType: MoglogTapHaptic.lightImpact,
      pressedScale: 0.94,
      semanticLabel: semanticLabel,
      focusRadius: MoglogShapes.pillRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: MoglogLayout.minTouchTarget,
          minHeight: MoglogLayout.minTouchTarget,
        ),
        child: Center(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor ?? c.glassSurface,
                  gradient: backgroundColor == null
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.alphaBlend(c.cardSheenTop, c.glassSurface),
                            c.glassSurface,
                          ],
                        )
                      : null,
                  border: Border.all(
                    color: c.glassBorder,
                    width: c.hairlineWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.shadowSoft,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: (tint ?? c.label)
                      .withValues(alpha: onTap != null ? 1.0 : 0.4),
                ),
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
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return button;
  }
}

void showIosInfoSheet({
  required BuildContext context,
  required String title,
  required String description,
}) {
  showIosBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      final t = ctx.typo;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MoglogIcons.info, size: 20, color: c.accentText),
                const SizedBox(width: 10),
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
            const SizedBox(height: 20),
            IosSecondaryButton(
              text: 'Got it',
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    },
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
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'More information about $title',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          MoglogHaptics.selectionChanged();
          showIosInfoSheet(
            context: context,
            title: title,
            description: description,
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              MoglogIcons.info,
              size: iconSize,
              color: c.secondaryLabel,
            ),
          ),
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
    final shape = MoglogShapes.smooth(
      MoglogShapes.cardRadius,
      side: BorderSide(color: c.cardBorder, width: c.hairlineWidth),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null && header!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
            child: Text(
              header!.toUpperCase(),
              style: t.caption.copyWith(
                color: c.secondaryLabel,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35],
              colors: [
                Color.alphaBlend(c.cardSheenTop, c.secondaryBackground),
                c.secondaryBackground,
              ],
            ),
            shadows: c.isDark
                ? null
                : [
                    BoxShadow(
                      color: c.shadowSoft,
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
        if (footer != null && footer!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
            child: Text(
              footer!,
              style: t.caption.copyWith(color: c.secondaryLabel),
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
    final badgeBg = iconBackground ?? c.accent;

    final rowContent = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxTrailingW = constraints.maxWidth.isFinite
                ? constraints.maxWidth * 0.42
                : 150.0;
            return Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: ShapeDecoration(
                      shape: MoglogShapes.smooth(9),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _shiftColorLightness(badgeBg, 0.06),
                          _shiftColorLightness(badgeBg, -0.05),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 18, color: c.onMedia),
                  ),
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.callout.copyWith(
                                color: titleColor ?? c.label,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (infoDescription != null &&
                              infoDescription!.isNotEmpty) ...[
                            const SizedBox(width: 2),
                            IosInfoButton(
                              title: title,
                              description: infoDescription!,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: t.caption.copyWith(color: c.secondaryLabel),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxTrailingW),
                    child: trailing!,
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  Icon(
                    MoglogIcons.chevronRight,
                    size: 18,
                    color: c.tertiaryLabel,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap != null)
          IosPressable(
            onTap: onTap,
            hapticOnTap: true,
            pressedScale: 0.985,
            child: rowContent,
          )
        else
          rowContent,
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 61 : 16),
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
      onTap: () {
        MoglogHaptics.selectionChanged();
        onChanged(!value);
      },
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

/// iOS 18 Segmented Control with spring-sliding thumb and glass track.
/// Adapts smoothly to text scaling up to 2.0x without clipping.
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
    final reduceMotion = context.reduceMotion;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final trackHeight = (38.0 + ((textScale - 1.0).clamp(0.0, 1.0) * 18.0));

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Center(
        child: Container(
          height: trackHeight,
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            color: c.tertiaryBackground,
            shape: MoglogShapes.smooth(
              MoglogShapes.controlRadius,
              side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (labels.isEmpty) return const SizedBox.shrink();
              final clampedSelected =
                  selectedIndex.clamp(0, labels.length - 1);
              final segmentWidth = constraints.maxWidth / labels.length;
              final thumbHeight = constraints.maxHeight;
              final resolvedThumbBg = activeColor ??
                  (c.isDark ? c.elevatedSurface : c.secondaryBackground);
              final useCompactCaption = segmentWidth < 80;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration:
                        reduceMotion ? Duration.zero : MoglogMotion.spring,
                    curve: MoglogMotion.springCurve,
                    left: clampedSelected * segmentWidth,
                    top: 0,
                    width: segmentWidth,
                    height: thumbHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: resolvedThumbBg,
                          shape: MoglogShapes.smooth(
                            MoglogShapes.controlRadius - 3,
                            side: BorderSide(
                              color: c.glassBorder,
                              width: c.hairlineWidth,
                            ),
                          ),
                          shadows: [
                            BoxShadow(
                              color: c.shadowSoft,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(labels.length, (i) {
                      final isSelected = i == clampedSelected;
                      final Color labelColor;
                      if (isSelected) {
                        if (activeColor != null) {
                          final est = ThemeData.estimateBrightnessForColor(
                            activeColor!,
                          );
                          labelColor = est == Brightness.dark
                              ? c.onMedia
                              : const Color(0xFF041C0A);
                        } else {
                          labelColor = c.label;
                        }
                      } else {
                        labelColor = c.secondaryLabel;
                      }

                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: isSelected,
                          label: labels[i],
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!isSelected) {
                                MoglogHaptics.selectionChanged();
                                onSelected(i);
                              }
                            },
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: (useCompactCaption
                                            ? t.caption2
                                            : t.footnote)
                                        .copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: labelColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// iOS 18 Rounded Glass Search Bar with leading icon, clear button, and an
/// animated `Cancel` action that slides in on focus or input.
class IosSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool showCancelButton;

  const IosSearchBar({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    this.onClear,
    this.focusNode,
    this.showCancelButton = true,
  });

  @override
  State<IosSearchBar> createState() => _IosSearchBarState();
}

class _IosSearchBarState extends State<IosSearchBar> {
  FocusNode? _ownedFocusNode;
  bool _hasFocus = false;

  FocusNode get _effectiveFocus => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedFocusNode = FocusNode();
    }
    _effectiveFocus.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
    _hasFocus = _effectiveFocus.hasFocus;
  }

  @override
  void didUpdateWidget(covariant IosSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode)?.removeListener(_onFocusChange);
      if (widget.focusNode == null && _ownedFocusNode == null) {
        _ownedFocusNode = FocusNode();
      }
      _effectiveFocus.addListener(_onFocusChange);
      _hasFocus = _effectiveFocus.hasFocus;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChange);
      widget.controller.addListener(_onTextChange);
    }
  }

  void _onFocusChange() {
    if (!mounted) return;
    final next = _effectiveFocus.hasFocus;
    if (_hasFocus != next) setState(() => _hasFocus = next);
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _effectiveFocus.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _clearOnly() {
    MoglogHaptics.selectionChanged();
    widget.controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  void _cancelSearch() {
    MoglogHaptics.selectionChanged();
    if (widget.controller.text.isNotEmpty) {
      widget.controller.clear();
      widget.onChanged('');
      widget.onClear?.call();
    }
    _effectiveFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final reduceMotion = context.reduceMotion;
    final hasText = widget.controller.text.isNotEmpty;
    final showCancel = widget.showCancelButton && (_hasFocus || hasText);

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : MoglogMotion.fast,
            curve: MoglogMotion.curve,
            constraints: const BoxConstraints(minHeight: 42),
            decoration: ShapeDecoration(
              color: c.tertiaryBackground,
              shape: MoglogShapes.smooth(
                14,
                side: BorderSide(
                  color: _hasFocus
                      ? c.accent.withValues(alpha: 0.65)
                      : c.glassBorder,
                  width: _hasFocus ? 1.0 : c.hairlineWidth,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  MoglogIcons.search,
                  size: 18,
                  color: _hasFocus ? c.accentText : c.secondaryLabel,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _effectiveFocus,
                    onChanged: widget.onChanged,
                    style: t.subhead.copyWith(color: c.label),
                    cursorColor: c.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: widget.placeholder,
                      hintStyle: t.subhead.copyWith(color: c.secondaryLabel),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                if (hasText)
                  Semantics(
                    button: true,
                    label: 'Clear search',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _clearOnly,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: c.secondaryLabel.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            MoglogIcons.close,
                            size: 12,
                            color: c.label,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : MoglogMotion.fast,
          curve: MoglogMotion.curve,
          child: showCancel
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Semantics(
                    button: true,
                    label: 'Cancel search',
                    child: IosPressable(
                      onTap: _cancelSearch,
                      hapticOnTap: false,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 42,
                        ),
                        child: Center(
                          widthFactor: 1.0,
                          heightFactor: 1.0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Cancel',
                              style: t.subhead.copyWith(
                                color: c.accentText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

enum MoglogButtonSize {
  large(50, MoglogShapes.buttonRadius, 18),
  medium(44, MoglogShapes.buttonRadius, 16),
  small(36, MoglogShapes.buttonSmallRadius, 12);

  final double minHeight;
  final double cornerRadius;
  final double horizontalPadding;

  const MoglogButtonSize(
    this.minHeight,
    this.cornerRadius,
    this.horizontalPadding,
  );
}

Color _shiftColorLightness(Color color, double delta) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}

/// Reusable iOS 18 "Liquid Gloss" vector surface:
/// - Vertical base gradient (+8% top lightness -> -6% bottom lightness)
/// - Clipped top-half specular sheen (white 28% -> 0%)
/// - 1dp gradient inner stroke (white 26% top -> black 10% bottom)
/// - Soft colored ambient glow (25-35% base alpha, never black)
/// - Disabled: 40% opacity flat fill, zero gloss, zero glow
class GlossSurface extends StatelessWidget {
  final Color baseColor;
  final double cornerRadius;
  final bool enabled;
  final bool pressed;
  final bool showGlow;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final bool expandWidth;
  final Widget child;

  const GlossSurface({
    super.key,
    required this.baseColor,
    this.cornerRadius = MoglogShapes.buttonRadius,
    this.enabled = true,
    this.pressed = false,
    this.showGlow = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.minHeight = 50,
    this.expandWidth = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion = context.reduceMotion;
    final shape = MoglogShapes.smooth(cornerRadius);

    if (!enabled) {
      return Opacity(
        opacity: 0.40,
        child: Container(
          width: expandWidth ? double.infinity : null,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: ShapeDecoration(
            color: baseColor,
            shape: shape,
          ),
          child: Center(
            widthFactor: expandWidth ? null : 1.0,
            heightFactor: 1.0,
            child: child,
          ),
        ),
      );
    }

    final topColor = _shiftColorLightness(baseColor, 0.08);
    final bottomColor = _shiftColorLightness(baseColor, -0.06);
    final glowAlpha = pressed ? 0.15 : (c.isDark ? 0.33 : 0.27);
    final glowBlur = pressed ? 8.0 : 16.0;
    final glowOffsetY = pressed ? 2.0 : 6.0;
    final specularTopAlpha = pressed ? 0.14 : 0.28;

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : MoglogMotion.press,
      curve: MoglogMotion.curve,
      width: expandWidth ? double.infinity : null,
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
        shadows: showGlow
            ? [
                BoxShadow(
                  color: baseColor.withValues(alpha: glowAlpha),
                  blurRadius: glowBlur,
                  offset: Offset(0, glowOffsetY),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        foregroundPainter: SmoothGradientBorderPainter(
          cornerRadius: cornerRadius,
          strokeWidth: 1.0,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: pressed ? 0.16 : 0.26),
              Colors.black.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: 1.0,
                    heightFactor: 0.52,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: specularTopAlpha),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                  padding: padding,
                  child: Center(
                    widthFactor: expandWidth ? null : 1.0,
                    heightFactor: 1.0,
                    child: child,
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

Widget _buildButtonLabelContent({
  required BuildContext context,
  required String text,
  required Color foreground,
  required MoglogButtonSize size,
  IconData? leadingIcon,
  bool loading = false,
  bool singleLine = false,
}) {
  final t = context.typo;
  final textStyle = switch (size) {
    MoglogButtonSize.large => t.headline,
    MoglogButtonSize.medium => t.callout.copyWith(fontWeight: FontWeight.w600),
    MoglogButtonSize.small => t.footnote.copyWith(fontWeight: FontWeight.w600),
  }.copyWith(color: foreground);

  final iconSize = size == MoglogButtonSize.small ? 16.0 : 19.0;

  final labelWidget = Text(
    text,
    maxLines: singleLine ? 1 : 2,
    softWrap: !singleLine,
    textAlign: TextAlign.center,
    overflow: TextOverflow.ellipsis,
    style: textStyle,
  );

  final labelRow = Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (leadingIcon != null) ...[
        Icon(leadingIcon, size: iconSize, color: foreground),
        SizedBox(width: size == MoglogButtonSize.small ? 6 : 8),
      ],
      Flexible(child: labelWidget),
    ],
  );

  final effectiveContent = singleLine
      ? FittedBox(fit: BoxFit.scaleDown, child: labelRow)
      : labelRow;

  if (!loading) return effectiveContent;

  // Keep labelRow invisible in layout so button width never jumps on loading.
  return Stack(
    alignment: Alignment.center,
    children: [
      Opacity(
        opacity: 0.0,
        child: ExcludeSemantics(child: effectiveContent),
      ),
      SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: foreground,
        ),
      ),
    ],
  );
}

class IosPrimaryButton extends StatefulWidget {
  final String text;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool loading;
  final MoglogButtonSize size;
  final bool expand;
  final bool showGlow;
  final bool singleLine;

  const IosPrimaryButton({
    super.key,
    required this.text,
    this.leadingIcon,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.loading = false,
    this.size = MoglogButtonSize.large,
    this.expand = true,
    this.showGlow = true,
    this.singleLine = false,
  });

  @override
  State<IosPrimaryButton> createState() => _IosPrimaryButtonState();
}

class _IosPrimaryButtonState extends State<IosPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onTap != null && !widget.loading;
    final baseColor = widget.backgroundColor ?? c.accent;
    final Color resolvedForeground;
    if (widget.foregroundColor != null) {
      resolvedForeground = widget.foregroundColor!;
    } else if (widget.backgroundColor == null) {
      resolvedForeground = c.onAccent;
    } else {
      final est = ThemeData.estimateBrightnessForColor(baseColor);
      resolvedForeground =
          est == Brightness.dark ? c.onDestructive : const Color(0xFF041C0A);
    }

    return IosPressable(
      enabled: enabled,
      onTap: widget.onTap,
      hapticOnTap: true,
      hapticType: MoglogTapHaptic.lightImpact,
      pressedScale: MoglogMotion.pressedScale,
      focusRadius: widget.size.cornerRadius,
      onHighlightChanged: (v) {
        if (_pressed != v) setState(() => _pressed = v);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: MoglogLayout.minTouchTarget,
          minHeight: MoglogLayout.minTouchTarget,
        ),
        child: Center(
          widthFactor: widget.expand ? null : 1.0,
          heightFactor: 1.0,
          child: GlossSurface(
            baseColor: baseColor,
            cornerRadius: widget.size.cornerRadius,
            enabled: widget.onTap != null,
            pressed: _pressed,
            showGlow: widget.showGlow,
            minHeight: widget.size.minHeight,
            expandWidth: widget.expand,
            padding: EdgeInsets.symmetric(
              horizontal: widget.size.horizontalPadding,
              vertical: widget.size == MoglogButtonSize.small ? 6 : 10,
            ),
            child: _buildButtonLabelContent(
              context: context,
              text: widget.text,
              foreground: resolvedForeground,
              size: widget.size,
              leadingIcon: widget.leadingIcon,
              loading: widget.loading,
              singleLine: widget.singleLine,
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button: tinted glass surface with squircle hairline border & top sheen.
class IosSecondaryButton extends StatelessWidget {
  final String text;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final Color? textColor;
  final bool loading;
  final MoglogButtonSize size;
  final bool expand;
  final bool singleLine;

  const IosSecondaryButton({
    super.key,
    required this.text,
    this.leadingIcon,
    required this.onTap,
    this.textColor,
    this.loading = false,
    this.size = MoglogButtonSize.large,
    this.expand = true,
    this.singleLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null && !loading;
    final fg = textColor ?? c.label;
    final shape = MoglogShapes.smooth(
      size.cornerRadius,
      side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
    );

    return IosPressable(
      enabled: enabled,
      onTap: onTap,
      hapticOnTap: true,
      hapticType: MoglogTapHaptic.lightImpact,
      pressedScale: MoglogMotion.pressedScale,
      focusRadius: size.cornerRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: MoglogLayout.minTouchTarget,
          minHeight: MoglogLayout.minTouchTarget,
        ),
        child: Center(
          widthFactor: expand ? null : 1.0,
          heightFactor: 1.0,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.40,
            child: Container(
              width: expand ? double.infinity : null,
              constraints: BoxConstraints(minHeight: size.minHeight),
              padding: EdgeInsets.symmetric(
                horizontal: size.horizontalPadding,
                vertical: size == MoglogButtonSize.small ? 6 : 10,
              ),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: shape,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(c.cardSheenTop, c.tertiaryBackground),
                    c.tertiaryBackground,
                  ],
                ),
              ),
              child: _buildButtonLabelContent(
                context: context,
                text: text,
                foreground: fg,
                size: size,
                leadingIcon: leadingIcon,
                loading: loading,
                singleLine: singleLine,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tertiary button: plain crisp text/icon control with >= 48dp touch target.
class IosTertiaryButton extends StatelessWidget {
  final String text;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final Color? textColor;
  final MoglogButtonSize size;

  const IosTertiaryButton({
    super.key,
    required this.text,
    this.leadingIcon,
    required this.onTap,
    this.textColor,
    this.size = MoglogButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    final fg = textColor ?? c.accentText;

    return IosPressable(
      enabled: enabled,
      onTap: onTap,
      hapticOnTap: true,
      hapticType: MoglogTapHaptic.lightImpact,
      pressedScale: MoglogMotion.pressedScale,
      focusRadius: size.cornerRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: MoglogLayout.minTouchTarget,
          minHeight: MoglogLayout.minTouchTarget,
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.40,
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: _buildButtonLabelContent(
                context: context,
                text: text,
                foreground: fg,
                size: size,
                leadingIcon: leadingIcon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Destructive button: filled glossy red (`filled: true`) or tinted glass red (`filled: false`).
class IosDestructiveButton extends StatelessWidget {
  final String text;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final bool loading;
  final bool filled;
  final MoglogButtonSize size;
  final bool expand;

  const IosDestructiveButton({
    super.key,
    required this.text,
    this.leadingIcon,
    required this.onTap,
    this.loading = false,
    this.filled = true,
    this.size = MoglogButtonSize.large,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (filled) {
      return IosPrimaryButton(
        text: text,
        leadingIcon: leadingIcon,
        onTap: onTap,
        loading: loading,
        size: size,
        expand: expand,
        backgroundColor: c.destructive,
        foregroundColor: c.onDestructive,
      );
    }
    return IosSecondaryButton(
      text: text,
      leadingIcon: leadingIcon,
      onTap: onTap,
      loading: loading,
      size: size,
      expand: expand,
      textColor: c.destructive,
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

/// Frosted glass modal bottom sheet (squircle 28 top radius, grabber handle,
/// drag to dismiss, renders ABOVE the floating tab bar via root navigator,
/// with solid `elevatedSurface` fallback when reduce-transparency is active).
Future<T?> showIosBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  List<ChangeNotifier> disposeAfter = const [],
}) {
  final maxH = MediaQuery.sizeOf(context).height * 0.88;
  return _showIosBottomSheetImpl<T>(
    context: context,
    maxH: maxH,
    builder: builder,
    isScrollControlled: isScrollControlled,
  ).whenComplete(() {
    if (disposeAfter.isEmpty) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      for (final n in disposeAfter) {
        n.dispose();
      }
    });
  });
}

Future<T?> _showIosBottomSheetImpl<T>({
  required BuildContext context,
  required double maxH,
  required WidgetBuilder builder,
  required bool isScrollControlled,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    enableDrag: true,
    constraints: BoxConstraints(maxHeight: maxH),
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    shape: MoglogShapes.smoothTopSheet(radius: MoglogShapes.sheetRadius),
    builder: (ctx) {
      final c = ctx.colors;
      final reduceTransparency = ctx.reduceTransparency;
      final topShape = MoglogShapes.smoothTopSheet(
        radius: MoglogShapes.sheetRadius,
        side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
      );

      final sheetContent = SafeArea(
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
                  color: c.tertiaryLabel,
                  borderRadius: MoglogShapes.pill,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      );

      if (reduceTransparency) {
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: c.elevatedSurface,
            shape: topShape,
          ),
          child: sheetContent,
        );
      }

      return RepaintBoundary(
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: MoglogShapes.smoothTopSheet(radius: MoglogShapes.sheetRadius),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: c.isDark
                    ? Color.alphaBlend(
                        c.glassTint,
                        c.secondaryBackground.withValues(alpha: 0.88),
                      )
                    : Color.alphaBlend(
                        c.glassTint,
                        c.elevatedSurface.withValues(alpha: 0.86),
                      ),
                shape: topShape,
              ),
              child: sheetContent,
            ),
          ),
        ),
      );
    },
  );
}

/// iOS 18 Floating Action Sheet: detached rounded frosted action group +
/// separate floating rounded `Cancel` button above safe area.
Future<void> showIosActionSheet({
  required BuildContext context,
  String? title,
  String? message,
  required List<ActionSheetItem> actions,
  String cancelLabel = 'Cancel',
}) {
  final maxH = MediaQuery.sizeOf(context).height * 0.88;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    enableDrag: true,
    constraints: BoxConstraints(maxHeight: maxH),
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    builder: (ctx) {
      final c = ctx.colors;
      final t = ctx.typo;
      final reduceTransparency = ctx.reduceTransparency;
      final groupShape = MoglogShapes.smooth(
        MoglogShapes.cardRadius,
        side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
      );

      Widget wrapFrostedGroup(Widget child, {Color? solidOverride}) {
        final fill = solidOverride ??
            (c.isDark
                ? Color.alphaBlend(
                    c.glassTint,
                    c.elevatedSurface.withValues(alpha: 0.88),
                  )
                : Color.alphaBlend(
                    c.glassTint,
                    c.elevatedSurface.withValues(alpha: 0.90),
                  ));
        if (reduceTransparency) {
          return DecoratedBox(
            decoration: ShapeDecoration(
              color: c.elevatedSurface,
              shape: groupShape,
            ),
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
              ),
              child: child,
            ),
          );
        }
        return RepaintBoundary(
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: MoglogShapes.smooth(MoglogShapes.cardRadius),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: groupShape,
                ),
                child: child,
              ),
            ),
          ),
        );
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  wrapFrostedGroup(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null || message != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Column(
                              children: [
                                if (title != null)
                                  Text(
                                    title,
                                    style: t.footnote.copyWith(
                                      color: c.secondaryLabel,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                if (message != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: t.caption.copyWith(
                                      color: c.secondaryLabel,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Divider(
                            height: c.hairlineWidth,
                            thickness: c.hairlineWidth,
                            color: c.separator,
                          ),
                        ],
                        for (var i = 0; i < actions.length; i++) ...[
                          IosPressable(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              actions[i].onTap();
                            },
                            hapticOnTap: true,
                            pressedScale: 0.985,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 52),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    if (actions[i].icon != null) ...[
                                      Icon(
                                        actions[i].icon,
                                        size: 20,
                                        color: actions[i].isDestructive
                                            ? c.destructive
                                            : (actions[i].isSelected
                                                ? c.accentText
                                                : c.label),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        actions[i].label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: actions[i].icon == null &&
                                                !actions[i].isSelected &&
                                                actions[i].infoDescription ==
                                                    null
                                            ? TextAlign.center
                                            : TextAlign.start,
                                        style: t.callout.copyWith(
                                          fontWeight: actions[i].isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: actions[i].isDestructive
                                              ? c.destructive
                                              : (actions[i].isSelected
                                                  ? c.accentText
                                                  : c.label),
                                        ),
                                      ),
                                    ),
                                    if (actions[i].infoDescription != null &&
                                        actions[i]
                                            .infoDescription!
                                            .isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      IosInfoButton(
                                        title: actions[i].label,
                                        description:
                                            actions[i].infoDescription!,
                                      ),
                                    ],
                                    if (actions[i].isSelected)
                                      Icon(
                                        MoglogIcons.check,
                                        size: 19,
                                        color: c.accentText,
                                      ),
                                  ],
                                ),
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
                  // Separate floating Cancel card
                  wrapFrostedGroup(
                    IosPressable(
                      onTap: () => Navigator.of(ctx).pop(),
                      hapticOnTap: true,
                      pressedScale: 0.98,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 52,
                          minWidth: double.infinity,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              cancelLabel,
                              style: t.headline.copyWith(color: c.accentText),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    solidOverride: c.elevatedSurface,
                  ),
                ],
              ),
            ),
          ),
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
            width: 68,
            height: 68,
            decoration: ShapeDecoration(
              shape: MoglogShapes.smooth(
                22,
                side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(c.accentSubtle, c.secondaryBackground),
                  c.secondaryBackground,
                ],
              ),
              shadows: [
                BoxShadow(
                  color: c.shadowSoft,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: c.accentText),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: t.title3.copyWith(color: c.label),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              subtitle,
              style: t.subhead.copyWith(color: c.secondaryLabel, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
              child: IosPrimaryButton(
                text: actionLabel!,
                size: MoglogButtonSize.medium,
                onTap: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Floating glass capsule toast banner positioned dynamically above the tab bar.
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
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(c.cardSheenTop, c.elevatedSurface),
            borderRadius: MoglogShapes.pill,
            border: Border.all(color: c.glassBorder, width: c.hairlineWidth),
            boxShadow: [
              BoxShadow(
                color: c.tabShadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: onAction != null ? 6 : 11,
            ),
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
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 10),
                  IosPressable(
                    onTap: onAction,
                    hapticOnTap: true,
                    focusRadius: MoglogShapes.pillRadius,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 38,
                      ),
                      child: Center(
                        widthFactor: 1.0,
                        heightFactor: 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            actionLabel!,
                            style: t.footnote.copyWith(
                              color: c.accentText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    final radius = widget.borderRadius.topLeft.x;
    if (context.reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: ShapeDecoration(
          color: c.secondaryBackground,
          shape: MoglogShapes.smooth(radius),
        ),
      );
    }
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
          decoration: ShapeDecoration(
            color: color,
            shape: MoglogShapes.smooth(
              radius,
              side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
            ),
          ),
        );
      },
    );
  }
}

/// Poster image with continuous-corner squircle radius (default 14),
/// subtle hairline border, shimmer skeleton while loading, and smooth fade-in.
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
    final reduceMotion = context.reduceMotion;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final cacheW = effectiveWidth != null
        ? (effectiveWidth * dpr).round().clamp(96, 680)
        : 540;
    final optimizedUrl = optimizeTmdbImageUrl(
      widget.url,
      targetWidthDp: effectiveWidth,
      dpr: dpr,
    );

    final fallbackPlaceholder = Container(
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
        ? fallbackPlaceholder
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
            fadeInDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            fadeOutDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 90),
            placeholder: (_, __) => ShimmerBox(
              width: widget.width,
              height: widget.height,
              borderRadius: widget.borderRadius,
            ),
            errorWidget: (_, __, ___) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scheduleRetry());
              return fallbackPlaceholder;
            },
          );

    if (widget.isCircular) {
      return SizedBox.square(
        dimension: widget.width ?? widget.height ?? 64,
        child: ClipOval(
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.glassBorder, width: c.hairlineWidth),
            ),
            child: imageWidget,
          ),
        ),
      );
    }

    final cornerRadius = widget.borderRadius.topLeft.x;
    if (cornerRadius <= 0) {
      return imageWidget;
    }

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: MoglogShapes.smooth(
          cornerRadius,
          side: BorderSide(color: c.glassBorder, width: c.hairlineWidth),
        ),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: MoglogShapes.smooth(cornerRadius)),
        child: imageWidget,
      ),
    );
  }
}
