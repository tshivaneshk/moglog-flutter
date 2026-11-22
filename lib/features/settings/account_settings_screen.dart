import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/icons.dart';
import '../../core/design_system/motion_haptics.dart';
import '../../core/design_system/shapes.dart';
import '../../core/design_system/theme.dart';
import 'widgets/profile_photo_dialogs.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AccountSettingsScreen({super.key, required this.onBack});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _signingIn = false;

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source, maxWidth: 1600);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final base64Str = await showProfileImageCropDialog(
        context: context,
        imageBytes: bytes,
      );
      if (base64Str != null && base64Str.isNotEmpty) {
        await ref
            .read(settingsStoreProvider)
            .setCustomProfileImageBase64(base64Str);
        await ref.read(authControllerProvider.notifier).syncProfileOnly();
        ref.read(toastProvider.notifier).show('Profile photo updated');
      }
    } catch (_) {
      ref.read(toastProvider.notifier).show('Unable to select image');
    }
  }

  void _showProfilePhotoSheet() {
    final settings = ref.read(currentSettingsProvider);
    final user = ref.read(authControllerProvider).user;
    final hasPhoto = settings.customProfileImageBase64.isNotEmpty ||
        (user?.photoURL ?? '').isNotEmpty;

    showIosActionSheet(
      context: context,
      title: 'Profile Photo & Name',
      actions: [
        if (hasPhoto)
          ActionSheetItem(
            label: 'View Current Photo',
            icon: MoglogIcons.eye,
            onTap: () => showProfilePhotoViewerDialog(
              context: context,
              photoBase64: settings.customProfileImageBase64,
              photoUrl: user?.photoURL ?? '',
            ),
          ),
        ActionSheetItem(
          label: 'Take Photo with Camera',
          icon: MoglogIcons.camera,
          onTap: () => _pickAndCropImage(ImageSource.camera),
        ),
        ActionSheetItem(
          label: 'Choose from Gallery',
          icon: MoglogIcons.photo,
          onTap: () => _pickAndCropImage(ImageSource.gallery),
        ),
        ActionSheetItem(
          label: 'Edit Display Name',
          icon: MoglogIcons.person,
          onTap: _showEditDisplayNameSheet,
        ),
        if (settings.customProfileImageBase64.isNotEmpty)
          ActionSheetItem(
            label: 'Remove Custom Photo',
            icon: MoglogIcons.trash,
            isDestructive: true,
            onTap: () async {
              await ref
                  .read(settingsStoreProvider)
                  .setCustomProfileImageBase64('');
              await ref.read(authControllerProvider.notifier).syncProfileOnly();
              ref.read(toastProvider.notifier).show('Custom photo removed');
            },
          ),
      ],
    );
  }

  void _showEditDisplayNameSheet() {
    final settings = ref.read(currentSettingsProvider);
    final user = ref.read(authControllerProvider).user;
    final ctrl = TextEditingController(
      text: settings.customDisplayName.isNotEmpty
          ? settings.customDisplayName
          : (user?.displayName ?? ''),
    );

    showIosBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Display Name',
              style: ctx.typo.title3.copyWith(color: ctx.colors.label),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ctx.colors.tertiaryBackground,
                borderRadius: MoglogShapes.control,
              ),
              child: TextField(
                controller: ctrl,
                maxLength: 40,
                autofocus: true,
                style: ctx.typo.body.copyWith(color: ctx.colors.label),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Your display name',
                ),
              ),
            ),
            const SizedBox(height: 14),
            IosPrimaryButton(
              text: 'Save',
              onTap: () async {
                final name = ctrl.text.trim();
                Navigator.of(ctx).pop();
                await ref.read(settingsStoreProvider).setCustomDisplayName(name);
                await ref.read(authControllerProvider.notifier).syncProfileOnly();
                ref.read(toastProvider.notifier).show('Display name saved');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPassphraseSheet({bool enableE2eOnSave = false}) {
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Backup Passphrase',
                        style: t.title3.copyWith(color: c.label),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const IosInfoButton(
                      title: 'Encryption Details',
                      description:
                          'End-to-end cloud backups are encrypted on your device using PBKDF2-HMAC-SHA256 (600,000 iterations) + AES-256-GCM before upload.',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Protects your encrypted cloud backups (min 6 chars).',
                  style: t.caption.copyWith(color: c.secondaryLabel, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                            hintText: 'Enter passphrase (min 6 chars)',
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
                  text: 'Save Passphrase',
                  onTap: () async {
                    final pass = ctrl.text.trim();
                    if (pass.length < 6) {
                      setSheetState(
                        () => error = 'Passphrase must be at least 6 characters.',
                      );
                      return;
                    }
                    await ref.read(secureStoreProvider).setBackupPassphrase(pass);
                    if (enableE2eOnSave) {
                      await ref
                          .read(settingsStoreProvider)
                          .setEncryptedCloudBackupEnabled(true);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    setState(() {});
                    ref.read(toastProvider.notifier).show(
                          'Backup passphrase saved securely',
                        );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleBackUpNow() async {
    final dramas = ref.read(currentDramasProvider);
    final authCtrl = ref.read(authControllerProvider.notifier);

    if (dramas.isEmpty) {
      final hasCloud = await authCtrl.checkCloudHasShows();
      if (hasCloud && mounted) {
        showIosActionSheet(
          context: context,
          title: 'Local Library is Empty',
          message:
              'Your cloud backup contains shows. Backing up an empty local library is blocked to prevent accidental data loss. Restore from Cloud instead?',
          actions: [
            ActionSheetItem(
              label: 'Restore from Cloud',
              icon: MoglogIcons.download,
              onTap: _handleRestoreFromCloud,
            ),
          ],
        );
        return;
      }
    }

    final ok = await authCtrl.syncToCloud();
    if (ok) {
      ref.read(toastProvider.notifier).show('Cloud backup completed');
    }
  }

  Future<void> _handleRestoreFromCloud() async {
    try {
      final data = await ref.read(authControllerProvider.notifier).fetchFromCloud();
      final count = data?.dramas.length ?? 0;
      ref.read(toastProvider.notifier).show('Restored $count shows from Cloud');
    } catch (e) {
      ref
          .read(toastProvider.notifier)
          .show(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _showDeleteAccountFlow() {
    showIosActionSheet(
      context: context,
      title: 'Delete Cloud Account & Data',
      message: 'Choose whether to keep your local encrypted library on this device.',
      actions: [
        ActionSheetItem(
          label: 'Delete Cloud Only (Keep Local Library)',
          isDestructive: true,
          onTap: () => _confirmFinalDelete(deleteLocal: false),
        ),
        ActionSheetItem(
          label: 'Delete Cloud & Wipe Local Library',
          isDestructive: true,
          onTap: () => _confirmFinalDelete(deleteLocal: true),
        ),
      ],
    );
  }

  void _confirmFinalDelete({required bool deleteLocal}) {
    showIosActionSheet(
      context: context,
      title: 'Permanent Deletion',
      message: deleteLocal
          ? 'This will permanently delete your cloud backups, Watch Circle profile, Firebase account, AND all local shows. This cannot be undone.'
          : 'This will permanently delete your cloud backups, Watch Circle profile, and Firebase account. Local shows will remain on this device.',
      actions: [
        ActionSheetItem(
          label: 'Confirm Permanent Delete',
          isDestructive: true,
          onTap: () async {
            final err = await ref
                .read(authControllerProvider.notifier)
                .deleteAccount(deleteLocalData: deleteLocal);
            if (err != null) {
              ref.read(toastProvider.notifier).show(err);
            } else {
              ref
                  .read(toastProvider.notifier)
                  .show('Cloud account permanently deleted');
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final settings = ref.watch(currentSettingsProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final hasPassphrase = ref.read(secureStoreProvider).hasBackupPassphrase();

    final displayName = settings.customDisplayName.trim().isNotEmpty
        ? settings.customDisplayName.trim()
        : (user?.displayName ?? 'Moglog User');

    ImageProvider? avatarImg;
    if (settings.customProfileImageBase64.trim().isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(settings.customProfileImageBase64));
      } catch (_) {}
    } else if ((user?.photoURL ?? '').isNotEmpty) {
      avatarImg = NetworkImage(user!.photoURL!);
    }

    final lastSyncedLabel = settings.lastSyncedAt > 0
        ? 'Last synced ${DateFormat("MMM d, h:mm a", "en_US").format(DateTime.fromMillisecondsSinceEpoch(settings.lastSyncedAt))}'
        : 'Not synced yet';

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          IosLargeTitleHeader(
            title: 'Account & Cloud',
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
                // Hero Identity Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: ShapeDecoration(
                    color: c.secondaryBackground,
                    shape: MoglogShapes.smooth(18),
                  ),
                  child: Column(
                    children: [
                      IosPressable(
                        onTap: _showProfilePhotoSheet,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: c.tertiaryBackground,
                              backgroundImage: avatarImg,
                              child: avatarImg == null
                                  ? Icon(MoglogIcons.person,
                                      size: 36, color: c.accent)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.secondaryBackground,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  MoglogIcons.plus,
                                  size: 14,
                                  color: c.onAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(displayName, style: t.title2.copyWith(color: c.label)),
                      if (user?.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user!.email!,
                          style: t.footnote.copyWith(color: c.secondaryLabel),
                        ),
                      ],
                      const SizedBox(height: 12),
                      IosPressable(
                        onTap: _showProfilePhotoSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: c.tertiaryBackground,
                            borderRadius: MoglogShapes.pill,
                          ),
                          child: Text(
                            'Edit Profile & Name',
                            style: t.caption.copyWith(
                              color: c.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (user == null)
                  IosPrimaryButton(
                    text: 'Sign In with Google',
                    leadingIcon: MoglogIcons.cloud,
                    loading: _signingIn,
                    onTap: () async {
                      setState(() => _signingIn = true);
                      final err = await ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle();
                      if (mounted) {
                        setState(() => _signingIn = false);
                        if (err != null) {
                          ref.read(toastProvider.notifier).show(err);
                        }
                      }
                    },
                  )
                else ...[
                  IosGroupedSection(
                    header: 'Cloud Backup & Sync',
                    footer: lastSyncedLabel,
                    children: [
                      IosGroupedRow(
                        title: 'Back Up Now',
                        subtitle: authState.isSyncing
                            ? 'Syncing with cloud…'
                            : 'Save library & shelves to cloud',
                        icon: MoglogIcons.upload,
                        iconBackground: c.accent,
                        onTap: authState.isSyncing ? null : _handleBackUpNow,
                      ),
                      IosGroupedRow(
                        title: 'Restore from Cloud',
                        subtitle: 'Merge cloud backup to this device',
                        icon: MoglogIcons.download,
                        iconBackground: c.statusPlanned,
                        onTap:
                            authState.isSyncing ? null : _handleRestoreFromCloud,
                      ),
                      IosSwitchRow(
                        title: 'Encrypted Cloud Backup',
                        subtitle: 'Lock cloud sync with your passphrase',
                        infoDescription:
                            'Encrypts your library client-side using PBKDF2-HMAC-SHA256 (600,000 iterations) and AES-256-GCM before uploading.',
                        icon: MoglogIcons.lock,
                        iconBackground: c.statusWatching,
                        value: settings.encryptedCloudBackupEnabled,
                        onChanged: (enabled) async {
                          if (enabled && !hasPassphrase) {
                            _showPassphraseSheet(enableE2eOnSave: true);
                          } else {
                            await ref
                                .read(settingsStoreProvider)
                                .setEncryptedCloudBackupEnabled(enabled);
                          }
                        },
                      ),
                      IosGroupedRow(
                        title: 'Backup Passphrase',
                        subtitle: hasPassphrase ? 'Configured' : 'Not Set',
                        icon: MoglogIcons.key,
                        iconBackground: c.tertiaryBackground,
                        showChevron: true,
                        showDivider: false,
                        onTap: () => _showPassphraseSheet(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  IosGroupedSection(
                    header: 'Account Actions',
                    children: [
                      IosGroupedRow(
                        title: 'Sign Out',
                        subtitle: 'Keeps local library & TMDB key',
                        icon: MoglogIcons.person,
                        iconBackground: c.secondaryLabel,
                        onTap: () {
                          showIosActionSheet(
                            context: context,
                            title: 'Sign Out?',
                            message:
                                'Local shows and your TMDB API key remain stored on this device.',
                            actions: [
                              ActionSheetItem(
                                label: 'Sign Out',
                                isDestructive: true,
                                onTap: () => ref
                                    .read(authControllerProvider.notifier)
                                    .signOut(),
                              ),
                            ],
                          );
                        },
                      ),
                      IosGroupedRow(
                        title: 'Delete Cloud Account & Data',
                        titleColor: c.destructive,
                        icon: MoglogIcons.trash,
                        iconBackground: c.destructive,
                        showDivider: false,
                        onTap: _showDeleteAccountFlow,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
