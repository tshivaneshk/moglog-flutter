import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/model/drama.dart';

class NotificationTapEvent {
  final int? dramaId;
  final String? navigateTo;
  const NotificationTapEvent({this.dramaId, this.navigateTo});
}

/// Manages local notifications with 1:1 channel parity:
/// 1. `moglog_episode_reminders` ("Episode Air-Date Reminders", emerald #30D158)
/// 2. `watch_circle_notifications` ("Watch Circle Social", emerald #2ECC71)
class NotificationService {
  static const String channelEpisodeReminders = 'moglog_episode_reminders';
  static const String channelWatchCircle = 'watch_circle_notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationTapEvent> _tapController =
      StreamController<NotificationTapEvent>.broadcast();

  Stream<NotificationTapEvent> get taps => _tapController.stream;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('ic_stat_moglog');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          _handlePayload(response.payload);
        },
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelEpisodeReminders,
            'Episode Air-Date Reminders',
            description: 'Notifies you when new episodes of your Watching shows air today',
            importance: Importance.high,
            enableLights: true,
            ledColor: Color(0xFF30D158),
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelWatchCircle,
            'Watch Circle Social',
            description:
                'Alerts when a friend connects with your code or joins your circle',
            importance: Importance.high,
            enableLights: true,
            ledColor: Color(0xFF2ECC71),
          ),
        );
      }

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        _handlePayload(launchDetails.notificationResponse!.payload);
      }
    } catch (_) {
      // Safe fallback in unit/widget test environments
    }
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final dramaId = (map['open_drama_id'] as num?)?.toInt();
      final target = map['navigate_to'] as String?;
      _tapController.add(NotificationTapEvent(dramaId: dramaId, navigateTo: target));
    } catch (_) {}
  }

  Future<void> showEpisodeReminderNotification({
    required Drama drama,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    await init();
    final epCode =
        'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
    final title = 'New Episode Airing Today: ${drama.title}';
    final body = '$epCode is out today! Tap to log your progress.';

    StyleInformation styleInfo = BigTextStyleInformation(
      drama.overview.isNotEmpty ? '$body\n${drama.overview}' : body,
    );

    if (drama.posterPath.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/notif_poster_${drama.id}.jpg';
        final response = await Dio().get<List<int>>(
          drama.posterPath,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null) {
          final file = File(filePath);
          await file.writeAsBytes(response.data!);
          styleInfo = BigPictureStyleInformation(
            FilePathAndroidBitmap(filePath),
            contentTitle: title,
            summaryText: body,
          );
        }
      } catch (_) {}
    }

    final androidDetails = AndroidNotificationDetails(
      channelEpisodeReminders,
      'Episode Air-Date Reminders',
      channelDescription: 'Notifies you when new episodes of your Watching shows air today',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_moglog',
      color: const Color(0xFF30D158),
      styleInformation: styleInfo,
      actions: const [
        AndroidNotificationAction(
          'log_episode',
          'Log Episode',
          showsUserInterface: true,
        ),
      ],
    );

    try {
      await _plugin.show(
        drama.id,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: jsonEncode({'open_drama_id': drama.id}),
      );
    } catch (_) {}
  }

  Future<void> showFriendAddedNotification({
    required String friendName,
    required String friendUid,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      channelWatchCircle,
      'Watch Circle Social',
      channelDescription:
          'Alerts when a friend connects with your code or joins your circle',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_moglog',
      color: const Color(0xFF2ECC71),
      styleInformation: BigTextStyleInformation(
        '$friendName connected with your Watch Circle code. Tap to check their watching progress and compare your Taste Blend.',
      ),
    );
    try {
      await _plugin.show(
        friendUid.hashCode & 0x7FFFFFFF,
        'New Watch Circle Friend',
        '$friendName added you to their Watch Circle.',
        NotificationDetails(android: androidDetails),
        payload: jsonEncode({'navigate_to': 'watch_circle'}),
      );
    } catch (_) {}
  }
}
