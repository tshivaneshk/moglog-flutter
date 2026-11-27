import 'package:flutter/material.dart';

import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';

/// Calm iOS 18 startup splash overlay with tokenized atmospheric gradient,
/// squircle-24 logo medallion, and reduce-motion support.
class MoglogStartupSplashScreen extends StatefulWidget {
  const MoglogStartupSplashScreen({super.key});

  @override
  State<MoglogStartupSplashScreen> createState() =>
      _MoglogStartupSplashScreenState();
}

class _MoglogStartupSplashScreenState extends State<MoglogStartupSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.fastOutSlowIn),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion = context.reduceMotion;

    final logoBadge = Container(
      width: 88,
      height: 88,
      decoration: ShapeDecoration(
        shape: MoglogShapes.smooth(
          24,
          side: BorderSide(
            color: c.accent.withValues(alpha: 0.38),
            width: 1.0,
          ),
        ),
        shadows: [
          BoxShadow(
            color: c.accent.withValues(alpha: c.isDark ? 0.24 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/app_logo2.png',
        fit: BoxFit.cover,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.splashTop,
            c.background,
            c.splashBottom,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reduceMotion)
              logoBadge
            else
              ScaleTransition(
                scale: _scaleAnim,
                child: logoBadge,
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: 140,
              height: 4,
              child: ClipRRect(
                borderRadius: MoglogShapes.pill,
                child: LinearProgressIndicator(
                  color: c.accent,
                  backgroundColor: c.tertiaryBackground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
