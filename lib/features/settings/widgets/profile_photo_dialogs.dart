import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/design_system/components.dart';
import '../../../core/design_system/icons.dart';
import '../../../core/design_system/theme.dart';
import '../../../core/network/image_cache_manager.dart';

/// Full-screen WhatsApp-style circular pan/pinch-to-zoom cropper (1x..4.5x)
/// exporting 512x512 JPEG (quality 85) as Base64 matching Kotlin `ProfilePhotoDialogs.kt`.
Future<String?> showProfileImageCropDialog({
  required BuildContext context,
  required Uint8List imageBytes,
}) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ProfileImageCropPage(imageBytes: imageBytes),
    ),
  );
}

class _ProfileImageCropPage extends StatefulWidget {
  final Uint8List imageBytes;
  const _ProfileImageCropPage({required this.imageBytes});

  @override
  State<_ProfileImageCropPage> createState() => _ProfileImageCropPageState();
}

class _ProfileImageCropPageState extends State<_ProfileImageCropPage> {
  final TransformationController _transformCtrl = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCroppedBase64() async {
    setState(() => _saving = true);
    try {
      final decoded = img.decodeImage(widget.imageBytes);
      if (decoded == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }

      final matrix = _transformCtrl.value;
      final scale = matrix.getMaxScaleOnAxis().clamp(1.0, 4.5);
      final tx = matrix.getTranslation().x;
      final ty = matrix.getTranslation().y;

      final minDim = min(decoded.width, decoded.height);
      final cropSize = (minDim / scale).round().clamp(64, minDim);

      final centerX = (decoded.width / 2) - (tx / scale);
      final centerY = (decoded.height / 2) - (ty / scale);
      final left = (centerX - cropSize / 2).round().clamp(0, decoded.width - cropSize);
      final top = (centerY - cropSize / 2).round().clamp(0, decoded.height - cropSize);

      final cropped = img.copyCrop(
        decoded,
        x: left,
        y: top,
        width: cropSize,
        height: cropSize,
      );
      final resized = img.copyResize(cropped, width: 512, height: 512);
      final jpgBytes = img.encodeJpg(resized, quality: 85);
      final b64 = base64Encode(jpgBytes);

      if (mounted) Navigator.of(context).pop(b64);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typo;
    final screenW = MediaQuery.sizeOf(context).width;
    final cropDiameter = min(screenW - 48, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IosCircleIconButton(
                    icon: MoglogIcons.close,
                    backgroundColor: const Color(0xFF1C1C1E),
                    tint: Colors.white,
                    onTap: () => Navigator.of(context).pop(null),
                  ),
                  Text(
                    'Move and Scale',
                    style: t.headline.copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: cropDiameter,
                  height: cropDiameter,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipOval(
                        child: InteractiveViewer(
                          transformationController: _transformCtrl,
                          minScale: 1.0,
                          maxScale: 4.5,
                          boundaryMargin: const EdgeInsets.all(200),
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.accent.withValues(alpha: 0.85),
                              width: 2.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: IosPrimaryButton(
                text: 'Use Photo',
                loading: _saving,
                onTap: _exportCroppedBase64,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen dark profile photo viewer matching Kotlin `ProfilePhotoViewerDialog`.
Future<void> showProfilePhotoViewerDialog({
  required BuildContext context,
  required String photoBase64,
  required String photoUrl,
}) {
  ImageProvider? imgProvider;
  if (photoBase64.trim().isNotEmpty) {
    try {
      imgProvider = MemoryImage(base64Decode(photoBase64));
    } catch (_) {}
  } else if (photoUrl.trim().isNotEmpty) {
    imgProvider = CachedNetworkImageProvider(
      photoUrl,
      cacheManager: MoglogImageCacheManager.instance,
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: imgProvider != null
                    ? InteractiveViewer(
                        maxScale: 4.0,
                        child: Image(image: imgProvider, fit: BoxFit.contain),
                      )
                    : const Icon(
                        MoglogIcons.person,
                        size: 96,
                        color: Colors.white54,
                      ),
              ),
              Positioned(
                top: 12,
                right: 16,
                child: IosCircleIconButton(
                  icon: MoglogIcons.close,
                  backgroundColor: const Color(0xFF1C1C1E),
                  tint: Colors.white,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
