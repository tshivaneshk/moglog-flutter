import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/notifications/notification_service.dart';
import 'core/security/secure_store.dart';
import 'data/local/app_database.dart';
import 'data/local/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Firebase gracefully (activates automatically once google-services.json
  // / firebase_options.dart is configured for com.skech.moglog.flutter)
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
