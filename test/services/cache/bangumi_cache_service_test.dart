// DT-2D: BangumiCacheService persistence against an in-memory Drift database.
// Network and image layers are out of scope.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/cache/bangumi_cache_service.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';
import 'package:mikan_player/services/cache/models/bangumi_subject_cache.dart';
import 'package:mikan_player/services/cache/models/download_record.dart';
import 'package:mikan_player/services/cache/models/timetable_cache.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';

import '../../support/drift_in_memory.dart';

AnimeInfo _anime({
  required String id,
  required String title,
  String? day = 'Mon',
}) {
  return AnimeInfo(
    title: title,
    subTitle: null,
    bangumiId: id,
    mikanId: null,
    coverUrl: null,
    siteUrl: null,
    broadcastDay: day,
    broadcastTime: '20:00',
    score: 7.5,
    rank: 1,
    tags: const ['tag'],
    fullJson: null,
  );
}

RankingAnime _ranking({required String id, required String title}) {
  return RankingAnime(
    title: title,
    bangumiId: id,
    coverUrl: 'https://example.com/$id.jpg',
    score: 8.0,
    rank: 1,
    info: 'info',
    originalTitle: title,
  );
}

BangumiImages _images(String suffix) => BangumiImages(
  small: 'small-$suffix',
  grid: 'grid-$suffix',
  large: 'large-$suffix',
  medium: 'medium-$suffix',
  common: 'common-$suffix',
);

BangumiCharacter _character({int id = 1, String name = 'Character'}) {
  return BangumiCharacter(
    id: id,
    name: name,
    roleName: 'Main',
    images: _images('$id'),
    actors: [BangumiActor(id: id + 100, name: 'Actor $id')],
  );
}

BangumiRelatedSubject _relation({int id = 2, String name = 'Related'}) {
  return BangumiRelatedSubject(
    id: id,
    name: name,
    nameCn: '关联 $id',
    relation: 'sequel',
    image: 'image-$id',
  );
}

BangumiEpisode _episode({int id = 1, String name = 'Episode 1'}) {
  return BangumiEpisode(
    id: id,
    name: name,
    nameCn: name,
    description: 'Description $id',
    airdate: '2024-01-01',
    duration: '24',
    sort: id.toDouble(),
  );
}

BangumiPerson _person({int id = 3, String name = 'Person'}) {
  return BangumiPerson(
    id: id,
    name: name,
    relation: 'director',
    career: const ['Director'],
    personType: 1,
    images: _images('$id'),
  );
}

