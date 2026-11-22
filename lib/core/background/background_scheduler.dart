import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/local/settings_store.dart';
import '../../data/repository/drama_repository_impl.dart';
import '../notifications/notification_service.dart';
import '../platform/platform_bridge.dart';

/// Handles periodic background maintenance mirroring Kotlin WorkManager workers:
/// 1. RecycleBinPurgeWorker: purges soft-deleted shows > 30 days old daily & on startup.
/// 2. EpisodeReminderWorker: schedules native Android WorkManager 12-hour periodic checks
///    (works even when app is swiped away) plus immediate foreground checks.
class BackgroundScheduler {
  final AppDatabase db;
  final DramaRepositoryImpl dramaRepository;
  final SettingsStore settingsStore;
  final NotificationService notificationService;

  Timer? _episodeTimer;
  Timer? _purgeTimer;
  StreamSubscription<dynamic>? _dramasSub;

  BackgroundScheduler({
    required this.db,
    required this.dramaRepository,
    required this.settingsStore,
    required this.notificationService,
  });

  void start() {
    // Immediate Recycle Bin 30-day purge on startup + every 24h
    db.purgeExpiredRecycleBin();
    _purgeTimer?.cancel();
    _purgeTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => db.purgeExpiredRecycleBin(),
    );

    _dramasSub?.cancel();
    _dramasSub = dramaRepository.watchAllDramas().listen((_) {
      if (settingsStore.state.episodeRemindersEnabled) {
        unawaited(_syncNativeWorker(enabled: true, runImmediate: false));
      }
    });

    // Episode reminders if enabled
    if (settingsStore.state.episodeRemindersEnabled) {
      enableEpisodeReminders(runImmediateCheck: false);
    } else {
      unawaited(_syncNativeWorker(enabled: false, runImmediate: false));
    }
  }

  void enableEpisodeReminders({bool runImmediateCheck = true}) {
    _episodeTimer?.cancel();
    unawaited(_syncNativeWorker(enabled: true, runImmediate: runImmediateCheck));
    if (runImmediateCheck) {
      unawaited(checkEpisodeRemindersNow());
    }
    _episodeTimer = Timer.periodic(
      const Duration(hours: 12),
      (_) => unawaited(checkEpisodeRemindersNow()),
    );
  }

  void disableEpisodeReminders() {
    _episodeTimer?.cancel();
    _episodeTimer = null;
    unawaited(_syncNativeWorker(enabled: false, runImmediate: false));
  }

  Future<void> _syncNativeWorker({
    required bool enabled,
    required bool runImmediate,
  }) async {
    final watching = dramaRepository
        .getAllDramasSync()
        .where((d) => !d.isDeleted && d.status == 'Watching')
        .map(
          (d) => {
            'id': d.id,
            'title': d.title,
            'overview': d.overview,
            'posterPath': d.posterPath,
            'season': d.nextSeasonNumber > 0 ? d.nextSeasonNumber : d.currentSeason,
            'episode': d.nextEpisodeNumber > 0
                ? d.nextEpisodeNumber
                : d.episodesWatched + 1,
            'nextEpisodeAirDate': d.nextEpisodeAirDate ?? '',
          },
        )
        .toList();
    await PlatformBridge.syncEpisodeReminderWorker(
      enabled: enabled,
      watchingJson: jsonEncode(watching),
      runImmediate: runImmediate,
    );
  }

  Future<int> checkEpisodeRemindersNow() async {
    if (!settingsStore.state.episodeRemindersEnabled) return 0;
    final todayIso = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
    final watching = dramaRepository
        .getAllDramasSync()
        .where((d) => !d.isDeleted && d.status == 'Watching')
        .toList();

    var notified = 0;
    for (final drama in watching) {
      try {
        final extra = await dramaRepository.getDramaExtraDetails(drama.id);
        final airDate = extra?.nextEpisodeAirDate ?? drama.nextEpisodeAirDate;
        if (airDate != null && airDate.startsWith(todayIso)) {
          await notificationService.showEpisodeReminderNotification(
            drama: drama,
            seasonNumber:
                (extra?.nextSeasonNumber ?? 0) > 0 ? extra!.nextSeasonNumber : drama.currentSeason,
            episodeNumber: (extra?.nextEpisodeNumber ?? 0) > 0
                ? extra!.nextEpisodeNumber
                : drama.episodesWatched + 1,
          );
          notified++;
        }
      } catch (_) {}
    }
    unawaited(_syncNativeWorker(enabled: true, runImmediate: false));
    return notified;
  }

  void dispose() {
    _episodeTimer?.cancel();
    _purgeTimer?.cancel();
    _dramasSub?.cancel();
  }
}
