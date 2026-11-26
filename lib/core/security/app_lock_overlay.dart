import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../design_system/components.dart';
import '../design_system/icons.dart';
import '../design_system/theme.dart';

/// Full-screen biometric/PIN lock & background privacy shield matching Kotlin `AppLockOverlay.kt`.
class AppLockOverlay extends StatefulWidget {
  final bool appLockEnabled;
  final int timeoutSeconds;
  final bool hideInRecents;

  const AppLockOverlay({
    super.key,
    required this.appLockEnabled,
    required this.timeoutSeconds,
    required this.hideInRecents,
  });

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay>
    with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Stopwatch _backgroundWatch = Stopwatch();

  bool _isLocked = false;
  bool _isBackgroundShielded = false;
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.appLockEnabled) {
      _isLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void didUpdateWidget(covariant AppLockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.appLockEnabled && _isLocked) {
      _backgroundWatch
        ..stop()
        ..reset();
      setState(() {
        _isLocked = false;
        _errorMessage = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if ((widget.appLockEnabled || widget.hideInRecents) &&
          !_isBackgroundShielded) {
        setState(() => _isBackgroundShielded = true);
      }
      if ((state == AppLifecycleState.paused ||
              state == AppLifecycleState.hidden) &&
          widget.appLockEnabled &&
          !_backgroundWatch.isRunning) {
        _backgroundWatch
          ..reset()
          ..start();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isBackgroundShielded) {
        setState(() => _isBackgroundShielded = false);
      }
      if (widget.appLockEnabled) {
        if (_backgroundWatch.isRunning) {
          final elapsedSec = _backgroundWatch.elapsed.inSeconds;
          _backgroundWatch
            ..stop()
            ..reset();
          if (elapsedSec >= widget.timeoutSeconds) {
            setState(() => _isLocked = true);
            _authenticate();
            return;
          }
        }
        if (_isLocked && !_isAuthenticating) {
          _authenticate();
        }
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || !mounted) return;
    _isAuthenticating = true;
    setState(() => _errorMessage = null);

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!isSupported && !canCheck) {
        // Exact parity: auto-unlock only if device has no biometric/PIN credential enrolled at OS level
        if (mounted) {
          setState(() {
            _isLocked = false;
            _isAuthenticating = false;
          });
        }
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Moglog with biometrics or device PIN',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (mounted) {
        setState(() {
          _isLocked = !ok;
          _errorMessage =
              ok ? null : 'Authentication cancelled. Tap Unlock to retry.';
        });
      }
    } on PlatformException catch (e) {
      // Fail-closed: NEVER unlock on biometric lockout or platform error
      if (mounted) {
        final isLockout =
            e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut';
        setState(() {
          _isLocked = true;
          _errorMessage = isLockout
              ? 'Too many failed attempts. Wait briefly or use your device PIN to unlock.'
              : 'Authentication failed. Tap Unlock to retry.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocked = true;
          _errorMessage = 'Authentication failed. Tap Unlock to retry.';
        });
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked && !_isBackgroundShielded) return const SizedBox.shrink();
    final c = context.colors;
    final t = context.typo;

    return Positioned.fill(
      child: Material(
        color: c.background,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: c.secondaryBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(MoglogIcons.lock, size: 32, color: c.accent),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Moglog is Locked',
                    style: t.title2.copyWith(color: c.label),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ??
                        'Authenticate with biometrics or your device PIN to continue.',
                    style: t.subhead.copyWith(color: c.secondaryLabel),
                    textAlign: TextAlign.center,
                  ),
                  if (_isLocked) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 210,
                      child: IosPrimaryButton(
                        text: 'Unlock Moglog',
                        leadingIcon: MoglogIcons.shield,
                        onTap: _authenticate,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
