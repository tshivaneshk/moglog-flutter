import 'package:flutter/material.dart';

/// Bundled Inter OFL font configured with the exact iOS type scale from Kotlin `Typography.kt`.
@immutable
class MoglogTypography extends ThemeExtension<MoglogTypography> {
  static const String fontFamily = 'Inter';

  final TextStyle largeTitle;
  final TextStyle title1;
  final TextStyle title2;
  final TextStyle title3;
  final TextStyle headline;
  final TextStyle body;
  final TextStyle callout;
  final TextStyle subhead;
  final TextStyle footnote;
  final TextStyle caption;
  final TextStyle caption2;

  const MoglogTypography({
    this.largeTitle = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 34,
      height: 41 / 34,
      letterSpacing: -0.4,
    ),
    this.title1 = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 34 / 28,
      letterSpacing: -0.3,
    ),
    this.title2 = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 22,
      height: 28 / 22,
      letterSpacing: -0.25,
    ),
    this.title3 = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 20,
      height: 25 / 20,
      letterSpacing: -0.2,
    ),
    this.headline = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 17,
      height: 22 / 17,
      letterSpacing: -0.15,
    ),
    this.body = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 17,
      height: 22 / 17,
      letterSpacing: -0.1,
    ),
    this.callout = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 21 / 16,
      letterSpacing: -0.08,
    ),
    this.subhead = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 15,
      height: 20 / 15,
      letterSpacing: -0.05,
    ),
    this.footnote = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 18 / 13,
      letterSpacing: 0,
    ),
    this.caption = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: 0,
    ),
    this.caption2 = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 11,
      height: 14 / 11,
      letterSpacing: 0,
    ),
  });

  static const MoglogTypography defaults = MoglogTypography();

  @override
  MoglogTypography copyWith() => this;

  @override
  MoglogTypography lerp(ThemeExtension<MoglogTypography>? other, double t) => this;
}
