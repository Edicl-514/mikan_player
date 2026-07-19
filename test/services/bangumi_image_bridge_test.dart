import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_image_bridge.dart';

void main() {
  late FakeImageBackend backend;

  setUp(() {
    backend = FakeImageBackend();
    BangumiImageBridge.clear();
    BangumiImageBridge.debugBindBackendForTest(backend);
  });

  tearDown(BangumiImageBridge.debugResetForTest);

  group('BangumiImageBridge URL classification', () {
    test('accepts canonical and mirror hosts but rejects lookalikes', () {
      for (final url in [
        'https://bgm.tv/pic/cover.jpg',
        'https://api.bgm.tv/v0/subjects/1/image',
        'https://bangumi.tv/pic/cover.jpg',
        'https://lain.bangumi.tv/pic/cover.jpg',
        'https://chii.in/pic/cover.jpg',
        'https://api.bangumi.lol/v0/subjects/1/image',
      ]) {
        expect(BangumiImageBridge.isBangumiUrl(url), isTrue, reason: url);
      }
      for (final url in [
        '',
        'not a url',
        'https://bgm.tv.example.com/image',
        'https://evilbangumi.tv/image',
        'https://example.com/?next=https://bgm.tv/image',
      ]) {
        expect(BangumiImageBridge.isBangumiUrl(url), isFalse, reason: url);
      }
    });

    test('extracts only numeric subject image ids', () {
      expect(
        BangumiImageBridge.subjectIdFromImageUrl(
          'https://api.bgm.tv/v0/subjects/123/image?type=large',
        ),
        123,
      );
      expect(
        BangumiImageBridge.subjectIdFromImageUrl(
          'https://api.bgm.tv/v0/subjects/not-a-number/image',
        ),
        0,
      );
      expect(
        BangumiImageBridge.subjectIdFromImageUrl(
          'https://api.bgm.tv/v0/subjects/123',
        ),
        0,
      );
    });
  });

  group('BangumiImageBridge fetching', () {
    test('invalid cover id returns null without touching backend', () async {
      expect(await BangumiImageBridge.fetchCover(0, 'large'), isNull);
      expect(await BangumiImageBridge.fetchCover(-1, 'large'), isNull);
      expect(backend.subjectCalls, isEmpty);
    });

    test(
      'cover requests are coalesced and successful bytes are cached',
      () async {
        final pending = Completer<Uint8List>();
        backend.onSubject = ({required subjectId, required imageType}) =>
            pending.future;

        final first = BangumiImageBridge.fetchCover(42, 'large');
        final second = BangumiImageBridge.fetchCover(42, 'large');
        pending.complete(Uint8List.fromList([1, 2, 3]));

        expect(await first, [1, 2, 3]);
        expect(await second, [1, 2, 3]);
        expect(await BangumiImageBridge.fetchCover(42, 'large'), [1, 2, 3]);
        expect(backend.subjectCalls, [(42, 'large')]);
      },
    );

    test('empty and failed responses are not cached', () async {
      var calls = 0;
      backend.onUrl = (url) async {
        calls++;
        if (calls == 1) return Uint8List(0);
        throw StateError('offline');
      };
      const url = 'https://bangumi.tv/pic/cover.jpg';

      expect(await BangumiImageBridge.fetchUrl(url), isNull);
      expect(await BangumiImageBridge.fetchUrl(url), isNull);
      expect(calls, 2);
    });

    test(
      'fetchFromUrl chooses subject endpoint, type, generic URL, or fallback',
      () async {
        backend.onSubject = ({required subjectId, required imageType}) async =>
            Uint8List.fromList([subjectId, imageType.length]);
        backend.onUrl = (url) async => Uint8List.fromList([url.length]);

        expect(
          await BangumiImageBridge.fetchFromUrl(
            'https://api.bgm.tv/v0/subjects/7/image?type=large',
          ),
          [7, 5],
        );
        expect(
          await BangumiImageBridge.fetchFromUrl(
            'https://api.bgm.tv/v0/subjects/8/image',
          ),
          [8, 6],
        );
        expect(
          await BangumiImageBridge.fetchFromUrl(
            'https://bangumi.tv/pic/photo.jpg',
          ),
          isNotNull,
        );
        expect(
          await BangumiImageBridge.fetchFromUrl(
            'https://example.com/image.jpg',
          ),
          isNull,
        );
        expect(backend.subjectCalls, [(7, 'large'), (8, 'common')]);
        expect(backend.urlCalls, ['https://bangumi.tv/pic/photo.jpg']);
      },
    );

    test(
      'clear prevents an old request from repopulating or removing a newer flight',
      () async {
        final old = Completer<Uint8List>();
        final fresh = Completer<Uint8List>();
        var calls = 0;
        backend.onUrl = (url) {
          calls++;
          return calls == 1 ? old.future : fresh.future;
        };
        const url = 'https://bangumi.tv/pic/race.jpg';

        final oldFuture = BangumiImageBridge.fetchUrl(url);
        BangumiImageBridge.clear();
        final freshFuture = BangumiImageBridge.fetchUrl(url);
        old.complete(Uint8List.fromList([1]));
        expect(await oldFuture, [1]);

        final coalescedFresh = BangumiImageBridge.fetchUrl(url);
        expect(calls, 2);
        fresh.complete(Uint8List.fromList([2]));
        expect(await freshFuture, [2]);
        expect(await coalescedFresh, [2]);
        expect(await BangumiImageBridge.fetchUrl(url), [2]);
        expect(calls, 2);
      },
    );
  });
}

class FakeImageBackend implements BangumiImageBackend {
  Future<Uint8List> Function({
    required int subjectId,
    required String imageType,
  })?
  onSubject;
  Future<Uint8List> Function(String url)? onUrl;
  final subjectCalls = <(int, String)>[];
  final urlCalls = <String>[];

  @override
  Future<Uint8List> fetchSubjectImage({
    required int subjectId,
    required String imageType,
  }) {
    subjectCalls.add((subjectId, imageType));
    return onSubject?.call(subjectId: subjectId, imageType: imageType) ??
        Future.value(Uint8List(0));
  }

  @override
  Future<Uint8List> fetchImageUrl(String url) {
    urlCalls.add(url);
    return onUrl?.call(url) ?? Future.value(Uint8List(0));
  }
}
