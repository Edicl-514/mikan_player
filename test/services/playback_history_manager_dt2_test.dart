// DT-2C: PlaybackHistoryManager supplements for corruption, migration, and
// hard limits. Happy-path concurrency already lives in
// playback_history_manager_test.dart.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shared_prefs_support.dart';

AnimeInfo _anime({String id = '123', String title = 'Test Anime'}) {
  return AnimeInfo(
    title: title,
    subTitle: null,
    bangumiId: id,
    mikanId: null,
    coverUrl: null,
    siteUrl: null,
    broadcastDay: null,
    broadcastTime: null,
    score: null,
    rank: null,
    tags: const [],
    fullJson: null,
  );
}

BangumiEpisode _episode({int id = 1, double sort = 1, String name = 'EP1'}) {
  return BangumiEpisode(
    id: id,
    name: name,
    nameCn: name,
    description: '',
    airdate: '',
    duration: '',
    sort: sort,
  );
}

Map<String, Object?> _validItemJson({
  String key = 'bgm:1',
  String title = 'Valid',
  int episodeId = 1,
  int lastPositionMs = 1000,
}) {
  return <String, Object?>{
    'key': key,
    'title': title,
    'subTitle': null,
    'bangumiId': '1',
    'mikanId': null,
    'coverUrl': null,
    'siteUrl': null,
    'broadcastDay': null,
    'broadcastTime': null,
    'score': null,
    'rank': null,
    'tags': <String>[],
    'fullJson': null,
    'episodeId': episodeId,
    'episodeSort': 1.0,
    'episodeName': 'EP1',
    'episodeNameCn': 'EP1',
    'episodesJson': '[]',
    'updatedAt': 1,
    'lastPositionMs': lastPositionMs,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaybackHistoryManager manager;

  setUp(() async {
    await resetSharedPreferences();
    manager = PlaybackHistoryManager()..debugResetCacheForTest();
    await manager.clear();
  });

  group('buildKey', () {
    test('prefers bangumiId, then mikanId, then title', () {
      expect(
        manager.buildKey(
          AnimeInfo(
            title: 'T',
            subTitle: null,
            bangumiId: '9',
            mikanId: 'm',
            coverUrl: null,
            siteUrl: null,
            broadcastDay: null,
            broadcastTime: null,
            score: null,
            rank: null,
            tags: const [],
            fullJson: null,
          ),
        ),
        'bgm:9',
      );
      expect(
        manager.buildKey(
          AnimeInfo(
            title: 'T',
            subTitle: null,
            bangumiId: null,
            mikanId: 'm',
            coverUrl: null,
            siteUrl: null,
            broadcastDay: null,
            broadcastTime: null,
            score: null,
            rank: null,
            tags: const [],
            fullJson: null,
          ),
        ),
        'mikan:m',
      );
      expect(
        manager.buildKey(
          AnimeInfo(
            title: 'Only Title',
            subTitle: null,
            bangumiId: '',
            mikanId: '',
            coverUrl: null,
            siteUrl: null,
            broadcastDay: null,
            broadcastTime: null,
            score: null,
            rank: null,
            tags: const [],
            fullJson: null,
          ),
        ),
        'title:Only Title',
      );
    });
  });

  group('corrupt storage', () {
    test('non-JSON payload yields empty history instead of throwing', () async {
      await seedSharedPreferences(<String, Object>{
        'playback_history_v1': 'not-json{{{',
      });
      manager.debugResetCacheForTest();

      final history = await manager.getHistory();
      expect(history, isEmpty);
    });

    test('JSON object (not list) yields empty history', () async {
      await seedSharedPreferences(<String, Object>{
        'playback_history_v1': jsonEncode(<String, Object>{'oops': true}),
      });
      manager.debugResetCacheForTest();
      expect(await manager.getHistory(), isEmpty);
    });

    test('single corrupt entry does not wipe the rest of the list', () async {
      // Regression for DT-2-001: whole-list wipe on first bad row.
      final payload = <Object?>[
        _validItemJson(key: 'bgm:good', title: 'Good', lastPositionMs: 42),
        <String, Object?>{'key': 'bgm:bad'}, // missing required fields
        'not-a-map',
        _validItemJson(key: 'bgm:also', title: 'Also', lastPositionMs: 7),
      ];
      await seedSharedPreferences(<String, Object>{
        'playback_history_v1': jsonEncode(payload),
      });
      manager.debugResetCacheForTest();

      final history = await manager.getHistory();
      expect(history.map((e) => e.key).toList(), <String>[
        'bgm:good',
        'bgm:also',
      ]);
      expect(history.first.lastPositionMs, 42);
    });

    test('legacy entry without lastPositionMs defaults to 0', () async {
      final legacy = _validItemJson();
      legacy.remove('lastPositionMs');
      await seedSharedPreferences(<String, Object>{
        'playback_history_v1': jsonEncode(<Object?>[legacy]),
      });
      manager.debugResetCacheForTest();

      final history = await manager.getHistory();
      expect(history, hasLength(1));
      expect(history.single.lastPositionMs, 0);
    });
  });

  group('limits and mutations', () {
    test('addOrUpdate caps the list at 200 entries', () async {
      final ep = _episode();
      for (var i = 0; i < 205; i++) {
        await manager.addOrUpdate(
          anime: _anime(id: '$i', title: 'Show $i'),
          currentEpisode: ep,
          allEpisodes: [ep],
          lastPositionMs: i,
        );
      }
      final history = await manager.getHistory();
      expect(history, hasLength(200));
      // Newest insert is at the front.
      expect(history.first.key, 'bgm:204');
      expect(history.last.key, 'bgm:5');
    });

    test('updatePosition is a no-op for unknown keys', () async {
      await manager.updatePosition('bgm:missing', 999);
      expect(await manager.getHistory(), isEmpty);
    });

    test('updatePosition clamps negative values to 0', () async {
      final anime = _anime();
      final ep = _episode();
      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 50,
      );
      await manager.updatePosition(manager.buildKey(anime), -10);
      final history = await manager.getHistory();
      expect(history.single.lastPositionMs, 0);
    });

    test('remove drops only the matching key', () async {
      final ep = _episode();
      await manager.addOrUpdate(
        anime: _anime(id: '1'),
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 1,
      );
      await manager.addOrUpdate(
        anime: _anime(id: '2'),
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 2,
      );

      await manager.remove('bgm:1');
      final history = await manager.getHistory();
      expect(history.map((e) => e.key).toList(), <String>['bgm:2']);
    });

    test('clear empties memory and the preference key', () async {
      final ep = _episode();
      await manager.addOrUpdate(
        anime: _anime(),
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 1,
      );
      await manager.clear();

      expect(await manager.getHistory(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('playback_history_v1'), isFalse);
    });

    test('findByAnime returns the matching entry', () async {
      final anime = _anime(id: '55');
      final ep = _episode();
      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 1234,
      );

      final found = await manager.findByAnime(anime);
      expect(found?.lastPositionMs, 1234);
      expect(await manager.findByAnime(_anime(id: '999')), isNull);
    });

    test('toEpisodes recovers from corrupt episodesJson', () {
      final item = PlaybackHistoryItem.fromJson(
        Map<String, dynamic>.from(
          _validItemJson()..['episodesJson'] = 'not-json',
        ),
      );
      expect(item.toEpisodes(), isEmpty);
    });
  });

  group('serialized concurrent updatePosition', () {
    test('last write wins across overlapping position ticks', () async {
      final anime = _anime();
      final ep = _episode();
      final key = manager.buildKey(anime);
      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 0,
      );

      await Future.wait(<Future<void>>[
        manager.updatePosition(key, 10_000),
        manager.updatePosition(key, 20_000),
        manager.updatePosition(key, 30_000),
      ]);

      final history = await manager.getHistory();
      expect(history.single.lastPositionMs, 30_000);
    });
  });
}
