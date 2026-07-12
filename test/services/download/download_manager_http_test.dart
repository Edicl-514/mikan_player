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
        final localManager = DownloadManager.forTesting(httpPort: port500);
        localManager.setDownloadDirForTesting(tempRoot.path);
        localManager.seedHttpTaskForTesting(task);
        try {
          final downloadFuture = localManager.downloadHttpFileForTesting(task);
          await downloadFuture;

          expect(task.status, DownloadTaskStatus.error);
          expect(task.errorMessage, contains('500'));
          expect(outFile.existsSync(), isFalse);
        } finally {
          localManager.dispose();
        }
      },
    );
  });

  group('DownloadManager HTTP headers + cookies', () {
    test('start receives the task headers and cookies verbatim', () async {
      final outFile = File('${tempRoot.path}/with_headers.mp4');
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
      expect(fake.lastHeaders, headers);
      expect(fake.lastCookies, 'session=abc-123; token=xyz');

      fake.done();
      await downloadFuture;
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

  group('DownloadManager resumeTask HTTP path', () {
    test(
      'resumeTask deletes an existing partial file BEFORE restarting '
      '(_downloadHttpFile restarts from scratch with NO Range request)',
      () async {
        final outFile = File('${tempRoot.path}/resume_partial.mp4')
          ..createSync(recursive: true)
          ..writeAsBytesSync([1, 2, 3, 4, 5]);

        final task = buildTask(
          localFilePath: outFile.path,
          // Task is paused: resumeTask's HTTP branch deletes the partial
          // file (no Range request), resets state, and unawaited()s a fresh
          // _downloadHttpFile.
          status: DownloadTaskStatus.paused,
        );
        manager.seedHttpTaskForTesting(task);

        expect(outFile.existsSync(), isTrue);

        final ok = await manager.resumeTask(task.id);
        expect(ok, isTrue);
        // The partial file must be GONE immediately after resumeTask —
        // the branch calls file.deleteSync() before _downloadHttpFile.
        expect(outFile.existsSync(), isFalse);

        // resumeTask reset the state before the restart.
        expect(task.progress, 0.0);
        expect(task.downloaded, BigInt.zero);
        expect(task.errorMessage, isNull);

        // Drive the background restart: pump until the fake's start() runs.
        var waited = 0;
        while (fake.startCallCount == 0 && waited < 2000) {
          await Future<void>.delayed(Duration.zero);
          waited++;
        }
        expect(fake.startCallCount, 1);
        // No Range header was sent: resumeTask does NOT ask the port to add
        // `Range: bytes=`, so headers fall back to whatever the task had on
        // it (none here). The header capture confirms the absence.
        expect(fake.lastHeaders, isNull);

        // Close the stream so the manager's _downloadHttpFile can finish
        // (empty stream → completed status; file recreated empty).
        fake.done();
        waited = 0;
        while (task.status != DownloadTaskStatus.completed &&
            task.status != DownloadTaskStatus.paused &&
            task.status != DownloadTaskStatus.error &&
            waited < 2000) {
          await Future<void>.delayed(Duration.zero);
          waited++;
        }
        expect(task.status, DownloadTaskStatus.completed);
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
