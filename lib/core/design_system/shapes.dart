import 'dart:math';

import 'package:flutter/material.dart';

/// Continuous-corner (squircle) shape matching Kotlin `SmoothRoundedCornerShape`.
class SmoothRoundedRectangleBorder extends OutlinedBorder {
  final double cornerRadius;
  final double smoothness;

  const SmoothRoundedRectangleBorder({
    required this.cornerRadius,
    this.smoothness = 0.6,
    super.side,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _buildPath(Rect rect) {
    final maxR = min(rect.width, rect.height) / 2.0;
    final radius = cornerRadius.clamp(0.0, maxR);
    if (radius <= 0) {
      return Path()..addRect(rect);
    }
    final w = rect.width;
    final h = rect.height;
    final s = min(maxR, radius * (1.0 + smoothness * 0.25));
    final c = radius * 0.5522847;
    final l = rect.left;
    final t = rect.top;

    return Path()
      ..moveTo(l + s, t)
      ..lineTo(l + w - s, t)
      ..cubicTo(l + w - s + c, t, l + w, t + s - c, l + w, t + s)
      ..lineTo(l + w, t + h - s)
      ..cubicTo(l + w, t + h - s + c, l + w - s + c, t + h, l + w - s, t + h)
      ..lineTo(l + s, t + h)
      ..cubicTo(l + s - c, t + h, l, t + h - s + c, l, t + h - s)
      ..lineTo(l, t + s)
      ..cubicTo(l, t + s - c, l + s - c, t, l + s, t)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.solid && side.width > 0) {
      final paint = side.toPaint();
      canvas.drawPath(_buildPath(rect.deflate(side.width / 2)), paint);
    }
  }

  @override
  SmoothRoundedRectangleBorder copyWith({BorderSide? side}) {
    return SmoothRoundedRectangleBorder(
      cornerRadius: cornerRadius,
      smoothness: smoothness,
      side: side ?? this.side,
    );
  }

  @override
  ShapeBorder scale(double t) => SmoothRoundedRectangleBorder(
        cornerRadius: cornerRadius * t,
        smoothness: smoothness,
        side: side.scale(t),
      );
}

class MoglogShapes {
  static const double controlRadius = 10;
  static const double cardRadius = 14;
  static const double posterRadius = 14;
  static const double sheetRadius = 20;

  static const BorderRadius control = BorderRadius.all(Radius.circular(controlRadius));
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius poster = BorderRadius.all(Radius.circular(posterRadius));
  static const BorderRadius sheet = BorderRadius.all(Radius.circular(sheetRadius));
  static const BorderRadius topSheet = BorderRadius.vertical(top: Radius.circular(sheetRadius));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static SmoothRoundedRectangleBorder smooth(double radius, {BorderSide side = BorderSide.none}) =>
      SmoothRoundedRectangleBorder(cornerRadius: radius, side: side);
}
