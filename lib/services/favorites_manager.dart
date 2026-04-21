import 'package:drift/drift.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';

class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  AppDatabase? _db;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    _db = AppDatabase();
    _isInitialized = true;
  }

  AppDatabase get db {
    if (_db == null) {
      throw StateError('FavoritesManager not initialized. Call init() first.');
    }
    return _db!;
  }

  Future<void> addFavorite({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    int type = 1, // Default to "Want to Watch" or generic
  }) async {
    if (!_isInitialized) await init();

    final favorite = LocalFavorite.create(
      bangumiId: bangumiId,
      title: title,
      coverUrl: coverUrl,
      score: score,
      type: type,
    );

    await db
        .into(db.dbLocalFavorites)
        .insert(
          _favoriteToCompanion(favorite),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> removeFavorite(int bangumiId) async {
    if (!_isInitialized) await init();

    await (db.delete(
      db.dbLocalFavorites,
    )..where((tbl) => tbl.bangumiId.equals(bangumiId))).go();
  }

  Future<bool> isFavorite(int bangumiId) async {
    if (!_isInitialized) await init();

    final count =
        await (db.selectOnly(db.dbLocalFavorites)
              ..addColumns([db.dbLocalFavorites.id.count()])
              ..where(db.dbLocalFavorites.bangumiId.equals(bangumiId)))
            .map((row) => row.read(db.dbLocalFavorites.id.count()) ?? 0)
            .getSingle();
    return count > 0;
  }

  Future<List<LocalFavorite>> getAllFavorites() async {
    if (!_isInitialized) await init();

    final rows = await (db.select(
      db.dbLocalFavorites,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])).get();
    return rows.map(_favoriteFromRow).toList();
  }

  DbLocalFavoritesCompanion _favoriteToCompanion(LocalFavorite favorite) {
    return DbLocalFavoritesCompanion.insert(
      bangumiId: favorite.bangumiId,
      title: favorite.title,
      coverUrl: favorite.coverUrl,
      type: favorite.type,
      score: favorite.score,
      createdAt: favorite.createdAt,
    );
  }

  LocalFavorite _favoriteFromRow(DbLocalFavorite row) {
    return LocalFavorite()
      ..id = row.id
      ..bangumiId = row.bangumiId
      ..title = row.title
      ..coverUrl = row.coverUrl
      ..type = row.type
      ..score = row.score
      ..createdAt = row.createdAt;
  }
}
