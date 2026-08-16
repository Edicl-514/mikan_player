import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Singleton keeps an in-memory cache across tests; wipe it explicitly.
    await PlaybackHistoryManager().clear();
  });

  test(
    'addOrUpdate preserves position when lastPositionMs is omitted',
    () async {
      final manager = PlaybackHistoryManager();
      final anime = _anime();
      final ep = _episode();

      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 120_000,
      );

      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: [ep],
        // omit lastPositionMs — must not wipe progress
      );

      final history = await manager.getHistory();
      expect(history, hasLength(1));
      expect(history.first.lastPositionMs, 120_000);
      expect(history.first.episodeId, ep.id);
    },
  );

  test(
    'addOrUpdate resets position when switching episode without position',
    () async {
      final manager = PlaybackHistoryManager();
      final anime = _anime();
      final ep1 = _episode(id: 1, sort: 1);
      final ep2 = _episode(id: 2, sort: 2, name: 'EP2');

      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep1,
        allEpisodes: [ep1, ep2],
        lastPositionMs: 90_000,
      );

      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep2,
        allEpisodes: [ep1, ep2],
      );

      final history = await manager.getHistory();
      expect(history.single.episodeId, ep2.id);
      expect(history.single.lastPositionMs, 0);
    },
  );

  test(
    'serialized writes do not lose newer position to a stale overwrite',
    () async {
      final manager = PlaybackHistoryManager();
      final anime = _anime();
      final ep = _episode();

      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 10_000,
      );

      // Fire overlapping updates; later positions must win after the chain settles.
      final futures = <Future<void>>[
        manager.addOrUpdate(
          anime: anime,
          currentEpisode: ep,
          allEpisodes: [ep],
          lastPositionMs: 20_000,
        ),
        manager.addOrUpdate(
          anime: anime,
          currentEpisode: ep,
          allEpisodes: [ep],
          lastPositionMs: 30_000,
        ),
        manager.addOrUpdate(
          anime: anime,
          currentEpisode: ep,
          allEpisodes: [ep],
          lastPositionMs: 40_000,
        ),
      ];
      await Future.wait(futures);

      final history = await manager.getHistory();
      expect(history.single.lastPositionMs, 40_000);
    },
  );

  test('resumePositionMsFor returns only for the matching episode', () async {
    final manager = PlaybackHistoryManager();
    final anime = _anime();
    final ep1 = _episode(id: 1, sort: 1);
    final ep2 = _episode(id: 2, sort: 2, name: 'EP2');

    await manager.addOrUpdate(
      anime: anime,
      currentEpisode: ep1,
      allEpisodes: [ep1, ep2],
      lastPositionMs: 55_000,
    );

    expect(
      await manager.resumePositionMsFor(anime: anime, episode: ep1),
      55_000,
    );
    expect(
      await manager.resumePositionMsFor(anime: anime, episode: ep2),
      isNull,
    );
  });

  test('live history wins over a stale route resume position', () async {
    final manager = PlaybackHistoryManager();
    final anime = _anime();
    final ep = _episode();

    await manager.addOrUpdate(
      anime: anime,
      currentEpisode: ep,
      allEpisodes: [ep],
      lastPositionMs: 120_000,
    );

    expect(
      await manager.resolveStartPositionMsFor(
        anime: anime,
        episode: ep,
        fallbackPositionMs: 0,
      ),
      120_000,
    );
    expect(
      await manager.resolveStartPositionMsFor(
        anime: anime,
        episode: ep,
        fallbackPositionMs: 30_000,
      ),
      120_000,
    );
  });

  test(
    'route resume position remains a fallback when history has no match',
    () async {
      final manager = PlaybackHistoryManager();

      expect(
        await manager.resolveStartPositionMsFor(
          anime: _anime(),
          episode: _episode(),
          fallbackPositionMs: 45_000,
        ),
        45_000,
      );
    },
  );

  test('live zero position rejects a stale non-zero route fallback', () async {
    final manager = PlaybackHistoryManager();
    final anime = _anime();
    final ep = _episode();

    await manager.addOrUpdate(
      anime: anime,
      currentEpisode: ep,
      allEpisodes: [ep],
      lastPositionMs: 0,
    );

    expect(
      await manager.resolveStartPositionMsFor(
        anime: anime,
        episode: ep,
        fallbackPositionMs: 45_000,
      ),
      isNull,
    );
  });

  test('successful mutations notify mounted history consumers', () async {
    final manager = PlaybackHistoryManager();
    final anime = _anime();
    final ep = _episode();
    var notifications = 0;
    void listener() => notifications++;

    manager.addListener(listener);
    try {
      await manager.addOrUpdate(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: [ep],
        lastPositionMs: 10_000,
      );
      await manager.updatePosition(manager.buildKey(anime), 20_000);
      await manager.remove(manager.buildKey(anime));

      expect(notifications, 3);
    } finally {
      manager.removeListener(listener);
    }
  });
}
