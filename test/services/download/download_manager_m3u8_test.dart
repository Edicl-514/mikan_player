// HLS playlist-resolution characterization tests for `DownloadManager`
// (Phase 3 — m3u8 / HLS resolution seam, parallel in shape to
// `download_manager_http_test.dart`).
//
// These exercise the manager's `_resolveHlsSegments` code path via an
// injected [FakeM3u8PlaylistPort] — no real network sockets, no real
// `HttpClient`, no platform channels, no `InAppWebView`. The pure parser
// (`parseM3u8Playlist`) is covered separately in
// `m3u8_playlist_port_test.dart`; here we lock down the RECURSION, the
// `depth > 4` throw, the highest-BANDWIDTH variant selection, encrypted-key
// rejection, empty-segment rejection, and headers/cookies forwarding — the
// behavior that stays in the manager (the parser is depth-naive and parses
// exactly ONE playlist text per call).
//
// `SharedPreferences` is mocked via `SharedPreferences.setMockInitialValues({})`
// so the manager's `_saveTasks` / `_taskStore` work in-memory. No file IO is
// required for resolution tests (the parser is pure and the port is faked),
// so no temp directory is used.
//
// Per-segment download is covered in the group at the bottom via
// `downloadHttpFileForTesting` + dual fakes (playlist + HTTP segment port).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'http_file_download_port_test.dart' show FakeHttpFileDownloadPort;
import 'm3u8_playlist_port_test.dart' show FakeM3u8PlaylistPort;

