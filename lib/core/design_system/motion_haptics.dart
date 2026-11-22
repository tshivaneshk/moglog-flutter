import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/platform_bridge.dart';

/// Tactile haptic patterns matching Kotlin `MoglogHaptics`.
class MoglogHaptics {
  static Future<void> tickMinus() =>
      PlatformBridge.playPulseHaptic(durationMs: 12, amplitude: 70);

  static Future<void> clickPlus() =>
      PlatformBridge.playPulseHaptic(durationMs: 18, amplitude: 140);

  static Future<void> selectionChanged() => HapticFeedback.selectionClick();

  static Future<void> longPress() => HapticFeedback.heavyImpact();

  static Future<void> success() =>
      PlatformBridge.playPulseHaptic(durationMs: 24, amplitude: 180);

  static Future<void> warning() =>
      PlatformBridge.playPulseHaptic(durationMs: 30, amplitude: 220);
}

/// iOS-like press-scale & opacity feedback container matching Kotlin `Modifier.iosClickable`.
class IosPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double pressedScale;
  final bool hapticOnTap;
  final HitTestBehavior behavior;

  const IosPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.pressedScale = 0.97,
    this.hapticOnTap = false,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<IosPressable> createState() => _IosPressableState();
}

class _IosPressableState extends State<IosPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isInteractive = widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    return Semantics(
      button: isInteractive,
      enabled: isInteractive,
      container: false,
      child: GestureDetector(
      behavior: widget.behavior,
      onTapDown: isInteractive ? (_) => _setPressed(true) : null,
      onTapUp: isInteractive ? (_) => _setPressed(false) : null,
      onTapCancel: isInteractive ? () => _setPressed(false) : null,
      onTap: isInteractive && widget.onTap != null
          ? () {
              if (widget.hapticOnTap) MoglogHaptics.selectionChanged();
              widget.onTap!();
            }
          : null,
      onLongPress: isInteractive && widget.onLongPress != null
          ? () {
              _setPressed(false);
              MoglogHaptics.longPress();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: (_pressed && !reduceMotion) ? widget.pressedScale : 1.0,
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.86 : 1.0,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    ),
    );
  }
}
