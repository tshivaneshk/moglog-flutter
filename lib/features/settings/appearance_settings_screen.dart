import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/theme.dart';
import '../../domain/model/app_settings.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const AppearanceSettingsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.typo;
    final settings = ref.watch(currentSettingsProvider);
    final store = ref.read(settingsStoreProvider);

    const modes = [
      ThemeModeSetting.system,
      ThemeModeSetting.dark,
      ThemeModeSetting.light,
    ];
    final themeIdx = modes.indexOf(settings.themeMode).clamp(0, 2);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'Appearance',
            collapsed: true,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              onTap: onBack,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              children: [
                IosGroupedSection(
                  header: 'Theme',
                  footer:
                      'Dark mode uses true OLED black (#000000) matching native Moglog.',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: IosSegmentedControl(
                        labels: const ['System', 'Dark', 'Light'],
                        selectedIndex: themeIdx,
                        onSelected: (i) => store.setThemeMode(modes[i]),
                      ),
                    ),
                    IosSwitchRow(
                      title: 'Dynamic Poster Accent Tint',
                      subtitle:
                          'Adapt show detail accents from each series poster',
                      icon: MoglogIcons.sparkles,
                      iconBackground: c.accent,
                      value: settings.dynamicPosterTint,
                      showDivider: false,
                      onChanged: (v) => store.setDynamicPosterTint(v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                IosGroupedSection(
                  header: 'Library Layout',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: IosSegmentedControl(
                        labels: const ['Poster Grid', 'Compact List'],
                        selectedIndex:
                            settings.layoutMode == LibraryLayoutMode.grid ? 0 : 1,
                        onSelected: (i) => store.setLayoutMode(
                          i == 0
                              ? LibraryLayoutMode.grid
                              : LibraryLayoutMode.list,
                        ),
                      ),
                    ),
                    IosGroupedRow(
                      title: 'Poster Grid Density',
                      subtitle: 'Tap to cycle 2 → 3 → 4 columns',
                      icon: MoglogIcons.grid,
                      iconBackground: c.statusPlanned,
                      showDivider: false,
                      trailing: Text(
                        '${settings.gridColumns} Columns',
                        style: t.subhead.copyWith(
                          color: c.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        final next = settings.gridColumns == 2
                            ? 3
                            : (settings.gridColumns == 3 ? 4 : 2);
                        store.setGridColumns(next);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
