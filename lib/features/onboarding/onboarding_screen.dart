import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';
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
    _tmdbCtrl.text =
        ref.read(secureStoreProvider).getUserTmdbCredentialOrEmpty();
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
    if (context.reduceMotion) {
      _pageController.jumpToPage(target);
    } else {
      _pageController.animateToPage(
        target,
        duration: MoglogMotion.spring,
        curve: MoglogMotion.curve,
      );
    }
  }

  void _showHowToGetKeySheet() {
    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        final t = ctx.typo;
        return SingleChildScrollView(
          padding: MoglogSpacing.sheetPadding,
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
                  Uri.parse(
                    'https://moglog-instructions.vercel.app/obtain-api-key',
                  ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final reduceMotion = context.reduceMotion;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MoglogSpacing.md,
                vertical: 6,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    label: 'Step ${_step + 1} of 3',
                    child: Row(
                      children: List.generate(3, (i) {
                        final active = i == _step;
                        return AnimatedContainer(
                          duration:
                              reduceMotion ? Duration.zero : MoglogMotion.fast,
                          curve: MoglogMotion.curve,
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active ? c.accent : c.tertiaryBackground,
                            borderRadius: MoglogShapes.pill,
                          ),
                        );
                      }),
                    ),
                  ),
                  IosTertiaryButton(
                    text: 'Skip',
                    textColor: c.secondaryLabel,
                    size: MoglogButtonSize.small,
                    onTap: _finishOnboarding,
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
                    // Step 0: Welcome
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MoglogSpacing.xl,
                        vertical: MoglogSpacing.md,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 32).clamp(0, 1200),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                    shadows: [
                                      BoxShadow(
                                        color: c.accent.withValues(
                                          alpha: c.isDark ? 0.22 : 0.14,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.asset(
                                    'assets/images/app_logo2.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  'Welcome to Moglog',
                                  style: t.title1.copyWith(color: c.label),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Track dramas, series, and anime privately on your device.',
                                  style: t.subhead
                                      .copyWith(color: c.secondaryLabel),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                _FeatureHighlightTile(
                                  icon: MoglogIcons.library,
                                  color: c.accentText,
                                  badgeBg: c.accentSubtle,
                                  title: 'Track Every Episode',
                                  subtitle:
                                      'Steppers, binge estimates & custom shelves.',
                                ),
                                const SizedBox(height: 12),
                                _FeatureHighlightTile(
                                  icon: MoglogIcons.shield,
                                  color: c.statusTextColor('Planned'),
                                  badgeBg:
                                      c.statusPlanned.withValues(alpha: 0.15),
                                  title: 'Private On-Device Storage',
                                  subtitle:
                                      'Your library stays encrypted on device.',
                                  infoDescription:
                                      'Your watchlist and API credentials stay private and encrypted on your device.',
                                ),
                                const SizedBox(height: 12),
                                _FeatureHighlightTile(
                                  icon: MoglogIcons.users,
                                  color: c.statusTextColor('Watching'),
                                  badgeBg:
                                      c.statusWatching.withValues(alpha: 0.15),
                                  title: 'Watch Circle & Taste Blend',
                                  subtitle:
                                      'Compare taste & race shows with friends.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Step 1: TMDB Credential
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MoglogSpacing.xl,
                        vertical: MoglogSpacing.md,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 32).clamp(0, 1200),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: ShapeDecoration(
                                    color: c.accentSubtle,
                                    shape: MoglogShapes.smooth(
                                      24,
                                      side: BorderSide(
                                        color: c.glassBorder,
                                        width: c.hairlineWidth,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    MoglogIcons.key,
                                    size: 34,
                                    color: c.accentText,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Connect to TMDB',
                                  style: t.title1.copyWith(color: c.label),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Paste your free TMDB key for search & posters.',
                                  style: t.subhead
                                      .copyWith(color: c.secondaryLabel),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  decoration: ShapeDecoration(
                                    color: c.secondaryBackground,
                                    shape: MoglogShapes.smooth(
                                      MoglogShapes.cardRadius,
                                      side: BorderSide(
                                        color: _keyError != null
                                            ? c.destructive
                                            : c.cardBorder,
                                        width: _keyError != null
                                            ? 1.2
                                            : c.hairlineWidth,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
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
                                    style: t.footnote
                                        .copyWith(color: c.destructive),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                IosSecondaryButton(
                                  text: 'Paste from Clipboard',
                                  leadingIcon: MoglogIcons.copy,
                                  onTap: _pasteClipboard,
                                ),
                                const SizedBox(height: 8),
                                IosTertiaryButton(
                                  text: 'How to get a free TMDB key',
                                  onTap: _showHowToGetKeySheet,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Step 2: Optional Cloud Sync
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MoglogSpacing.xl,
                        vertical: MoglogSpacing.md,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 32).clamp(0, 1200),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: ShapeDecoration(
                                    color:
                                        c.statusPlanned.withValues(alpha: 0.16),
                                    shape: MoglogShapes.smooth(
                                      24,
                                      side: BorderSide(
                                        color: c.glassBorder,
                                        width: c.hairlineWidth,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    MoglogIcons.cloud,
                                    size: 34,
                                    color: c.statusTextColor('Planned'),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Private Cloud Sync',
                                        style:
                                            t.title1.copyWith(color: c.label),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const IosInfoButton(
                                      title: 'Cloud Encryption',
                                      description:
                                          'Optional password-protected cloud backup encrypted on your device before upload.',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in with Google to back up your library across devices.',
                                  style: t.subhead
                                      .copyWith(color: c.secondaryLabel),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                if (authState.user != null)
                                  IosCard(
                                    child: Row(
                                      children: [
                                        Icon(
                                          MoglogIcons.check,
                                          color: c.accentText,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Signed in as ${authState.user!.email ?? authState.user!.displayName ?? "Google Account"}',
                                            style: t.subhead
                                                .copyWith(color: c.label),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  IosSecondaryButton(
                                    text: 'Sign In with Google',
                                    leadingIcon: MoglogIcons.person,
                                    loading: _signingIn,
                                    onTap: _signingIn
                                        ? null
                                        : () async {
                                            setState(() => _signingIn = true);
                                            final err = await ref
                                                .read(
                                                  authControllerProvider
                                                      .notifier,
                                                )
                                                .signInWithGoogle();
                                            if (mounted) {
                                              setState(
                                                () => _signingIn = false,
                                              );
                                              if (err != null) {
                                                ref
                                                    .read(
                                                        toastProvider.notifier)
                                                    .show(err);
                                              }
                                            }
                                          },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
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
  final Color badgeBg;
  final String title;
  final String subtitle;
  final String? infoDescription;

  const _FeatureHighlightTile({
    required this.icon,
    required this.color,
    required this.badgeBg,
    required this.title,
    required this.subtitle,
    this.infoDescription,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return IosCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: badgeBg,
              shape: MoglogShapes.smooth(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.subhead.copyWith(
                          color: c.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (infoDescription != null &&
                        infoDescription!.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      IosInfoButton(
                        title: title,
                        description: infoDescription!,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: c.secondaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
