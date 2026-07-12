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
    try {
      sink.close();
    } catch (_) {}
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

  try {
    final uri = Uri.parse(url);
    handle = await httpPort.start(
      url: uri,
      headers: task.headers,
      cookies: task.cookies,
    );

    sink = outputFile.openWrite();
    registerJob(
      ActiveHttpDownload(handle: handle, outputFile: outputFile, sink: sink),
    );

    final contentLength = handle.contentLength;
    if (contentLength != null && contentLength > 0) {
      task.totalSize = BigInt.from(contentLength);
    }

    var received = 0;
    var lastReceived = 0;
    var lastUpdate = DateTime.now();

    await for (final chunk in handle.chunks) {
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
        if (contentLength != null && contentLength > 0) {
          task.progress = (received / contentLength * 100.0).clamp(0.0, 100.0);
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

    if (isCancelled() || wasCancelled) {
      task.status = DownloadTaskStatus.paused;
      task.downloadSpeed = 0;
      task.uploadSpeed = 0;
      debugPrint(
        '[DownloadManager] HTTP download paused (partial): ${task.name}',
      );
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.paused);
    }

    task.status = DownloadTaskStatus.completed;
    task.progress = 100.0;
    task.downloadSpeed = 0;
    if (contentLength == null || contentLength <= 0) {
      try {
        final fileLen = outputFile.lengthSync();
        task.totalSize = BigInt.from(fileLen);
      } catch (_) {}
    }
    debugPrint('[DownloadManager] HTTP download completed: ${task.name}');
    return const HttpDownloadJobResult(HttpDownloadJobOutcome.completed);
  } catch (e) {
    debugPrint('[DownloadManager] HTTP download error: $e');
    if (!isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }
    if (isCancelled()) {
      task.status = DownloadTaskStatus.paused;
      task.downloadSpeed = 0;
      task.uploadSpeed = 0;
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.paused);
    }
    task.status = DownloadTaskStatus.error;
    task.errorMessage = e.toString();
    try {
      sink?.close();
    } catch (_) {}
    return HttpDownloadJobResult(
      HttpDownloadJobOutcome.error,
      errorMessage: e.toString(),
    );
  } finally {
    clearJob();
    await handle?.close();
  }
}
