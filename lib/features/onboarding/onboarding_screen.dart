import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/security/secure_store.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _tmdbCtrl = TextEditingController();
  int _step = 0;
  String? _keyError;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _tmdbCtrl.text = ref.read(secureStoreProvider).getUserTmdbCredentialOrEmpty();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tmdbCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await ref.read(settingsStoreProvider).setFirstLaunchCompleted();
    widget.onCompleted();
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _tmdbCtrl.text = text;
      setState(() => _keyError = null);
    }
  }

  Future<void> _saveKeyAndContinue() async {
    final raw = _tmdbCtrl.text.trim();
    if (raw.isNotEmpty) {
      if (!SecureStore.isValidTmdbCredentialFormat(raw)) {
        setState(() {
          _keyError =
              'Enter a valid 32-character TMDB v3 API Key or a TMDB v4 Read Access Token (JWT).';
        });
        return;
      }
      await ref.read(dramaControllerProvider).saveTmdbApiKey(raw);
    }
    setState(() => _keyError = null);
    _goToStep(2);
  }

  void _goToStep(int target) {
    setState(() => _step = target);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _showHowToGetKeySheet() {
    final c = context.colors;
    final t = context.typo;
    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to get a free TMDB key',
              style: t.title2.copyWith(color: c.label),
            ),
            const SizedBox(height: 10),
            Text(
              '1. Create a free account on themoviedb.org.\n'
              '2. Go to Settings → API → Request an API Key (Developer).\n'
              '3. Copy either your 32-character API Key (v3) or API Read Access Token (v4).\n'
              '4. Paste it here—your key is stored encrypted on your device and never leaves it.',
              style: t.subhead.copyWith(color: c.secondaryLabel, height: 1.5),
            ),
            const SizedBox(height: 18),
            IosPrimaryButton(
              text: 'Open Visual Setup Guide',
              leadingIcon: MoglogIcons.externalLink,
              onTap: () => launchUrl(
                Uri.parse('https://moglog-instructions.vercel.app/obtain-api-key'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 10),
            IosSecondaryButton(
              text: 'Sign Up on TMDB',
              leadingIcon: MoglogIcons.key,
              onTap: () => launchUrl(
                Uri.parse('https://www.themoviedb.org/signup'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(3, (i) {
                      final active = i == _step;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? c.accent : c.tertiaryBackground,
                          borderRadius: MoglogShapes.pill,
                        ),
                      );
                    }),
                  ),
                  IosPressable(
                    onTap: _finishOnboarding,
                    hapticOnTap: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        'Skip',
                        style: t.callout.copyWith(
                          color: c.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) => PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    // Step 0: Welcome (centered vertically & horizontally)
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 32).clamp(0, 1200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: ShapeDecoration(
                                shape: MoglogShapes.smooth(
                                  24,
                                  side: BorderSide(
                                    color: c.accent.withValues(alpha: 0.4),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/images/app_logo2.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Welcome to Moglog',
                              style: t.title1.copyWith(color: c.label),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'A clean, fluid library for your dramas, series, and anime—encrypted on your device by default.',
                              style: t.subhead.copyWith(color: c.secondaryLabel),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            _FeatureHighlightTile(
                              icon: MoglogIcons.library,
                              color: c.accent,
                              title: 'Track Every Episode',
                              subtitle:
                                  'Multi-season steppers, binge time estimates, custom shelves, and completion celebrations.',
                            ),
                            const SizedBox(height: 12),
                            _FeatureHighlightTile(
                              icon: MoglogIcons.shield,
                              color: c.statusPlanned,
                              title: 'Local-First SQLCipher Encryption',
                              subtitle:
                                  'Your library and watch ratings stay encrypted on-device with 256-bit AES.',
                            ),
                            const SizedBox(height: 12),
                            _FeatureHighlightTile(
                              icon: MoglogIcons.users,
                              color: c.statusWatching,
                              title: 'Watch Circle & Taste Blend',
                              subtitle:
                                  'Compare compatibility with friends, race co-watched episodes, and send quick nudges.',
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Step 1: TMDB Credential (centered matching Kotlin OnboardingScreen)
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 32).clamp(0, 1200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: c.accentSubtle,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child:
                                  Icon(MoglogIcons.key, size: 36, color: c.accent),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Connect to TMDB',
                              style: t.title1.copyWith(color: c.label),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Paste your free TMDB v3 API Key (32 hex chars) or v4 Read Access Token to unlock search, posters, cast, and air dates.',
                              style: t.subhead.copyWith(color: c.secondaryLabel),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                color: c.secondaryBackground,
                                borderRadius: MoglogShapes.card,
                                border: Border.all(
                                  color: _keyError != null
                                      ? c.destructive
                                      : c.separator,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              child: TextField(
                                controller: _tmdbCtrl,
                                style: t.subhead.copyWith(color: c.label),
                                maxLines: 3,
                                minLines: 2,
                                cursorColor: c.accent,
                                onChanged: (_) {
                                  if (_keyError != null) {
                                    setState(() => _keyError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'Paste TMDB API Key or v4 Read Token…',
                                  hintStyle: t.subhead
                                      .copyWith(color: c.tertiaryLabel),
                                ),
                              ),
                            ),
                            if (_keyError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _keyError!,
                                style: t.footnote.copyWith(color: c.destructive),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 14),
                            IosSecondaryButton(
                              text: 'Paste from Clipboard',
                              leadingIcon: MoglogIcons.copy,
                              onTap: _pasteClipboard,
                            ),
                            const SizedBox(height: 10),
                            IosPressable(
                              onTap: _showHowToGetKeySheet,
                              hapticOnTap: true,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  'How to get a free TMDB key',
                                  style: t.subhead.copyWith(
                                    color: c.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Step 2: Optional Cloud Sync (centered matching Kotlin OnboardingScreen)
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 32).clamp(0, 1200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: c.statusPlanned.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                MoglogIcons.cloud,
                                size: 36,
                                color: c.statusPlanned,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Zero-Knowledge Cloud Sync',
                              style: t.title1.copyWith(color: c.label),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Optionally sign in with Google and set a passphrase to back up your library with AES-256-GCM end-to-end encryption.',
                              style: t.subhead.copyWith(color: c.secondaryLabel),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            if (authState.user != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: ShapeDecoration(
                                  color: c.secondaryBackground,
                                  shape: MoglogShapes.smooth(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(MoglogIcons.check, color: c.accent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Signed in as ${authState.user!.email ?? authState.user!.displayName ?? "Google Account"}',
                                        style: t.subhead.copyWith(color: c.label),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              IosSecondaryButton(
                                text: _signingIn
                                    ? 'Signing in…'
                                    : 'Sign In with Google',
                                leadingIcon: MoglogIcons.person,
                                onTap: _signingIn
                                    ? null
                                    : () async {
                                        setState(() => _signingIn = true);
                                        final err = await ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .signInWithGoogle();
                                        if (mounted) {
                                          setState(() => _signingIn = false);
                                          if (err != null) {
                                            ref
                                                .read(toastProvider.notifier)
                                                .show(err);
                                          }
                                        }
                                      },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: IosPrimaryButton(
                text: _step == 2 ? 'Get Started' : 'Continue',
                onTap: () {
                  if (_step == 0) {
                    _goToStep(1);
                  } else if (_step == 1) {
                    _saveKeyAndContinue();
                  } else {
                    _finishOnboarding();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureHighlightTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureHighlightTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: c.secondaryBackground,
        shape: MoglogShapes.smooth(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.headline.copyWith(color: c.label, fontSize: 15.5),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
