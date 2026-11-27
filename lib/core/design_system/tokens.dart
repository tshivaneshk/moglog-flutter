import 'package:flutter/material.dart';

/// Spacing scale (4dp grid with iOS 16/20/24 rhythm).
class MoglogSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(lg, xs, lg, xl);
}

/// Shared motion curves and durations (spring-like iOS 18 feel).
class MoglogMotion {
  static const Duration press = Duration(milliseconds: 110);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration spring = Duration(milliseconds: 280);
  static const Duration page = Duration(milliseconds: 300);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve reverseCurve = Curves.easeInCubic;
  static const Curve springCurve = Cubic(0.22, 1.0, 0.36, 1.0);

  static const double pressedScale = 0.97;
}

/// Shared layout & floating glass shell metrics.
class MoglogLayout {
  static const double tabBarHeight = 64.0;
  static const double tabBarCompactHeight = 56.0;
  static const double tabBarHorizontalMargin = 16.0;
  static const double tabBarBottomMargin = 12.0;
  static const double minTouchTarget = 48.0;

  static double effectiveTabBarHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompactHeight = size.height < 440;
    return (isLandscape || isCompactHeight)
        ? tabBarCompactHeight
        : tabBarHeight;
  }

  /// Total scroll bottom inset required so content scrolls cleanly under the
  /// detached floating glass tab bar and nothing is obscured at the bottom.
  static double shellScrollBottomPadding(
    BuildContext context, {
    double extra = 20.0,
  }) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return safeBottom +
        effectiveTabBarHeight(context) +
        tabBarBottomMargin +
        extra;
  }

  /// Vertical distance from bottom (excluding SafeArea bottom, or combined)
  /// so floating toasts hover cleanly above the floating tab bar.
  static double toastBottomOffset(BuildContext context) {
    return effectiveTabBarHeight(context) + tabBarBottomMargin + 12.0;
  }
}

/// Semantic iOS 18 "Liquid Glass" color tokens with layered surfaces:
/// `background < groupedBackground < secondaryBackground < elevatedSurface < glassSurface`.
@immutable
class MoglogColors extends ThemeExtension<MoglogColors> {
  final bool isDark;
  final Color background;
  final Color groupedBackground;
  final Color secondaryBackground;
  final Color tertiaryBackground;
  final Color elevatedSurface;
  final Color frostedBarSurface;
  final Color glassSurface;
  final Color glassTint;
  final Color glassScrimBase;
  final Color glassBorder;
  final Color glassPillFill;
  final Color cardSheenTop;
  final Color cardBorder;
  final Color shadowSoft;
  final Color tabShadow;
  final Color separator;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color accent;
  final Color accentText;
  final Color accentSubtle;
  final Color onAccent;
  final Color statusWatching;
  final Color statusPlanned;
  final Color statusDone;
  final Color destructive;
  final Color destructiveSubtle;
  final Color onDestructive;
  final Color warning;
  final Color starGold;
  final Color onMedia;
  final Color onMediaSecondary;
  final Color mediaScrim;
  final Color mediaScrimLight;
  final Color splashTop;
  final Color splashBottom;
  final double hairlineWidth;

  const MoglogColors({
    required this.isDark,
    required this.background,
    required this.groupedBackground,
    required this.secondaryBackground,
    required this.tertiaryBackground,
    required this.elevatedSurface,
    required this.frostedBarSurface,
    required this.glassSurface,
    required this.glassTint,
    required this.glassScrimBase,
    required this.glassBorder,
    required this.glassPillFill,
    required this.cardSheenTop,
    required this.cardBorder,
    required this.shadowSoft,
    required this.tabShadow,
    required this.separator,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.accent,
    required this.accentText,
    required this.accentSubtle,
    required this.onAccent,
    required this.statusWatching,
    required this.statusPlanned,
    required this.statusDone,
    required this.destructive,
    required this.destructiveSubtle,
    required this.onDestructive,
    required this.warning,
    required this.starGold,
    required this.onMedia,
    required this.onMediaSecondary,
    required this.mediaScrim,
    required this.mediaScrimLight,
    required this.splashTop,
    required this.splashBottom,
    this.hairlineWidth = 0.5,
  });

  Color statusColor(String status) => switch (status) {
        'Watching' => statusWatching,
        'Planned' => statusPlanned,
        'Done' => statusDone,
        _ => accent,
      };

  /// Status text color meeting WCAG AA against card/grouped surfaces.
  Color statusTextColor(String status) => switch (status) {
        'Watching' => isDark ? statusWatching : const Color(0xFFB25E00),
        'Planned' => isDark ? statusPlanned : const Color(0xFF005EC4),
        'Done' => accentText,
        _ => accentText,
      };

