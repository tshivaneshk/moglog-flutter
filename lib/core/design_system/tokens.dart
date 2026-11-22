import 'package:flutter/material.dart';

/// Semantic iOS-inspired color tokens matching Kotlin `Tokens.kt` 1:1.
@immutable
class MoglogColors extends ThemeExtension<MoglogColors> {
  final bool isDark;
  final Color background;
  final Color groupedBackground;
  final Color secondaryBackground;
  final Color tertiaryBackground;
  final Color elevatedSurface;
  final Color frostedBarSurface;
  final Color separator;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color accent;
  final Color accentSubtle;
  final Color onAccent;
  final Color statusWatching;
  final Color statusPlanned;
  final Color statusDone;
  final Color destructive;
  final Color warning;
  final Color starGold;
  final double hairlineWidth;

  const MoglogColors({
    required this.isDark,
    required this.background,
    required this.groupedBackground,
    required this.secondaryBackground,
    required this.tertiaryBackground,
    required this.elevatedSurface,
    required this.frostedBarSurface,
    required this.separator,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.accent,
    required this.accentSubtle,
    required this.onAccent,
    required this.statusWatching,
    required this.statusPlanned,
    required this.statusDone,
    required this.destructive,
    required this.warning,
    required this.starGold,
    this.hairlineWidth = 0.5,
  });

  Color statusColor(String status) => switch (status) {
        'Watching' => statusWatching,
        'Planned' => statusPlanned,
        'Done' => statusDone,
        _ => accent,
      };

  static const MoglogColors dark = MoglogColors(
    isDark: true,
    background: Color(0xFF000000),
    groupedBackground: Color(0xFF000000),
    secondaryBackground: Color(0xFF1C1C1E),
    tertiaryBackground: Color(0xFF2C2C2E),
    elevatedSurface: Color(0xFF242426),
    frostedBarSurface: Color(0xEB161618),
    separator: Color(0xFF38383A),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0x99EBEBF5),
    tertiaryLabel: Color(0x4DEBEBF5),
    accent: Color(0xFF30D158),
    accentSubtle: Color(0x2630D158),
    onAccent: Color(0xFF000000),
    statusWatching: Color(0xFFFF9F0A),
    statusPlanned: Color(0xFF0A84FF),
    statusDone: Color(0xFF30D158),
    destructive: Color(0xFFFF453A),
    warning: Color(0xFFFFD60A),
    starGold: Color(0xFFFFD60A),
  );

  static const MoglogColors light = MoglogColors(
    isDark: false,
    background: Color(0xFFF2F2F7),
    groupedBackground: Color(0xFFF2F2F7),
    secondaryBackground: Color(0xFFFFFFFF),
    tertiaryBackground: Color(0xFFE5E5EA),
    elevatedSurface: Color(0xFFFFFFFF),
    frostedBarSurface: Color(0xF0F9F9FB),
    separator: Color(0xFFC6C6C8),
    label: Color(0xFF000000),
    secondaryLabel: Color(0x993C3C43),
    tertiaryLabel: Color(0x4D3C3C43),
    accent: Color(0xFF34C759),
    accentSubtle: Color(0x2234C759),
    onAccent: Color(0xFFFFFFFF),
    statusWatching: Color(0xFFFF9500),
    statusPlanned: Color(0xFF007AFF),
    statusDone: Color(0xFF34C759),
    destructive: Color(0xFFFF3B30),
    warning: Color(0xFFFFCC00),
    starGold: Color(0xFFFFB800),
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
    Color? separator,
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? accent,
    Color? accentSubtle,
    Color? onAccent,
    Color? statusWatching,
    Color? statusPlanned,
    Color? statusDone,
    Color? destructive,
    Color? warning,
    Color? starGold,
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
      separator: separator ?? this.separator,
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
      accent: accent ?? this.accent,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      onAccent: onAccent ?? this.onAccent,
      statusWatching: statusWatching ?? this.statusWatching,
      statusPlanned: statusPlanned ?? this.statusPlanned,
      statusDone: statusDone ?? this.statusDone,
      destructive: destructive ?? this.destructive,
      warning: warning ?? this.warning,
      starGold: starGold ?? this.starGold,
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
      separator: Color.lerp(separator, other.separator, t)!,
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      statusWatching: Color.lerp(statusWatching, other.statusWatching, t)!,
      statusPlanned: Color.lerp(statusPlanned, other.statusPlanned, t)!,
      statusDone: Color.lerp(statusDone, other.statusDone, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      starGold: Color.lerp(starGold, other.starGold, t)!,
      hairlineWidth: hairlineWidth,
    );
  }
}
