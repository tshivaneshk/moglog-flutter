import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class DeepLinkEvent {
  final int? openDramaId;
  final String? navigateTo;
  const DeepLinkEvent({this.openDramaId, this.navigateTo});
}

/// Platform channel bridge to Android native features (`FLAG_SECURE`, installed app detection,
/// `nflx://` deep links, MediaStore gallery save, PCM audio chime, custom vibration waveforms).
class PlatformBridge {
  static const MethodChannel _channel =
      MethodChannel('com.skech.moglog/platform');

  static final StreamController<DeepLinkEvent> _deepLinkController =
      StreamController<DeepLinkEvent>.broadcast();

  static Stream<DeepLinkEvent> get deepLinks => _deepLinkController.stream;

  static bool _initialized = false;

  static const Set<String> _allowedDeepLinkTargets = {'watch_circle'};

  static String? _sanitizeNavigateTarget(Object? raw) {
    if (raw is! String) return null;
    final clean = raw.trim();
    return _allowedDeepLinkTargets.contains(clean) ? clean : null;
  }

  static void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink' && call.arguments is Map) {
        final map = Map<String, dynamic>.from(call.arguments as Map);
        final rawId = (map['open_drama_id'] as num?)?.toInt();
        final dramaId = (rawId != null && rawId > 0) ? rawId : null;
        final target = _sanitizeNavigateTarget(map['navigate_to']);
        if (dramaId != null || target != null) {
          _deepLinkController.add(
            DeepLinkEvent(openDramaId: dramaId, navigateTo: target),
          );
        }
      }
    });
  }

  static Future<DeepLinkEvent?> consumePendingDeepLink() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('consumePendingDeepLink');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        final rawId = (map['open_drama_id'] as num?)?.toInt();
        final dramaId = (rawId != null && rawId > 0) ? rawId : null;
        final target = _sanitizeNavigateTarget(map['navigate_to']);
        if (dramaId != null || target != null) {
          return DeepLinkEvent(
            openDramaId: dramaId,
            navigateTo: target,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> setFlagSecure(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setFlagSecure', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<bool> isPackageInstalled(String packageName) async {
    if (!Platform.isAndroid || packageName.isEmpty) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'isPackageInstalled',
        {'packageName': packageName},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchPackageDeepLink(String packageName, String uri) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'launchPackageDeepLink',
        {'packageName': packageName, 'uri': uri},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveImageToGallery(Uint8List bytes, String fileName) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'saveImageToGallery',
        {'bytes': bytes, 'fileName': fileName},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> playCompletionChime() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('playCompletionChime');
    } catch (_) {}
  }

  static Future<void> playVictoryHaptic() async {
    if (!Platform.isAndroid) {
      await HapticFeedback.heavyImpact();
      return;
    }
    try {
      await _channel.invokeMethod('playVictoryHaptic');
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<Map<String, dynamic>?> migrateLegacyKotlinData() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('migrateLegacyKotlinData');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> markLegacyKotlinMigrationComplete() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('markLegacyKotlinMigrationComplete');
    } catch (_) {}
  }

  static Future<void> syncEpisodeReminderWorker({
    required bool enabled,
    required String watchingJson,
    bool runImmediate = false,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('syncEpisodeReminderWorker', {
        'enabled': enabled,
        'watchingJson': watchingJson,
        'runImmediate': runImmediate,
      });
    } catch (_) {}
  }

  static Future<Map<String, String>?> migrateV9EncryptedPrefs() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('migrateV9EncryptedPrefs');
      if (res is Map) {
        final out = <String, String>{};
        for (final entry in res.entries) {
          if (entry.key is String && entry.value is String) {
            out[entry.key as String] = entry.value as String;
          }
        }
        return out;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> purgeV9EncryptedPrefs() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('purgeV9EncryptedPrefs');
    } catch (_) {}
  }

  static Future<void> copySensitiveClipboard(
    String text, {
    String label = 'Moglog',
  }) async {
    if (text.isEmpty) return;
    if (Platform.isAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>(
          'copySensitiveClipboard',
          {'text': text, 'label': label},
        );
        if (ok == true) return;
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> playPulseHaptic({
    int durationMs = 14,
    int amplitude = 90,
  }) async {
    if (!Platform.isAndroid) {
      await HapticFeedback.selectionClick();
      return;
    }
    try {
      await _channel.invokeMethod('playPulseHaptic', {
        'durationMs': durationMs,
        'amplitude': amplitude,
      });
    } catch (_) {
      await HapticFeedback.selectionClick();
    }
  }
}
