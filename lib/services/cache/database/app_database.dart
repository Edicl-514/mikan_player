import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/utils/app_directories.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class DbLocalFavorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bangumiId => integer().unique()();
  TextColumn get title => text()();
  TextColumn get coverUrl => text()();
  IntColumn get type => integer()();
  RealColumn get score => real()();
  IntColumn get createdAt => integer()();

  // ── User collection metadata (Bangumi "my collection" fields) ─────────────
  // All nullable so schema v3 rows migrate without inventing user data. A null
  // here means "this app has never known a value", which the merge engine
  // treats differently from an explicit empty value.
  IntColumn get rate => integer().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get tagsJson => text().nullable()();
  BoolColumn get private => boolean().nullable()();

  /// Local last-modified time (ms since epoch) for the metadata above.
  IntColumn get updatedAt => integer().nullable()();

  // ── Sync baseline: the snapshot both sides agreed on at last sync ─────────
  // Field-level three-way merge needs this; comparing only local-vs-remote
  // cannot tell "I changed it" from "they changed it".
  IntColumn get baseType => integer().nullable()();
  IntColumn get baseRate => integer().nullable()();
  TextColumn get baseComment => text().nullable()();
  TextColumn get baseTagsJson => text().nullable()();
  BoolColumn get basePrivate => boolean().nullable()();

  /// Server-side ISO timestamp, for display/diagnostics only — never used as a
  /// merge input (clock skew and coarse granularity make it unreliable).
  TextColumn get remoteUpdatedAt => text().nullable()();
  IntColumn get lastSyncedAt => integer().nullable()();

  /// Bangumi account the baseline belongs to. Switching accounts must not let
  /// account A's baseline turn account B's values into "local edits".
  IntColumn get ownerAccountId => integer().nullable()();
}

/// Durable, account-scoped queue of collection writes that still need to reach
/// Bangumi. Local state is applied immediately; this table is what makes the
/// remote side eventually consistent across offline periods and app restarts.
class DbBangumiSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Bangumi user id. Tasks are never sent under a different account and remain
  /// available if the user later returns to this account.
  IntColumn get accountId => integer()();
  IntColumn get subjectId => integer()();

  /// `status` | `metadata` | `delete`.
  TextColumn get operation => text()();

  /// Field-level payload. Must distinguish "leave unchanged" from "clear", so
  /// presence is encoded explicitly rather than by key omission.
  TextColumn get payloadJson => text()();

  /// Baseline captured at enqueue time, so a replay can tell whether the remote
  /// side was changed by someone else in the meantime.
  TextColumn get baselineJson => text().nullable()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountId, subjectId, operation},
  ];
}

class DbBangumiSubjectCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bangumiId => integer().unique()();
  TextColumn get title => text()();
  TextColumn get titleCn => text().nullable()();
  TextColumn get originalTitle => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get score => real().nullable()();
  IntColumn get rank => integer().nullable()();
  TextColumn get imageSmall => text().nullable()();
  TextColumn get imageGrid => text().nullable()();
  TextColumn get imageLarge => text().nullable()();
  TextColumn get imageMedium => text().nullable()();
  TextColumn get imageCommon => text().nullable()();
  TextColumn get localImagePath => text().nullable()();
  TextColumn get airDate => text().nullable()();
  TextColumn get airWeekday => text().nullable()();
  TextColumn get tagsJson => text().nullable()();
  TextColumn get fullJson => text().nullable()();
  IntColumn get type => integer().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  IntColumn get cachedAt => integer()();
  IntColumn get expiresAt => integer()();
}

class DbBangumiCharacterCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer()();
  IntColumn get characterId => integer()();
  TextColumn get name => text()();
  TextColumn get roleName => text()();
  TextColumn get imageSmall => text().nullable()();
  TextColumn get imageGrid => text().nullable()();
  TextColumn get imageLarge => text().nullable()();
  TextColumn get imageMedium => text().nullable()();
  TextColumn get imageCommon => text().nullable()();
  TextColumn get localImagePath => text().nullable()();
  TextColumn get actorsJson => text().nullable()();
  IntColumn get cachedAt => integer()();
  IntColumn get expiresAt => integer()();
}

class DbBangumiRelationCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceSubjectId => integer()();
  IntColumn get relatedSubjectId => integer()();
  TextColumn get name => text()();
  TextColumn get nameCn => text().nullable()();
  TextColumn get relation => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get localImagePath => text().nullable()();
  IntColumn get cachedAt => integer()();
  IntColumn get expiresAt => integer()();
}

class DbTimetableCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get quarter => text().unique()();
  TextColumn get animesJson => text()();
  IntColumn get cachedAt => integer()();
  IntColumn get expiresAt => integer()();
}

class DbRankingCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cacheKey => text().unique()();
  TextColumn get sortType => text()();
  TextColumn get year => text().nullable()();
  TextColumn get tagsJson => text().nullable()();
  IntColumn get page => integer()();
  TextColumn get resultsJson => text()();
  IntColumn get cachedAt => integer()();
  IntColumn get expiresAt => integer()();
}

class DbBangumiEpisodeCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().unique()();
  TextColumn get episodesJson => text()();
  IntColumn get cachedAt => integer()();
  IntColumn get expiresAt => integer()();
}

class DbBangumiPersonCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().unique()();
  TextColumn get personsJson => text()();
  IntColumn get cachedAt => integer()();
  IntColumn get expiresAt => integer()();
}

class DbDownloadRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get infoHash => text().unique()();
  TextColumn get magnet => text()();
  TextColumn get name => text().nullable()();
  TextColumn get animeName => text().nullable()();
  TextColumn get bangumiId => text().nullable()();
  IntColumn get episodeNumber => integer().nullable()();
  IntColumn get status => integer()();
  TextColumn get filePath => text().nullable()();
  IntColumn get totalSize => integer()();
  IntColumn get downloaded => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

@DriftDatabase(
  tables: [
    DbLocalFavorites,
    DbBangumiSyncQueue,
    DbBangumiSubjectCaches,
    DbBangumiCharacterCaches,
    DbBangumiRelationCaches,
    DbTimetableCaches,
    DbRankingCaches,
    DbBangumiEpisodeCaches,
    DbBangumiPersonCaches,
    DbDownloadRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase get instance {
    _instance ??= AppDatabase._internal();
    return _instance!;
  }

  AppDatabase._internal() : super(_openConnection());

  /// Opens a non-singleton database backed by an arbitrary [QueryExecutor].
  ///
  /// Used by unit tests with [NativeDatabase.memory] so they never touch the
  /// on-disk singleton under the user's AppData directory. Production code
  /// must keep using [instance].
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(dbBangumiEpisodeCaches);
      }
      if (from < 3) {
        await m.createTable(dbBangumiPersonCaches);
      }
      if (from < 4) {
        // Collection metadata + sync baseline. Every column is nullable, so
        // existing rows stay valid and read back as "no value known yet".
        final favorites = dbLocalFavorites;
        for (final column in [
          favorites.rate,
          favorites.comment,
          favorites.tagsJson,
          favorites.private,
          favorites.updatedAt,
          favorites.baseType,
          favorites.baseRate,
          favorites.baseComment,
          favorites.baseTagsJson,
          favorites.basePrivate,
          favorites.remoteUpdatedAt,
          favorites.lastSyncedAt,
          favorites.ownerAccountId,
        ]) {
          await m.addColumn(favorites, column);
        }
        await m.createTable(dbBangumiSyncQueue);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final appDir = await AppDirectories.getUnifiedAppDataDirectory();
    final dbDir = Directory(p.join(appDir.path, 'database'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final file = File(p.join(dbDir.path, 'mikan_player.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
