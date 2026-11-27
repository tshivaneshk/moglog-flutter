import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/celebration/show_completion_celebration.dart';
import '../core/design_system/components.dart';
import '../core/design_system/theme.dart';
import '../core/design_system/tokens.dart';
import '../core/platform/platform_bridge.dart';
import '../core/security/app_lock_overlay.dart';
import '../domain/model/app_settings.dart';
import '../features/splash/startup_splash_overlay.dart';
import 'providers.dart';
import 'router.dart';

class MoglogApp extends ConsumerStatefulWidget {
  const MoglogApp({super.key});

  @override
  ConsumerState<MoglogApp> createState() => _MoglogAppState();
}

class _MoglogAppState extends ConsumerState<MoglogApp> {
  StreamSubscription<DeepLinkEvent>? _deepLinkSub;
  StreamSubscription<dynamic>? _notifTapSub;
  bool _createAccountDialogShown = false;

  @override
  void initState() {
    super.initState();
    PlatformBridge.init();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(dramaControllerProvider).initialize();
      await syncFlagSecure(ref.read(currentSettingsProvider));
      ref.read(backgroundSchedulerProvider).start();

      final pending = await PlatformBridge.consumePendingDeepLink();
      if (pending != null) _handleDeepLink(pending);

      _deepLinkSub = PlatformBridge.deepLinks.listen(_handleDeepLink);
      _notifTapSub = ref.read(notificationServiceProvider).taps.listen((ev) {
        _handleDeepLink(
          DeepLinkEvent(openDramaId: ev.dramaId, navigateTo: ev.navigateTo),
        );
      });
    });
  }

  void _handleDeepLink(DeepLinkEvent ev) {
    final router = ref.read(routerProvider);
    if (ev.openDramaId != null && ev.openDramaId! > 0) {
      router.push('/detail/${ev.openDramaId}');
    } else if (ev.navigateTo == 'watch_circle') {
      router.push('/watch-circle');
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _notifTapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(currentSettingsProvider);
    final router = ref.watch(routerProvider);
    final isReady = ref.watch(isInitialReadyProvider);
    final toast = ref.watch(toastProvider);
    final celebrationKey = ref.watch(celebrationTriggerProvider);
    final authState = ref.watch(authControllerProvider);

    final themeMode = switch (settings.themeMode) {
      ThemeModeSetting.system => ThemeMode.system,
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.light => ThemeMode.light,
    };

    // Handle new Google account confirmation sheet
    if (authState.pendingCreateAccountPrompt && !_createAccountDialogShown) {
      _createAccountDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final navCtx = router.routerDelegate.navigatorKey.currentContext;
        if (navCtx == null) {
          _createAccountDialogShown = false;
          return;
        }
        final accountEmail = authState.user?.email;
        final accountLabel = (accountEmail != null && accountEmail.isNotEmpty)
            ? accountEmail
            : 'this Google account';
        var confirmed = false;
        await showIosActionSheet(
          context: navCtx,
          title: 'Create Moglog Account?',
          message:
              'No Moglog account exists for $accountLabel yet. Create one now to sync your library?',
          actions: [
            ActionSheetItem(
              label: 'Create Moglog Account',
              onTap: () {
                confirmed = true;
                ref
                    .read(authControllerProvider.notifier)
                    .confirmCreateCloudAccount();
              },
            ),
            ActionSheetItem(
              label: 'Cancel & Sign Out',
              isDestructive: true,
              onTap: () => ref
                  .read(authControllerProvider.notifier)
                  .cancelCreateCloudAccount(),
            ),
          ],
        );
        if (!confirmed &&
            ref.read(authControllerProvider).pendingCreateAccountPrompt) {
          await ref
              .read(authControllerProvider.notifier)
              .cancelCreateCloudAccount();
        }
        _createAccountDialogShown = false;
      });
    }

    return MaterialApp.router(
      title: 'Moglog',
      debugShowCheckedModeBanner: false,
      theme: MoglogTheme.light(),
      darkTheme: MoglogTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final isLightEffective = switch (themeMode) {
          ThemeMode.light => true,
          ThemeMode.dark => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.light,
        };
        final overlayStyle = (isLightEffective
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        );

        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final toastBottom = MoglogLayout.toastBottomOffset(context);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Stack(
            children: [
              // Support full accessibility font scaling up to 2.0x without clipping.
              MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.textScalerOf(context).clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 2.0,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              ),

              // Global Confetti Celebration Overlay
              if (celebrationKey > 0)
                Positioned.fill(
                  child: CelebrationBlastOverlay(
                    triggerKey: celebrationKey,
                    onFinished: () {
                      if (ref.read(celebrationTriggerProvider) ==
                          celebrationKey) {
                        ref.read(celebrationTriggerProvider.notifier).state = 0;
                      }
                    },
                  ),
                ),

              // Global Floating iOS Glass Toast Banner positioned above the floating tab bar
              if (toast != null)
                Positioned(
                  left: MoglogSpacing.md,
                  right: MoglogSpacing.md,
                  bottom: toastBottom,
                  child: IgnorePointer(
                    ignoring: toast.onAction == null,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration:
                              reduceMotion ? Duration.zero : MoglogMotion.fast,
                          child: IosToastBanner(
                            key: ValueKey(toast.id),
                            message: toast.message,
                            actionLabel: toast.actionLabel,
                            onAction: toast.onAction != null
                                ? () {
                                    toast.onAction!();
                                    ref.read(toastProvider.notifier).dismiss();
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Biometric / PIN App Lock & Background Privacy Shield
              AppLockOverlay(
                appLockEnabled: settings.appLockEnabled,
                timeoutSeconds: settings.appLockTimeoutSeconds,
                hideInRecents: settings.hideInRecents,
              ),

              // Startup Splash Overlay (fades out after >= 750ms + DB ready)
              IgnorePointer(
                ignoring: isReady,
                child: AnimatedOpacity(
                  opacity: isReady ? 0.0 : 1.0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 380),
                  curve: Curves.fastOutSlowIn,
                  child: const MoglogStartupSplashScreen(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
