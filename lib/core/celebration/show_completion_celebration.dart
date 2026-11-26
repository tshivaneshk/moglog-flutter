import 'dart:math';

import 'package:flutter/material.dart';

import '../platform/platform_bridge.dart';

class CelebrationAudio {
  static Future<void> playCompletionChime() =>
      PlatformBridge.playCompletionChime();
}

class CelebrationHaptics {
  static Future<void> playCelebrationHaptic() =>
      PlatformBridge.playVictoryHaptic();
}

class _ConfettiParticle {
  final double initialX;
  final double initialY;
  final double vx;
  final double vy;
  final double gravity;
  final Color color;
  final double size;
  final double rotationSpeed;
  final int shapeType; // 0: ribbon, 1: circle, 2: 4-point star

  const _ConfettiParticle({
    required this.initialX,
    required this.initialY,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.color,
    required this.size,
    required this.rotationSpeed,
    required this.shapeType,
  });
}

/// Exact 1:1 port of `ShowCompletionCelebration.kt` (`CelebrationBlastOverlay`):
/// 85 particles, 1800ms FastOutSlowIn burst from (0.5, 0.4), ribbon/circle/star shapes.
class CelebrationBlastOverlay extends StatefulWidget {
  final int triggerKey;
  final VoidCallback? onFinished;

  const CelebrationBlastOverlay({
    super.key,
    required this.triggerKey,
    this.onFinished,
  });

  @override
  State<CelebrationBlastOverlay> createState() => _CelebrationBlastOverlayState();
}

class _CelebrationBlastOverlayState extends State<CelebrationBlastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_ConfettiParticle> _particles;

  static const _palette = [
    Color(0xFF10B981), // Moglog Emerald
    Color(0xFFF59E0B), // Star Gold
    Color(0xFF38BDF8), // Electric Sky Blue
    Color(0xFFEF4444), // Scarlet Red
    Color(0xFFA855F7), // Amethyst Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFF8FAFC), // Frost White
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onFinished?.call();
        }
      });
    _particles = _buildParticles(widget.triggerKey);
    if (widget.triggerKey > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant CelebrationBlastOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerKey != oldWidget.triggerKey && widget.triggerKey > 0) {
      _particles = _buildParticles(widget.triggerKey);
      _controller.forward(from: 0);
    }
  }

  List<_ConfettiParticle> _buildParticles(int seed) {
    if (seed <= 0) return const [];
    final rng = Random.secure();
    return List.generate(85, (_) {
      final angle = (-170.0 + rng.nextDouble() * 160.0) * (pi / 180.0);
      final speed = 450.0 + rng.nextDouble() * 850.0;
      return _ConfettiParticle(
        initialX: 0.5,
        initialY: 0.40,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        gravity: 900.0 + rng.nextDouble() * 600.0,
        color: _palette[rng.nextInt(_palette.length)],
        size: 8.0 + rng.nextDouble() * 10.0,
        rotationSpeed: -720.0 + rng.nextDouble() * 1440.0,
        shapeType: rng.nextInt(3),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.triggerKey <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.fastOutSlowIn.transform(_controller.value);
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(particles: _particles, t: t),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double t;

  const _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = t > 0.7 ? (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
    for (final p in particles) {
      final px = (p.initialX * size.width) + (p.vx * t);
      final py = (p.initialY * size.height) + (p.vy * t) + (0.5 * p.gravity * t * t);
      if (px < -50 || px > size.width + 50 || py < -50 || py > size.height + 50) {
        continue;
      }
      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotationSpeed * t * (pi / 180.0));
      if (p.shapeType == 0) {
        final w = p.size * (1.0 - t * 0.15);
        final h = p.size * 0.45;
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
      } else if (p.shapeType == 1) {
        canvas.drawCircle(Offset.zero, p.size * 0.35, paint);
      } else {
        final r = p.size * 0.5;
        final path = Path()
          ..moveTo(0, -r)
          ..quadraticBezierTo(0, 0, r, 0)
          ..quadraticBezierTo(0, 0, 0, r)
          ..quadraticBezierTo(0, 0, -r, 0)
          ..quadraticBezierTo(0, 0, 0, -r)
          ..close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.particles != particles;
}