DownloadRecord _download({
  String hash = 'hash-1',
  int status = 0,
  int downloaded = 10,
}) {
  return DownloadRecord.create(
      infoHash: hash,
      magnet: 'magnet:?xt=urn:btih:$hash',
      name: 'Episode.mkv',
      animeName: 'Show',
      bangumiId: '10',
      episodeNumber: 1,
      status: status,
      filePath: 'C:/downloads/$hash.mkv',
    )
    ..totalSize = 100
    ..downloaded = downloaded;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BangumiCacheService cache;

  setUp(() async {
    db = AppDatabase.forTesting(driftInMemoryExecutor());
    cache = BangumiCacheService.instance..debugBindForTest(db);
  });

  tearDown(() async {
    cache.debugResetForTest();
    await db.close();
  });

  group('lifecycle', () {
    test('db getter throws when not initialized', () {
      cache.debugResetForTest();
      expect(() => cache.db, throwsStateError);
      // re-bind so tearDown is safe
      cache.debugBindForTest(db);
    });

    test('initialize is idempotent once already bound', () async {
      await cache.initialize();
      expect(identical(cache.db, db), isTrue);
      expect(cache.isInitialized, isTrue);
    });

    test('close detaches the database and resets initialized state', () async {
      await cache.close();

      expect(cache.isInitialized, isFalse);
      expect(() => cache.db, throwsStateError);
    });
  });

  group('subject cache', () {
    test('save + getSubject round-trips fields', () async {
      final subject = BangumiSubjectCache.create(
        bangumiId: 10,
        title: 'Show',
        titleCn: '节目',
        score: 9.1,
        rank: 3,
        fullJson: '{"eps":12}',
      );
      await cache.saveSubject(subject);

      final hit = await cache.getSubject(10);
      expect(hit, isNotNull);
      expect(hit!.title, 'Show');
      expect(hit.titleCn, '节目');
      expect(hit.score, 9.1);
      expect(hit.rank, 3);
      expect(hit.fullJson, '{"eps":12}');
      expect(hit.isExpired, isFalse);
    });

    test('getSubject returns null for missing ids', () async {
      expect(await cache.getSubject(404), isNull);
    });

    test(
      'expired subject is a miss, includingExpired still returns it',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final expired =
            BangumiSubjectCache.create(
                bangumiId: 11,
                title: 'Old',
                cacheDurationDays: 0,
              )
              // Force past expiry regardless of clock tick during create().
              ..expiresAt = now - 1;
        await cache.saveSubject(expired);

        expect(await cache.getSubject(11), isNull);
        final including = await cache.getSubjectIncludingExpired(11);
        expect(including, isNotNull);
        expect(including!.isExpired, isTrue);
        expect(including.title, 'Old');
      },
    );

    test('saveSubjects batch upserts and replaces', () async {
      await cache.saveSubjects([
        BangumiSubjectCache.create(bangumiId: 1, title: 'A'),
        BangumiSubjectCache.create(bangumiId: 2, title: 'B'),
      ]);
      await cache.saveSubjects([
        BangumiSubjectCache.create(bangumiId: 1, title: 'A2'),
      ]);

      expect((await cache.getSubject(1))!.title, 'A2');
      expect((await cache.getSubject(2))!.title, 'B');
    });

    test('cacheFromAnimeInfo skips null / non-int bangumiId', () async {
      final noId = await cache.cacheFromAnimeInfo(
        AnimeInfo(
          title: 'X',
          subTitle: null,
          bangumiId: null,
          mikanId: null,
          coverUrl: null,
          siteUrl: null,
          broadcastDay: null,
          broadcastTime: null,
          score: null,
          rank: null,
          tags: const [],
          fullJson: null,
        ),
      );
      expect(noId, isNull);

      final badId = await cache.cacheFromAnimeInfo(
        AnimeInfo(
          title: 'X',
          subTitle: null,
          bangumiId: 'not-int',
          mikanId: null,
          coverUrl: null,
          siteUrl: null,
          broadcastDay: null,
          broadcastTime: null,
          score: null,
          rank: null,
          tags: const [],
          fullJson: null,
        ),
      );
      expect(badId, isNull);
    });

    test('cacheFromAnimeInfo saves a fresh subject', () async {
      final saved = await cache.cacheFromAnimeInfo(
        _anime(id: '77', title: 'Fresh'),
      );
      expect(saved, isNotNull);
      expect(saved!.bangumiId, 77);
      expect((await cache.getSubject(77))!.title, 'Fresh');
    });

    test(
      'cacheFromRankingAnime validates ids and keeps richer existing data',
      () async {
        expect(
          await cache.cacheFromRankingAnime(
            _ranking(id: 'not-int', title: 'Invalid'),
          ),
          isNull,
        );

        final first = await cache.cacheFromRankingAnime(
          _ranking(id: '88', title: 'Ranking'),
        );
        expect(first?.title, 'Ranking');

        await cache.saveSubject(
          BangumiSubjectCache.create(
            bangumiId: 88,
            title: 'Detailed',
            fullJson: '{"complete":true}',
          ),
        );
        final existing = await cache.cacheFromRankingAnime(
          _ranking(id: '88', title: 'Must not replace'),
        );
        expect(existing?.title, 'Detailed');
        expect(existing?.fullJson, '{"complete":true}');
      },
    );
  });

  group('timetable cache', () {
    test('save + get + animesFromTimetableCache round-trip', () async {
      final animes = [
        _anime(id: '1', title: 'One'),
        _anime(id: '2', title: 'Two'),
        _anime(id: '3', title: 'Three'),
      ];
      await cache.saveTimetable('2024q1', animes);

      final hit = await cache.getTimetable('2024q1');
      expect(hit, isNotNull);
      final decoded = cache.animesFromTimetableCache(hit!);
      expect(decoded.map((a) => a.title).toList(), <String>[
        'One',
        'Two',
        'Three',
      ]);
      expect(decoded.first.bangumiId, '1');
      expect(decoded.first.broadcastDay, 'Mon');
    });

    test('corrupt animesJson returns empty list, not throw', () async {
      final broken = TimetableCache.create(
        quarter: '2020q1',
        animesJson: 'not-json',
      );
      // Insert via the subject of the conversion helper only.
      expect(cache.animesFromTimetableCache(broken), isEmpty);
    });

    test('expired timetable is a miss, includingExpired returns it', () async {
      await cache.saveTimetable('2023q4', [_anime(id: '1', title: 'A')]);
      // Overwrite expiresAt by re-inserting a past-dated companion is hard
      // without a raw insert; instead verify the isExpired flag on a model
      // and the includingExpired path via a zero-duration re-save pattern.
      final now = DateTime.now().millisecondsSinceEpoch;
      final row = await (db.select(
        db.dbTimetableCaches,
      )..where((t) => t.quarter.equals('2023q4'))).getSingle();
      await db
          .into(db.dbTimetableCaches)
          .insert(
            DbTimetableCachesCompanion.insert(
              quarter: row.quarter,
              animesJson: row.animesJson,
              cachedAt: row.cachedAt,
              expiresAt: now - 1,
            ),
            mode: InsertMode.insertOrReplace,
          );

      expect(await cache.getTimetable('2023q4'), isNull);
      final including = await cache.getTimetableIncludingExpired('2023q4');
      expect(including, isNotNull);
      expect(including!.isExpired, isTrue);
    });
  });

  group('character / relation caches', () {
    test(
      'characters round-trip images and actors, then replace by subject',
      () async {
        await cache.saveCharacters(10, [_character(id: 1)]);

        final hit = await cache.getCharacters(10);
        expect(hit, hasLength(1));
        expect(hit.single.characterId, 1);
        expect(hit.single.imageLarge, 'large-1');
        expect(
          cache.charactersFromCache(hit).single.actors.single.name,
          'Actor 1',
        );

        await cache.saveCharacters(10, [
          _character(id: 2, name: 'Replacement'),
        ]);
        final replaced = await cache.getCharacters(10);
        expect(replaced.single.characterId, 2);
        expect(replaced.single.name, 'Replacement');
      },
    );

    test(
      'relations round-trip and empty results use a hidden placeholder',
      () async {
        await cache.saveRelations(10, [_relation()]);
        final hit = await cache.getRelations(10);
        expect(hit.single.relatedSubjectId, 2);
        expect(cache.relationsFromCache(hit).single.nameCn, '关联 2');

        await cache.saveRelations(10, const []);
        expect(await cache.getRelations(10), isEmpty);
        final stored = await cache.getRelationsIncludingExpired(10);
        expect(stored, isEmpty);
        expect((await cache.getCacheStats())['relations'], 1);
      },
    );
  });

  group('episode / person caches', () {
    test('episodes round-trip and malformed JSON is tolerated', () async {
      await cache.saveEpisodes(20, [_episode(id: 1), _episode(id: 2)]);
      final hit = await cache.getEpisodes(20);
      expect(hit.map((episode) => episode.id).toList(), [1, 2]);

      final row = await (db.select(
        db.dbBangumiEpisodeCaches,
      )..where((table) => table.subjectId.equals(20))).getSingle();
      await db
          .into(db.dbBangumiEpisodeCaches)
          .insert(
            DbBangumiEpisodeCachesCompanion.insert(
              subjectId: row.subjectId,
              episodesJson: 'bad-json',
              cachedAt: row.cachedAt,
              expiresAt: row.expiresAt,
            ),
            mode: InsertMode.insertOrReplace,
          );
      expect(await cache.getEpisodes(20), isEmpty);
    });

    test('empty episode/person saves do not erase an existing cache', () async {
      await cache.saveEpisodes(20, [_episode()]);
      await cache.saveEpisodes(20, const []);
      expect(await cache.getEpisodes(20), hasLength(1));

      await cache.savePersons(20, [_person()]);
      final people = await cache.getPersons(20);
      expect(people.single.name, 'Person');
      expect(people.single.images?.large, 'large-3');
      expect(people.single.career, ['Director']);
      await cache.savePersons(20, const []);
      expect(await cache.getPersons(20), hasLength(1));
    });
  });

  group('ranking cache', () {
    test('save + getRanking round-trips results', () async {
      await cache.saveRanking(
        sortType: 'rank',
        year: '2024',
        tags: const ['sci-fi'],
        page: 1,
        results: [
          _ranking(id: '1', title: 'Alpha'),
          _ranking(id: '2', title: 'Beta'),
        ],
      );

      final hit = await cache.getRanking(
        sortType: 'rank',
        year: '2024',
        tags: const ['sci-fi'],
        page: 1,
      );
      expect(hit, isNotNull);
      final items = cache.rankingFromCache(hit!);
      expect(items.map((a) => a.title).toList(), <String>['Alpha', 'Beta']);
    });

    test('saveRanking skips empty results', () async {
      await cache.saveRanking(sortType: 'rank', page: 1, results: const []);
      expect(await cache.getRanking(sortType: 'rank', page: 1), isNull);
    });

    test('deleteRanking removes the entry', () async {
      await cache.saveRanking(
        sortType: 'rank',
        page: 2,
        results: [_ranking(id: '9', title: 'Z')],
      );
      await cache.deleteRanking(sortType: 'rank', page: 2);
      expect(await cache.getRanking(sortType: 'rank', page: 2), isNull);
    });
  });

  group('clear / stats', () {
    test('clearAll wipes caches but leaves the schema usable', () async {
      await cache.saveSubject(
        BangumiSubjectCache.create(bangumiId: 1, title: 'X'),
      );
      await cache.saveTimetable('2024q1', [_anime(id: '1', title: 'X')]);
      await cache.saveRanking(
        sortType: 'rank',
        page: 1,
        results: [_ranking(id: '1', title: 'X')],
      );

      await cache.clearAll();

      expect(await cache.getSubject(1), isNull);
      expect(await cache.getTimetable('2024q1'), isNull);
      expect(await cache.getRanking(sortType: 'rank', page: 1), isNull);

      final stats = await cache.getCacheStats();
      expect(stats['subjects'], 0);
      expect(stats['timetables'], 0);
      expect(stats['rankings'], 0);
    });

    test('clearExpired removes only past-dated rows', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await cache.saveSubject(
        BangumiSubjectCache.create(bangumiId: 1, title: 'Fresh'),
      );
      await cache.saveSubject(
        BangumiSubjectCache.create(
          bangumiId: 2,
          title: 'Stale',
          cacheDurationDays: 0,
        )..expiresAt = now - 5,
      );
      await cache.saveCharacters(2, [_character()]);
      await cache.saveRelations(2, [_relation()]);
      await cache.saveEpisodes(2, [_episode()]);
      await cache.savePersons(2, [_person()]);
      await cache.saveTimetable('stale', [_anime(id: '2', title: 'Stale')]);
      await cache.saveRanking(
        sortType: 'stale',
        page: 1,
        results: [_ranking(id: '2', title: 'Stale')],
      );
      for (final table in <String>[
        'db_bangumi_character_caches',
        'db_bangumi_relation_caches',
        'db_bangumi_episode_caches',
        'db_bangumi_person_caches',
        'db_timetable_caches',
        'db_ranking_caches',
      ]) {
        await db.customStatement('UPDATE $table SET expires_at = ?', [now - 5]);
      }

      await cache.clearExpired();

      expect(await cache.getSubject(1), isNotNull);
      expect(await cache.getSubjectIncludingExpired(2), isNull);
      final stats = await cache.getCacheStats();
      expect(stats['characters'], 0);
      expect(stats['relations'], 0);
      expect(stats['episodes'], 0);
      expect(stats['persons'], 0);
      expect(stats['timetables'], 0);
      expect(stats['rankings'], 0);
    });

    test('getCacheStats reports inserted counts', () async {
      await cache.saveSubject(
        BangumiSubjectCache.create(bangumiId: 1, title: 'A'),
      );
      await cache.saveSubject(
        BangumiSubjectCache.create(bangumiId: 2, title: 'B'),
      );
      final stats = await cache.getCacheStats();
      expect(stats['subjects'], 2);
      expect(stats['downloadRecords'], 0);
    });

    test('clearAll removes caches but preserves download records', () async {
      await cache.saveSubject(
        BangumiSubjectCache.create(bangumiId: 1, title: 'Cached'),
      );
      await cache.saveDownloadRecord(_download());

      await cache.clearAll();

      expect(await cache.getSubject(1), isNull);
      final record = await cache.getDownloadRecord('hash-1');
      expect(record, isNotNull);
      expect(record!.downloaded, 10);
      expect((await cache.getCacheStats())['downloadRecords'], 1);
    });

    test(
      'download records support upsert, completed lookup, list and delete',
      () async {
        await cache.saveDownloadRecord(_download());
        await cache.saveDownloadRecord(_download(status: 1, downloaded: 100));

        final completed = await cache.findCompletedDownload('Show', 1);
        expect(completed, isNotNull);
        expect(completed!.status, 1);
        expect(completed.downloaded, 100);
        expect(await cache.getAllDownloadRecords(), hasLength(1));

        await cache.deleteDownloadRecord('hash-1');
        expect(await cache.getDownloadRecord('hash-1'), isNull);
      },
    );
  });
}
