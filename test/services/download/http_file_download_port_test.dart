// Tests for the `HttpFileDownloadPort` seam (Phase 3 Package B).
//
// These tests verify the handle + fake-port infrastructure used by the
// manager-side characterization tests. They do NOT instantiate a real
// `HttpClient`, a real socket, or platform channels — the fake port drives
// a `StreamController<List<int>>` so the manager's chunk loop can be
// exercised deterministically (the same fake is used by
// `download_manager_http_test.dart`).
//
// The production `IoHttpFileDownloadPort` is intentionally NOT exercised
// here because doing so would require a real network socket; its
// byte-for-byte wire behavior is preserved by the manager-side
// characterization tests asserting on the resulting `task.status` /
// `task.progress` / partial-file bytes via the fake port, and by reading
// the prod impl against the original inline code.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/http_file_download_port.dart';

/// Fake [HttpFileDownloadPort] used by both this file and the manager-side
/// characterization tests (`download_manager_http_test.dart`).
///
/// Captures the start parameters, lets the test push chunks / errors /
/// completion through a [StreamController], and tracks `cancel` / `close`
/// invocations so cancellation tests can assert the abort path ran.
class FakeHttpFileDownloadPort implements HttpFileDownloadPort {
  FakeHttpFileDownloadPort({
    this.contentLength = 12,
    this.startException,
    this.cancelClosesStream = true,
  });

  /// Value returned as the handle's `contentLength`. `null` mimics a missing
  /// Content-Length header (dart:io reports -1).
  final int? contentLength;

  /// When non-null, `start()` synchronously throws this object instead of
  /// producing a handle (used to characterise the non-2xx / connect-fail
  /// paths without a real `HttpClient`).
  final Object? startException;

  /// When true (the default), `cancel()` closes the underlying
  /// [StreamController] so the manager's `await for` exits promptly, mirroring
  /// the prod `request.abort()` that stops the HTTP response stream. Set to
  /// false for tests that want to keep pushing chunks after cancel.
  final bool cancelClosesStream;

  Uri? lastUrl;
  Map<String, String>? lastHeaders;
  String? lastCookies;
  int startCallCount = 0;
  bool cancelCalled = false;
  bool closeCalled = false;

  StreamController<List<int>>? _chunkController;

  @override
  Future<HttpFileDownloadHandle> start({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async {
    startCallCount++;
    lastUrl = url;
    lastHeaders = headers;
    lastCookies = cookies;
    if (startException != null) {
      throw startException!;
    }
    _chunkController = StreamController<List<int>>();
    return HttpFileDownloadHandle(
      chunks: _chunkController!.stream,
      contentLength: contentLength,
      cancel: () {
        cancelCalled = true;
        if (cancelClosesStream) {
          _chunkController?.close();
        }
      },
      close: () async {
        closeCalled = true;
      },
    );
  }

  void emit(List<int> chunk) {
    final controller = _chunkController;
    if (controller != null && !controller.isClosed) {
      controller.add(chunk);
    }
  }

  void emitError(Object error, [StackTrace? stack]) {
    final controller = _chunkController;
    if (controller != null && !controller.isClosed) {
      controller.addError(error, stack);
    }
  }

  void done() => _chunkController?.close();
}

void main() {
  group('HttpFileDownloadHandle', () {
    test('can be constructed with all required fields', () {
      final handle = HttpFileDownloadHandle(
        chunks: const Stream<List<int>>.empty(),
        contentLength: 42,
        cancel: () {},
        close: () async {},
      );
      expect(handle.contentLength, 42);
    });

    test(
      'accepts a null contentLength for chunked / unknown-length responses',
      () {
        final handle = HttpFileDownloadHandle(
          chunks: const Stream<List<int>>.empty(),
          contentLength: null,
          cancel: () {},
          close: () async {},
        );
        expect(handle.contentLength, isNull);
      },
    );
  });

  group('FakeHttpFileDownloadPort', () {
    test('start captures url, headers, and cookies in order', () async {
      final port = FakeHttpFileDownloadPort();
      await port.start(
        url: Uri.parse('https://example.com/a.mp4'),
        headers: {'Range': 'bytes=0-', 'User-Agent': 'mikan-test/1'},
        cookies: 'session=abcde',
      );

      expect(port.startCallCount, 1);
      expect(port.lastUrl, Uri.parse('https://example.com/a.mp4'));
      expect(port.lastHeaders, {
        'Range': 'bytes=0-',
        'User-Agent': 'mikan-test/1',
      });
      expect(port.lastCookies, 'session=abcde');
    });

    test('start rethrows startException without producing a handle', () {
      final port = FakeHttpFileDownloadPort(
        startException: Exception('HTTP 404'),
      );
      expect(
        () => port.start(
          url: Uri.parse('https://example.com/missing'),
          headers: null,
          cookies: null,
        ),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'toString',
            contains('HTTP 404'),
          ),
        ),
      );
      expect(port.startCallCount, 1);
    });

    test(
      'emitted chunks arrive in order on the handle.chunks stream',
      () async {
        final port = FakeHttpFileDownloadPort(contentLength: null);
        final handle = await port.start(
          url: Uri.parse('https://example.com/v'),
        );
        final collector = <List<int>>[];
        final done = Completer<void>();
        final sub = handle.chunks.listen(
          collector.add,
          onDone: () => done.complete(),
        );
        port
          ..emit([1, 2, 3])
          ..emit([4, 5])
          ..emit([6])
          ..done();
        await done.future;
        await sub.cancel();
        expect(collector, [
          [1, 2, 3],
          [4, 5],
          [6],
        ]);
      },
    );

    test('cancel closes the underlying stream so the consumer stops', () async {
      final port = FakeHttpFileDownloadPort();
      final handle = await port.start(url: Uri.parse('https://example.com/v'));
      final collector = <List<int>>[];
      final done = Completer<void>();
      handle.chunks.listen(collector.add, onDone: done.complete);
      port.emit([1, 2]);
      await Future<void>.delayed(Duration.zero);
      handle.cancel();
      expect(port.cancelCalled, isTrue);
      // closing the controller means a subsequent emit is dropped
      port.emit([3, 4]);
      if (!done.isCompleted) {
        await done.future;
      }
      expect(collector, [
        [1, 2],
      ]);
    });

    test('emitError surfaces the error on the chunks stream', () async {
      final port = FakeHttpFileDownloadPort();
      final handle = await port.start(url: Uri.parse('https://example.com/v'));
      Object? caught;
      final sub = handle.chunks.listen(
        (_) {},
        onError: (Object e) => caught = e,
      );
      port.emitError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(caught, isA<StateError>());
    });

    test('close marks closeCalled and does not throw', () async {
      final port = FakeHttpFileDownloadPort();
      final handle = await port.start(url: Uri.parse('https://example.com/v'));
      await handle.close();
      expect(port.closeCalled, isTrue);
    });
  });
}
