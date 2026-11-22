import 'package:flutter_test/flutter_test.dart';
import 'package:moglog_flutter/data/local/app_database.dart';
import 'package:moglog_flutter/domain/model/drama.dart';
import 'package:moglog_flutter/domain/model/shortcut.dart';

void main() {
  group('AppDatabase SQLite Schema & Operations', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase();
      await db.open(hexKey: '', inMemory: true);
    });

    tearDown(() {
      db.dispose();
    });

    test('CRUD dramas, detail cache, shortcuts & 30-day Recycle Bin auto-purge', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final oldDeleted = now - const Duration(days: 35).inMilliseconds;
      final recentDeleted = now - const Duration(days: 5).inMilliseconds;

      db.upsertDrama(Drama(
        id: 101,
        title: 'Active Show',
        status: 'Watching',
        episodesWatched: 3,
        totalEpisodes: 10,
        updatedAt: now,
      ));
      db.upsertDrama(Drama(
        id: 102,
        title: 'Expired Bin Show',
        isDeleted: true,
        deletedAt: oldDeleted,
        updatedAt: oldDeleted,
      ));
      db.upsertDrama(Drama(
        id: 103,
        title: 'Recent Bin Show',
        isDeleted: true,
        deletedAt: recentDeleted,
        updatedAt: recentDeleted,
      ));

      expect(db.getAllDramasSync().length, 3);
      expect(db.getDramaById(101)?.title, 'Active Show');

      final purged = db.purgeExpiredRecycleBin(nowMs: now);
      expect(purged, 1);
      expect(db.getDramaById(102), isNull);
      expect(db.getDramaById(103), isNotNull);

      db.putDetailCache(101, '{"episodeRuntime":50}', now);
      expect(db.getDetailCache(101)?.payloadJson, '{"episodeRuntime":50}');
      db.clearDetailCache();
      expect(db.getDetailCache(101), isNull);

      db.saveShortcutForDrama(
        101,
        const Shortcut(title: 'Netflix', data: 'com.netflix.mediaclient', type: 'APP', dramaId: 101),
      );
      expect(db.getShortcutForDrama(101)?.title, 'Netflix');
    });
  });
}
