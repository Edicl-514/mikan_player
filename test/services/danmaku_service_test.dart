import 'dart:async';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/src/rust/api/danmaku.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DanmakuSettings', () {
    test('copyWith changes only supplied fields', () {
      const original = DanmakuSettings();
      final changed = original.copyWith(
        enabled: false,
        opacity: 0.2,
        showTop: false,
      );

      expect(changed.enabled, isFalse);
      expect(changed.opacity, 0.2);
      expect(changed.showTop, isFalse);
      expect(changed.fontSize, original.fontSize);
      expect(changed.speed, original.speed);
      expect(changed.showBottom, original.showBottom);
    });
  });

  group('DanmakuService', () {
    test('loads all persisted settings and notifies once', () async {
      SharedPreferences.setMockInitialValues({
        'danmaku_enabled': false,
        'danmaku_opacity': 0.4,
        'danmaku_fontSize': 30.0,
        'danmaku_speed': 6.0,
        'danmaku_displayArea': 0.5,
        'danmaku_showScrolling': false,
        'danmaku_showTop': false,
        'danmaku_showBottom': true,
        'danmaku_fontWeight': 7,
        'danmaku_strokeWidth': 3.0,
      });
      final service = DanmakuService(api: FakeDanmakuApi());
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.debugSettingsLoaded;

      expect(service.settings.enabled, isFalse);
      expect(service.settings.opacity, 0.4);
      expect(service.settings.fontSize, 30);
      expect(service.settings.speed, 6);
      expect(service.settings.displayArea, 0.5);
      expect(service.settings.showScrolling, isFalse);
      expect(service.settings.showTop, isFalse);
      expect(service.settings.showBottom, isTrue);
      expect(service.settings.fontWeight, 7);
      expect(service.settings.strokeWidth, 3);
      expect(notifications, 1);
    });

    test('updates and toggles settings with persistence', () async {
      final service = DanmakuService(api: FakeDanmakuApi());
      await service.debugSettingsLoaded;
      var notifications = 0;
      service.addListener(() => notifications++);

      service.updateSettings(
        service.settings.copyWith(opacity: 0.25, fontSize: 31),
      );
      service.toggleEnabled();
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('danmaku_opacity'), 0.25);
      expect(prefs.getDouble('danmaku_fontSize'), 31);
      expect(prefs.getBool('danmaku_enabled'), isFalse);
      expect(notifications, 2);
    });

    test('title lookup sorts comments and clears loading state', () async {
      final api = FakeDanmakuApi()
        ..onGetByTitle =
            ({
              required animeTitle,
              required episodeNumber,
              relativeEpisode,
            }) async => const [
              Danmaku(time: 4, danmakuType: 1, color: 1, text: 'late'),
              Danmaku(time: 1, danmakuType: 5, color: 2, text: 'early'),
            ];
      final service = DanmakuService(api: api);
      await service.debugSettingsLoaded;

      await service.loadDanmakuByTitle('作品', '2', relativeEpisode: 1);

      expect(service.isLoading, isFalse);
      expect(service.error, isNull);
      expect(service.danmakuList.map((d) => d.text), ['early', 'late']);
      expect(api.titleCalls.single, ('作品', '2', 1));
    });

    test('Bangumi lookup retries by title after the first failure', () async {
      final api = FakeDanmakuApi();
      api.onGetByBangumiId =
          ({
            required subjectId,
            required episodeNumber,
            relativeEpisode,
          }) async => throw StateError('id failed');
      api.onGetByTitle =
          ({
            required animeTitle,
            required episodeNumber,
            relativeEpisode,
          }) async => const [
            Danmaku(time: 2, danmakuType: 1, color: 0, text: 'fallback'),
          ];
      final service = DanmakuService(api: api);
      await service.debugSettingsLoaded;

      await service.loadDanmakuByBangumiId(
        123,
        '1',
        relativeEpisode: 4,
        animeTitle: '备用标题',
      );

      expect(service.error, isNull);
      expect(service.danmakuList.single.text, 'fallback');
      expect(api.bangumiCalls.single, (123, '1', 4));
      expect(api.titleCalls.single, ('备用标题', '1', 4));
    });

    test('reports retry failure and always releases loading state', () async {
      final api = FakeDanmakuApi();
      api.onGetByBangumiId =
          ({
            required subjectId,
            required episodeNumber,
            relativeEpisode,
          }) async => throw StateError('id failed');
      api.onGetByTitle =
          ({
            required animeTitle,
            required episodeNumber,
            relativeEpisode,
          }) async => throw StateError('title failed');
      final service = DanmakuService(api: api);
      await service.debugSettingsLoaded;

      await service.loadDanmakuByBangumiId(1, '1', animeTitle: 'title');

      expect(service.isLoading, isFalse);
      expect(service.error, contains('title failed'));
      expect(service.danmakuList, isEmpty);
    });

    test('late search response cannot overwrite the latest query', () async {
      final first = Completer<List<DanmakuAnime>>();
      final second = Completer<List<DanmakuAnime>>();
      final api = FakeDanmakuApi()
        ..onSearchAnime = ({required keyword}) =>
            keyword == 'first' ? first.future : second.future;
      final service = DanmakuService(api: api);
      await service.debugSettingsLoaded;

      final firstFuture = service.searchAnime('first');
      final secondFuture = service.searchAnime('second');
      second.complete([anime(2, 'second result')]);
      await secondFuture;
      first.complete([anime(1, 'stale result')]);
      await firstFuture;

      expect(service.searchResults, [anime(2, 'second result')]);
      expect(service.isLoading, isFalse);
    });

    test(
      'selecting anime and episode updates selection and sorted comments',
      () async {
        final api = FakeDanmakuApi();
        api.onGetEpisodes = ({required animeId}) async => [
          episode(9, 'Episode 9'),
        ];
        api.onGetComments = ({required episodeId}) async => const [
          Danmaku(time: 3, danmakuType: 1, color: 0, text: 'b'),
          Danmaku(time: 1, danmakuType: 1, color: 0, text: 'a'),
        ];
        final service = DanmakuService(api: api);
        await service.debugSettingsLoaded;
        final selectedAnime = anime(7, 'Anime');
        final selectedEpisode = episode(9, 'Episode 9');

        await service.selectAnime(selectedAnime);
        await service.selectEpisode(selectedEpisode);

        expect(service.selectedAnime, selectedAnime);
        expect(service.episodes, [selectedEpisode]);
        expect(service.selectedEpisode, selectedEpisode);
        expect(service.currentEpisodeId, 9);
        expect(service.danmakuList.map((d) => d.text), ['a', 'b']);
      },
    );

    test(
      'file matching loads first result, while no match clears comments',
      () async {
        var hasMatch = true;
        final api = FakeDanmakuApi();
        api.onMatchAnime = ({required fileName, fileHash}) async => hasMatch
            ? [
                const DanmakuMatch(
                  episodeId: 5,
                  animeId: 6,
                  animeTitle: 'A',
                  episodeTitle: 'E',
                ),
              ]
            : const [];
        api.onGetComments = ({required episodeId}) async => const [
          Danmaku(time: 1, danmakuType: 1, color: 0, text: 'matched'),
        ];
        final service = DanmakuService(api: api);
        await service.debugSettingsLoaded;

        await service.matchAndLoadDanmaku('a.mkv', fileHash: 'hash');
        expect(service.currentEpisodeId, 5);
        expect(service.danmakuList.single.text, 'matched');
        expect(api.matchCalls.single, ('a.mkv', 'hash'));

        hasMatch = false;
        await service.matchAndLoadDanmaku('b.mkv');
        expect(service.danmakuList, isEmpty);
      },
    );

    test('clear invalidates an in-flight request', () async {
      final pending = Completer<List<Danmaku>>();
      final api = FakeDanmakuApi()
        ..onGetByTitle =
            ({required animeTitle, required episodeNumber, relativeEpisode}) =>
                pending.future;
      final service = DanmakuService(api: api);
      await service.debugSettingsLoaded;

      final future = service.loadDanmakuByTitle('A', '1');
      service.clearDanmaku();
      pending.complete(const [
        Danmaku(time: 1, danmakuType: 1, color: 0, text: 'late'),
      ]);
      await future;

      expect(service.danmakuList, isEmpty);
      expect(service.isLoading, isFalse);
      expect(service.currentEpisodeId, isNull);
      expect(service.error, isNull);
    });

    test(
      'range and type filters honor interval and visibility settings',
      () async {
        final api = FakeDanmakuApi()
          ..onGetByTitle =
              ({
                required animeTitle,
                required episodeNumber,
                relativeEpisode,
              }) async => const [
                Danmaku(time: 0.9, danmakuType: 1, color: 0, text: 'before'),
                Danmaku(time: 1, danmakuType: 1, color: 0, text: 'scroll'),
                Danmaku(time: 2, danmakuType: 4, color: 0, text: 'bottom'),
                Danmaku(time: 2.9, danmakuType: 5, color: 0, text: 'top'),
                Danmaku(time: 3, danmakuType: 6, color: 0, text: 'after'),
              ];
        final service = DanmakuService(api: api);
        await service.debugSettingsLoaded;
        await service.loadDanmakuByTitle('A', '1');
        service.updateSettings(
          service.settings.copyWith(showScrolling: false, showTop: false),
        );

        final range = service.getDanmakuInRange(1, 3);
        final filtered = service.filterDanmaku(range);

        expect(range.map((d) => d.text), ['scroll', 'bottom', 'top']);
        expect(filtered.map((d) => d.text), ['bottom']);
      },
    );
  });
}

