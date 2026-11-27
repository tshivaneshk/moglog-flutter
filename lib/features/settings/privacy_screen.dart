import 'package:flutter/material.dart';

import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.dart';

class PrivacyScreen extends StatefulWidget {
  final VoidCallback onBack;

  const PrivacyScreen({super.key, required this.onBack});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'Privacy & Security',
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
                64,
              ),
              children: [
                IosCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.accentSubtle,
                          borderRadius: MoglogShapes.control,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          MoglogIcons.shield,
                          size: 22,
                          color: c.accentText,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Built for Local-First Privacy',
                              style: t.headline.copyWith(color: c.label),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your library and watch progress stay encrypted on your device.',
                              style:
                                  t.footnote.copyWith(color: c.secondaryLabel),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const IosGroupedSection(
                  header: 'On-Device Protection',
                  children: [
                    IosGroupedRow(
                      title: 'Private Local Database',
                      subtitle: 'Watchlist & ratings stay encrypted on device',
                      infoDescription:
                          'Encrypted at rest with SQLCipher (256-bit AES) using a random 256-bit passphrase sealed inside hardware-backed Android Keystore.',
                    ),
                    IosGroupedRow(
                      title: 'Protected API Credentials',
                      subtitle: 'TMDB key stays local, never uploaded',
                      infoDescription:
                          'Your TMDB v3 API Key or v4 Read Access Token is encrypted inside hardware-backed SecureStore and is never synced to the cloud.',
                    ),
                    IosGroupedRow(
                      title: 'Excluded from Auto-Backup',
                      subtitle: 'Keys & databases stay off device transfers',
                      infoDescription:
                          'Android cloud auto-backup and device-to-device extraction rules explicitly exclude encrypted databases and keystore keysets.',
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const IosGroupedSection(
                  header: 'Optional Cloud Sync',
                  children: [
                    IosGroupedRow(
                      title: 'Passphrase Cloud Lock',
                      subtitle: 'End-to-end encrypted before upload',
                      infoDescription:
                          'When enabled, your library is encrypted client-side with PBKDF2-HMAC-SHA256 (600,000 iterations) and AES-256-GCM before upload.',
                    ),
                    IosGroupedRow(
                      title: 'Full Account Control',
                      subtitle: 'Export backups or delete cloud data anytime',
                      infoDescription:
                          'You can export a portable .moglog or CSV backup or permanently delete your cloud backups and account anytime from Settings.',
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const IosGroupedSection(
                  header: 'Third-Party Services',
                  footer: 'Uses the TMDB API; not endorsed by TMDB.',
                  children: [
                    IosGroupedRow(
                      title: 'The Movie Database (TMDB)',
                      subtitle: 'Fetches posters, episodes & watch links',
                      infoDescription:
                          'Queried directly from your device using your own personal TMDB API credential to retrieve posters, episode metadata, and regional streaming providers.',
                    ),
                    IosGroupedRow(
                      title: 'Google Firebase (Optional)',
                      subtitle: 'Used only when signed in for sync & circle',
                      infoDescription:
                          'Used exclusively for optional Google Sign-In, cross-device cloud backup storage, and Watch Circle friend connections.',
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
