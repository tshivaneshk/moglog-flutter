import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/design_system/icons.dart';
import '../core/design_system/motion_haptics.dart';
import '../core/design_system/shapes.dart';
import '../core/design_system/theme.dart';
import '../core/design_system/tokens.dart';

class MoglogTabItem {
  final String label;
  final IconData icon;
  const MoglogTabItem(this.label, this.icon);
}

const List<MoglogTabItem> kMoglogMainTabs = [
  MoglogTabItem('Library', MoglogIcons.library),
  MoglogTabItem('Discover', MoglogIcons.discover),
  MoglogTabItem('Stats', MoglogIcons.stats),
  MoglogTabItem('Settings', MoglogIcons.settings),
];

/// Broadcasts active-tab re-tap events to shell branch scroll views so
/// re-tapping an active tab smoothly scrolls its list back to top without
/// rebuilding the widget tree.
class TabRetapController extends ChangeNotifier {
  int _lastRetappedIndex = -1;
  int _sequence = 0;

  int get lastRetappedIndex => _lastRetappedIndex;
  int get sequence => _sequence;

  void notifyRetap(int index) {
    _lastRetappedIndex = index;
    _sequence++;
    notifyListeners();
  }
}

class TabRetapScope extends InheritedNotifier<TabRetapController> {
  const TabRetapScope({
    super.key,
    required TabRetapController controller,
    required super.child,
  }) : super(notifier: controller);

  static TabRetapController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TabRetapScope>()
        ?.notifier;
  }

  static TabRetapController? read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<TabRetapScope>();
    return (element?.widget as TabRetapScope?)?.notifier;
  }
}

/// Helper mixin/utility to scroll a `ScrollController` to top when its branch
/// tab is re-tapped.
void scrollControllerToTop(
  BuildContext context,
  ScrollController controller,
) {
  if (!controller.hasClients) return;
  if (controller.offset <= 0) return;
  if (context.reduceMotion) {
    controller.jumpTo(0);
  } else {
    controller.animateTo(
      0,
      duration: MoglogMotion.spring,
      curve: MoglogMotion.curve,
    );
  }
}

/// Attaches to `TabRetapScope` without rebuilding `child` on unrelated retaps;
/// smoothly scrolls `scrollController` to top when `branchIndex` is re-tapped.
class TabRetapListener extends StatefulWidget {
  final int branchIndex;
  final ScrollController scrollController;
  final Widget child;

  const TabRetapListener({
    super.key,
    required this.branchIndex,
    required this.scrollController,
    required this.child,
  });

  @override
  State<TabRetapListener> createState() => _TabRetapListenerState();
}

