// HTTP file-download job orchestration (Phase 3).
//
// Owns the byte loop for a single plain-HTTP download: open the injected
// [HttpFileDownloadPort], write chunks to a file IOSink, throttle, progress
// ticks, and map cancel / error / success onto a small result type.
//
// [DownloadManager] still owns slots, task-map membership, persistence,
// notifyListeners, and the active-job registry used by pause/remove.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/http_file_download_port.dart';

/// Tracks an in-flight HTTP (or HLS-segment) write so pause/remove can abort.
class ActiveHttpDownload {
  final HttpFileDownloadHandle? handle;
  final File outputFile;
  final IOSink sink;
  bool cancelled = false;

  ActiveHttpDownload({
    this.handle,
    required this.outputFile,
    required this.sink,
  });

  void cancel() {
    cancelled = true;
    handle?.cancel();
    // The download coroutine is the sole owner of the IOSink. Closing it
    // here races a chunk that has already passed the cancellation check and
    // caused the `Bad state: StreamSink is closed` failure seen on remove.
    // Aborting the HTTP handle makes the loop exit; its `finally` closes and
    // flushes the sink exactly once.
  }
}

enum HttpDownloadJobOutcome { completed, paused, error, removed }

class HttpDownloadJobResult {
  final HttpDownloadJobOutcome outcome;
  final String? errorMessage;

  const HttpDownloadJobResult(this.outcome, {this.errorMessage});
}

/// Runs the plain-HTTP file download body for [task].
///
/// [isCancelled] is checked each chunk (and after the stream ends) so the
/// manager's active-job cancel flag is honored. [registerJob] / [clearJob]
/// let the manager publish the [ActiveHttpDownload] for pause/remove.
/// [onProgress] is invoked on the 500ms progress tick and after completion
/// paths that need a UI refresh from the manager.
Future<HttpDownloadJobResult> runHttpFileDownload({
  required DownloadTask task,
  required HttpFileDownloadPort httpPort,
  required Future<void> Function(int chunkBytes) throttle,
  required bool Function() isCancelled,
  required void Function(ActiveHttpDownload job) registerJob,
  required void Function() clearJob,
  required void Function() onProgress,
  required bool Function() isTaskStillTracked,
}) async {
  final url = task.videoUrl;
  if (url == null) {
    return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
  }

  final outputFile = File(task.localFilePath!);
  IOSink? sink;
  HttpFileDownloadHandle? handle;
  var wasCancelled = false;
  var wasRemoved = false;

  try {
    if (!isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }

    final uri = Uri.parse(url);
    var existingBytes = 0;
    if (outputFile.existsSync()) {
      try {
        existingBytes = outputFile.lengthSync();
      } catch (_) {}
    }

    handle = await httpPort.start(
      url: uri,
      headers: _headersForHttpDownload(task.headers, resumeFrom: existingBytes),
      cookies: task.cookies,
    );

    // A pause/remove can happen while the asynchronous HTTP connection is
    // opening, before an ActiveHttpDownload is registered for cancellation.
    // Membership and generation are the durable guards in that window.
    if (!isTaskStillTracked()) {
      handle.cancel();
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }
    if (isCancelled()) {
      handle.cancel();
      return _cancelledHttpDownloadResult(task);
    }

    final append =
        existingBytes > 0 &&
        _isMatchingPartialResponse(handle, expectedStart: existingBytes);
    if (existingBytes > 0 && !append) {
      // A server that ignores Range returns 200 with the entire resource.
      // Start cleanly in that case: blindly appending would corrupt the file.
      debugPrint(
        '[DownloadManager] HTTP server did not honour resume range '
        '(status=${handle.statusCode}, content-range=${handle.contentRange}); '
        'restarting ${task.name}',
      );
      existingBytes = 0;
      task.downloaded = BigInt.zero;
      task.totalSize = BigInt.zero;
      task.progress = 0.0;
    }

    sink = outputFile.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    registerJob(
      ActiveHttpDownload(handle: handle, outputFile: outputFile, sink: sink),
    );

    final contentLength = handle.contentLength;
    final totalLength =
        _totalLengthFromContentRange(handle.contentRange) ??
        (contentLength != null && contentLength > 0
            ? existingBytes + contentLength
            : null);
    if (totalLength != null && totalLength > 0) {
      task.totalSize = BigInt.from(totalLength);
    }

    var received = existingBytes;
    task.downloaded = BigInt.from(received);
    if (totalLength != null && totalLength > 0) {
      task.progress = (received / totalLength * 100.0).clamp(0.0, 100.0);
    }
    var lastReceived = received;
    var lastUpdate = DateTime.now();

    await for (final chunk in handle.chunks) {
      if (!isTaskStillTracked()) {
        wasRemoved = true;
        handle.cancel();
        break;
      }
      if (isCancelled()) {
        wasCancelled = true;
        break;
      }
      sink.add(chunk);
      received += chunk.length;
      task.downloaded = BigInt.from(received);
      await throttle(chunk.length);

      final now = DateTime.now();
      if (now.difference(lastUpdate).inMilliseconds >= 500) {
        final elapsed = now.difference(lastUpdate).inMilliseconds / 1000.0;
        if (elapsed > 0) {
          final bytesSince = received - lastReceived;
          task.downloadSpeed = bytesSince / elapsed;
        }
        if (totalLength != null && totalLength > 0) {
          task.progress = (received / totalLength * 100.0).clamp(0.0, 100.0);
        } else {
          task.progress = 0.0;
        }
        lastUpdate = now;
        lastReceived = received;
        onProgress();
      }
    }

    await sink.close();
    sink = null;

    if (wasRemoved || !isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }

    if (isCancelled() || wasCancelled) {
      return _cancelledHttpDownloadResult(task);
    }

    task.status = DownloadTaskStatus.completed;
    task.progress = 100.0;
    task.downloadSpeed = 0;
    try {
      final fileLen = outputFile.lengthSync();
      task.downloaded = BigInt.from(fileLen);
      if (totalLength == null || totalLength <= 0) {
        task.totalSize = BigInt.from(fileLen);
      }
    } catch (_) {}
    debugPrint('[DownloadManager] HTTP download completed: ${task.name}');
    return const HttpDownloadJobResult(HttpDownloadJobOutcome.completed);
  } catch (e) {
    if (!isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }
    if (isCancelled()) {
      return _cancelledHttpDownloadResult(task);
    }
    debugPrint('[DownloadManager] HTTP download error: $e');
    task.status = DownloadTaskStatus.error;
    task.errorMessage = e.toString();
    return HttpDownloadJobResult(
      HttpDownloadJobOutcome.error,
      errorMessage: e.toString(),
    );
  } finally {
    final openSink = sink;
    if (openSink != null) {
      try {
        await openSink.close();
      } catch (_) {}
    }
    clearJob();
    await handle?.close();
  }
}

