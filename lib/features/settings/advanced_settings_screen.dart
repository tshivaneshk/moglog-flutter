import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import '../../core/security/backup_crypto_envelope.dart';
import '../../core/security/secure_store.dart';

class AdvancedSettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNavigateToRecycleBin;

  const AdvancedSettingsScreen({
    super.key,
    required this.onBack,
    required this.onNavigateToRecycleBin,
  });

  @override
  ConsumerState<AdvancedSettingsScreen> createState() =>
      _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState
    extends ConsumerState<AdvancedSettingsScreen> {
  String _timeoutLabel(int seconds) => switch (seconds) {
        0 => 'Immediately',
        300 => 'After 5 minutes',
        _ => 'After 1 minute',
      };

  void _showTimeoutSheet(int currentSeconds) {
    showIosActionSheet(
      context: context,
      title: 'Lock Timeout',
      message: 'Choose when Moglog requires re-authentication after leaving.',
      actions: [
        for (final pair in const [
          (0, 'Immediately'),
          (60, 'After 1 minute'),
          (300, 'After 5 minutes'),
        ])
          ActionSheetItem(
            label: pair.$2,
            isSelected: currentSeconds == pair.$1,
            onTap: () =>
                ref.read(settingsStoreProvider).setAppLockTimeoutSeconds(pair.$1),
          ),
      ],
    );
  }

  void _showExportModeSheet() {
    showIosActionSheet(
      context: context,
      title: 'Export Library Backup',
      message: 'Choose an encrypted .moglog archive or a portable CSV spreadsheet.',
      actions: [
        ActionSheetItem(
          label: 'Encrypted Archive (.moglog · AES-256-GCM)',
          icon: MoglogIcons.lock,
          onTap: _promptExportPassphrase,
        ),
        ActionSheetItem(
          label: 'CSV Spreadsheet (.csv)',
          icon: MoglogIcons.download,
          onTap: () => _performExport(passphrase: null),
        ),
      ],
    );
  }

  void _promptExportPassphrase() {
    final ctrl = TextEditingController(
      text: ref.read(secureStoreProvider).getBackupPassphrase(),
    );
    var obscure = true;
    String? error;

    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encrypt .moglog Export',
                  style: t.title3.copyWith(color: c.label),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your backup will be encrypted with PBKDF2-HMAC-SHA256 (600,000 iterations) + AES-256-GCM, 100% compatible with Kotlin Moglog.',
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: c.tertiaryBackground,
                    borderRadius: MoglogShapes.control,
                    border: Border.all(
                      color: error != null ? c.destructive : c.separator,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          obscureText: obscure,
                          style: t.body.copyWith(color: c.label),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Passphrase (min 6 chars)',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          obscure ? MoglogIcons.eye : MoglogIcons.eyeOff,
                          size: 18,
                          color: c.secondaryLabel,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscure = !obscure),
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: t.footnote.copyWith(color: c.destructive)),
                ],
                const SizedBox(height: 16),
                IosPrimaryButton(
                  text: 'Export Encrypted .moglog',
                  onTap: () {
                    final pass = ctrl.text.trim();
                    if (pass.length < 6) {
                      setSheetState(
                        () => error = 'Passphrase must be at least 6 characters.',
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    _performExport(passphrase: pass);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _performExport({String? passphrase}) async {
    try {
      final isEnc = passphrase != null && passphrase.isNotEmpty;
      final bytes = await ref
          .read(dramaControllerProvider)
          .buildExportBytes(passphrase: passphrase);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = isEnc ? 'moglog_backup_$ts.moglog' : 'moglog_library_$ts.csv';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Moglog Backup',
        fileName: fileName,
        bytes: bytes,
      );
      if (savedPath != null && savedPath.isNotEmpty) {
        try {
          final f = File(savedPath);
          if (!await f.exists() || await f.length() == 0) {
            await f.writeAsBytes(bytes);
          }
        } catch (_) {}
        final count =
            ref.read(currentDramasProvider).where((d) => !d.isDeleted).length;
        ref.read(toastProvider.notifier).show(
              'Exported $count shows (${isEnc ? "encrypted .moglog" : "CSV spreadsheet"}).',
            );
      }
    } catch (e) {
      ref.read(toastProvider.notifier).show('Export failed: $e');
    }
  }

  void _showImportModeSheet() {
    showIosActionSheet(
      context: context,
      title: 'Import Library Backup',
      message: 'Supports Moglog encrypted (.moglog) and CSV exports (Moglog, TV Time, Trakt).',
      actions: [
        ActionSheetItem(
          label: 'Select .moglog or .csv File',
          icon: MoglogIcons.upload,
          onTap: _pickAndImportFile,
        ),
      ],
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || !mounted) return;

      // Check if it is an encrypted MOGLOG_ENC_V1 envelope
      final preview = String.fromCharCodes(bytes.take(2048));
      final isEncrypted = preview.contains(BackupEnvelopePayload.formatMagic);
      if (isEncrypted) {
        _promptImportPassphrase(bytes);
      } else {
        await _executeImport(bytes);
      }
    } catch (e) {
      ref.read(toastProvider.notifier).show('Unable to read file: $e');
    }
  }

  void _promptImportPassphrase(Uint8List bytes) {
    final ctrl = TextEditingController(
      text: ref.read(secureStoreProvider).getBackupPassphrase(),
    );
    var obscure = true;

    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock Encrypted Backup',
                  style: t.title3.copyWith(color: c.label),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the passphrase used when exporting this .moglog file.',
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: c.tertiaryBackground,
                    borderRadius: MoglogShapes.control,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          obscureText: obscure,
                          autofocus: true,
                          style: t.body.copyWith(color: c.label),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Backup passphrase',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          obscure ? MoglogIcons.eye : MoglogIcons.eyeOff,
                          size: 18,
                          color: c.secondaryLabel,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscure = !obscure),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                IosPrimaryButton(
                  text: 'Decrypt & Import',
                  onTap: () {
                    final pass = ctrl.text.trim();
                    Navigator.of(ctx).pop();
                    _executeImport(bytes, passphrase: pass);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _executeImport(Uint8List bytes, {String? passphrase}) async {
    final summary = await ref
        .read(dramaControllerProvider)
        .importBackupBytes(bytes, passphrase: passphrase);
    if (summary.errorMessage != null) {
      ref.read(toastProvider.notifier).show(summary.errorMessage!);
    } else {
      ref.read(toastProvider.notifier).show(
            'Imported: ${summary.added} added, ${summary.updated} updated, ${summary.skipped} skipped.',
          );
    }
  }

  void _showTmdbCredentialSheet() {
    final ctrl = TextEditingController(
      text: ref.read(secureStoreProvider).getUserTmdbCredentialOrEmpty(),
    );
    var obscure = true;
    String? error;

    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TMDB API Key / Read Token',
                  style: t.title3.copyWith(color: c.label),
                ),
                const SizedBox(height: 6),
                Text(
                  'Stored locally in hardware-backed SecureStore. Never synced to Firestore.',
                  style: t.footnote.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: c.tertiaryBackground,
                    borderRadius: MoglogShapes.control,
                    border: Border.all(
                      color: error != null ? c.destructive : c.separator,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          obscureText: obscure,
                          style: t.subhead.copyWith(color: c.label),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '32-char v3 key or v4 JWT token',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          obscure ? MoglogIcons.eye : MoglogIcons.eyeOff,
                          size: 18,
                          color: c.secondaryLabel,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscure = !obscure),
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: t.footnote.copyWith(color: c.destructive)),
                ],
                const SizedBox(height: 16),
                IosPrimaryButton(
                  text: 'Save Credential',
                  onTap: () async {
                    final raw = ctrl.text.trim();
                    if (raw.isNotEmpty &&
                        !SecureStore.isValidTmdbCredentialFormat(raw)) {
                      setSheetState(
                        () => error =
                            'Invalid format. Expected 32 hex chars (v3) or JWT token (v4).',
                      );
                      return;
                    }
                    await ref.read(dramaControllerProvider).saveTmdbApiKey(raw);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    ref.read(toastProvider.notifier).show(
                          raw.isEmpty
                              ? 'TMDB API credential removed'
                              : 'TMDB API credential saved',
                        );
                  },
                ),
                if (ctrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  IosSecondaryButton(
                    text: 'Remove Credential',
                    textColor: c.destructive,
                    onTap: () async {
                      await ref.read(dramaControllerProvider).saveTmdbApiKey('');
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      ref
                          .read(toastProvider.notifier)
                          .show('TMDB API credential removed');
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final settings = ref.watch(currentSettingsProvider);
    final hasKey = ref.watch(hasApiKeyProvider);
    final deletedCount =
        ref.watch(currentDramasProvider).where((d) => d.isDeleted).length;
    final store = ref.read(settingsStoreProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'Advanced & Storage',
            collapsed: true,
            leadingActions: IosCircleIconButton(
              icon: MoglogIcons.chevronLeft,
              onTap: widget.onBack,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              children: [
                // App Security
                IosGroupedSection(
                  header: 'App Security',
                  children: [
                    IosSwitchRow(
                      title: 'Biometric / Device PIN Lock',
                      subtitle: 'Require fingerprint, face, or PIN to open Moglog',
                      icon: MoglogIcons.lock,
                      iconBackground: c.accent,
                      value: settings.appLockEnabled,
                      onChanged: (v) async {
                        await store.setAppLockEnabled(v);
                        await syncFlagSecure(store.state);
                      },
                    ),
                    IosGroupedRow(
                      title: 'Lock Timeout',
                      subtitle: _timeoutLabel(settings.appLockTimeoutSeconds),
                      icon: MoglogIcons.clock,
                      iconBackground: c.statusWatching,
                      showChevron: true,
                      onTap: () =>
                          _showTimeoutSheet(settings.appLockTimeoutSeconds),
                    ),
                    IosSwitchRow(
                      title: 'Hide in App Switcher',
                      subtitle: 'Blocks screenshots & recent-apps previews (FLAG_SECURE)',
                      icon: MoglogIcons.shield,
                      iconBackground: c.statusPlanned,
                      value: settings.hideInRecents,
                      showDivider: false,
                      onChanged: (v) async {
                        await store.setHideInRecents(v);
                        await syncFlagSecure(store.state);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Data & Storage
                IosGroupedSection(
                  header: 'Data & Storage',
                  children: [
                    IosGroupedRow(
                      title: 'Export Library Backup',
                      subtitle: 'Encrypted .moglog archive or CSV spreadsheet',
                      icon: MoglogIcons.download,
                      iconBackground: c.accent,
                      showChevron: true,
                      onTap: _showExportModeSheet,
                    ),
                    IosGroupedRow(
                      title: 'Import Library Backup',
                      subtitle: 'Supports .moglog, Moglog CSV, TV Time & Trakt',
                      icon: MoglogIcons.upload,
                      iconBackground: c.statusPlanned,
                      showChevron: true,
                      onTap: _showImportModeSheet,
                    ),
                    IosGroupedRow(
                      title: 'Recycle Bin',
                      subtitle: deletedCount > 0
                          ? '$deletedCount show${deletedCount == 1 ? "" : "s"} · Auto-purged after 30 days'
                          : 'Empty · Deleted shows kept for 30 days',
                      icon: MoglogIcons.trash,
                      iconBackground: c.destructive,
                      showChevron: true,
                      onTap: widget.onNavigateToRecycleBin,
                    ),
                    IosGroupedRow(
                      title: 'Clear Metadata Cache',
                      subtitle: 'Clears 7-day TMDB detail cache & Discover rails',
                      icon: MoglogIcons.refresh,
                      iconBackground: c.statusWatching,
                      showDivider: false,
                      onTap: () {
                        ref.read(dramaControllerProvider).clearMetadataCache();
                        ref
                            .read(toastProvider.notifier)
                            .show('TMDB metadata cache cleared');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // TMDB API Integration
                IosGroupedSection(
                  header: 'TMDB API Integration',
                  children: [
                    IosGroupedRow(
                      title: 'TMDB API Key / Read Token',
                      subtitle: hasKey ? 'Configured' : 'Not Set',
                      icon: MoglogIcons.key,
                      iconBackground: c.accent,
                      showChevron: true,
                      trailing: Text(
                        hasKey ? 'Configured' : 'Not Set',
                        style: t.footnote.copyWith(
                          color: hasKey ? c.accent : c.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: _showTmdbCredentialSheet,
                    ),
                    IosGroupedRow(
                      title: 'How to Obtain Your API Key',
                      subtitle: 'Step-by-step free TMDB guide',
                      icon: MoglogIcons.externalLink,
                      iconBackground: c.statusPlanned,
                      showChevron: true,
                      showDivider: false,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://moglog-instructions.vercel.app/obtain-api-key',
                        ),
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
