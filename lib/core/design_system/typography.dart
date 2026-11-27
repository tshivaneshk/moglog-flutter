import 'package:flutter/material.dart';

/// Bundled Inter OFL font configured with the iOS 18 type scale:
/// Large Title 34, Title 28/22/20, Headline 17 semibold, Body 17,
/// Callout 16, Subhead 15, Footnote 13, Caption 12, Caption2 11.
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
  final TextStyle microBadge;

  const MoglogTypography({
    this.largeTitle = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 34,
      height: 41 / 34,
      letterSpacing: -0.45,
    ),
    this.title1 = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 34 / 28,
      letterSpacing: -0.35,
    ),
    this.title2 = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 22,
      height: 28 / 22,
      letterSpacing: -0.26,
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
      letterSpacing: -0.18,
    ),
    this.body = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 17,
      height: 22 / 17,
      letterSpacing: -0.12,
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
      letterSpacing: -0.06,
    ),
    this.footnote = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 18 / 13,
      letterSpacing: -0.02,
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
      letterSpacing: 0.04,
    ),
    this.microBadge = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 10,
      height: 13 / 10,
      letterSpacing: 0.12,
    ),
  });

  static const MoglogTypography defaults = MoglogTypography();

  @override
  MoglogTypography copyWith() => this;

  @override
  MoglogTypography lerp(ThemeExtension<MoglogTypography>? other, double t) =>
      this;
}

extension MoglogTextStyleX on TextStyle {
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