DanmakuAnime anime(int id, String title) =>
    DanmakuAnime(animeId: id, animeTitle: title, animeType: 'tvseries');

DanmakuEpisode episode(int id, String title) => DanmakuEpisode(
  episodeId: id,
  episodeTitle: title,
  episodeNumber: id.toString(),
);

class FakeDanmakuApi implements DanmakuApi {
  Future<List<Danmaku>> Function({
    required String animeTitle,
    required String episodeNumber,
    int? relativeEpisode,
  })?
  onGetByTitle;
  Future<List<Danmaku>> Function({
    required int subjectId,
    required String episodeNumber,
    int? relativeEpisode,
  })?
  onGetByBangumiId;
  Future<List<DanmakuAnime>> Function({required String keyword})? onSearchAnime;
  Future<List<DanmakuEpisode>> Function({required PlatformInt64 animeId})?
  onGetEpisodes;
  Future<List<Danmaku>> Function({required PlatformInt64 episodeId})?
  onGetComments;
  Future<List<DanmakuMatch>> Function({
    required String fileName,
    String? fileHash,
  })?
  onMatchAnime;

  final titleCalls = <(String, String, int?)>[];
  final bangumiCalls = <(int, String, int?)>[];
  final matchCalls = <(String, String?)>[];

  @override
  Future<List<Danmaku>> getByTitle({
    required String animeTitle,
    required String episodeNumber,
    int? relativeEpisode,
  }) {
    titleCalls.add((animeTitle, episodeNumber, relativeEpisode));
    return onGetByTitle?.call(
          animeTitle: animeTitle,
          episodeNumber: episodeNumber,
          relativeEpisode: relativeEpisode,
        ) ??
        Future.value(const []);
  }

  @override
  Future<List<Danmaku>> getByBangumiId({
    required int subjectId,
    required String episodeNumber,
    int? relativeEpisode,
  }) {
    bangumiCalls.add((subjectId, episodeNumber, relativeEpisode));
    return onGetByBangumiId?.call(
          subjectId: subjectId,
          episodeNumber: episodeNumber,
          relativeEpisode: relativeEpisode,
        ) ??
        Future.value(const []);
  }

  @override
  Future<List<DanmakuAnime>> searchAnime({required String keyword}) =>
      onSearchAnime?.call(keyword: keyword) ?? Future.value(const []);

  @override
  Future<List<DanmakuEpisode>> getEpisodes({required PlatformInt64 animeId}) =>
      onGetEpisodes?.call(animeId: animeId) ?? Future.value(const []);

  @override
  Future<List<Danmaku>> getComments({required PlatformInt64 episodeId}) =>
      onGetComments?.call(episodeId: episodeId) ?? Future.value(const []);

  @override
  Future<List<DanmakuMatch>> matchAnime({
    required String fileName,
    String? fileHash,
  }) {
    matchCalls.add((fileName, fileHash));
    return onMatchAnime?.call(fileName: fileName, fileHash: fileHash) ??
        Future.value(const []);
  }
}
