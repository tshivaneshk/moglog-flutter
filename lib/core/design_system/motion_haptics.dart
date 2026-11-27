import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/platform_bridge.dart';
import 'shapes.dart';
import 'theme.dart';
import 'tokens.dart';

enum MoglogTapHaptic {
  none,
  selection,
  lightImpact,
}

/// Tactile haptic patterns for iPhone-grade interactions.
class MoglogHaptics {
  static Future<void> tickMinus() =>
      PlatformBridge.playPulseHaptic(durationMs: 12, amplitude: 70);

  static Future<void> clickPlus() =>
      PlatformBridge.playPulseHaptic(durationMs: 18, amplitude: 140);

  static Future<void> selectionChanged() => HapticFeedback.selectionClick();

  static Future<void> lightImpact() => HapticFeedback.lightImpact();

  static Future<void> mediumImpact() => HapticFeedback.mediumImpact();

  static Future<void> longPress() => HapticFeedback.heavyImpact();

  static Future<void> success() =>
      PlatformBridge.playPulseHaptic(durationMs: 24, amplitude: 180);

  static Future<void> warning() =>
      PlatformBridge.playPulseHaptic(durationMs: 30, amplitude: 220);
}

/// iOS 18 press-scale, opacity & focus feedback container.
/// Honors `MediaQuery.disableAnimations` and keyboard/TalkBack focus highlights.
class IosPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final bool enabled;
  final double pressedScale;
  final bool hapticOnTap;
  final MoglogTapHaptic hapticType;
  final HitTestBehavior behavior;
  final String? semanticLabel;
  final bool? semanticSelected;
  final double focusRadius;

  const IosPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onHighlightChanged,
    this.enabled = true,
    this.pressedScale = MoglogMotion.pressedScale,
    this.hapticOnTap = false,
    this.hapticType = MoglogTapHaptic.lightImpact,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.semanticSelected,
    this.focusRadius = MoglogShapes.controlRadius,
  });

  @override
  State<IosPressable> createState() => _IosPressableState();
}

class _IosPressableState extends State<IosPressable> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    widget.onHighlightChanged?.call(value);
  }

  void _triggerTap() {
    if (!widget.enabled || widget.onTap == null) return;
    if (widget.hapticOnTap) {
      switch (widget.hapticType) {
        case MoglogTapHaptic.none:
          break;
        case MoglogTapHaptic.selection:
          MoglogHaptics.selectionChanged();
        case MoglogTapHaptic.lightImpact:
          MoglogHaptics.lightImpact();
      }
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    final c = context.colors;
    final isInteractive =
        widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    Widget content = AnimatedScale(
      scale: (_pressed && !reduceMotion) ? widget.pressedScale : 1.0,
      duration: reduceMotion ? Duration.zero : MoglogMotion.press,
      curve: MoglogMotion.curve,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.88 : 1.0,
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );

    if (_focused && isInteractive) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: MoglogShapes.smooth(
            widget.focusRadius,
            side: BorderSide(color: c.accent, width: 2),
          ),
        ),
        child: content,
      );
    }

    return Semantics(
      button: isInteractive,
      enabled: isInteractive,
      selected: widget.semanticSelected,
      label: widget.semanticLabel,
      container: false,
      child: FocusableActionDetector(
        enabled: isInteractive,
        onShowFocusHighlight: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        actions: isInteractive && widget.onTap != null
            ? <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _triggerTap();
                    return null;
                  },
                ),
              }
            : null,
        child: GestureDetector(
          behavior: widget.behavior,
          onTapDown: isInteractive ? (_) => _setPressed(true) : null,
          onTapUp: isInteractive ? (_) => _setPressed(false) : null,
          onTapCancel: isInteractive ? () => _setPressed(false) : null,
          onTap: isInteractive && widget.onTap != null ? _triggerTap : null,
          onLongPress: isInteractive && widget.onLongPress != null
              ? () {
                  _setPressed(false);
                  MoglogHaptics.longPress();
                  widget.onLongPress!();
                }
              : null,
          child: content,
        ),
      ),
    );
  }
}
