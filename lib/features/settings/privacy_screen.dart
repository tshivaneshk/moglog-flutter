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
                        'Moglog stores your library, notes, and watch progress on your device inside an encrypted SQLCipher database backed by Android Keystore.',
                        style: t.subhead.copyWith(color: c.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const IosGroupedSection(
                  header: 'On-Device Encryption',
                  children: [
                    _PrivacyBulletRow(
                      title: 'Encrypted Local Database',
                      body:
                          'Your watchlist, personal ratings, and notes are encrypted at rest with SQLCipher (256-bit AES) using a random passphrase sealed in Android Keystore.',
                    ),
                    _PrivacyBulletRow(
                      title: 'Protected API Credentials',
                      body:
                          'Your personal TMDB API key or Read Access Token is encrypted in SecureStore and is never synced to Firestore or third-party servers.',
                    ),
                    _PrivacyBulletRow(
                      title: 'Excluded from Auto-Backup',
                      body:
                          'Android cloud backup and device-to-device extraction rules explicitly exclude encrypted databases and keystore keysets so keys never leave your hardware.',
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const IosGroupedSection(
                  header: 'Optional Cloud Sync & E2E Backup',
                  children: [
                    _PrivacyBulletRow(
                      title: 'Zero-Knowledge Passphrase Option',
                      body:
                          'When End-to-End Encrypted Cloud Backup is enabled, your library is encrypted client-side using PBKDF2-HMAC-SHA256 (600,000 iterations) + AES-256-GCM before upload.',
                    ),
                    _PrivacyBulletRow(
                      title: 'Full Account Control',
                      body:
                          'You can export your library to an encrypted .moglog archive or permanently delete your cloud backup and Firebase Auth account at any time from Settings.',
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const IosGroupedSection(
                  header: 'Third-Party Services',
                  footer:
                      'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                  children: [
                    IosGroupedRow(
                      title: 'The Movie Database (TMDB)',
                      subtitle:
                          'Used directly from your device to fetch show posters, episode counts, and regional streaming availability.',
                    ),
                    IosGroupedRow(
                      title: 'Google Firebase (Optional)',
                      subtitle:
                          'Used only if you sign in with Google for cross-device cloud backup.',
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

class _PrivacyBulletRow extends StatelessWidget {
  final String title;
  final String body;
  final bool showDivider;

  const _PrivacyBulletRow({
    required this.title,
    required this.body,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.body.copyWith(
                  color: c.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(body, style: t.footnote.copyWith(color: c.secondaryLabel)),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: c.hairlineWidth,
            thickness: c.hairlineWidth,
            color: c.separator,
            indent: 16,
          ),
      ],
    );
  }
}
