import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/tokens.dart';
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
    transitionDuration: MoglogMotion.page,
    reverseTransitionDuration: MoglogMotion.standard,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: MoglogMotion.curve,
        reverseCurve: MoglogMotion.reverseCurve,
      );
      final secondaryCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: MoglogMotion.curve,
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
            opacity: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Hosts `StatefulShellRoute.indexedStack` with a zero-jank `ValueNotifier`
/// scroll-direction observer so the floating glass tab bar auto-hides on
/// downward scroll, reappears on upward scroll or at top, and broadcasts
/// active-tab re-taps to scroll the current list back to top.
class _MoglogShellScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _MoglogShellScaffold({required this.navigationShell});

  @override
  State<_MoglogShellScaffold> createState() => _MoglogShellScaffoldState();
}

class _MoglogShellScaffoldState extends State<_MoglogShellScaffold> {
  final ValueNotifier<bool> _barVisible = ValueNotifier<bool>(true);
  final TabRetapController _retapController = TabRetapController();
  double _accumulatedDelta = 0.0;

  @override
  void didUpdateWidget(covariant _MoglogShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _accumulatedDelta = 0.0;
      if (!_barVisible.value) {
        _barVisible.value = true;
      }
    }
  }

  @override
  void dispose() {
    _barVisible.dispose();
    _retapController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;

    // Always keep the floating tab bar visible near the top of any scroll view.
    if (pixels <= 24) {
      _accumulatedDelta = 0.0;
      if (!_barVisible.value) {
        _barVisible.value = true;
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;
      if (delta.abs() < 0.5) return false;

      if ((delta > 0 && _accumulatedDelta < 0) ||
          (delta < 0 && _accumulatedDelta > 0)) {
        _accumulatedDelta = 0.0;
      }
      _accumulatedDelta += delta;

      if (_accumulatedDelta > 22.0 && _barVisible.value) {
        _barVisible.value = false;
        _accumulatedDelta = 0.0;
      } else if (_accumulatedDelta < -14.0 && !_barVisible.value) {
        _barVisible.value = true;
        _accumulatedDelta = 0.0;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return TabRetapScope(
      controller: _retapController,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: Stack(
            children: [
              widget.navigationShell,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _barVisible,
                  builder: (context, visible, _) {
                    return IosBottomTabBar(
                      currentIndex: widget.navigationShell.currentIndex,
                      visible: visible,
                      onTap: (index) {
                        final isRetap =
                            index == widget.navigationShell.currentIndex;
                        widget.navigationShell.goBranch(
                          index,
                          initialLocation: isRetap,
                        );
                        if (isRetap) {
                          _retapController.notifyRetap(index);
                        }
                        if (!_barVisible.value) {
                          _barVisible.value = true;
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          return _MoglogShellScaffold(navigationShell: navigationShell);
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
                  onNavigateToSettings: () =>
                      context.push('/settings/advanced'),
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
                  onNavigateToAdvanced: () =>
                      context.push('/settings/advanced'),
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
            onNavigateToRecycleBin: () =>
                context.push('/settings/recycle-bin'),
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
