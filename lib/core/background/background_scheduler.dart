import 'dart:async';

import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/local/settings_store.dart';
import '../../data/repository/drama_repository_impl.dart';
import '../notifications/notification_service.dart';

/// Handles periodic background maintenance mirroring Kotlin WorkManager workers:
/// 1. RecycleBinPurgeWorker: purges soft-deleted shows > 30 days old daily & on startup.
/// 2. EpisodeReminderWorker: checks active `Watching` shows against today's ISO air date
///    every 12 hours and immediately when enabled, posting rich notifications.
class BackgroundScheduler {
  final AppDatabase db;
  final DramaRepositoryImpl dramaRepository;
  final SettingsStore settingsStore;
  final NotificationService notificationService;

  Timer? _episodeTimer;
  Timer? _purgeTimer;

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

    // Episode reminders if enabled
    if (settingsStore.state.episodeRemindersEnabled) {
      enableEpisodeReminders(runImmediateCheck: false);
    }
  }

  void enableEpisodeReminders({bool runImmediateCheck = true}) {
    _episodeTimer?.cancel();
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
    return notified;
  }

  void dispose() {
    _episodeTimer?.cancel();
    _purgeTimer?.cancel();
  }
}
