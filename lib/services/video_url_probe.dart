import 'dart:async';
import 'dart:convert';
import 'dart:io';

class VideoUrlProbeResult {
  final bool playable;
  final int? statusCode;
  final String? contentType;
  final String? error;
  final Duration latency;

  const VideoUrlProbeResult({
    required this.playable,
    this.statusCode,
    this.contentType,
    this.error,
    required this.latency,
  });
}

class VideoUrlProbeService {
  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  static const int _maxProbeBytes = 2048;

  Future<VideoUrlProbeResult> probe(
    String url, {
    Map<String, String> headers = const {},
    String? cookies,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final stopwatch = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final mergedHeaders = <String, String>{
        'User-Agent': _defaultUserAgent,
        'Range': 'bytes=0-1023',
        ...headers,
      };
      if (cookies != null && cookies.trim().isNotEmpty) {
        mergedHeaders.putIfAbsent('Cookie', () => cookies.trim());
      }
      mergedHeaders.forEach(request.headers.set);

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final contentType =
          response.headers.contentType?.mimeType ??
          response.headers.value(HttpHeaders.contentTypeHeader);
      final bytes = await _readProbeBytes(response, timeout);
      stopwatch.stop();

      if (statusCode >= 400) {
        return VideoUrlProbeResult(
          playable: false,
          statusCode: statusCode,
          contentType: contentType,
          error: 'HTTP $statusCode',
          latency: stopwatch.elapsed,
        );
      }

      final body = utf8.decode(bytes, allowMalformed: true);
      final lowerContentType = (contentType ?? '').toLowerCase();
      final lowerBody = body.toLowerCase();
      final hasSuccessStatus =
          statusCode == HttpStatus.ok ||
          statusCode == HttpStatus.partialContent;

      if (_looksLikeHtmlError(lowerContentType, lowerBody)) {
        return VideoUrlProbeResult(
          playable: false,
          statusCode: statusCode,
          contentType: contentType,
          error: 'Returned an HTML error page',
          latency: stopwatch.elapsed,
        );
      }

      if (_isObviousNonMedia(lowerContentType)) {
        return VideoUrlProbeResult(
          playable: false,
          statusCode: statusCode,
          contentType: contentType,
          error: 'Returned a non-media response',
          latency: stopwatch.elapsed,
        );
      }

      final looksLikePlaylist =
          body.contains('#EXTM3U') || body.contains('#EXT-X-STREAM-INF');
      final looksLikeMedia =
          lowerContentType.startsWith('video/') ||
          lowerContentType.contains('mpegurl') ||
          lowerContentType.contains('vnd.apple.mpegurl') ||
          looksLikePlaylist;

      final playable =
          hasSuccessStatus &&
          (looksLikeMedia || !_looksClearlyTextResponse(lowerContentType));
      return VideoUrlProbeResult(
        playable: playable,
        statusCode: statusCode,
        contentType: contentType,
        error: playable ? null : 'Response did not look playable',
        latency: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      return VideoUrlProbeResult(
        playable: false,
        error: 'Probe timed out',
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return VideoUrlProbeResult(
        playable: false,
        error: e.toString(),
        latency: stopwatch.elapsed,
      );
    } finally {
      client.close(force: true);
    }
  }

  bool _looksLikeHtmlError(String contentType, String body) {
    if (!contentType.contains('html')) {
      return false;
    }
    return body.contains('<html') ||
        body.contains('access denied') ||
        body.contains('forbidden') ||
        body.contains('captcha') ||
        body.contains('404') ||
        body.contains('403');
  }

  bool _isObviousNonMedia(String contentType) {
    return contentType.startsWith('image/') ||
        contentType.startsWith('text/css') ||
        contentType.contains('javascript') ||
        contentType.contains('ecmascript') ||
        contentType.startsWith('font/');
  }

  bool _looksClearlyTextResponse(String contentType) {
    return contentType.startsWith('text/') || contentType.contains('json');
  }

  Future<List<int>> _readProbeBytes(
    HttpClientResponse response,
    Duration timeout,
  ) async {
    final completer = Completer<List<int>>();
    final buffer = <int>[];
    StreamSubscription<List<int>>? subscription;
    Timer? timer;

    void completeIfNeeded(List<int> result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    void failIfNeeded(Object error, [StackTrace? stackTrace]) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }

    timer = Timer(timeout, () {
      failIfNeeded(TimeoutException('Probe body read timed out', timeout));
      subscription?.cancel();
    });

    subscription = response.listen(
      (chunk) {
        final remaining = _maxProbeBytes - buffer.length;
        if (remaining <= 0) {
          completeIfNeeded(buffer);
          timer?.cancel();
          subscription?.cancel();
          return;
        }

        if (chunk.length <= remaining) {
          buffer.addAll(chunk);
        } else {
          buffer.addAll(chunk.take(remaining));
        }

        if (buffer.length >= _maxProbeBytes) {
          completeIfNeeded(buffer);
          timer?.cancel();
          subscription?.cancel();
        }
      },
      onDone: () {
        timer?.cancel();
        completeIfNeeded(buffer);
      },
      onError: (Object error, StackTrace stackTrace) {
        timer?.cancel();
        failIfNeeded(error, stackTrace);
      },
      cancelOnError: true,
    );

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }
}
