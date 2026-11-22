import 'package:flutter/material.dart';

import '../core/design_system/components.dart';
import '../core/design_system/icons.dart';
import '../core/design_system/motion_haptics.dart';
import '../core/design_system/theme.dart';

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

/// Exact 1:1 port of Kotlin `IosBottomTabBar.kt`:
/// Translucent frosted 4-tab bar adapting to compact inline layout in landscape.
class IosBottomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const IosBottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final size = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isUltraNarrow = size.width < 250;
    final isCompactHeight = size.height < 440;

    final double barHeight;
    if (isLandscape || isCompactHeight) {
      barHeight = 44;
    } else if (isUltraNarrow) {
      barHeight = 46;
    } else {
      barHeight = 56;
    }

    return IosFrostedBar(
      showTopBorder: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width < 320 ? 4 : 8),
            child: Row(
              children: List.generate(kMoglogMainTabs.length, (i) {
                final tab = kMoglogMainTabs[i];
                final selected = i == currentIndex;
                final tint = selected ? c.accent : c.secondaryLabel;

                return Expanded(
                  child: IosPressable(
                    pressedScale: 0.94,
                    onTap: () {
                      if (!selected) MoglogHaptics.selectionChanged();
                      onTap(i);
                    },
                    child: (isLandscape && size.width >= 380)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(tab.icon, size: 18, color: tint),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.footnote.copyWith(
                                    fontSize: size.width < 460 ? 11.5 : 13,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: tint,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tab.icon,
                                size:
                                    (isCompactHeight || isUltraNarrow) ? 19 : 22,
                                color: tint,
                              ),
                              if (!isUltraNarrow && !isCompactHeight) ...[
                                const SizedBox(height: 2),
                                Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.caption.copyWith(
                                    fontSize: size.width < 310 ? 9 : 10,
                                    height: 1.1,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: tint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
