import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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

    _db = AppDatabase.instance;
    _isInitialized = true;
  }

  /// Binds an in-memory [AppDatabase.forTesting] instance for unit tests.
  ///
  /// Does not close any previously bound database — callers own that lifecycle.
  @visibleForTesting
  void debugBindForTest(AppDatabase db) {
    _db = db;
    _isInitialized = true;
  }

  /// Clears the singleton so the next [init] re-attaches to production state.
  @visibleForTesting
  void debugResetForTest() {
    _db = null;
    _isInitialized = false;
  }

  AppDatabase get db {
    if (_db == null) {
      throw StateError('FavoritesManager not initialized. Call init() first.');
    }
    return _db!;
  }

  /// Adds a favorite or updates its status, preserving any collection metadata
  /// and sync baseline already stored for the subject.
  ///
  /// This is a *local edit*: it stamps `updatedAt` so a later three-way merge
  /// can tell the change apart from one made on Bangumi.
  Future<void> addFavorite({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    int type = 1, // Default to "Want to Watch" or generic
  }) async {
    if (!_isInitialized) await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dbLocalFavorites)
        .insert(
          DbLocalFavoritesCompanion.insert(
            bangumiId: bangumiId,
            title: title,
            coverUrl: coverUrl,
            type: type,
            score: score,
            createdAt: now,
            updatedAt: Value(now),
          ),
          // Deliberately not insertOrReplace: replacing the row would reset
          // rate / comment / tags / private and the sync baseline to null.
          onConflict: DoUpdate(
            (_) => DbLocalFavoritesCompanion(
              title: Value(title),
              coverUrl: Value(coverUrl),
              type: Value(type),
              score: Value(score),
              updatedAt: Value(now),
            ),
            target: [db.dbLocalFavorites.bangumiId],
          ),
        );
  }

  /// Records a local metadata edit. All four fields are written together
  /// because the collection editor always submits a complete set; `null`
  /// clears the field locally.
  Future<void> setLocalMetadata({
    required int bangumiId,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) async {
    if (!_isInitialized) await init();

    await (db.update(
      db.dbLocalFavorites,
    )..where((tbl) => tbl.bangumiId.equals(bangumiId))).write(
      DbLocalFavoritesCompanion(
        rate: Value(rate),
        comment: Value(comment),
        tagsJson: Value(encodeFavoriteTags(tags)),
        private: Value(private),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Writes the merge result for a subject without touching the baseline.
  ///
  /// Used when a field-level merge resolves some fields to the remote value and
  /// others to the local one; the caller records the baseline separately once
  /// the upload half has succeeded.
  Future<void> applyMergedValues({
    required int bangumiId,
    required int type,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) async {
    if (!_isInitialized) await init();

    await (db.update(
      db.dbLocalFavorites,
    )..where((tbl) => tbl.bangumiId.equals(bangumiId))).write(
      DbLocalFavoritesCompanion(
        type: Value(type),
        rate: Value(rate),
        comment: Value(comment),
        tagsJson: Value(encodeFavoriteTags(tags)),
        private: Value(private),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Stores the server's canonical state as both the local value and the sync
  /// baseline, clearing any pending local-edit marker.
  Future<void> applyRemoteSnapshot({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    required int type,
    required int accountId,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
    String? remoteUpdatedAt,
  }) async {
    if (!_isInitialized) await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    final tagsJson = encodeFavoriteTags(tags);
    final values = DbLocalFavoritesCompanion(
      title: Value(title),
      coverUrl: Value(coverUrl),
      type: Value(type),
      score: Value(score),
      rate: Value(rate),
      comment: Value(comment),
      tagsJson: Value(tagsJson),
      private: Value(private),
      // Local and remote now agree, so there is no outstanding local edit.
      updatedAt: const Value(null),
      baseType: Value(type),
      baseRate: Value(rate),
      baseComment: Value(comment),
      baseTagsJson: Value(tagsJson),
      basePrivate: Value(private),
      remoteUpdatedAt: Value(remoteUpdatedAt),
      lastSyncedAt: Value(now),
      ownerAccountId: Value(accountId),
    );

    await db
        .into(db.dbLocalFavorites)
        .insert(
          DbLocalFavoritesCompanion.insert(
            bangumiId: bangumiId,
            title: title,
            coverUrl: coverUrl,
            type: type,
            score: score,
            createdAt: now,
            rate: Value(rate),
            comment: Value(comment),
            tagsJson: Value(tagsJson),
            private: Value(private),
            baseType: Value(type),
            baseRate: Value(rate),
            baseComment: Value(comment),
            baseTagsJson: Value(tagsJson),
            basePrivate: Value(private),
            remoteUpdatedAt: Value(remoteUpdatedAt),
            lastSyncedAt: Value(now),
            ownerAccountId: Value(accountId),
          ),
          onConflict: DoUpdate(
            (_) => values,
            target: [db.dbLocalFavorites.bangumiId],
          ),
        );
  }

  /// Marks the current local values as agreed with Bangumi after a successful
  /// upload, without changing what the user sees.
  Future<void> confirmBaseline({
    required int bangumiId,
    required int accountId,
    String? remoteUpdatedAt,
  }) async {
    if (!_isInitialized) await init();

    final row = await _rowFor(bangumiId);
    if (row == null) return;

    await (db.update(
      db.dbLocalFavorites,
    )..where((tbl) => tbl.bangumiId.equals(bangumiId))).write(
      DbLocalFavoritesCompanion(
        updatedAt: const Value(null),
        baseType: Value(row.type),
        baseRate: Value(row.rate),
        baseComment: Value(row.comment),
        baseTagsJson: Value(row.tagsJson),
        basePrivate: Value(row.private),
        remoteUpdatedAt: Value(remoteUpdatedAt ?? row.remoteUpdatedAt),
        lastSyncedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ownerAccountId: Value(accountId),
      ),
    );
  }

  /// Marks a queued write settled only if the row still contains [expected].
  ///
  /// Queue sends are asynchronous. A user can edit the same subject after the
  /// request succeeds but before its completion is observed, so an unconditional
  /// update could mark that newer edit as synced. The three-way baseline itself
  /// is intentionally preserved: a status-only or single-field PATCH does not
  /// prove that every other remote field still matches the local row.
  Future<bool> markQueueSettledIfUnchanged({
    required LocalFavorite expected,
    required int accountId,
  }) async {
    if (!_isInitialized) await init();

    Expression<bool> nullableEquals<T extends Object>(
      GeneratedColumn<T> column,
      T? value,
    ) => value == null ? column.isNull() : column.equals(value);

    final tagsJson = encodeFavoriteTags(expected.tags);
    final updated =
        await (db.update(db.dbLocalFavorites)..where(
              (tbl) =>
                  tbl.bangumiId.equals(expected.bangumiId) &
                  tbl.type.equals(expected.type) &
                  nullableEquals(tbl.rate, expected.rate) &
                  nullableEquals(tbl.comment, expected.comment) &
                  nullableEquals(tbl.tagsJson, tagsJson) &
                  nullableEquals(tbl.private, expected.private) &
                  nullableEquals(tbl.updatedAt, expected.updatedAt) &
                  nullableEquals(tbl.ownerAccountId, expected.ownerAccountId),
            ))
            .write(
              DbLocalFavoritesCompanion(
                updatedAt: const Value(null),
                lastSyncedAt: Value(DateTime.now().millisecondsSinceEpoch),
                ownerAccountId: Value(accountId),
              ),
            );
    return updated == 1;
  }

  /// Removes collection rows owned by another Bangumi account.
  ///
  /// Account-owned rows cannot be downgraded to ordinary local favorites: if
  /// the active account does not contain the same subject, the merge engine
  /// would treat that row as a local-only addition and upload it across
  /// accounts. Rows with no owner are genuine local favorites and remain
  /// eligible for first-time upload.
  Future<void> removeFavoritesForOtherAccounts(int accountId) async {
    if (!_isInitialized) await init();

    await (db.delete(db.dbLocalFavorites)..where(
          (tbl) =>
              tbl.ownerAccountId.isNotNull() &
              tbl.ownerAccountId.equals(accountId).not(),
        ))
        .go();
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

  Future<int?> getFavoriteType(int bangumiId) async {
    if (!_isInitialized) await init();

    return (await _rowFor(bangumiId))?.type;
  }

  /// Full local favorite row, including collection metadata and baseline.
  Future<LocalFavorite?> getFavorite(int bangumiId) async {
    if (!_isInitialized) await init();

    final row = await _rowFor(bangumiId);
    return row == null ? null : _favoriteFromRow(row);
  }

  Future<List<LocalFavorite>> getAllFavorites() async {
    if (!_isInitialized) await init();

    final rows = await (db.select(
      db.dbLocalFavorites,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])).get();
    return rows.map(_favoriteFromRow).toList();
  }

  Future<DbLocalFavorite?> _rowFor(int bangumiId) => (db.select(
    db.dbLocalFavorites,
  )..where((tbl) => tbl.bangumiId.equals(bangumiId))).getSingleOrNull();

  LocalFavorite _favoriteFromRow(DbLocalFavorite row) {
    return LocalFavorite()
      ..id = row.id
      ..bangumiId = row.bangumiId
      ..title = row.title
      ..coverUrl = row.coverUrl
      ..type = row.type
      ..score = row.score
      ..createdAt = row.createdAt
      ..rate = row.rate
      ..comment = row.comment
      ..tags = decodeFavoriteTags(row.tagsJson)
      ..private = row.private
      ..updatedAt = row.updatedAt
      ..baseType = row.baseType
      ..baseRate = row.baseRate
      ..baseComment = row.baseComment
      ..baseTags = decodeFavoriteTags(row.baseTagsJson)
      ..basePrivate = row.basePrivate
      ..remoteUpdatedAt = row.remoteUpdatedAt
      ..lastSyncedAt = row.lastSyncedAt
      ..ownerAccountId = row.ownerAccountId;
  }
}
