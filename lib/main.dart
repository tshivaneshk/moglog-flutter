import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/notifications/notification_service.dart';
import 'core/platform/platform_bridge.dart';
import 'core/security/secure_store.dart';
import 'data/local/app_database.dart';
import 'data/local/settings_store.dart';
import 'domain/model/drama.dart';
import 'domain/model/shortcut.dart';

Future<void> _migrateLegacyKotlinIfNeeded(
  SecureStore secureStore,
  SettingsStore settingsStore,
  AppDatabase appDb,
) async {
  try {
    final payload = await PlatformBridge.migrateLegacyKotlinData();
    if (payload == null) return;

    final tmdb = (payload['tmdbCredential'] as String? ?? '').trim();
    if (tmdb.isNotEmpty && secureStore.getUserTmdbCredentialOrEmpty().isEmpty) {
      await secureStore.setTmdbCredential(tmdb);
    }

    final backupPass = (payload['backupPassphrase'] as String? ?? '').trim();
    if (backupPass.isNotEmpty && !secureStore.hasBackupPassphrase()) {
      await secureStore.setBackupPassphrase(backupPass);
    }

    final rawSettings = payload['settings'];
    if (rawSettings is Map) {
      await settingsStore.importLegacySettings(
        Map<String, dynamic>.from(rawSettings),
      );
    } else {
      await settingsStore.setFirstLaunchCompleted();
    }

    final rawDramas = payload['dramas'];
    if (rawDramas is List) {
      for (final item in rawDramas) {
        if (item is Map) {
          final drama = Drama.fromJson(Map<String, dynamic>.from(item));
          if (drama.id > 0 && drama.title.trim().isNotEmpty) {
            appDb.upsertDrama(drama);
          }
        }
      }
    }

    final rawShortcuts = payload['shortcuts'];
    if (rawShortcuts is List) {
      for (final item in rawShortcuts) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final dramaId = (m['dramaId'] as num?)?.toInt() ?? 0;
          final title = (m['title'] as String? ?? '').trim();
          final data = (m['data'] as String? ?? '').trim();
          if (dramaId > 0 && title.isNotEmpty && data.isNotEmpty) {
            appDb.saveShortcutForDrama(
              dramaId,
              Shortcut(
                id: (m['id'] as num?)?.toInt() ?? 0,
                title: title,
                data: data,
                type: (m['type'] as String? ?? 'URL'),
                iconUrl: m['iconUrl'] as String?,
                dramaId: dramaId,
              ),
            );
          }
        }
      }
    }

    final rawCache = payload['detailCache'];
    if (rawCache is List) {
      for (final item in rawCache) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final dramaId = (m['dramaId'] as num?)?.toInt() ?? 0;
          final jsonStr = (m['payloadJson'] as String? ?? '');
          final cachedAt = (m['cachedAt'] as num?)?.toInt() ?? 0;
          if (dramaId > 0 && jsonStr.isNotEmpty) {
            appDb.putDetailCache(dramaId, jsonStr, cachedAt);
          }
        }
      }
    }

    await PlatformBridge.markLegacyKotlinMigrationComplete();
  } catch (_) {
    // Non-fatal: app proceeds cleanly and can also recover via Cloud Sync
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    );
  } catch (_) {
    // Local-first offline mode continues seamlessly without Firebase config
  }

  final secureStore = SecureStore();
  await secureStore.init();

  final settingsStore = SettingsStore();
  await settingsStore.init();

  final dbKeyHex = await secureStore.getOrCreateDatabaseKeyHex();
  final appDb = AppDatabase();
  await appDb.open(hexKey: dbKeyHex);

  // Seamless one-time migration for existing Kotlin v3.0.x users updating in-place to v3.1.0+
  await _migrateLegacyKotlinIfNeeded(secureStore, settingsStore, appDb);

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(secureStore),
        settingsStoreProvider.overrideWithValue(settingsStore),
        appDatabaseProvider.overrideWithValue(appDb),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const MoglogApp(),
    ),
  );
}
