import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToAccount;
  final VoidCallback onNavigateToWatchCircle;
  final VoidCallback onNavigateToAppearance;
  final VoidCallback onNavigateToAdvanced;
  final VoidCallback onNavigateToAbout;

  const SettingsScreen({
    super.key,
    required this.onNavigateToAccount,
    required this.onNavigateToWatchCircle,
    required this.onNavigateToAppearance,
    required this.onNavigateToAdvanced,
    required this.onNavigateToAbout,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;
  String _versionName = '3.0.73';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    PackageInfo.fromPlatform().then((info) {
      if (mounted && info.version.isNotEmpty) {
        setState(() => _versionName = info.version);
      }
    }).catchError((_) {});
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (!_headerCollapsed && offset > 60) {
      setState(() => _headerCollapsed = true);
    } else if (_headerCollapsed && offset < 16) {
      setState(() => _headerCollapsed = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleEpisodeReminders(bool enabled) async {
    if (enabled && Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        ref.read(toastProvider.notifier).show(
              'Notification permission is required for episode reminders.',
            );
        return;
      }
    }
    await ref.read(settingsStoreProvider).setEpisodeRemindersEnabled(enabled);
    final scheduler = ref.read(backgroundSchedulerProvider);
    if (enabled) {
      scheduler.enableEpisodeReminders(runImmediateCheck: true);
      ref
          .read(toastProvider.notifier)
          .show('Episode air-date reminders enabled');
    } else {
      scheduler.disableEpisodeReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final settings = ref.watch(currentSettingsProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    final displayName = settings.customDisplayName.trim().isNotEmpty
        ? settings.customDisplayName.trim()
        : (user?.displayName ?? 'Moglog Guest');
    final emailSubtitle = user != null
        ? (user.email ?? 'Signed in with Google')
        : 'Sign in with Google for Cloud Sync & Watch Circle';

    ImageProvider? avatarImg;
    if (settings.customProfileImageBase64.trim().isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(settings.customProfileImageBase64));
      } catch (_) {}
    } else if ((user?.photoURL ?? '').isNotEmpty) {
      avatarImg = NetworkImage(user!.photoURL!);
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'Settings',
            collapsed: _headerCollapsed,
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
              children: [
                // Top Hero Profile Card
                IosPressable(
                  onTap: widget.onNavigateToAccount,
                  hapticOnTap: true,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: ShapeDecoration(
                      color: c.secondaryBackground,
                      shape: MoglogShapes.smooth(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: c.tertiaryBackground,
                          backgroundImage: avatarImg,
                          child: avatarImg == null
                              ? Icon(MoglogIcons.person,
                                  size: 26, color: c.accent)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: t.title3.copyWith(color: c.label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                emailSubtitle,
                                style: t.footnote.copyWith(
                                  color: c.secondaryLabel,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          MoglogIcons.chevronRight,
                          size: 18,
                          color: c.tertiaryLabel,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Connected Services
                IosGroupedSection(
                  header: 'Connected Services',
                  children: [
                    IosGroupedRow(
                      title: 'Watch Circle & Friends',
                      subtitle: user != null
                          ? '${authState.circleFriends.length} connected friend${authState.circleFriends.length == 1 ? "" : "s"}'
                          : 'Taste Blend, co-watching race & nudges',
                      icon: MoglogIcons.users,
                      iconBackground: c.accent,
                      showChevron: true,
                      showDivider: user != null,
                      onTap: widget.onNavigateToWatchCircle,
                    ),
                    if (user != null)
                      IosSwitchRow(
                        title: 'Share My Watch Activity',
                        subtitle: 'Visible only to your Watch Circle friends',
                        icon: MoglogIcons.sparkles,
                        iconBackground: c.statusPlanned,
                        value: settings.watchCircleSharingEnabled,
                        showDivider: false,
                        onChanged: (v) async {
                          await ref
                              .read(settingsStoreProvider)
                              .setWatchCircleSharingEnabled(v);
                          await ref
                              .read(watchCircleRepositoryProvider)
                              .publishMyActivity(ref.read(currentDramasProvider));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Preferences
                IosGroupedSection(
                  header: 'Preferences',
                  children: [
                    IosGroupedRow(
                      title: 'Appearance',
                      subtitle: 'Theme, poster accent tint, grid & list layout',
                      icon: MoglogIcons.sunMoon,
                      iconBackground: c.statusWatching,
                      showChevron: true,
                      onTap: widget.onNavigateToAppearance,
                    ),
                    IosGroupedRow(
                      title: 'Advanced & Storage',
                      subtitle:
                          'App lock, backups (.moglog / CSV), Recycle Bin, TMDB key',
                      icon: MoglogIcons.shield,
                      iconBackground: c.statusPlanned,
                      showChevron: true,
                      showDivider: false,
                      onTap: widget.onNavigateToAdvanced,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Notifications
                IosGroupedSection(
                  header: 'Notifications',
                  footer:
                      'Checks your Watching shows every 12 hours for episodes airing today.',
                  children: [
                    IosSwitchRow(
                      title: 'Episode Air-Date Reminders',
                      subtitle: 'Notify when new episodes air today',
                      icon: MoglogIcons.bell,
                      iconBackground: c.destructive,
                      value: settings.episodeRemindersEnabled,
                      showDivider: false,
                      onChanged: _toggleEpisodeReminders,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // About
                IosGroupedSection(
                  header: 'About',
                  children: [
                    IosGroupedRow(
                      title: 'About Moglog',
                      subtitle: 'Updates, GitHub Releases, Privacy & Security',
                      icon: MoglogIcons.award,
                      iconBackground: c.accent,
                      showChevron: true,
                      onTap: widget.onNavigateToAbout,
                    ),
                    IosGroupedRow(
                      title: 'Version',
                      subtitle: 'v$_versionName (SQLCipher + E2E)',
                      icon: MoglogIcons.lock,
                      iconBackground: c.tertiaryBackground,
                      showDivider: false,
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
