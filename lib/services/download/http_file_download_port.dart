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

  /// HTTP status returned by the server.  Plain downloads accept every 2xx
  /// response, while the job runner needs to distinguish a 206 response that
  /// honoured a resume Range request from a 200 response that ignored it.
  final int statusCode;

  /// Raw `Content-Range` response header, when supplied.  It lets the job
  /// verify that a 206 response starts at the byte offset it requested before
  /// appending to an existing partial file.
  final String? contentRange;

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
    this.statusCode = HttpStatus.ok,
    this.contentRange,
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
        statusCode: response.statusCode,
        contentRange: response.headers.value(HttpHeaders.contentRangeHeader),
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
    // Capture intentional Range before normalisation. Captured WebView
    // Range is stripped by the job / HLS callers; resume re-adds it on
    // purpose and must survive the hop-by-hop denylist.
    final intentionalRange = _findHeaderValue(headers, 'range');
    final effectiveHeaders = normalizeHttpRequestHeaders(
      headers,
      cookies: cookies,
    );
    if (intentionalRange != null) {
      effectiveHeaders['Range'] = intentionalRange;
    }
    for (final entry in effectiveHeaders.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }

  static String? _findHeaderValue(Map<String, String>? headers, String name) {
    if (headers == null) return null;
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.trim().toLowerCase() != target) continue;
      final value = entry.value.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}

/// Returns a copy of [headers] without any `Range` entry. Used by full-file
/// and HLS paths so a captured WebView partial request is never replayed.
Map<String, String>? headersWithoutHttpRange(Map<String, String>? headers) {
  if (headers == null) return null;
  final result = <String, String>{};
  for (final entry in headers.entries) {
    if (entry.key.trim().toLowerCase() == 'range') continue;
    result[entry.key] = entry.value;
  }
  return result;
}

/// Makes captured browser headers safe and deterministic for a new
/// [HttpClient] request.
///
/// Browser interception can expose the same semantic header under different
/// casing (`referer` + `Referer`, `userAgent` + `User-Agent`).  `HttpHeaders`
/// is case-insensitive, but applying an unnormalised map one item at a time
/// makes the winner depend on map order.  Cookies are additionally available
/// through the separately persisted [cookies] field; keep the cookie captured
/// from the actual media request as the primary value and add only missing
/// configured cookies behind it.
///
/// Captured WebView request headers often also include hop-by-hop fields,
/// conditional validators, Accept-Encoding, and internal extractor flags.
/// Replaying those on a fresh `dart:io` GET is a common reason a URL plays
/// (media_kit / proxy path does not forward the full capture) but the
/// download path returns HTTP 403. Drop those non-replayable headers here
/// so every download/probe client sees the same safe browser context.
Map<String, String> normalizeHttpRequestHeaders(
  Map<String, String>? headers, {
  String? cookies,
}) {
  final normalized = <String, String>{};
  String? mergedCookies;

  if (headers != null) {
    for (final entry in headers.entries) {
      final rawKey = entry.key.trim();
      final value = entry.value.trim();
      if (rawKey.isEmpty || value.isEmpty) continue;

      final key = _canonicalHttpHeaderName(rawKey);
      if (_shouldDropHttpRequestHeader(key)) continue;
      if (key == 'Cookie') {
        // Later entries are closer to the final captured request, so they
        // take precedence for duplicate cookie names.
        mergedCookies = mergeHttpCookieHeaders(value, mergedCookies);
      } else {
        normalized[key] = value;
      }
    }
  }

  mergedCookies = mergeHttpCookieHeaders(mergedCookies, cookies);
  if (mergedCookies != null && mergedCookies.isNotEmpty) {
    normalized['Cookie'] = mergedCookies;
  }
  return normalized;
}

/// Headers that must not be replayed onto a fresh download/probe request.
///
/// Kept as a pure helper so tests can pin the denylist without spinning up
/// an [HttpClient]. Names are already canonicalised by
/// [_canonicalHttpHeaderName] / compared case-insensitively.
bool _shouldDropHttpRequestHeader(String key) {
  final lower = key.toLowerCase();
  if (lower.startsWith('x-opencode-')) return true;
  if (lower.startsWith('sec-fetch-')) return true;
  if (lower.startsWith('sec-ch-')) return true;
  if (lower.startsWith('proxy-')) return true;
  return switch (lower) {
    'host' ||
    'connection' ||
    'keep-alive' ||
    'te' ||
    'trailer' ||
    'transfer-encoding' ||
    'upgrade' ||
    'content-length' ||
    'content-type' ||
    'accept-encoding' ||
    'if-match' ||
    'if-none-match' ||
    'if-modified-since' ||
    'if-unmodified-since' ||
    'if-range' ||
    // Drop captured WebView Range so full / HLS downloads request the whole
    // resource. Resume re-injects Range after normalisation via the port's
    // intentional-range path (job layer adds `Range: bytes=N-`).
    'range' => true,
    _ => false,
  };
}

/// Combines two request `Cookie` values without letting an older fallback
/// overwrite a cookie captured from the live video request.  The first value
/// wins for duplicate cookie names.
String? mergeHttpCookieHeaders(String? primary, String? fallback) {
  final values = <String>[];
  final seenNames = <String>{};

  void add(String? raw) {
    if (raw == null || raw.trim().isEmpty) return;
    for (final item in raw.split(';')) {
      final cookie = item.trim();
      if (cookie.isEmpty) continue;
      final separator = cookie.indexOf('=');
      if (separator <= 0) {
        values.add(cookie);
        continue;
      }
      final name = cookie.substring(0, separator).trim();
      if (name.isEmpty || !seenNames.add(name)) continue;
      values.add(cookie);
    }
  }

  add(primary);
  add(fallback);
  return values.isEmpty ? null : values.join('; ');
}

String _canonicalHttpHeaderName(String rawKey) {
  return switch (rawKey.toLowerCase()) {
    'useragent' || 'user-agent' => 'User-Agent',
    'referer' => 'Referer',
    'cookie' => 'Cookie',
    'origin' => 'Origin',
    'range' => 'Range',
    _ => rawKey,
  };
}