  static const MoglogColors dark = MoglogColors(
    isDark: true,
    background: Color(0xFF000000),
    groupedBackground: Color(0xFF09090B),
    secondaryBackground: Color(0xFF161618),
    tertiaryBackground: Color(0xFF26262A),
    elevatedSurface: Color(0xFF202024),
    frostedBarSurface: Color(0xE0121215),
    glassSurface: Color(0xCF18181C),
    // White 9% tint layered over dark translucent base for iOS 18 Liquid Glass
    glassTint: Color(0x17FFFFFF),
    glassScrimBase: Color(0xA8050507),
    // White 12% inner hairline border
    glassBorder: Color(0x1FFFFFFF),
    glassPillFill: Color(0x21FFFFFF),
    cardSheenTop: Color(0x0FFFFFFF),
    cardBorder: Color(0x17FFFFFF),
    shadowSoft: Color(0x38000000),
    // Soft shadow alpha 0.25
    tabShadow: Color(0x40000000),
    separator: Color(0xFF343438),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xA6EBEBF5),
    tertiaryLabel: Color(0x66EBEBF5),
    accent: Color(0xFF30D158),
    accentText: Color(0xFF30D158),
    accentSubtle: Color(0x2630D158),
    // Dark text on bright green (#30D158) -> >10:1 WCAG AAA contrast
    onAccent: Color(0xFF031708),
    statusWatching: Color(0xFFFF9F0A),
    statusPlanned: Color(0xFF0A84FF),
    statusDone: Color(0xFF30D158),
    destructive: Color(0xFFFF453A),
    destructiveSubtle: Color(0x24FF453A),
    onDestructive: Color(0xFFFFFFFF),
    warning: Color(0xFFFFD60A),
    starGold: Color(0xFFFFD60A),
    onMedia: Color(0xFFFFFFFF),
    onMediaSecondary: Color(0xC2FFFFFF),
    mediaScrim: Color(0xBD000000),
    mediaScrimLight: Color(0x4D000000),
    splashTop: Color(0xFF06080E),
    splashBottom: Color(0xFF07120D),
  );

  static const MoglogColors light = MoglogColors(
    isDark: false,
    background: Color(0xFFF2F2F7),
    groupedBackground: Color(0xFFF2F2F7),
    secondaryBackground: Color(0xFFFFFFFF),
    tertiaryBackground: Color(0xFFE5E5EA),
    elevatedSurface: Color(0xFFFFFFFF),
    frostedBarSurface: Color(0xEBFFFFFF),
    glassSurface: Color(0xD9FFFFFF),
    // White 70% translucent glass tint
    glassTint: Color(0xB3FFFFFF),
    glassScrimBase: Color(0x26FFFFFF),
    // Black 8% inner hairline border
    glassBorder: Color(0x14000000),
    glassPillFill: Color(0xEBFFFFFF),
    cardSheenTop: Color(0x80FFFFFF),
    cardBorder: Color(0x12000000),
    shadowSoft: Color(0x12000000),
    tabShadow: Color(0x24000000),
    separator: Color(0xFFC6C6C8),
    label: Color(0xFF000000),
    secondaryLabel: Color(0xA83C3C43),
    tertiaryLabel: Color(0x6B3C3C43),
    accent: Color(0xFF34C759),
    // Deep emerald ink for text/icons on white/grouped surfaces (>= 4.6:1 AA)
    accentText: Color(0xFF157A31),
    accentSubtle: Color(0x2234C759),
    // Never white-on-light-green (#34C759): deep obsidian-green gives >8:1 contrast
    onAccent: Color(0xFF041C0A),
    statusWatching: Color(0xFFFF9500),
    statusPlanned: Color(0xFF007AFF),
    statusDone: Color(0xFF34C759),
    destructive: Color(0xFFD70015),
    destructiveSubtle: Color(0x1AD70015),
    onDestructive: Color(0xFFFFFFFF),
    warning: Color(0xFFFFCC00),
    starGold: Color(0xFFD99B00),
    onMedia: Color(0xFFFFFFFF),
    onMediaSecondary: Color(0xCCFFFFFF),
    mediaScrim: Color(0xBD000000),
    mediaScrimLight: Color(0x4D000000),
    splashTop: Color(0xFFEBF5EE),
    splashBottom: Color(0xFFE6ECF5),
  );

  @override
  MoglogColors copyWith({
    bool? isDark,
    Color? background,
    Color? groupedBackground,
    Color? secondaryBackground,
    Color? tertiaryBackground,
    Color? elevatedSurface,
    Color? frostedBarSurface,
    Color? glassSurface,
    Color? glassTint,
    Color? glassScrimBase,
    Color? glassBorder,
    Color? glassPillFill,
    Color? cardSheenTop,
    Color? cardBorder,
    Color? shadowSoft,
    Color? tabShadow,
    Color? separator,
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? accent,
    Color? accentText,
    Color? accentSubtle,
    Color? onAccent,
    Color? statusWatching,
    Color? statusPlanned,
    Color? statusDone,
    Color? destructive,
    Color? destructiveSubtle,
    Color? onDestructive,
    Color? warning,
    Color? starGold,
    Color? onMedia,
    Color? onMediaSecondary,
    Color? mediaScrim,
    Color? mediaScrimLight,
    Color? splashTop,
    Color? splashBottom,
    double? hairlineWidth,
  }) {
    return MoglogColors(
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      groupedBackground: groupedBackground ?? this.groupedBackground,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      tertiaryBackground: tertiaryBackground ?? this.tertiaryBackground,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      frostedBarSurface: frostedBarSurface ?? this.frostedBarSurface,
      glassSurface: glassSurface ?? this.glassSurface,
      glassTint: glassTint ?? this.glassTint,
      glassScrimBase: glassScrimBase ?? this.glassScrimBase,
      glassBorder: glassBorder ?? this.glassBorder,
      glassPillFill: glassPillFill ?? this.glassPillFill,
      cardSheenTop: cardSheenTop ?? this.cardSheenTop,
      cardBorder: cardBorder ?? this.cardBorder,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      tabShadow: tabShadow ?? this.tabShadow,
      separator: separator ?? this.separator,
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      onAccent: onAccent ?? this.onAccent,
      statusWatching: statusWatching ?? this.statusWatching,
      statusPlanned: statusPlanned ?? this.statusPlanned,
      statusDone: statusDone ?? this.statusDone,
      destructive: destructive ?? this.destructive,
      destructiveSubtle: destructiveSubtle ?? this.destructiveSubtle,
      onDestructive: onDestructive ?? this.onDestructive,
      warning: warning ?? this.warning,
      starGold: starGold ?? this.starGold,
      onMedia: onMedia ?? this.onMedia,
      onMediaSecondary: onMediaSecondary ?? this.onMediaSecondary,
      mediaScrim: mediaScrim ?? this.mediaScrim,
      mediaScrimLight: mediaScrimLight ?? this.mediaScrimLight,
      splashTop: splashTop ?? this.splashTop,
      splashBottom: splashBottom ?? this.splashBottom,
      hairlineWidth: hairlineWidth ?? this.hairlineWidth,
    );
  }

  @override
  MoglogColors lerp(ThemeExtension<MoglogColors>? other, double t) {
    if (other is! MoglogColors) return this;
    return MoglogColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      groupedBackground: Color.lerp(groupedBackground, other.groupedBackground, t)!,
      secondaryBackground: Color.lerp(secondaryBackground, other.secondaryBackground, t)!,
      tertiaryBackground: Color.lerp(tertiaryBackground, other.tertiaryBackground, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      frostedBarSurface: Color.lerp(frostedBarSurface, other.frostedBarSurface, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassScrimBase: Color.lerp(glassScrimBase, other.glassScrimBase, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassPillFill: Color.lerp(glassPillFill, other.glassPillFill, t)!,
      cardSheenTop: Color.lerp(cardSheenTop, other.cardSheenTop, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
      tabShadow: Color.lerp(tabShadow, other.tabShadow, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      statusWatching: Color.lerp(statusWatching, other.statusWatching, t)!,
      statusPlanned: Color.lerp(statusPlanned, other.statusPlanned, t)!,
      statusDone: Color.lerp(statusDone, other.statusDone, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveSubtle: Color.lerp(destructiveSubtle, other.destructiveSubtle, t)!,
      onDestructive: Color.lerp(onDestructive, other.onDestructive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      starGold: Color.lerp(starGold, other.starGold, t)!,
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      onMediaSecondary: Color.lerp(onMediaSecondary, other.onMediaSecondary, t)!,
      mediaScrim: Color.lerp(mediaScrim, other.mediaScrim, t)!,
      mediaScrimLight: Color.lerp(mediaScrimLight, other.mediaScrimLight, t)!,
      splashTop: Color.lerp(splashTop, other.splashTop, t)!,
      splashBottom: Color.lerp(splashBottom, other.splashBottom, t)!,
      hairlineWidth: hairlineWidth,
    );
  }
}
