import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

class MoglogTheme {
  static ThemeData dark() => _build(MoglogColors.dark, Brightness.dark);
  static ThemeData light() => _build(MoglogColors.light, Brightness.light);

  static ThemeData _build(MoglogColors colors, Brightness brightness) {
    const typo = MoglogTypography.defaults;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: MoglogTypography.fontFamily,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      cardColor: colors.secondaryBackground,
      dividerColor: colors.separator,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        secondary: colors.statusPlanned,
        onSecondary: Colors.white,
        error: colors.destructive,
        onError: Colors.white,
        surface: colors.secondaryBackground,
        onSurface: colors.label,
      ),
      textTheme: TextTheme(
        displayLarge: typo.largeTitle.copyWith(color: colors.label),
        headlineLarge: typo.title1.copyWith(color: colors.label),
        headlineMedium: typo.title2.copyWith(color: colors.label),
        headlineSmall: typo.title3.copyWith(color: colors.label),
        titleLarge: typo.title2.copyWith(color: colors.label),
        titleMedium: typo.headline.copyWith(color: colors.label),
        titleSmall: typo.subhead.copyWith(
          color: colors.label,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: typo.body.copyWith(color: colors.label),
        bodyMedium: typo.subhead.copyWith(color: colors.label),
        bodySmall: typo.footnote.copyWith(color: colors.secondaryLabel),
        labelLarge: typo.callout.copyWith(
          color: colors.label,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: typo.footnote.copyWith(
          color: colors.label,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: typo.caption.copyWith(color: colors.secondaryLabel),
      ),
      extensions: [colors, typo],
    );
  }
}

extension MoglogThemeContext on BuildContext {
  MoglogColors get colors =>
      Theme.of(this).extension<MoglogColors>() ?? MoglogColors.dark;

  MoglogTypography get typo =>
      Theme.of(this).extension<MoglogTypography>() ?? MoglogTypography.defaults;
}
