import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/detail/detail_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/library/library_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/account_settings_screen.dart';
import '../features/settings/advanced_settings_screen.dart';
import '../features/settings/appearance_settings_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/recycle_bin_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/social/watch_circle_screen.dart';
import '../features/stats/stats_screen.dart';
import 'ios_bottom_tab_bar.dart';
import 'providers.dart';

CustomTransitionPage<void> _iosSlidePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final secondaryCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.28, 0),
        ).animate(secondaryCurved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final isFirstLaunch = ref.read(settingsStoreProvider).state.isFirstLaunch;

  return GoRouter(
    initialLocation: isFirstLaunch ? '/onboarding' : '/library',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          onCompleted: () => context.go('/library'),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: Stack(
              children: [
                navigationShell,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IosBottomTabBar(
                    currentIndex: navigationShell.currentIndex,
                    onTap: (index) {
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => LibraryScreen(
                  onDramaTap: (id) => context.push('/detail/$id'),
                  onNavigateToDiscover: () => context.go('/discover'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => DiscoverScreen(
                  onDramaTap: (id) => context.push('/detail/$id'),
                  onNavigateToSettings: () => context.push('/settings/advanced'),
                  onNavigateToWatchCircle: () => context.push('/watch-circle'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => StatsScreen(
                  onDramaTap: (id) => context.push('/detail/$id'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => SettingsScreen(
                  onNavigateToAccount: () => context.push('/settings/account'),
                  onNavigateToWatchCircle: () => context.push('/watch-circle'),
                  onNavigateToAppearance: () =>
                      context.push('/settings/appearance'),
                  onNavigateToAdvanced: () => context.push('/settings/advanced'),
                  onNavigateToAbout: () => context.push('/settings/about'),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/detail/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return _iosSlidePage(
            key: state.pageKey,
            child: DetailScreen(
              dramaId: id,
              onBack: () => context.pop(),
              onOpenRecommendation: (recId) => context.push('/detail/$recId'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/watch-circle',
        pageBuilder: (context, state) => _iosSlidePage(
          key: state.pageKey,
          child: WatchCircleScreen(
            onBack: () => context.pop(),
            onDramaTap: (id) => context.push('/detail/$id'),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/account',
        pageBuilder: (context, state) => _iosSlidePage(
          key: state.pageKey,
          child: AccountSettingsScreen(onBack: () => context.pop()),
        ),
      ),
      GoRoute(
        path: '/settings/appearance',
        pageBuilder: (context, state) => _iosSlidePage(
          key: state.pageKey,
          child: AppearanceSettingsScreen(onBack: () => context.pop()),
        ),
      ),
      GoRoute(
        path: '/settings/advanced',
        pageBuilder: (context, state) => _iosSlidePage(
          key: state.pageKey,
          child: AdvancedSettingsScreen(
            onBack: () => context.pop(),
            onNavigateToRecycleBin: () => context.push('/settings/recycle-bin'),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/recycle-bin',
        pageBuilder: (context, state) => _iosSlidePage(
          key: state.pageKey,
          child: RecycleBinScreen(onBack: () => context.pop()),
        ),
      ),
      GoRoute(
        path: '/settings/about',
        pageBuilder: (context, state) => _iosSlidePage(
          key: state.pageKey,
          child: AboutScreen(
            onBack: () => context.pop(),
            onNavigateToPrivacy: () => context.push('/settings/privacy'),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (context, state) => _iosSlidePage(
          key: state.pageKey,
          child: PrivacyScreen(onBack: () => context.pop()),
        ),
      ),
    ],
  );
});