void main() {
  late FakeM3u8PlaylistPort fake;
  late DownloadManager manager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeM3u8PlaylistPort();
    manager = DownloadManager.forTesting(m3u8Port: fake);
  });

  tearDown(() {
    manager.dispose();
  });

  group('DownloadManager HLS resolution — single media playlist', () {
    test('returns segments in file order', () async {
      const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXTINF:10.0,
seg3.ts
#EXT-X-ENDLIST
''';
      final mediaUri = Uri.parse('https://hls.example.com/media.m3u8');
      fake.register(mediaUri, mediaText);

      final segments = await manager.resolveHlsSegmentsForTesting(mediaUri);

      expect(segments, [
        Uri.parse('https://hls.example.com/seg1.ts'),
        Uri.parse('https://hls.example.com/seg2.ts'),
        Uri.parse('https://hls.example.com/seg3.ts'),
      ]);
      expect(fake.callCount, 1);
      expect(fake.calls.single.url, mediaUri);
    });
  });

  group('DownloadManager HLS resolution — nested master -> media', () {
    test(
      'selects the highest-BANDWIDTH variant, recurses, returns segments',
      () async {
        // Master carries three variants; the highest-BANDWIDTH one
        // (1080p, 3000000) must be selected for recursion, proving the
        // sort + `.first` selection is preserved behind the seam.
        const masterText = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=500000
360p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000
1080p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000
720p.m3u8
''';
        const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXT-X-ENDLIST
''';
        final masterUri = Uri.parse('https://hls.example.com/master.m3u8');
        final mediaUri = Uri.parse('https://hls.example.com/1080p.m3u8');
        fake.register(masterUri, masterText);
        fake.register(mediaUri, mediaText);

        final segments = await manager.resolveHlsSegmentsForTesting(masterUri);

        expect(segments, [
          Uri.parse('https://hls.example.com/seg1.ts'),
          Uri.parse('https://hls.example.com/seg2.ts'),
        ]);
        // The master was fetched first, then the highest-BANDWIDTH variant
        // (1080p.m3u8) — NOT 360p or 720p.
        expect(fake.callCount, 2);
        expect(fake.calls[0].url, masterUri);
        expect(fake.calls[1].url, mediaUri);
      },
    );
  });

  group('DownloadManager HLS resolution — depth limit', () {
    test(
      'self-referencing master throws m3u8层级过深，无法解析 after 5 fetches',
      () async {
        // A master that points to itself recurses depths 0..4 (each fetch
        // succeeds), then depth 5 trips the `depth > 4` guard and throws
        // before fetching — so exactly 5 fetches ran.
        const masterText = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
self.m3u8
''';
        final selfUri = Uri.parse('https://hls.example.com/self.m3u8');
        fake.register(selfUri, masterText);

        await expectLater(
          manager.resolveHlsSegmentsForTesting(selfUri),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'toString',
              contains('m3u8层级过深，无法解析'),
            ),
          ),
        );
        // depth 0..4 each fetched exactly once; depth 5 throws pre-fetch.
        expect(fake.callCount, 5);
        for (final call in fake.calls) {
          expect(call.url, selfUri);
        }
      },
    );
  });

  group('DownloadManager HLS resolution — encryption', () {
    test('encrypted #EXT-X-KEY in a reachable media playlist throws '
        '暂不支持下载加密HLS流', () async {
      const masterText = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
enc.m3u8
''';
      const encryptedMediaText = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="https://hls.example.com/key.bin",IV=0x1234
#EXTINF:10.0,
seg1.ts
''';
      final masterUri = Uri.parse('https://hls.example.com/master.m3u8');
      final encryptedMediaUri = Uri.parse('https://hls.example.com/enc.m3u8');
      fake.register(masterUri, masterText);
      fake.register(encryptedMediaUri, encryptedMediaText);

      await expectLater(
        manager.resolveHlsSegmentsForTesting(masterUri),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.toString(),
            'toString',
            contains('暂不支持下载加密HLS流'),
          ),
        ),
      );
      // The throw surfaces from the media playlist: both the master and
      // the encrypted media were fetched.
      expect(fake.callCount, 2);
      expect(fake.calls[0].url, masterUri);
      expect(fake.calls[1].url, encryptedMediaUri);
    });

    test('a single directly-fetched encrypted media playlist throws without '
        'recursing', () async {
      const encryptedMediaText = '''
#EXTM3U
#EXT-X-KEY:METHOD=EXAMPLE
#EXTINF:10.0,
seg1.ts
''';
      final uri = Uri.parse('https://hls.example.com/enc.m3u8');
      fake.register(uri, encryptedMediaText);

      await expectLater(
        manager.resolveHlsSegmentsForTesting(uri),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.toString(),
            'toString',
            contains('暂不支持下载加密HLS流'),
          ),
        ),
      );
      expect(fake.callCount, 1);
    });
  });

  group('DownloadManager HLS resolution — empty media playlist', () {
    test('a media playlist with no segments throws 未找到可下载的HLS分片', () async {
      const emptyMediaText = '''
#EXTM3U
#EXT-X-TARGETDURATION:10
#EXT-X-ENDLIST
''';
      final uri = Uri.parse('https://hls.example.com/empty.m3u8');
      fake.register(uri, emptyMediaText);

      await expectLater(
        manager.resolveHlsSegmentsForTesting(uri),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains('未找到可下载的HLS分片'),
          ),
        ),
      );
      expect(fake.callCount, 1);
    });
  });

  group('DownloadManager HLS resolution — headers + cookies forwarding', () {
    test(
      'forwards headers and cookies verbatim into every fetch call',
      () async {
        const masterText = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
media.m3u8
''';
        const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXT-X-ENDLIST
''';
        final masterUri = Uri.parse('https://hls.example.com/master.m3u8');
        final mediaUri = Uri.parse('https://hls.example.com/media.m3u8');
        fake.register(masterUri, masterText);
        fake.register(mediaUri, mediaText);

        final headers = {
          'User-Agent': 'MikanPlayer/1.2 (Linux)',
          'Referer': 'https://source.example.com/embed',
        };
        const cookies = 'session=abc-123; token=xyz';

        final segments = await manager.resolveHlsSegmentsForTesting(
          masterUri,
          headers: headers,
          cookies: cookies,
        );

        expect(segments, [Uri.parse('https://hls.example.com/seg1.ts')]);
        // Both the master fetch AND the media (variant) fetch must carry the
        // same headers and cookies verbatim, matching the original pass-
        // through of `headers`/`cookies` to every `_fetchHttpText` call along
        // the recursion.
        expect(fake.callCount, 2);
        for (final call in fake.calls) {
          expect(call.headers, headers);
          expect(call.cookies, cookies);
        }
      },
    );
  });

  group('DownloadManager HLS segment download (via HTTP port)', () {
    late Directory tempRoot;
    late FakeHttpFileDownloadPort httpFake;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('mikan_hls_mgr_');
      httpFake = FakeHttpFileDownloadPort(contentLength: 3);
      manager.dispose();
      manager = DownloadManager.forTesting(httpPort: httpFake, m3u8Port: fake);
      manager.setDownloadDirForTesting(tempRoot.path);
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    Future<void> pumpSlots() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'media playlist segments are fetched in order and concatenated',
      () async {
        const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXT-X-ENDLIST
''';
        final mediaUri = Uri.parse('https://hls.example.com/media.m3u8');
        fake.register(mediaUri, mediaText);

        final outFile = File('${tempRoot.path}/hls.mp4');
        final task = DownloadTask(
          id: 'hls_test',
          name: 'HLS Episode',
          magnet: '',
          animeName: 'Test',
          episodeNumber: 1,
          startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          taskType: DownloadTaskType.http,
          status: DownloadTaskStatus.downloading,
          progress: 0.0,
          videoUrl: mediaUri.toString(),
          localFilePath: outFile.path,
        );
        manager.seedHttpTaskForTesting(task);

        final downloadFuture = manager.downloadHttpFileForTesting(task);
        await pumpSlots();

        // Segment 1
        expect(httpFake.startCallCount, 1);
        expect(httpFake.lastUrl, Uri.parse('https://hls.example.com/seg1.ts'));
        httpFake.emit([1, 2, 3]);
        httpFake.done();
        await pumpSlots();

        // Segment 2
        expect(httpFake.startCallCount, 2);
        expect(httpFake.lastUrl, Uri.parse('https://hls.example.com/seg2.ts'));
        httpFake.emit([4, 5, 6]);
        httpFake.done();
        await downloadFuture;

        expect(task.status, DownloadTaskStatus.completed);
        expect(task.progress, 100.0);
        expect(await outFile.readAsBytes(), [1, 2, 3, 4, 5, 6]);
        expect(fake.callCount, 1);
      },
    );
  });
}
