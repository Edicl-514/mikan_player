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
}
