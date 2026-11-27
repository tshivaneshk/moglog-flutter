import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../core/design_system/tokens.dart';
import '../../core/network/image_cache_manager.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;
  bool _signingIn = false;

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

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final picked =
          await _imagePicker.pickImage(source: source, maxWidth: 1600);
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
      disposeAfter: [ctrl],
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        final t = ctx.typo;
        return SingleChildScrollView(
          padding: MoglogSpacing.sheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Display Name',
                style: t.title3.copyWith(color: c.label),
              ),
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: ShapeDecoration(
                  color: c.tertiaryBackground,
                  shape: MoglogShapes.smooth(
                    MoglogShapes.controlRadius,
                    side: BorderSide(
                      color: c.glassBorder,
                      width: c.hairlineWidth,
                    ),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: ctrl,
                  maxLength: 40,
                  autofocus: true,
                  cursorColor: c.accent,
                  style: t.body.copyWith(color: c.label),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'Your display name',
                    hintStyle: t.subhead.copyWith(color: c.tertiaryLabel),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              IosPrimaryButton(
                text: 'Save',
                onTap: () async {
                  final name = ctrl.text.trim();
                  Navigator.of(ctx).pop();
                  await ref
                      .read(settingsStoreProvider)
                      .setCustomDisplayName(name);
                  await ref
                      .read(authControllerProvider.notifier)
                      .syncProfileOnly();
                  ref.read(toastProvider.notifier).show('Display name saved');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPassphraseSheet({bool enableE2eOnSave = false}) {
    final ctrl = TextEditingController(
      text: ref.read(secureStoreProvider).getBackupPassphrase(),
    );
    var obscure = true;
    String? error;

    showIosBottomSheet<void>(
      disposeAfter: [ctrl],
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final c = ctx.colors;
          final t = ctx.typo;
          return SingleChildScrollView(
            padding: MoglogSpacing.sheetPadding,
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
                          'End-to-end cloud backups are locked with your password on your device before upload.',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Protects your encrypted cloud backups (minimum 6 characters).',
                  style: t.caption.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 14),
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  decoration: ShapeDecoration(
                    color: c.tertiaryBackground,
                    shape: MoglogShapes.smooth(
                      MoglogShapes.controlRadius,
                      side: BorderSide(
                        color: error != null ? c.destructive : c.glassBorder,
                        width: error != null ? 1.2 : c.hairlineWidth,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          obscureText: obscure,
                          cursorColor: c.accent,
                          style: t.body.copyWith(color: c.label),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter passphrase (min 6 chars)',
                            hintStyle:
                                t.subhead.copyWith(color: c.tertiaryLabel),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: obscure ? 'Show passphrase' : 'Hide passphrase',
                        icon: Icon(
                          obscure ? MoglogIcons.eye : MoglogIcons.eyeOff,
                          size: 19,
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
                  Text(
                    error!,
                    style: t.footnote.copyWith(color: c.destructive),
                  ),
                ],
                const SizedBox(height: 16),
                IosPrimaryButton(
                  text: 'Save Passphrase',
                  onTap: () async {
                    final pass = ctrl.text.trim();
                    if (pass.length < 6) {
                      setSheetState(
                        () =>
                            error = 'Passphrase must be at least 6 characters.',
                      );
                      return;
                    }
                    await ref
                        .read(secureStoreProvider)
                        .setBackupPassphrase(pass);
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
      final data =
          await ref.read(authControllerProvider.notifier).fetchFromCloud();
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
      message:
          'Choose whether to keep your local encrypted library on this device.',
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
        avatarImg =
            MemoryImage(base64Decode(settings.customProfileImageBase64));
      } catch (_) {}
    } else if ((user?.photoURL ?? '').isNotEmpty) {
      avatarImg = CachedNetworkImageProvider(
        user!.photoURL!,
        cacheManager: MoglogImageCacheManager.instance,
      );
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
                // Hero Identity Card
                IosCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      IosPressable(
                        semanticLabel: 'Change profile photo',
                        onTap: _showProfilePhotoSheet,
                        focusRadius: MoglogShapes.pillRadius,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: c.tertiaryBackground,
                              backgroundImage: avatarImg,
                              child: avatarImg == null
                                  ? Icon(
                                      MoglogIcons.person,
                                      size: 36,
                                      color: c.accentText,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 28,
                                height: 28,
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
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: t.title2.copyWith(color: c.label),
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          user!.email!,
                          textAlign: TextAlign.center,
                          style: t.footnote.copyWith(color: c.secondaryLabel),
                        ),
                      ],
                      const SizedBox(height: 14),
                      IosSecondaryButton(
                        text: 'Edit Profile & Name',
                        size: MoglogButtonSize.small,
                        expand: false,
                        textColor: c.accentText,
                        onTap: _showProfilePhotoSheet,
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
                        onTap: authState.isSyncing
                            ? null
                            : _handleRestoreFromCloud,
                      ),
                      IosSwitchRow(
                        title: 'Encrypted Cloud Backup',
                        subtitle: 'Lock cloud sync with your passphrase',
                        infoDescription:
                            'Encrypts your library on your device with your password before uploading.',
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
                        iconBackground: c.secondaryLabel,
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
