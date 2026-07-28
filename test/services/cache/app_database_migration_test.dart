// DT-2D: Drift schema upgrades from the two on-disk versions that production
// users can have to the current schema version.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates a v1 database and preserves existing rows', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE db_local_favorites (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              bangumi_id INTEGER NOT NULL UNIQUE,
              title TEXT NOT NULL,
              cover_url TEXT NOT NULL,
              type INTEGER NOT NULL,
              score REAL NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          raw.execute('''
            INSERT INTO db_local_favorites
              (bangumi_id, title, cover_url, type, score, created_at)
            VALUES (7, 'Legacy', 'cover', 1, 8.5, 100)
          ''');
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(db.close);

    final favorite = await db.select(db.dbLocalFavorites).getSingle();
    expect(favorite.bangumiId, 7);
    expect(favorite.title, 'Legacy');

    await db
        .into(db.dbBangumiEpisodeCaches)
        .insert(
          DbBangumiEpisodeCachesCompanion.insert(
            subjectId: 7,
            episodesJson: '[]',
            cachedAt: 100,
            expiresAt: 200,
          ),
        );
    await db
        .into(db.dbBangumiPersonCaches)
        .insert(
          DbBangumiPersonCachesCompanion.insert(
            subjectId: 7,
            personsJson: '[]',
            cachedAt: 100,
            expiresAt: 200,
          ),
        );
    expect(await db.select(db.dbBangumiEpisodeCaches).get(), hasLength(1));
    expect(await db.select(db.dbBangumiPersonCaches).get(), hasLength(1));
  });

  test('migrates a v2 database and creates the v3 person table', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          // A real v2 database still carries the v1 favorites table; the v4
          // upgrade adds columns to it, so the fixture must include it.
          raw.execute('''
            CREATE TABLE db_local_favorites (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              bangumi_id INTEGER NOT NULL UNIQUE,
              title TEXT NOT NULL,
              cover_url TEXT NOT NULL,
              type INTEGER NOT NULL,
              score REAL NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          raw.execute('''
            CREATE TABLE db_bangumi_episode_caches (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              subject_id INTEGER NOT NULL UNIQUE,
              episodes_json TEXT NOT NULL,
              cached_at INTEGER NOT NULL,
              expires_at INTEGER NOT NULL
            )
          ''');
          raw.execute('''
            INSERT INTO db_bangumi_episode_caches
              (subject_id, episodes_json, cached_at, expires_at)
            VALUES (9, '[{"id":1}]', 100, 200)
          ''');
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );
    addTearDown(db.close);

    final episode = await db.select(db.dbBangumiEpisodeCaches).getSingle();
    expect(episode.subjectId, 9);
    expect(episode.episodesJson, '[{"id":1}]');

    await db
        .into(db.dbBangumiPersonCaches)
        .insert(
          DbBangumiPersonCachesCompanion.insert(
            subjectId: 9,
            personsJson: '[]',
            cachedAt: 100,
            expiresAt: 200,
          ),
        );
    expect(await db.select(db.dbBangumiPersonCaches).get(), hasLength(1));
  });

  test('migrates a v3 database to the v4 collection-sync schema', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE db_local_favorites (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              bangumi_id INTEGER NOT NULL UNIQUE,
              title TEXT NOT NULL,
              cover_url TEXT NOT NULL,
              type INTEGER NOT NULL,
              score REAL NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          raw.execute('''
            INSERT INTO db_local_favorites
              (bangumi_id, title, cover_url, type, score, created_at)
            VALUES (11, 'Pre-sync', 'cover', 3, 7.5, 100)
          ''');
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(db.close);

    // The pre-v4 row survives, and every new column reads as null rather than
    // as an invented value the merge engine would mistake for a real edit.
    final favorite = await db.select(db.dbLocalFavorites).getSingle();
    expect(favorite.bangumiId, 11);
    expect(favorite.title, 'Pre-sync');
    expect(favorite.type, 3);
    expect(favorite.rate, isNull);
    expect(favorite.comment, isNull);
    expect(favorite.tagsJson, isNull);
    expect(favorite.private, isNull);
    expect(favorite.updatedAt, isNull);
    expect(favorite.baseType, isNull);
    expect(favorite.baseRate, isNull);
    expect(favorite.baseComment, isNull);
    expect(favorite.baseTagsJson, isNull);
    expect(favorite.basePrivate, isNull);
    expect(favorite.remoteUpdatedAt, isNull);
    expect(favorite.lastSyncedAt, isNull);
    expect(favorite.ownerAccountId, isNull);

    await db
        .into(db.dbBangumiSyncQueue)
        .insert(
          DbBangumiSyncQueueCompanion.insert(
            accountId: 5,
            subjectId: 11,
            operation: 'metadata',
            payloadJson: '{"rate":{"set":8}}',
            createdAt: 100,
            updatedAt: 100,
          ),
        );
    final queued = await db.select(db.dbBangumiSyncQueue).getSingle();
    expect(queued.subjectId, 11);
    expect(queued.attemptCount, 0);
    expect(queued.nextAttemptAt, 0);
  });

  test('enforces one queued task per account/subject/operation', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    Future<void> insert(String operation) => db
        .into(db.dbBangumiSyncQueue)
        .insert(
          DbBangumiSyncQueueCompanion.insert(
            accountId: 5,
            subjectId: 11,
            operation: operation,
            payloadJson: '{}',
            createdAt: 100,
            updatedAt: 100,
          ),
        );

    await insert('metadata');
    // A different operation for the same subject is allowed; a duplicate of the
    // same one is not, which is what lets the queue merge instead of pile up.
    await insert('status');
    await expectLater(insert('metadata'), throwsA(isA<Exception>()));
  });
}
