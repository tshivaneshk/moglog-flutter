import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart';

import '../../domain/model/drama.dart';
import '../../domain/model/shortcut.dart';

class CachedDetailEntry {
  final int dramaId;
  final String payloadJson;
  final int cachedAt;
  const CachedDetailEntry({
    required this.dramaId,
    required this.payloadJson,
    required this.cachedAt,
  });
}

/// Encrypted SQLite database using SQLCipher 256-bit AES with 1:1 Room v7 schema parity:
/// - `dramas`
/// - `shortcuts`
/// - `drama_details_cache`
class AppDatabase {
  Database? _db;
  final StreamController<List<Drama>> _dramasController =
      StreamController<List<Drama>>.broadcast();
  List<Drama> _latestDramas = const [];

  bool get isOpen => _db != null;
  List<Drama> get currentDramas => _latestDramas;

  Stream<List<Drama>> watchAllDramas() async* {
    yield _latestDramas;
    yield* _dramasController.stream;
  }

  /// Opens the encrypted SQLCipher database on Android/iOS (or unencrypted in-memory in tests).
  Future<void> open({required String hexKey, bool inMemory = false}) async {
    if (_db != null) return;
    if (inMemory) {
      _db = sqlite3.openInMemory();
    } else {
      if (Platform.isAndroid) {
        sqlite_open.open.overrideFor(
          sqlite_open.OperatingSystem.android,
          openCipherOnAndroid,
        );
      }
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, 'drama_db_encrypted.db');
      _db = sqlite3.open(dbPath);
      if (Platform.isAndroid && hexKey.isNotEmpty) {
        _db!.execute("PRAGMA key = \"x'$hexKey'\";");
      }
    }
    _createTables();
    _emitDramas();
  }

  void _createTables() {
    final db = _db!;
    db.execute('''
      CREATE TABLE IF NOT EXISTS dramas (
        id INTEGER PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        overview TEXT NOT NULL,
        rating REAL NOT NULL,
        posterPath TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Planned',
        episodesWatched INTEGER NOT NULL DEFAULT 0,
        totalEpisodes INTEGER NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        addedAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        completedAt INTEGER NOT NULL DEFAULT 0,
        myRating REAL NOT NULL DEFAULT 0.0,
        notes TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        genres TEXT NOT NULL DEFAULT '',
        releaseYear INTEGER NOT NULL DEFAULT 0,
        totalSeasons INTEGER NOT NULL DEFAULT 0,
        currentSeason INTEGER NOT NULL DEFAULT 1,
        currentEpisode INTEGER NOT NULL DEFAULT 0,
        nextEpisodeAirDate TEXT,
        nextEpisodeNumber INTEGER NOT NULL DEFAULT 0,
        nextSeasonNumber INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER NOT NULL DEFAULT 0
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS shortcuts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        data TEXT NOT NULL,
        type TEXT NOT NULL,
        iconUrl TEXT,
        dramaId INTEGER NOT NULL DEFAULT 0
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS drama_details_cache (
        dramaId INTEGER PRIMARY KEY NOT NULL,
        payloadJson TEXT NOT NULL,
        cachedAt INTEGER NOT NULL
      );
    ''');
  }

  Drama _rowToDrama(Row row) {
    return Drama(
      id: row['id'] as int,
      title: row['title'] as String,
      overview: row['overview'] as String,
      rating: (row['rating'] as num).toDouble(),
      posterPath: row['posterPath'] as String,
      status: row['status'] as String,
      episodesWatched: row['episodesWatched'] as int,
      totalEpisodes: row['totalEpisodes'] as int,
      isDeleted: (row['isDeleted'] as int) != 0,
      addedAt: row['addedAt'] as int,
      updatedAt: row['updatedAt'] as int,
      completedAt: row['completedAt'] as int,
      myRating: (row['myRating'] as num).toDouble(),
      notes: row['notes'] as String,
      tags: row['tags'] as String,
      genres: row['genres'] as String,
      releaseYear: row['releaseYear'] as int,
      totalSeasons: row['totalSeasons'] as int,
      currentSeason: row['currentSeason'] as int,
      currentEpisode: row['currentEpisode'] as int,
      nextEpisodeAirDate: row['nextEpisodeAirDate'] as String?,
      nextEpisodeNumber: row['nextEpisodeNumber'] as int,
      nextSeasonNumber: row['nextSeasonNumber'] as int,
      deletedAt: row['deletedAt'] as int,
    );
  }

  List<Drama> getAllDramasSync() {
    final db = _db;
    if (db == null) return const [];
    final rows = db.select('SELECT * FROM dramas ORDER BY updatedAt DESC');
    return rows.map(_rowToDrama).toList();
  }

  void _emitDramas() {
    _latestDramas = getAllDramasSync();
    if (!_dramasController.isClosed) {
      _dramasController.add(_latestDramas);
    }
  }

  Drama? getDramaById(int id) {
    final db = _db;
    if (db == null) return null;
    final rows = db.select('SELECT * FROM dramas WHERE id = ? LIMIT 1', [id]);
    if (rows.isEmpty) return null;
    return _rowToDrama(rows.first);
  }

  void upsertDrama(Drama d) {
    final db = _db;
    if (db == null) return;
    _upsertDramaRow(db, d);
    _emitDramas();
  }

  /// Inserts/updates multiple dramas in a single SQLite transaction and emits once,
  /// preventing N redundant UI rebuilds & native worker syncs during cloud reconcile.
  void upsertDramasBatch(List<Drama> dramas) {
    final db = _db;
    if (db == null || dramas.isEmpty) return;
    db.execute('BEGIN TRANSACTION');
    try {
      for (final d in dramas) {
        _upsertDramaRow(db, d);
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
    _emitDramas();
  }

  void _upsertDramaRow(Database db, Drama d) {
    db.execute(
      '''
      INSERT OR REPLACE INTO dramas (
        id, title, overview, rating, posterPath, status,
        episodesWatched, totalEpisodes, isDeleted, addedAt, updatedAt,
        completedAt, myRating, notes, tags, genres, releaseYear,
        totalSeasons, currentSeason, currentEpisode, nextEpisodeAirDate,
        nextEpisodeNumber, nextSeasonNumber, deletedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        d.id,
        d.title,
        d.overview,
        d.rating,
        d.posterPath,
        d.status,
        d.episodesWatched,
        d.totalEpisodes,
        d.isDeleted ? 1 : 0,
        d.addedAt,
        d.updatedAt,
        d.completedAt,
        d.myRating,
        d.notes,
        d.tags,
        d.genres,
        d.releaseYear,
        d.totalSeasons,
        d.currentSeason,
        d.currentEpisode,
        d.nextEpisodeAirDate,
        d.nextEpisodeNumber,
        d.nextSeasonNumber,
        d.deletedAt,
      ],
    );
  }

  void updateDramaStatus(int id, String status) {
    final db = _db;
    if (db == null) return;
    db.execute('UPDATE dramas SET status = ? WHERE id = ?', [status, id]);
    _emitDramas();
  }

  void deleteDramaById(int id) {
    final db = _db;
    if (db == null) return;
    db.execute('DELETE FROM dramas WHERE id = ?', [id]);
    _emitDramas();
  }

  void clearAllDramas() {
    final db = _db;
    if (db == null) return;
    db.execute('DELETE FROM dramas');
    _emitDramas();
  }

  /// Permanently purges Recycle Bin shows older than 30 days (exact parity with `RecycleBinPurgeWorker`).
  int purgeExpiredRecycleBin({int? nowMs}) {
    final db = _db;
    if (db == null) return 0;
    final cutoff = (nowMs ?? DateTime.now().millisecondsSinceEpoch) -
        const Duration(days: 30).inMilliseconds;
    db.execute(
      'DELETE FROM dramas WHERE isDeleted = 1 AND deletedAt > 0 AND deletedAt < ?',
      [cutoff],
    );
    final purged = db.updatedRows;
    if (purged > 0) _emitDramas();
    return purged;
  }

  // --- Detail Cache ---
  CachedDetailEntry? getDetailCache(int dramaId) {
    final db = _db;
    if (db == null) return null;
    final rows = db.select(
      'SELECT dramaId, payloadJson, cachedAt FROM drama_details_cache WHERE dramaId = ? LIMIT 1',
      [dramaId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return CachedDetailEntry(
      dramaId: r['dramaId'] as int,
      payloadJson: r['payloadJson'] as String,
      cachedAt: r['cachedAt'] as int,
    );
  }

  void putDetailCache(int dramaId, String payloadJson, int cachedAt) {
    final db = _db;
    if (db == null) return;
    db.execute(
      'INSERT OR REPLACE INTO drama_details_cache (dramaId, payloadJson, cachedAt) VALUES (?, ?, ?)',
      [dramaId, payloadJson, cachedAt],
    );
  }

  void clearDetailCache() {
    final db = _db;
    if (db == null) return;
    db.execute('DELETE FROM drama_details_cache');
  }

  // --- Shortcuts (Schema Compatibility) ---
  Shortcut? getShortcutForDrama(int dramaId) {
    final db = _db;
    if (db == null) return null;
    final rows = db.select(
      'SELECT * FROM shortcuts WHERE dramaId = ? LIMIT 1',
      [dramaId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Shortcut(
      id: r['id'] as int,
      title: r['title'] as String,
      data: r['data'] as String,
      type: r['type'] as String,
      iconUrl: r['iconUrl'] as String?,
      dramaId: r['dramaId'] as int,
    );
  }

  void saveShortcutForDrama(int dramaId, Shortcut? shortcut) {
    final db = _db;
    if (db == null) return;
    db.execute('DELETE FROM shortcuts WHERE dramaId = ?', [dramaId]);
    if (shortcut != null) {
      db.execute(
        'INSERT INTO shortcuts (title, data, type, iconUrl, dramaId) VALUES (?, ?, ?, ?, ?)',
        [shortcut.title, shortcut.data, shortcut.type, shortcut.iconUrl, dramaId],
      );
    }
  }

  void dispose() {
    _dramasController.close();
    _db?.dispose();
    _db = null;
  }
}
