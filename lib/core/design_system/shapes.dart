import 'dart:math';

import 'package:flutter/material.dart';

/// Continuous-corner (squircle) shape matching iOS continuous corner geometry.
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

  static Path buildSmoothPath(
    Rect rect, {
    required double cornerRadius,
    double smoothness = 0.6,
  }) {
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

  Path _buildPath(Rect rect) =>
      buildSmoothPath(rect, cornerRadius: cornerRadius, smoothness: smoothness);

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

/// Top-only continuous-corner squircle border for modal bottom sheets.
class SmoothTopRoundedBorder extends ShapeBorder {
  final double cornerRadius;
  final BorderSide side;

  const SmoothTopRoundedBorder({
    required this.cornerRadius,
    this.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
        top: side.width,
        left: side.width,
        right: side.width,
      );

  Path _buildTopPath(Rect rect) {
    final maxR = min(rect.width / 2.0, rect.height);
    final radius = cornerRadius.clamp(0.0, maxR);
    if (radius <= 0) return Path()..addRect(rect);
    final s = min(maxR, radius * 1.15);
    final c = radius * 0.5522847;
    final l = rect.left;
    final t = rect.top;
    final r = rect.right;
    final b = rect.bottom;

    return Path()
      ..moveTo(l, b)
      ..lineTo(l, t + s)
      ..cubicTo(l, t + s - c, l + s - c, t, l + s, t)
      ..lineTo(r - s, t)
      ..cubicTo(r - s + c, t, r, t + s - c, r, t + s)
      ..lineTo(r, b)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildTopPath(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildTopPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.solid && side.width > 0) {
      final paint = side.toPaint();
      canvas.drawPath(_buildTopPath(rect.deflate(side.width / 2)), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => SmoothTopRoundedBorder(
        cornerRadius: cornerRadius * t,
        side: side.scale(t),
      );
}

/// Vector gradient inner stroke painter for `GlossSurface` (no bitmaps).
class SmoothGradientBorderPainter extends CustomPainter {
  final double cornerRadius;
  final double strokeWidth;
  final Gradient gradient;

  const SmoothGradientBorderPainter({
    required this.cornerRadius,
    this.strokeWidth = 1.0,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    if (rect.isEmpty) return;
    final path = SmoothRoundedRectangleBorder.buildSmoothPath(
      rect,
      cornerRadius: cornerRadius,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SmoothGradientBorderPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gradient != gradient;
  }
}

class MoglogShapes {
  static const double controlRadius = 12;
  static const double buttonSmallRadius = 12;
  static const double buttonRadius = 15;
  static const double posterRadius = 14;
  static const double cardRadius = 20;
  static const double sheetRadius = 28;
  static const double tabCapsuleRadius = 32;
  static const double pillRadius = 999;

  static const BorderRadius control =
      BorderRadius.all(Radius.circular(controlRadius));
  static const BorderRadius button =
      BorderRadius.all(Radius.circular(buttonRadius));
  static const BorderRadius card =
      BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius poster =
      BorderRadius.all(Radius.circular(posterRadius));
  static const BorderRadius sheet =
      BorderRadius.all(Radius.circular(sheetRadius));
  static const BorderRadius topSheet =
      BorderRadius.vertical(top: Radius.circular(sheetRadius));
  static const BorderRadius tabCapsule =
      BorderRadius.all(Radius.circular(tabCapsuleRadius));
  static const BorderRadius pill =
      BorderRadius.all(Radius.circular(pillRadius));

  static SmoothRoundedRectangleBorder smooth(
    double radius, {
    BorderSide side = BorderSide.none,
  }) =>
      SmoothRoundedRectangleBorder(cornerRadius: radius, side: side);

  static SmoothTopRoundedBorder smoothTopSheet({
    double radius = sheetRadius,
    BorderSide side = BorderSide.none,
  }) =>
      SmoothTopRoundedBorder(cornerRadius: radius, side: side);
}
