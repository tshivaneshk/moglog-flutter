import 'package:flutter/material.dart';

import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';

/// Exact 1:1 port of Kotlin `MoglogStartupSplashScreen`:
/// Deep obsidian-to-emerald vertical gradient, pulsing 86dp `app_logo2` (scale 0.96..1.04, 1200ms reverse),
/// and 140dp emerald `LinearProgressIndicator`.
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF06080E),
            c.background,
            const Color(0xFF07120D),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 86,
                height: 86,
                decoration: ShapeDecoration(
                  shape: MoglogShapes.smooth(
                    22,
                    side: BorderSide(
                      color: c.accent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/app_logo2.png',
                  fit: BoxFit.cover,
                ),
              ),
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
