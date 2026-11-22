import 'package:flutter/material.dart';

import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/theme.dart';

/// Exact 1:1 port of Kotlin `PrivacyScreen.kt`.
class PrivacyScreen extends StatelessWidget {
  final VoidCallback onBack;

  const PrivacyScreen({super.key, required this.onBack});

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
            collapsed: true,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              onTap: onBack,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Built for Local-First Privacy',
                        style: t.title2.copyWith(color: c.label),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your library and watch progress stay encrypted on your device.',
                        style: t.footnote.copyWith(color: c.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
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
