// Injectable HTTP file-download seam (Phase 3 Package B).
//
// The production [DownloadManager] owns the download lifecycle (status
// transitions, throttle, notifyListeners, saveTasks, the cancel-flag check
// inside the chunk loop, and the file IOSink). This port owns ONLY the
// `dart:io` HttpClient lifecycle: opening the GET request, applying
// headers/cookies, the 2xx status check, exposing the response body as a
// chunk stream, aborting the request on cancel, and closing the client on
// completion.
//
// The manager writes chunks to its own file IOSink after the cancel-flag
// check, so the byte-for-byte behavior of the original inline code is
// preserved: a chunk pulled from the stream that hits a `cancelled` flag is
// discarded (not written), exactly as the pre-extraction `await for` body
// did.
//
// Production behavior is unchanged: `factory DownloadManager()` still
// constructs the singleton with the [IoHttpFileDownloadPort] default, so
// every existing call site keeps working with zero arguments.

import 'dart:async';
import 'dart:io';

/// Injectable seam for the HTTP file-download path of [DownloadManager].
///
/// The handle returned by [start] exposes the response body as a stream of
/// byte chunks plus a [cancel] callback that aborts the underlying request
/// and a [close] callback that releases the HttpClient. The caller writes
/// chunks to its own file IOSink and owns the per-chunk state updates
/// (received byte count, throttle, progress, speed).
abstract interface class HttpFileDownloadPort {
  /// Opens an HTTP GET to [url], applies [headers] and [cookies], validates
  /// the status code, and returns a handle to the response body stream.
  ///
  /// Throws `Exception('HTTP <statusCode>')` for non-2xx responses, matching
  /// the original inline behavior of `_downloadHttpFile`.
  Future<HttpFileDownloadHandle> start({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  });
}

/// Handle to an active HTTP file-download response.
///
/// The caller iterates [chunks], writes each chunk to its own file IOSink,
/// and per-chunk updates its download state. [cancel] aborts the underlying
/// HTTP request; [close] releases the HttpClient.
class HttpFileDownloadHandle {
  /// Response body as a stream of byte chunks.
  final Stream<List<int>> chunks;

  /// Response Content-Length, or `null` when the header is missing /
  /// unknown (dart:io reports `-1`; this port reports `null` so the caller
  /// checks `contentLength != null && contentLength > 0` instead of
  /// `contentLength > 0`).
  final int? contentLength;

  /// Aborts the underlying HTTP request. Idempotent; never throws. The
  /// manager also sets its own `cancelled` bool on the `_HttpDownloadJob`
  /// and the chunk-loop break is driven by that bool; this call stops the
  /// stream so the `await for` exits promptly.
  final void Function() cancel;

  /// Releases the HttpClient. Idempotent; never throws. Called from the
  /// manager's `finally` block (replacing the original `client.close()`).
  final Future<void> Function() close;

  const HttpFileDownloadHandle({
    required this.chunks,
    required this.contentLength,
    required this.cancel,
    required this.close,
  });
}

/// Production [HttpFileDownloadPort] backed by `dart:io.HttpClient`.
///
/// Replicates the original inline HTTP-download wiring byte-for-byte:
/// `client.getUrl(uri)` → header/cookie application → `request.close()` →
/// non-2xx throw → expose `response` as the chunk stream → `cancel` calls
/// `request.abort()` → `close` calls `client.close()`. On a thrown start
/// (e.g. non-2xx, connection failure) the client is closed before the
/// exception propagates.
class IoHttpFileDownloadPort implements HttpFileDownloadPort {
  @override
  Future<HttpFileDownloadHandle> start({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async {
    final client = HttpClient();
    HttpClientRequest? request;
    try {
      request = await client.getUrl(url);
      _applyHeaders(request, headers, cookies);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final cl = response.contentLength;
      return HttpFileDownloadHandle(
        chunks: response,
        contentLength: cl >= 0 ? cl : null,
        cancel: () {
          try {
            request?.abort();
          } catch (_) {}
        },
        close: () async {
          try {
            client.close();
          } catch (_) {}
        },
      );
    } catch (e) {
      try {
        client.close();
      } catch (_) {}
      rethrow;
    }
  }

  static void _applyHeaders(
    HttpClientRequest request,
    Map<String, String>? headers,
    String? cookies,
  ) {
    if (headers != null) {
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }
    if (cookies != null && cookies.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookies);
    }
  }
}