class _TabRetapListenerState extends State<TabRetapListener> {
  TabRetapController? _controller;
  int _seenSequence = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TabRetapScope.maybeOf(context);
    if (_controller != next) {
      _controller?.removeListener(_handleRetap);
      _controller = next;
      _seenSequence = next?.sequence ?? 0;
      _controller?.addListener(_handleRetap);
    }
  }

  void _handleRetap() {
    final ctrl = _controller;
    if (ctrl == null || !mounted) return;
    if (ctrl.sequence == _seenSequence) return;
    _seenSequence = ctrl.sequence;
    if (ctrl.lastRetappedIndex == widget.branchIndex) {
      scrollControllerToTop(context, widget.scrollController);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleRetap);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Detached iOS 18 "Liquid Glass" floating capsule tab bar:
/// - 16dp horizontal margin, sits at `safeArea.bottom + 12dp`
/// - ~64dp capsule height (radius 32 / full pill), grows safely at 2.0x text scale
/// - `RepaintBoundary` + `BackdropFilter(sigma: 24)` with solid elevated fallback
///   when `context.reduceTransparency` is enabled
/// - Animated spring-sliding pill behind active tab (`~280ms`)
/// - Auto-hides on downward scroll, reappears on upward scroll or at top, and
///   hides automatically while the software keyboard is open
/// - Accessible `Semantics(selected, label: '<Tab>, tab X of 4')`, >= 48dp hit
///   targets, and visible keyboard/TalkBack focus ring.
class IosBottomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool visible;

  const IosBottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final media = MediaQuery.of(context);
    final size = media.size;
    final reduceMotion = context.reduceMotion;
    final reduceTransparency = context.reduceTransparency;
    final keyboardOpen = media.viewInsets.bottom > 40;
    final effectiveVisible = visible && !keyboardOpen;

    final isLandscape = media.orientation == Orientation.landscape;
    final isUltraNarrow = size.width < 260;
    final isCompactHeight = size.height < 440;
    final baseHeight = MoglogLayout.effectiveTabBarHeight(context);
    final textScale = media.textScaler.scale(1.0);
    final extraScaleHeight =
        (!isLandscape && !isCompactHeight && textScale > 1.25)
            ? ((textScale - 1.25) * 18.0).clamp(0.0, 18.0)
            : 0.0;
    final capsuleHeight = baseHeight + extraScaleHeight;
    final horizontalMargin =
        size.width < 320 ? 10.0 : MoglogLayout.tabBarHorizontalMargin;
    final bottomInset = media.viewPadding.bottom +
        (isCompactHeight ? 8.0 : MoglogLayout.tabBarBottomMargin);

    Widget capsuleInterior = SizedBox(
      height: capsuleHeight,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabCount = kMoglogMainTabs.length;
            final slotWidth = constraints.maxWidth / tabCount;
            final slotHeight = constraints.maxHeight;

            return Stack(
              children: [
                // Animated spring sliding pill behind active item
                AnimatedPositioned(
                  duration: reduceMotion ? Duration.zero : MoglogMotion.spring,
                  curve: MoglogMotion.springCurve,
                  left: currentIndex * slotWidth,
                  top: 0,
                  width: slotWidth,
                  height: slotHeight,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.glassPillFill,
                        borderRadius: MoglogShapes.pill,
                        border: Border.all(
                          color: c.glassBorder,
                          width: c.hairlineWidth,
                        ),
                        boxShadow: c.isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: c.shadowSoft,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(tabCount, (i) {
                    final tab = kMoglogMainTabs[i];
                    final selected = i == currentIndex;
                    final tint = selected ? c.accentText : c.secondaryLabel;
                    final inlineRow = isLandscape && size.width >= 420;

                    return Expanded(
                      child: _TabCapsuleItem(
                        label: tab.label,
                        semanticLabel:
                            '${tab.label}, tab ${i + 1} of $tabCount',
                        icon: tab.icon,
                        selected: selected,
                        tint: tint,
                        inlineRow: inlineRow,
                        hideLabel: isUltraNarrow || isCompactHeight,
                        reduceMotion: reduceMotion,
                        textStyle: (inlineRow ? t.footnote : t.caption2)
                            .copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: tint,
                          height: 1.15,
                        ),
                        onTap: () {
                          MoglogHaptics.selectionChanged();
                          onTap(i);
                        },
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );

    Widget glassCapsule;
    if (reduceTransparency) {
      glassCapsule = DecoratedBox(
        decoration: BoxDecoration(
          color: c.elevatedSurface,
          borderRadius: MoglogShapes.pill,
          border: Border.all(color: c.glassBorder, width: c.hairlineWidth),
          boxShadow: [
            BoxShadow(
              color: c.tabShadow,
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: capsuleInterior,
      );
    } else {
      glassCapsule = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: MoglogShapes.pill,
          boxShadow: [
            BoxShadow(
              color: c.tabShadow,
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: MoglogShapes.pill,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(c.glassTint, c.glassScrimBase),
                borderRadius: MoglogShapes.pill,
                border: Border.all(
                  color: c.glassBorder,
                  width: c.hairlineWidth,
                ),
              ),
              child: capsuleInterior,
            ),
          ),
        ),
      );
    }

    // Constrain maximum capsule width on wide tablets/landscape so tabs stay cohesive.
    final constrainedCapsule = Center(
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: glassCapsule,
      ),
    );

    return IgnorePointer(
      ignoring: !effectiveVisible,
      child: ExcludeSemantics(
        excluding: !effectiveVisible,
        child: RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalMargin,
              0,
              horizontalMargin,
              bottomInset,
            ),
            child: AnimatedSlide(
              offset: effectiveVisible ? Offset.zero : const Offset(0, 1.35),
              duration: reduceMotion ? Duration.zero : MoglogMotion.standard,
              curve: MoglogMotion.curve,
              child: AnimatedOpacity(
                opacity: effectiveVisible ? 1.0 : 0.0,
                duration: reduceMotion ? Duration.zero : MoglogMotion.fast,
                curve: MoglogMotion.curve,
                child: constrainedCapsule,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabCapsuleItem extends StatefulWidget {
  final String label;
  final String semanticLabel;
  final IconData icon;
  final bool selected;
  final Color tint;
  final bool inlineRow;
  final bool hideLabel;
  final bool reduceMotion;
  final TextStyle textStyle;
  final VoidCallback onTap;

  const _TabCapsuleItem({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.selected,
    required this.tint,
    required this.inlineRow,
    required this.hideLabel,
    required this.reduceMotion,
    required this.textStyle,
    required this.onTap,
  });

  @override
  State<_TabCapsuleItem> createState() => _TabCapsuleItemState();
}

class _TabCapsuleItemState extends State<_TabCapsuleItem> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconWidget = AnimatedScale(
      scale: (widget.selected && !widget.reduceMotion) ? 1.06 : 1.0,
      duration: widget.reduceMotion ? Duration.zero : MoglogMotion.fast,
      curve: MoglogMotion.curve,
      child: Icon(
        widget.icon,
        size: widget.hideLabel ? 20 : 21,
        color: widget.tint,
      ),
    );

    Widget child = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: MoglogLayout.minTouchTarget,
        minHeight: MoglogLayout.minTouchTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: widget.inlineRow
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconWidget,
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.textStyle,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  if (!widget.hideLabel) ...[
                    const SizedBox(height: 3),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: widget.textStyle,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );

    if (_focused) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: MoglogShapes.pill,
          border: Border.all(color: c.accent, width: 2),
        ),
        child: child,
      );
    }

    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) {
          if (_focused != v) setState(() => _focused = v);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: (_pressed && !widget.reduceMotion) ? 0.94 : 1.0,
            duration: widget.reduceMotion ? Duration.zero : MoglogMotion.press,
            curve: MoglogMotion.curve,
            child: child,
          ),
        ),
      ),
    );
  }
}