HttpDownloadJobResult _cancelledHttpDownloadResult(DownloadTask task) {
  // A newer generation may already have changed the status back to
  // downloading. Its predecessor must not turn the resumed task back into a
  // paused one while it unwinds.
  if (task.status == DownloadTaskStatus.downloading ||
      task.status == DownloadTaskStatus.queued) {
    return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
  }
  task.status = DownloadTaskStatus.paused;
  task.downloadSpeed = 0;
  task.uploadSpeed = 0;
  debugPrint('[DownloadManager] HTTP download paused (partial): ${task.name}');
  return const HttpDownloadJobResult(HttpDownloadJobOutcome.paused);
}

Map<String, String>? _headersForHttpDownload(
  Map<String, String>? headers, {
  required int resumeFrom,
}) {
  if (resumeFrom <= 0) return headers;
  final result = <String, String>{...?headers};
  result.removeWhere((key, _) => key.trim().toLowerCase() == 'range');
  result['Range'] = 'bytes=$resumeFrom-';
  return result;
}

bool _isMatchingPartialResponse(
  HttpFileDownloadHandle handle, {
  required int expectedStart,
}) {
  if (handle.statusCode != HttpStatus.partialContent) return false;
  final value = handle.contentRange?.trim();
  if (value == null || value.isEmpty) {
    // The status code is enough for older/non-standard servers. Production
    // HttpClient exposes Content-Range when one is present, so normal servers
    // still receive the stricter start-offset check below.
    return true;
  }
  final match = RegExp(
    r'^bytes\s+(\d+)-\d+/(?:\d+|\*)$',
    caseSensitive: false,
  ).firstMatch(value);
  return match != null && int.tryParse(match.group(1)!) == expectedStart;
}

int? _totalLengthFromContentRange(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^bytes\s+\d+-\d+/(\d+)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}
