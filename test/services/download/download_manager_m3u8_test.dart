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

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/http_file_download_port.dart';
import 'package:mikan_player/services/download/m3u8_downloader.dart';
import 'package:mikan_player/services/download/m3u8_playlist_port.dart';
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

    test('falls back after playlist HTTP 403 and keeps the winning headers for '
        'the nested media playlist', () async {
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
      final fallbackPort = _SequencedM3u8PlaylistPort([
        Exception('HTTP 403'),
        masterText,
        mediaText,
      ]);
      final localManager = DownloadManager.forTesting(m3u8Port: fallbackPort);
      const headers = {
        'User-Agent': 'ua-1',
        'Referer': 'https://play.example/watch',
        'Origin': 'https://play.example',
      };

      try {
        final segments = await localManager.resolveHlsSegmentsForTesting(
          masterUri,
          headers: headers,
        );

        expect(segments, [Uri.parse('https://hls.example.com/seg1.ts')]);
        expect(fallbackPort.calls.length, 3);
        expect(fallbackPort.calls[0].url, masterUri);
        expect(fallbackPort.calls[0].headers, headers);
        expect(fallbackPort.calls[1].url, masterUri);
        expect(fallbackPort.calls[1].headers, {
          'User-Agent': 'ua-1',
          'Origin': 'https://play.example',
        });
        expect(fallbackPort.calls[2].url, mediaUri);
        expect(fallbackPort.calls[2].headers, {
          'User-Agent': 'ua-1',
          'Origin': 'https://play.example',
        });
      } finally {
        localManager.dispose();
      }
    });
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

    test(
      'segment HTTP 403 falls back once and pins the winning headers for the '
      'remaining segments',
      () async {
        const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXT-X-ENDLIST
''';
        final mediaUri = Uri.parse('https://hls.example.com/fallback.m3u8');
        fake.register(mediaUri, mediaText);
        final fallbackHttp = FakeHttpFileDownloadPort(
          contentLength: 3,
          startExceptionsByCall: [Exception('HTTP 403'), null, null],
        );
        final localManager = DownloadManager.forTesting(
          httpPort: fallbackHttp,
          m3u8Port: fake,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        final outFile = File('${tempRoot.path}/fallback_hls.ts');
        final task = DownloadTask(
          id: 'fallback_hls_test',
          name: 'Fallback HLS Episode',
          magnet: '',
          animeName: 'Test',
          episodeNumber: 1,
          startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          taskType: DownloadTaskType.http,
          status: DownloadTaskStatus.downloading,
          progress: 0.0,
          videoUrl: mediaUri.toString(),
          localFilePath: outFile.path,
          headers: {
            'User-Agent': 'ua-1',
            'Referer': 'https://play.example/watch',
            'Origin': 'https://play.example',
          },
        );
        localManager.seedHttpTaskForTesting(task);

        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpSlots();

          expect(fallbackHttp.startCallCount, 2);
          expect(fallbackHttp.allHeaders[0], {
            'User-Agent': 'ua-1',
            'Referer': 'https://play.example/watch',
            'Origin': 'https://play.example',
          });
          expect(fallbackHttp.allHeaders[1], {
            'User-Agent': 'ua-1',
            'Origin': 'https://play.example',
          });
          expect(task.headers, {
            'User-Agent': 'ua-1',
            'Origin': 'https://play.example',
          });

          fallbackHttp
            ..emit([1, 2, 3])
            ..done();
          await pumpSlots();

          expect(fallbackHttp.startCallCount, 3);
          expect(fallbackHttp.allHeaders[2], {
            'User-Agent': 'ua-1',
            'Origin': 'https://play.example',
          });
          fallbackHttp
            ..emit([4, 5, 6])
            ..done();
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.completed);
          expect(await outFile.readAsBytes(), [1, 2, 3, 4, 5, 6]);
        } finally {
          localManager.dispose();
        }
      },
    );

    test(
      'pause during HLS auto-retry backoff prevents another playlist fetch',
      () async {
        final mediaUri = Uri.parse('https://hls.example.com/retry.m3u8');
        final failingPort = _SequencedM3u8PlaylistPort([
          Exception('SocketException: Connection reset by peer'),
        ]);
        final backoffStarted = Completer<Duration>();
        final releaseBackoff = Completer<void>();
        final localManager = DownloadManager.forTesting(
          m3u8Port: failingPort,
          sleep: (duration) {
            if (!backoffStarted.isCompleted) {
              backoffStarted.complete(duration);
            }
            return releaseBackoff.future;
          },
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        final task = DownloadTask(
          id: 'retry_pause_hls_test',
          name: 'Retry Pause HLS Episode',
          magnet: '',
          animeName: 'Test',
          episodeNumber: 1,
          startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          taskType: DownloadTaskType.http,
          status: DownloadTaskStatus.downloading,
          progress: 0.0,
          videoUrl: mediaUri.toString(),
          localFilePath: '${tempRoot.path}/retry_pause_hls.ts',
        );
        localManager.seedHttpTaskForTesting(task);

        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          expect(await backoffStarted.future, greaterThan(Duration.zero));
          expect(failingPort.calls.length, 1);

          expect(await localManager.pauseTask(task.id), isTrue);
          releaseBackoff.complete();
          await downloadFuture;

          expect(failingPort.calls.length, 1);
          expect(task.status, DownloadTaskStatus.paused);
        } finally {
          if (!releaseBackoff.isCompleted) releaseBackoff.complete();
          localManager.dispose();
        }
      },
    );

    test(
      'removeTask after a completed segment does not start or write the next '
      'segment',
      () async {
        const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXT-X-ENDLIST
''';
        final mediaUri = Uri.parse('https://hls.example.com/remove.m3u8');
        final segment1Uri = Uri.parse('https://hls.example.com/seg1.ts');
        fake.register(mediaUri, mediaText);

        final port = _SegmentBoundaryHttpPort();
        final localManager = DownloadManager.forTesting(
          httpPort: port,
          m3u8Port: fake,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        final outFile = File('${tempRoot.path}/removed_hls.ts');
        final task = DownloadTask(
          id: 'remove_hls_test',
          name: 'Removed HLS Episode',
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
        localManager.seedHttpTaskForTesting(task);

        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpSlots();
          expect(port.startedUris, [segment1Uri]);

          port
            ..emitFirst([1, 2, 3])
            ..finishFirst();
          // Hold the first handle's close while the manager removes the task.
          // Once that handle is cleared, its cancellation flag no longer
          // exists; this is the segment-boundary race being guarded here.
          await port.firstHandleCloseStarted;
          await localManager.removeTask(task.id);
          port.releaseFirstHandleClose();
          await downloadFuture;

          expect(port.startedUris, [segment1Uri]);
          expect(localManager.tasks, isEmpty);
          expect(await outFile.readAsBytes(), [1, 2, 3]);
        } finally {
          port.dispose();
          localManager.dispose();
        }
      },
    );

    test(
      'pauseTask between segments still stops before the next segment',
      () async {
        const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXT-X-ENDLIST
''';
        final mediaUri = Uri.parse('https://hls.example.com/pause.m3u8');
        final segment1Uri = Uri.parse('https://hls.example.com/seg1.ts');
        fake.register(mediaUri, mediaText);

        final port = _SegmentBoundaryHttpPort();
        final localManager = DownloadManager.forTesting(
          httpPort: port,
          m3u8Port: fake,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        final outFile = File('${tempRoot.path}/paused_hls.ts');
        final task = DownloadTask(
          id: 'pause_hls_test',
          name: 'Paused HLS Episode',
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
        localManager.seedHttpTaskForTesting(task);

        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpSlots();
          expect(port.startedUris, [segment1Uri]);

          port
            ..emitFirst([4, 5, 6])
            ..finishFirst();
          await port.firstHandleCloseStarted;
          expect(await localManager.pauseTask(task.id), isTrue);
          port.releaseFirstHandleClose();
          await downloadFuture;

          expect(port.startedUris, [segment1Uri]);
          expect(task.status, DownloadTaskStatus.paused);
          expect(task.progress, 50.0);
          expect(await outFile.readAsBytes(), [4, 5, 6]);
        } finally {
          port.dispose();
          localManager.dispose();
        }
      },
    );

    test(
      'resume after pause downloads only remaining segments and appends bytes',
      () async {
        const mediaText = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXT-X-ENDLIST
''';
        final mediaUri = Uri.parse('https://hls.example.com/resume.m3u8');
        final segment2Uri = Uri.parse('https://hls.example.com/seg2.ts');
        fake.register(mediaUri, mediaText);

        final port = _HlsResumeHttpPort();
        final localManager = DownloadManager.forTesting(
          httpPort: port,
          m3u8Port: fake,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        final outFile = File('${tempRoot.path}/resume_hls.ts');
        final task = DownloadTask(
          id: 'resume_hls_test',
          name: 'Resume HLS Episode',
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
        localManager.seedHttpTaskForTesting(task);

        try {
          final firstRun = localManager.downloadHttpFileForTesting(task);
          await pumpSlots();
          port.finishFirst();
          await port.firstHandleCloseStarted;
          expect(await localManager.pauseTask(task.id), isTrue);
          port.releaseFirstHandleClose();
          await firstRun;

          expect(task.status, DownloadTaskStatus.paused);
          expect(task.progress, 50.0);
          expect(await outFile.readAsBytes(), [1, 2, 3]);

          expect(await localManager.resumeTask(task.id), isTrue);
          for (var i = 0; i < 32; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          port.finishSecond();
          for (var i = 0; i < 32; i++) {
            await Future<void>.delayed(Duration.zero);
            if (task.status == DownloadTaskStatus.completed) break;
          }

          expect(port.startedUris.length, 2);
          expect(port.startedUris.last, segment2Uri);
          expect(task.status, DownloadTaskStatus.completed);
          expect(task.progress, 100.0);
          expect(await outFile.readAsBytes(), [1, 2, 3, 7, 8, 9]);
        } finally {
          port.dispose();
          localManager.dispose();
        }
      },
    );
  });

  group('estimateHlsResumeSegmentIndex', () {
    test('maps progress percent to completed segment count', () {
      expect(estimateHlsResumeSegmentIndex(0, 4), 0);
      expect(estimateHlsResumeSegmentIndex(49.9, 4), 1);
      expect(estimateHlsResumeSegmentIndex(50, 4), 2);
      expect(estimateHlsResumeSegmentIndex(100, 4), 4);
    });
  });
}

class _SequencedM3u8PlaylistPort implements M3u8PlaylistPort {
  _SequencedM3u8PlaylistPort(this.responses);

  final List<Object> responses;
  final List<({Uri url, Map<String, String>? headers, String? cookies})> calls =
      [];

  @override
  Future<String> fetchText({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async {
    calls.add((
      url: url,
      headers: headers == null ? null : Map<String, String>.from(headers),
      cookies: cookies,
    ));
    final index = calls.length - 1;
    if (index >= responses.length) {
      throw StateError('Unexpected playlist fetch #${index + 1}: $url');
    }
    final response = responses[index];
    if (response is String) return response;
    throw response;
  }
}

/// A two-segment test port that pauses immediately after the first segment's
/// stream ends, but before its active-job registration is cleared.
class _SegmentBoundaryHttpPort implements HttpFileDownloadPort {
  final StreamController<List<int>> _firstChunks =
      StreamController<List<int>>();
  final Completer<void> _firstHandleCloseStarted = Completer<void>();
  final Completer<void> _allowFirstHandleClose = Completer<void>();

  final List<Uri> startedUris = [];

  Future<void> get firstHandleCloseStarted => _firstHandleCloseStarted.future;

  @override
  Future<HttpFileDownloadHandle> start({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async {
    startedUris.add(url);
    if (startedUris.length != 1) {
      throw StateError('A second HLS segment must not be requested');
    }

    return HttpFileDownloadHandle(
      chunks: _firstChunks.stream,
      contentLength: 3,
      cancel: finishFirst,
      close: () async {
        if (!_firstHandleCloseStarted.isCompleted) {
          _firstHandleCloseStarted.complete();
        }
        await _allowFirstHandleClose.future;
      },
    );
  }

  void emitFirst(List<int> chunk) {
    if (!_firstChunks.isClosed) {
      _firstChunks.add(chunk);
    }
  }

  void finishFirst() {
    if (!_firstChunks.isClosed) {
      _firstChunks.close();
    }
  }

  void releaseFirstHandleClose() {
    if (!_allowFirstHandleClose.isCompleted) {
      _allowFirstHandleClose.complete();
    }
  }

  void dispose() {
    finishFirst();
    releaseFirstHandleClose();
  }
}

class _HlsResumeHttpPort implements HttpFileDownloadPort {
  final StreamController<List<int>> _firstChunks =
      StreamController<List<int>>();
  final StreamController<List<int>> _secondChunks =
      StreamController<List<int>>();
  final Completer<void> _firstHandleCloseStarted = Completer<void>();
  final Completer<void> _allowFirstHandleClose = Completer<void>();

  final List<Uri> startedUris = [];

  Future<void> get firstHandleCloseStarted => _firstHandleCloseStarted.future;

  @override
  Future<HttpFileDownloadHandle> start({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async {
    startedUris.add(url);
    if (startedUris.length == 1) {
      return HttpFileDownloadHandle(
        chunks: _firstChunks.stream,
        contentLength: 3,
        cancel: finishFirst,
        close: () async {
          if (!_firstHandleCloseStarted.isCompleted) {
            _firstHandleCloseStarted.complete();
          }
          await _allowFirstHandleClose.future;
        },
      );
    }
    if (startedUris.length == 2) {
      return HttpFileDownloadHandle(
        chunks: _secondChunks.stream,
        contentLength: 3,
        cancel: finishSecond,
        close: () async {},
      );
    }
    throw StateError('Unexpected HLS segment start #${startedUris.length}');
  }

  void finishFirst() {
    if (!_firstChunks.isClosed) {
      _firstChunks.add([1, 2, 3]);
      _firstChunks.close();
    }
  }

  void finishSecond() {
    if (!_secondChunks.isClosed) {
      _secondChunks.add([7, 8, 9]);
      _secondChunks.close();
    }
  }

  void releaseFirstHandleClose() {
    if (!_allowFirstHandleClose.isCompleted) {
      _allowFirstHandleClose.complete();
    }
  }

  void dispose() {
    finishFirst();
    finishSecond();
    releaseFirstHandleClose();
  }
}
