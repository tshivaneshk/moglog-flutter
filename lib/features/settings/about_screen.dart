import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';
import '../../domain/logic/version_checker.dart';

sealed class _UpdateCheckState {
  const _UpdateCheckState();
}

class _UpdateIdle extends _UpdateCheckState {
  const _UpdateIdle();
}

class _UpdateChecking extends _UpdateCheckState {
  const _UpdateChecking();
}

class _UpdateUpToDate extends _UpdateCheckState {
  final String version;
  const _UpdateUpToDate(this.version);
}

class _UpdateAvailable extends _UpdateCheckState {
  final String latestVersion;
  final String releaseTitle;
  final String releaseNotes;
  final String downloadUrl;
  final String releasePageUrl;

  const _UpdateAvailable({
    required this.latestVersion,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releasePageUrl,
  });
}

class _UpdateError extends _UpdateCheckState {
  final String message;
  const _UpdateError(this.message);
}

class AboutScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNavigateToPrivacy;

  const AboutScreen({
    super.key,
    required this.onBack,
    required this.onNavigateToPrivacy,
  });

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const int _aboutCacheTtlMs = 30 * 60 * 1000;
  static _UpdateCheckState? _cachedUpdateState;
  static int _cachedUpdateAtMs = 0;
  static int? _cachedTotalDownloads;
  static int _cachedDownloadsAtMs = 0;

  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;
  String _versionName = '3.2.0';
  _UpdateCheckState _updateState = const _UpdateIdle();
  int? _totalDownloads;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {'User-Agent': 'Moglog-Flutter-App'},
    ),
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initAndCheck();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (!_headerCollapsed && offset > 48) {
      setState(() => _headerCollapsed = true);
    } else if (_headerCollapsed && offset < 14) {
      setState(() => _headerCollapsed = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _initAndCheck() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() => _versionName = info.version);
      }
    } catch (_) {}
    _checkUpdate(forceRefresh: false);
    _fetchDownloadStats(forceRefresh: false);
  }

  Future<void> _checkUpdate({bool forceRefresh = false}) async {
    if (_updateState is _UpdateChecking) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!forceRefresh &&
        _cachedUpdateState != null &&
        (now - _cachedUpdateAtMs) < _aboutCacheTtlMs) {
      if (mounted) {
        setState(() => _updateState = _cachedUpdateState!);
      }
      return;
    }
    setState(() => _updateState = const _UpdateChecking());
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/tshivaneshk/Moglog-Releases/releases/latest',
        options: Options(
          headers: const {'Accept': 'application/vnd.github.v3+json'},
        ),
      );
      final data = res.data;
      if (data == null) {
        if (mounted) {
          setState(
            () =>
                _updateState = const _UpdateError('Empty response from server'),
          );
        }
        return;
      }
      final tagName = (data['tag_name'] as String? ?? '').trim();
      final releaseTitle = (data['name'] as String?) ?? 'Moglog Update';
      final releaseNotes = (data['body'] as String?) ?? '';
      const defaultReleaseUrl =
          'https://github.com/tshivaneshk/Moglog-Releases/releases/latest';
      final releasePageUrl = sanitizeTrustedUpdateUrl(
        (data['html_url'] as String?) ?? defaultReleaseUrl,
        defaultReleaseUrl,
      );

      const defaultDownloadUrl =
          'https://moglog-instructions.vercel.app/download';
      var downloadUrl = defaultDownloadUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets.whereType<Map<String, dynamic>>()) {
          final name = (a['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk') && !name.contains('app-debug')) {
            downloadUrl = sanitizeTrustedUpdateUrl(
              (a['browser_download_url'] as String?) ?? defaultDownloadUrl,
              defaultDownloadUrl,
            );
            break;
          }
        }
      }

      if (!mounted) return;
      final _UpdateCheckState nextState;
      if (isNewerVersion(current: _versionName, latest: tagName)) {
        nextState = _UpdateAvailable(
          latestVersion: tagName,
          releaseTitle: releaseTitle,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
          releasePageUrl: releasePageUrl,
        );
      } else {
        nextState = _UpdateUpToDate(_versionName);
      }
      _cachedUpdateState = nextState;
      _cachedUpdateAtMs = DateTime.now().millisecondsSinceEpoch;
      setState(() => _updateState = nextState);
    } catch (e) {
      if (mounted) {
        setState(() => _updateState = _UpdateError(e.toString()));
      }
    }
  }

  Future<void> _fetchDownloadStats({bool forceRefresh = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!forceRefresh &&
        _cachedTotalDownloads != null &&
        (now - _cachedDownloadsAtMs) < _aboutCacheTtlMs) {
      if (mounted) {
        setState(() => _totalDownloads = _cachedTotalDownloads);
      }
      return;
    }
    int? count;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://moglog-instructions.vercel.app/api/badge?format=json',
      );
      final live = (res.data?['totalDownloads'] as num?)?.toInt() ?? -1;
      if (live > 0) count = live;
    } catch (_) {}

    if (count == null) {
      try {
        final res = await _dio.get<List<dynamic>>(
          'https://api.github.com/repos/tshivaneshk/Moglog-Releases/releases',
          options: Options(
            headers: const {'Accept': 'application/vnd.github.v3+json'},
          ),
        );
        var sum = 0;
        for (final rel
            in (res.data ?? const []).whereType<Map<String, dynamic>>()) {
          final assets = rel['assets'];
          if (assets is List) {
            for (final a in assets.whereType<Map<String, dynamic>>()) {
              final name = (a['name'] as String? ?? '').toLowerCase();
              if (name.endsWith('.apk')) {
                sum += (a['download_count'] as num?)?.toInt() ?? 0;
              }
            }
          }
        }
        if (sum > 0) count = sum;
      } catch (_) {}
    }

    if (count != null) {
      _cachedTotalDownloads = count;
      _cachedDownloadsAtMs = DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        setState(() => _totalDownloads = count);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    final footerText = switch (_updateState) {
      _UpdateUpToDate() => 'You are using the latest version of Moglog.',
      _UpdateAvailable() =>
        'A new signed APK release is ready for installation.',
      _UpdateError(message: final m) => 'Check failed: $m',
      _ => 'Check GitHub Releases for the newest signed APK build.',
    };

    final subtitleText = switch (_updateState) {
      _UpdateChecking() => 'Contacting release repository...',
      _UpdateUpToDate() => 'Up to date (v$_versionName)',
      _UpdateAvailable() => 'New version available',
      _UpdateError() => 'Tap to retry update check',
      _UpdateIdle() => 'Tap to verify latest APK',
    };

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'About',
            collapsed: _headerCollapsed,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              tooltip: 'Back',
              onTap: widget.onBack,
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                MoglogSpacing.md,
                MoglogSpacing.sm,
                MoglogSpacing.md,
                56,
              ),
              children: [
                // Branding Hero
                IosCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(10),
                        decoration: ShapeDecoration(
                          color: c.tertiaryBackground,
                          shape: MoglogShapes.smooth(
                            20,
                            side: BorderSide(
                              color: c.accent.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/app_logo2.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Moglog',
                        style: t.title1.copyWith(color: c.label),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version $_versionName',
                        style: t.subhead.copyWith(color: c.secondaryLabel),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Clean, private drama & TV tracker · Open Source (MIT)',
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(color: c.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section 1: Official Resources
                IosGroupedSection(
                  header: 'Official Resources',
                  children: [
                    IosGroupedRow(
                      title: 'About Developer',
                      subtitle: 'SKECH by T Shivanesh Kumar',
                      icon: MoglogIcons.person,
                      iconBackground: c.accent,
                      showChevron: true,
                      onTap: () => launchUrl(
                        Uri.parse('https://moglog-instructions.vercel.app'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    IosGroupedRow(
                      title: 'Open-Source Repository (MIT)',
                      subtitle: 'Browse source code & contribute on GitHub',
                      icon: MoglogIcons.sparkles,
                      iconBackground: c.statusPlanned,
                      showChevron: true,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://github.com/tshivaneshk/moglog-flutter',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    IosGroupedRow(
                      title: 'GitHub Releases',
                      subtitle: _totalDownloads != null
                          ? 'APK downloads • $_totalDownloads downloads'
                          : 'Changelog & APK downloads',
                      icon: MoglogIcons.externalLink,
                      iconBackground: c.secondaryLabel,
                      showChevron: true,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://github.com/tshivaneshk/Moglog-Releases',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    IosGroupedRow(
                      title: 'Report an Issue / Bug',
                      subtitle: 'Submit bug reports or requests on GitHub',
                      icon: MoglogIcons.externalLink,
                      iconBackground: c.destructive,
                      showChevron: true,
                      showDivider: false,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://github.com/tshivaneshk/moglog-flutter/issues',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 2: Software Updates
                IosGroupedSection(
                  header: 'Software Updates',
                  footer: footerText,
                  children: [
                    IosGroupedRow(
                      title: 'Check for Updates',
                      subtitle: subtitleText,
                      icon: MoglogIcons.refresh,
                      iconBackground: c.statusWatching,
                      showDivider: _updateState is _UpdateAvailable,
                      trailing: switch (_updateState) {
                        _UpdateChecking() => SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.accent,
                            ),
                          ),
                        _UpdateUpToDate() => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                MoglogIcons.check,
                                size: 16,
                                color: c.accentText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Latest',
                                style: t.subhead.copyWith(
                                  color: c.accentText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        _UpdateAvailable() => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: MoglogShapes.pill,
                            ),
                            child: Text(
                              'New',
                              style: t.caption2.copyWith(
                                color: c.onAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        _ => Text(
                            'Check',
                            style: t.subhead.copyWith(
                              color: c.accentText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      },
                      onTap: () => _checkUpdate(forceRefresh: true),
                    ),
                    if (_updateState case final _UpdateAvailable avail)
                      Container(
                        width: double.infinity,
                        color: c.elevatedSurface,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: c.accentSubtle,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    MoglogIcons.download,
                                    size: 14,
                                    color: c.accentText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    avail.latestVersion,
                                    style: t.headline.copyWith(color: c.label),
                                  ),
                                ),
                              ],
                            ),
                            if (avail.releaseTitle.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                avail.releaseTitle,
                                style: t.subhead.copyWith(
                                  color: c.secondaryLabel,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            IosPrimaryButton(
                              text: 'Download Latest APK',
                              leadingIcon: MoglogIcons.download,
                              onTap: () => launchUrl(
                                Uri.parse(avail.downloadUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                            const SizedBox(height: 8),
                            IosSecondaryButton(
                              text: 'View Release Notes',
                              leadingIcon: MoglogIcons.externalLink,
                              onTap: () => launchUrl(
                                Uri.parse(avail.releasePageUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 3: Privacy & Legal
                IosGroupedSection(
                  header: 'Privacy & Legal',
                  footer: 'Uses the TMDB API; not endorsed by TMDB.',
                  children: [
                    IosGroupedRow(
                      title: 'Privacy & Security',
                      subtitle: 'On-device data protection',
                      infoDescription:
                          'Detailed security architecture specs are listed on the Moglog instructions website and inside Privacy & Security.',
                      icon: MoglogIcons.shield,
                      iconBackground: c.accent,
                      showChevron: true,
                      onTap: widget.onNavigateToPrivacy,
                    ),
                    IosGroupedRow(
                      title: 'TMDB Terms of Use',
                      icon: MoglogIcons.externalLink,
                      iconBackground: c.statusPlanned,
                      showChevron: true,
                      showDivider: false,
                      onTap: () => launchUrl(
                        Uri.parse('https://www.themoviedb.org/terms-of-use'),
                        mode: LaunchMode.externalApplication,
                      ),
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
