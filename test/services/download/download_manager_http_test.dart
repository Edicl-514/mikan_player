// HTTP file-download characterization tests for `DownloadManager`
// (Phase 3 Package B).
//
// These exercise the manager's `_downloadHttpFile` code path via an
// injected [FakeHttpFileDownloadPort] — no real network sockets, no real
// `HttpClient`, no platform channels, no `InAppWebView`. `SharedPreferences`
// is mocked via `SharedPreferences.setMockInitialValues({})` so the
// manager's `_saveTasks` / `_taskStore` work in-memory.
//
// Each test drives the fake's `StreamController` to produce canned chunks,
// non-2xx throws, or mid-stream errors, then asserts on the resulting
// `task.status` / `task.progress` / partial-file bytes. This locks down the
// existing byte-for-byte behavior (which is NOT being moved out of the
// manager in this checkpoint — only the seam + tests) so a future
// extraction of `HttpDownloader` can be verified against these
// characterization tests.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'http_file_download_port_test.dart' show FakeHttpFileDownloadPort;

void main() {
  late Directory tempRoot;
  late FakeHttpFileDownloadPort fake;
  late DownloadManager manager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempRoot = Directory.systemTemp.createTempSync('mikan_http_mgr_');
    fake = FakeHttpFileDownloadPort();
    manager = DownloadManager.forTesting(httpPort: fake);
    manager.setDownloadDirForTesting(tempRoot.path);
  });

  tearDown(() {
    manager.dispose();
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  /// Helper: build an HTTP [DownloadTask] pointing at [localFilePath] (the
  /// caller must supply a real temp path to a file that may or may not
  /// pre-exist). Defaults so the caller's test body stays short.
  DownloadTask buildTask({
    required String localFilePath,
    DownloadTaskStatus status = DownloadTaskStatus.downloading,
    String? url = 'https://example.com/episode.mp4',
    Map<String, String>? headers,
    String? cookies,
    double downloadLimitMbps = 0,
  }) {
    if (downloadLimitMbps != 0) {
      manager.setDownloadLimitMbpsForTesting(downloadLimitMbps);
    }
    return DownloadTask(
      id: 'http_test',
      name: 'Episode 01',
      magnet: '',
      animeName: 'Test Anime',
      episodeNumber: 1,
      startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      taskType: DownloadTaskType.http,
      status: status,
      progress: 0.0,
      videoUrl: url,
      headers: headers,
      cookies: cookies,
      localFilePath: localFilePath,
    );
  }

  /// Pumps the event loop enough times to be sure the manager's
  /// `_downloadHttpFile` has progressed past every internal `await` up to
  /// the `await for (final chunk in handle.chunks)` loop entrance. The
  /// exact count is intentionally a few more than the minimum (two async
  /// hops: `_acquireDownloadSlot`, `_httpPort.start`) so fragile future
  /// additions of intermediate `await`s do not flake the tests.
  Future<void> pumpToAwaitFor() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('DownloadManager HTTP download happy path', () {
    test(
      '2xx single chunk writes bytes in order and marks task completed',
      () async {
        final outFile = File('${tempRoot.path}/single_chunk.mp4');
        final task = buildTask(localFilePath: outFile.path);
        manager.seedHttpTaskForTesting(task);

        final downloadFuture = manager.downloadHttpFileForTesting(task);
        await pumpToAwaitFor();

        fake.emit([10, 20, 30]);
        await Future<void>.delayed(Duration.zero);
        fake.done();
        await downloadFuture;

        expect(task.status, DownloadTaskStatus.completed);
        expect(task.progress, 100.0);
        expect(task.downloadSpeed, 0);
        expect(await outFile.readAsBytes(), [10, 20, 30]);
      },
    );

    test(
      '2xx multiple chunks aggregate bytes in order, progress == 100',
      () async {
        final outFile = File('${tempRoot.path}/multi_chunk.mp4');
        final task = buildTask(localFilePath: outFile.path);
        manager.seedHttpTaskForTesting(task);

        final downloadFuture = manager.downloadHttpFileForTesting(task);
        await pumpToAwaitFor();

        fake
          ..emit([1, 2, 3])
          ..emit([4])
          ..emit([5, 6, 7, 8]);
        await Future<void>.delayed(Duration.zero);
        fake.done();
        await downloadFuture;

        expect(task.status, DownloadTaskStatus.completed);
        expect(task.progress, 100.0);
        expect(await outFile.readAsBytes(), [1, 2, 3, 4, 5, 6, 7, 8]);
        // contentLength=12 (fake default) does NOT match 8 bytes, but the
        // original code sets totalSize from contentLength regardless and only
        // falls back to outputFile.lengthSync() when contentLength <= 0.
        expect(task.totalSize, BigInt.from(12));
      },
    );

    test(
      'unknown content length falls back to outputFile length for totalSize',
      () async {
        final fake2 = FakeHttpFileDownloadPort(contentLength: null);
        final localManager = DownloadManager.forTesting(httpPort: fake2);
        localManager.setDownloadDirForTesting(tempRoot.path);
        try {
          final outFile = File('${tempRoot.path}/unknown_len.mp4');
          final task = buildTask(localFilePath: outFile.path);
          localManager.seedHttpTaskForTesting(task);

          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpToAwaitFor();

          fake2
            ..emit([11, 22])
            ..emit([33, 44, 55]);
          await Future<void>.delayed(Duration.zero);
          fake2.done();
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.completed);
          expect(task.progress, 100.0);
          expect(await outFile.readAsBytes(), [11, 22, 33, 44, 55]);
          // contentLength==null → completion path reads actual file size.
          expect(task.totalSize, BigInt.from(5));
        } finally {
          localManager.dispose();
        }
      },
    );
  });

  group('DownloadManager HTTP non-2xx', () {
    test(
      '404 status surfaces as task error with status code in message',
      () async {
        final outFile = File('${tempRoot.path}/should_not_exist.mp4');
        final task = buildTask(localFilePath: outFile.path);

        final port404 = FakeHttpFileDownloadPort(
          contentLength: 12,
          startException: Exception('HTTP 404'),
        );
        // The manager injected in setUp uses `fake`; swap it by constructing a
        // fresh manager bound to the 404 thrower.
        final localManager = DownloadManager.forTesting(httpPort: port404);
        localManager.setDownloadDirForTesting(tempRoot.path);
        localManager.seedHttpTaskForTesting(task);
        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.error);
          expect(task.errorMessage, contains('404'));
          // No file should exist: the original throws BEFORE opening the sink.
          expect(outFile.existsSync(), isFalse);
        } finally {
          localManager.dispose();
        }
      },
    );

    test(
      '500 status surfaces as task error with status code in message',
      () async {
        final outFile = File('${tempRoot.path}/server_error.mp4');
        final task = buildTask(localFilePath: outFile.path);

        final port500 = FakeHttpFileDownloadPort(
          contentLength: 12,
          startException: Exception('HTTP 500'),
        );
        // Compress auto-retry backoff so this characterization stays fast.
        final localManager = DownloadManager.forTesting(
          httpPort: port500,
          sleep: (_) async {},
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        localManager.seedHttpTaskForTesting(task);
        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.error);
          expect(task.errorMessage, contains('500'));
          // Auto-retry walks the full 3-attempt budget for 5xx.
          expect(port500.startCallCount, 4);
          expect(outFile.existsSync(), isFalse);
        } finally {
          localManager.dispose();
        }
      },
    );
  });

  group('DownloadManager HTTP headers + cookies', () {
    test(
      'start receives task headers/cookies and strips a captured Range on a full download',
      () async {
        final outFile = File('${tempRoot.path}/with_headers.mp4');
        // WebView intercept of a media request often captures Range:
        // bytes=0-... A full download must not replay that partial request.
        final headers = {
          'Range': 'bytes=0-',
          'User-Agent': 'MikanPlayer/1.2 (Linux)',
          'Referer': 'https://source.example.com/embed',
        };
        final task = buildTask(
          localFilePath: outFile.path,
          headers: headers,
          cookies: 'session=abc-123; token=xyz',
        );
        manager.seedHttpTaskForTesting(task);

        final downloadFuture = manager.downloadHttpFileForTesting(task);
        await pumpToAwaitFor();

        expect(fake.startCallCount, 1);
        expect(fake.lastUrl, Uri.parse('https://example.com/episode.mp4'));
        expect(fake.lastHeaders, {
          'User-Agent': 'MikanPlayer/1.2 (Linux)',
          'Referer': 'https://source.example.com/embed',
        });
        expect(fake.lastHeaders, isNot(contains('Range')));
        expect(fake.lastCookies, 'session=abc-123; token=xyz');

        fake.done();
        await downloadFuture;
      },
    );

    test(
      'falls back to a no-Referer strategy after HTTP 403 and pins the winner',
      () async {
        final outFile = File('${tempRoot.path}/strategy_fallback.mp4');
        final fallbackFake = FakeHttpFileDownloadPort(
          startExceptionsByCall: [Exception('HTTP 403'), null],
        );
        final localManager = DownloadManager.forTesting(httpPort: fallbackFake);
        localManager.setDownloadDirForTesting(tempRoot.path);
        try {
          final task = buildTask(
            localFilePath: outFile.path,
            headers: {
              'User-Agent': 'ua-1',
              'Referer': 'https://play.example/watch',
              'Origin': 'https://play.example',
            },
          );
          localManager.seedHttpTaskForTesting(task);

          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpToAwaitFor();

          expect(fallbackFake.startCallCount, 2);
          expect(fallbackFake.allHeaders[0], {
            'User-Agent': 'ua-1',
            'Referer': 'https://play.example/watch',
            'Origin': 'https://play.example',
          });
          expect(fallbackFake.allHeaders[1], {
            'User-Agent': 'ua-1',
            'Origin': 'https://play.example',
          });
          // Winning strategy is pinned for resume / retries.
          expect(task.headers, {
            'User-Agent': 'ua-1',
            'Origin': 'https://play.example',
          });

          fallbackFake.emit([1, 2, 3]);
          fallbackFake.done();
          await downloadFuture;
          expect(task.status, DownloadTaskStatus.completed);
        } finally {
          localManager.dispose();
        }
      },
    );

    test('does not header-fallback on HTTP 404', () async {
      final outFile = File('${tempRoot.path}/no_fallback_404.mp4');
      final port404 = FakeHttpFileDownloadPort(
        startException: Exception('HTTP 404'),
      );
      final localManager = DownloadManager.forTesting(httpPort: port404);
      localManager.setDownloadDirForTesting(tempRoot.path);
      try {
        final task = buildTask(
          localFilePath: outFile.path,
          headers: {
            'User-Agent': 'ua-1',
            'Referer': 'https://play.example/watch',
          },
        );
        localManager.seedHttpTaskForTesting(task);
        await localManager.downloadHttpFileForTesting(task);
        expect(port404.startCallCount, 1);
        expect(task.status, DownloadTaskStatus.error);
        expect(task.errorMessage, contains('404'));
      } finally {
        localManager.dispose();
      }
    });

    test(
      'auto-retries a transient open failure then completes without delete',
      () async {
        final outFile = File('${tempRoot.path}/auto_retry.mp4');
        final retryFake = FakeHttpFileDownloadPort(
          startExceptionsByCall: [
            Exception('SocketException: Connection reset by peer'),
            null,
          ],
        );
        final localManager = DownloadManager.forTesting(
          httpPort: retryFake,
          sleep: (_) async {},
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        try {
          final task = buildTask(localFilePath: outFile.path);
          localManager.seedHttpTaskForTesting(task);

          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpToAwaitFor();
          // After the first failure the manager sleeps (compressed to zero)
          // and restarts; pump again for the second open.
          await pumpToAwaitFor();

          expect(retryFake.startCallCount, greaterThanOrEqualTo(2));
          retryFake.emit([9, 9, 9]);
          retryFake.done();
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.completed);
          expect(await outFile.readAsBytes(), [9, 9, 9]);
        } finally {
          localManager.dispose();
        }
      },
    );

    test('resumeTask restarts a failed HTTP task in place', () async {
      final outFile = File('${tempRoot.path}/manual_retry.mp4')
        ..writeAsBytesSync([1, 2, 3]);
      final task = buildTask(
        localFilePath: outFile.path,
        status: DownloadTaskStatus.error,
      );
      task.errorMessage = 'SocketException: Connection reset';
      task.downloaded = BigInt.from(3);
      manager.seedHttpTaskForTesting(task);

      final ok = await manager.resumeTask(task.id);
      expect(ok, isTrue);
      expect(task.status, DownloadTaskStatus.downloading);
      expect(task.errorMessage, isNull);

      await pumpToAwaitFor();
      expect(fake.startCallCount, 1);
      // Resume from existing partial bytes.
      expect(fake.lastHeaders?['Range'], 'bytes=3-');
      fake.emit([4, 5]);
      fake.done();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Wait for the background download body started by resumeTask.
      for (var i = 0; i < 20; i++) {
        if (task.status == DownloadTaskStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(task.status, DownloadTaskStatus.completed);
    });
  });

  group('DownloadManager HTTP cancellation', () {
    test(
      'pauseTask sets the cancel flag, partial bytes are retained, no further '
      'chunks are written after the flag',
      () async {
        final fakeNoClose = FakeHttpFileDownloadPort(
          contentLength: 12,
          cancelClosesStream: false,
        );
        final localManager = DownloadManager.forTesting(httpPort: fakeNoClose);
        localManager.setDownloadDirForTesting(tempRoot.path);
        try {
          final outFile = File('${tempRoot.path}/partial.mp4');
          final task = buildTask(localFilePath: outFile.path);
          localManager.seedHttpTaskForTesting(task);

          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpToAwaitFor();

          // Chunk A is written.
          fakeNoClose.emit([10, 20, 30]);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          // Cancel: pauseTask sets the cancelled flag, calls handle.cancel,
          // and closes the sink.
          final paused = await localManager.pauseTask(task.id);
          expect(paused, isTrue);
          expect(task.status, DownloadTaskStatus.paused);

          // Chunk B arrives AFTER cancel: the loop body must NOT write it.
          fakeNoClose.emit([40, 50, 60]);
          await Future<void>.delayed(Duration.zero);

          // Close the stream so the await-for terminates and the manager
          // can run the post-loop paused path (it re-checks the flag and
          // keeps the file).
          fakeNoClose.done();
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.paused);
          expect(task.downloadSpeed, 0);
          expect(task.uploadSpeed, 0);
          // Partial file LEAVES on disk with only chunk A's bytes.
          expect(await outFile.readAsBytes(), [10, 20, 30]);
          expect(outFile.existsSync(), isTrue);
          // Cancel and the eventual close ran exactly once each.
          expect(fakeNoClose.cancelCalled, isTrue);
          expect(fakeNoClose.closeCalled, isTrue);
        } finally {
          localManager.dispose();
        }
      },
    );

    test(
      'cancel halts the stream: chunks emitted after close are dropped',
      () async {
        // The default fake closes the chunk stream on cancel, exactly as
        // request.abort() stops the HTTP response stream.
        final outFile = File('${tempRoot.path}/closed_on_cancel.mp4');
        final task = buildTask(localFilePath: outFile.path);
        manager.seedHttpTaskForTesting(task);

        final downloadFuture = manager.downloadHttpFileForTesting(task);
        await pumpToAwaitFor();

        fake.emit([1, 2, 3, 4]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await manager.pauseTask(task.id);
        // Subsequent emits go into a closed controller and are dropped.
        fake.emit([99]);
        // The stream is already closed by cancel, so done is a no-op.
        fake.done();

        await downloadFuture;

        expect(task.status, DownloadTaskStatus.paused);
        expect(await outFile.readAsBytes(), [1, 2, 3, 4]);
        expect(fake.cancelCalled, isTrue);
      },
    );

    test(
      'removeTask drops a late chunk without closing the sink underneath it',
      () async {
        final lateChunkFake = FakeHttpFileDownloadPort(
          cancelClosesStream: false,
        );
        final localManager = DownloadManager.forTesting(
          httpPort: lateChunkFake,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        final outFile = File('${tempRoot.path}/remove_late_chunk.mp4');
        final task = buildTask(localFilePath: outFile.path);
        localManager.seedHttpTaskForTesting(task);

        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpToAwaitFor();
          lateChunkFake.emit([1, 2, 3]);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          await localManager.removeTask(task.id);
          // Simulate an already-buffered network chunk that arrives after the
          // manager removed the task. The job must discard it rather than write
          // to a sink that an external cancel path already closed.
          lateChunkFake.emit([4, 5, 6]);
          lateChunkFake.done();
          await downloadFuture;

          expect(localManager.tasks, isEmpty);
          expect(await outFile.readAsBytes(), [1, 2, 3]);
        } finally {
          localManager.dispose();
        }
      },
    );
  });

  group('DownloadManager HTTP mid-stream error', () {
    test('an error thrown after the first chunk surfaces as task error and '
        'partial bytes are flushed', () async {
      final outFile = File('${tempRoot.path}/miderror.mp4');
      final task = buildTask(localFilePath: outFile.path);
      manager.seedHttpTaskForTesting(task);

      final downloadFuture = manager.downloadHttpFileForTesting(task);
      await pumpToAwaitFor();

      fake.emit([100, 101]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      fake.emitError(StateError('network boom'));
      await downloadFuture;

      expect(task.status, DownloadTaskStatus.error);
      expect(task.errorMessage, isNotNull);
      expect(task.errorMessage!.toString(), contains('network boom'));
      // The sink.add for chunk A ran before the error; the file retains it.
      expect(await outFile.readAsBytes(), [100, 101]);
    });

    test(
      'an error while the cancel flag is set is treated as paused, not error',
      () async {
        final outFile = File('${tempRoot.path}/paused_error.mp4');
        final task = buildTask(localFilePath: outFile.path);

        final fakeNoClose = FakeHttpFileDownloadPort(
          contentLength: 12,
          cancelClosesStream: false,
        );
        final localManager = DownloadManager.forTesting(httpPort: fakeNoClose);
        localManager.setDownloadDirForTesting(tempRoot.path);
        localManager.seedHttpTaskForTesting(task);
        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await pumpToAwaitFor();

          fakeNoClose.emit([1, 2, 3]);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          await localManager.pauseTask(task.id);

          // Emit an error: the catch path sees the cancelled flag and treats
          // the error as a pause, not a real error.
          fakeNoClose.emitError(StateError('reactive abort noise'));
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.paused);
          expect(task.errorMessage, isNull);
          expect(await outFile.readAsBytes(), [1, 2, 3]);
        } finally {
          localManager.dispose();
        }
      },
    );
  });

  group('DownloadManager HTTP throttle (_throttleHttpChunk)', () {
    test('no delay when _downloadLimitMbps == 0 (unlimited)', () async {
      manager.setDownloadLimitMbpsForTesting(0);
      final sw = Stopwatch()..start();
      await manager.throttleHttpChunkForTesting(1024 * 1024);
      sw.stop();
      // The default unlimited path returns immediately; allow a generous
      // scheduler overhead budget but assert no deliberate sleep.
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('no delay when the chunk fits within the budget', () async {
      // 100 MB/s → 100*1024*1024 bytes per second budget; one KB chunk is
      // well inside it. Should not schedule a sleep delay here.
      manager.setDownloadLimitMbpsForTesting(100);
      final fakeOne = FakeHttpFileDownloadPort(cancelClosesStream: false);
      final localManager = DownloadManager.forTesting(httpPort: fakeOne);
      localManager.setDownloadDirForTesting(tempRoot.path);
      localManager.setDownloadLimitMbpsForTesting(100);
      try {
        final outFile = File('${tempRoot.path}/throttle_chunk.mp4');
        final task = buildTask(localFilePath: outFile.path);
        localManager.seedHttpTaskForTesting(task);

        final sw = Stopwatch()..start();
        final downloadFuture = localManager.downloadHttpFileForTesting(task);
        await pumpToAwaitFor();
        fakeOne.emit(List<int>.filled(1024, 1));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        fakeOne.done();
        await downloadFuture;
        sw.stop();
        expect(task.status, DownloadTaskStatus.completed);
        expect(sw.elapsedMilliseconds, lessThan(500));
        expect(outFile.lengthSync(), 1024);
      } finally {
        localManager.dispose();
      }
    });
  });

  group('DownloadManager HTTP throttle budget-exhaustion delay', () {
    // These cover the previously-untested `else if` branch of
    // `_throttleHttpChunk` — the budget-exhausted `await Future.delayed(...)`
    // path, plus the `elapsed >= 1000` new-window branch — by injecting a
    // controllable clock and a counting/no-op sleeper via
    // `DownloadManager.forTesting(clock:, sleep:)` so no wall-clock delay
    // runs and the elapsed math is deterministic.

    test(
      'sleeps exactly once when a chunk exhausts the per-second budget',
      () async {
        final sleepCalls = <Duration>[];
        var fakeNow = DateTime(2026, 7, 12, 0, 0, 0);
        DateTime clock() => fakeNow;
        Future<void> sleep(Duration d) {
          sleepCalls.add(d);
          // Advance the fake clock by the requested delay so the post-sleep
          // `_now()` reassigns the window start to the new window boundary.
          fakeNow = fakeNow.add(d);
          return Future<void>.value();
        }

        final localManager = DownloadManager.forTesting(
          httpPort: FakeHttpFileDownloadPort(),
          clock: clock,
          sleep: sleep,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        // 1 MB/s budget; a 2 MB chunk exhausts the window immediately.
        localManager.setDownloadLimitMbpsForTesting(1);
        try {
          await localManager.throttleHttpChunkForTesting(2 * 1024 * 1024);
          // Window started at construction (clock() == base), now == base, so
          // elapsed == 0 and remaining == 1000ms → exactly one sleep.
          expect(sleepCalls, [const Duration(milliseconds: 1000)]);
          // After the sleep the window + counter are reset; a within-budget
          // chunk must NOT sleep again.
          await localManager.throttleHttpChunkForTesting(512 * 1024);
          expect(sleepCalls.length, 1);
        } finally {
          localManager.dispose();
        }
      },
    );

    test(
      'does not sleep when the window has already elapsed >= 1000ms',
      () async {
        final sleepCalls = <Duration>[];
        var fakeNow = DateTime(2026, 7, 12, 0, 0, 0);
        DateTime clock() => fakeNow;
        Future<void> sleep(Duration d) {
          sleepCalls.add(d);
          fakeNow = fakeNow.add(d);
          return Future<void>.value();
        }

        final localManager = DownloadManager.forTesting(
          httpPort: FakeHttpFileDownloadPort(),
          clock: clock,
          sleep: sleep,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        localManager.setDownloadLimitMbpsForTesting(1);
        try {
          // Simulate a window that started 1.1s ago so the first chunk's
          // `elapsed >= 1000ms` branch resets the window and returns WITHOUT
          // sleeping (even though the chunk is 2x the budget).
          fakeNow = fakeNow.add(const Duration(milliseconds: 1100));
          await localManager.throttleHttpChunkForTesting(2 * 1024 * 1024);
          expect(sleepCalls, isEmpty);
          // The branch reset the window start to the current fakeNow; a
          // follow-up 2MB chunk now hits the exhausted branch and sleeps.
          await localManager.throttleHttpChunkForTesting(2 * 1024 * 1024);
          expect(sleepCalls, [const Duration(milliseconds: 1000)]);
        } finally {
          localManager.dispose();
        }
      },
    );

    test(
      'resetHttpThrottleForTesting pins the window start to the fake clock',
      () async {
        final sleepCalls = <Duration>[];
        var fakeNow = DateTime(2026, 7, 12, 0, 0, 5);
        DateTime clock() => fakeNow;
        Future<void> sleep(Duration d) {
          sleepCalls.add(d);
          fakeNow = fakeNow.add(d);
          return Future<void>.value();
        }

        final localManager = DownloadManager.forTesting(
          httpPort: FakeHttpFileDownloadPort(),
          clock: clock,
          sleep: sleep,
        );
        localManager.setDownloadDirForTesting(tempRoot.path);
        localManager.setDownloadLimitMbpsForTesting(1);
        try {
          // Constructor set _httpThrottleWindowStart = clock() == 00:00:05.
          // Advance fakeNow to 00:00:06 (1s later) would normally trip the
          // new-window branch. resetHttpThrottleForTesting re-pins the
          // window start to the advanced now so a 2MB chunk sleeps instead.
          fakeNow = fakeNow.add(const Duration(seconds: 1));
          localManager.resetHttpThrottleForTesting();
          await localManager.throttleHttpChunkForTesting(2 * 1024 * 1024);
          expect(sleepCalls, [const Duration(milliseconds: 1000)]);
        } finally {
          localManager.dispose();
        }
      },
    );
  });

  group('DownloadManager resumeTask HTTP path', () {
    test('resumeTask retains a partial MP4 and appends after a matching '
        '206 Range response', () async {
      final rangeFake = FakeHttpFileDownloadPort(
        contentLength: 3,
        statusCode: 206,
        contentRange: 'bytes 5-7/8',
      );
      final localManager = DownloadManager.forTesting(httpPort: rangeFake);
      localManager.setDownloadDirForTesting(tempRoot.path);
      final outFile = File('${tempRoot.path}/resume_partial.mp4')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3, 4, 5]);

      final task = buildTask(
        localFilePath: outFile.path,
        status: DownloadTaskStatus.paused,
      );
      localManager.seedHttpTaskForTesting(task);

      try {
        expect(await localManager.resumeTask(task.id), isTrue);
        // The existing bytes remain until the server has responded to the
        // resume request; no eager delete means an interrupted resume is
        // still recoverable.
        expect(await outFile.readAsBytes(), [1, 2, 3, 4, 5]);

        var waited = 0;
        while (rangeFake.startCallCount == 0 && waited < 2000) {
          await Future<void>.delayed(Duration.zero);
          waited++;
        }
        expect(rangeFake.startCallCount, 1);
        expect(rangeFake.lastHeaders?['Range'], 'bytes=5-');

        rangeFake
          ..emit([6, 7, 8])
          ..done();
        while (task.status != DownloadTaskStatus.completed &&
            task.status != DownloadTaskStatus.paused &&
            task.status != DownloadTaskStatus.error &&
            waited < 4000) {
          await Future<void>.delayed(Duration.zero);
          waited++;
        }
        expect(task.status, DownloadTaskStatus.completed);
        expect(task.totalSize, BigInt.from(8));
        expect(await outFile.readAsBytes(), [1, 2, 3, 4, 5, 6, 7, 8]);
      } finally {
        localManager.dispose();
      }
    });

    test(
      'a 200 response to a resume Range request safely restarts the file',
      () async {
        final fallbackFake = FakeHttpFileDownloadPort(contentLength: 3);
        final localManager = DownloadManager.forTesting(httpPort: fallbackFake);
        localManager.setDownloadDirForTesting(tempRoot.path);
        final outFile = File('${tempRoot.path}/resume_fallback.mp4')
          ..createSync(recursive: true)
          ..writeAsBytesSync([1, 2, 3]);
        final task = buildTask(
          localFilePath: outFile.path,
          status: DownloadTaskStatus.paused,
        );
        localManager.seedHttpTaskForTesting(task);

        try {
          expect(await localManager.resumeTask(task.id), isTrue);
          var waited = 0;
          while (fallbackFake.startCallCount == 0 && waited < 2000) {
            await Future<void>.delayed(Duration.zero);
            waited++;
          }
          expect(fallbackFake.lastHeaders?['Range'], 'bytes=3-');

          fallbackFake
            ..emit([9, 8, 7])
            ..done();
          while (task.status != DownloadTaskStatus.completed && waited < 4000) {
            await Future<void>.delayed(Duration.zero);
            waited++;
          }
          expect(task.status, DownloadTaskStatus.completed);
          expect(await outFile.readAsBytes(), [9, 8, 7]);
        } finally {
          localManager.dispose();
        }
      },
    );

    test(
      'resumeTask with no partial file on disk still restarts cleanly',
      () async {
        final outFile = File('${tempRoot.path}/never_downloaded.mp4');
        final task = buildTask(
          localFilePath: outFile.path,
          status: DownloadTaskStatus.paused,
        );
        manager.seedHttpTaskForTesting(task);

        expect(outFile.existsSync(), isFalse);

        final ok = await manager.resumeTask(task.id);
        expect(ok, isTrue);
        expect(outFile.existsSync(), isFalse);

        var waited = 0;
        while (fake.startCallCount == 0 && waited < 2000) {
          await Future<void>.delayed(Duration.zero);
          waited++;
        }
        expect(fake.startCallCount, 1);

        fake
          ..emit([200, 201])
          ..done();
        waited = 0;
        while (task.status != DownloadTaskStatus.completed &&
            task.status != DownloadTaskStatus.paused &&
            task.status != DownloadTaskStatus.error &&
            waited < 2000) {
          await Future<void>.delayed(Duration.zero);
          waited++;
        }
        expect(task.status, DownloadTaskStatus.completed);
        expect(await outFile.readAsBytes(), [200, 201]);
      },
    );
  });

  group('DownloadManager HTTP public-API invariants', () {
    test('factory DownloadManager() is still zero-arg and idempotent', () {
      expect(DownloadManager(), same(DownloadManager()));
    });
  });
}
