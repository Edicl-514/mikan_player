// m3u8 / HLS playlist resolution + segment download (Phase 3).
//
// Playlist text is fetched via [M3u8PlaylistPort] and parsed by
// [parseM3u8Playlist]. Per-segment bytes go through [HttpFileDownloadPort]
// (same seam as plain HTTP files). [DownloadManager] still owns slots,
// persistence, notifyListeners, and the active-job cancel registry.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/http_download_job.dart';
import 'package:mikan_player/services/download/http_file_download_port.dart';
import 'package:mikan_player/services/download/m3u8_playlist_port.dart';

/// Resolves a (possibly nested master) playlist into ordered segment URIs.
///
/// Recurses into the highest-BANDWIDTH master variant. Throws when
/// `depth > 4`, when the parser rejects encryption / empty media, or when
/// the port fetch fails.
Future<List<Uri>> resolveHlsSegments({
  required M3u8PlaylistPort m3u8Port,
  required Uri playlistUri,
  Map<String, String>? headers,
  String? cookies,
  int depth = 0,
}) async {
  if (depth > 4) {
    throw Exception('m3u8层级过深，无法解析');
  }

  final content = await m3u8Port.fetchText(
    url: playlistUri,
    headers: headers,
    cookies: cookies,
  );
  final parsed = parseM3u8Playlist(content, playlistUri);

  if (parsed is M3u8MasterPlaylist) {
    return resolveHlsSegments(
      m3u8Port: m3u8Port,
      playlistUri: parsed.variants.first.uri,
      headers: headers,
      cookies: cookies,
      depth: depth + 1,
    );
  }

  return (parsed as M3u8MediaPlaylist).segments;
}

/// Downloads every HLS segment into [task.localFilePath], concatenating
/// bytes in playlist order. Supports pause/resume by appending to an
/// existing partial file and skipping completed segment indices.
Future<HttpDownloadJobResult> runM3u8Download({
  required DownloadTask task,
  required M3u8PlaylistPort m3u8Port,
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
  var wasCancelled = false;
  var wasRemoved = false;

  try {
    final playlistUri = Uri.parse(url);
    final segments = await resolveHlsSegments(
      m3u8Port: m3u8Port,
      playlistUri: playlistUri,
      headers: task.headers,
      cookies: task.cookies,
    );

    if (!isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }

    final segmentCount = segments.length;
    if (segmentCount == 0) {
      throw Exception('未找到可下载的HLS分片');
    }

    var startSegmentIndex = 0;
    var received = 0;
    if (outputFile.existsSync()) {
      final existingLen = outputFile.lengthSync();
      if (existingLen > 0) {
        // Prefer the explicit completed-segment counter over percent math so
        // resume is stable even when progress was only a 500ms UI tick.
        if (task.hlsCompletedSegmentCount != null) {
          startSegmentIndex = task.hlsCompletedSegmentCount!.clamp(
            0,
            segmentCount,
          );
        } else {
          startSegmentIndex = _estimateHlsResumeSegmentIndex(
            task.progress,
            segmentCount,
          );
        }

        // Truncate any incomplete final segment left by a mid-segment pause.
        final checkpoint =
            task.hlsCheckpointBytes ??
            (startSegmentIndex > 0 ? existingLen : 0);
        if (checkpoint >= 0 && checkpoint < existingLen) {
          final raf = await outputFile.open(mode: FileMode.write);
          try {
            await raf.truncate(checkpoint);
          } finally {
            await raf.close();
          }
          received = checkpoint;
        } else {
          received = existingLen;
        }
        task.downloaded = BigInt.from(received);
        task.hlsCheckpointBytes = received;
      }
    }

    task.hlsSegmentCount = segmentCount;
    task.hlsCompletedSegmentCount = startSegmentIndex.clamp(0, segmentCount);
    task.hlsCheckpointBytes ??= received;
    task.totalSize = BigInt.zero;
    task.progress = segmentCount > 0
        ? (task.hlsCompletedSegmentCount! / segmentCount * 100.0).clamp(
            0.0,
            100.0,
          )
        : 0.0;

    sink = outputFile.openWrite(mode: FileMode.append);
    var lastReceived = received;
    var finishedSegments = task.hlsCompletedSegmentCount!;
    var lastUpdate = DateTime.now();

    for (var i = startSegmentIndex; i < segmentCount; i++) {
      final segmentUri = segments[i];
      if (!isTaskStillTracked()) {
        wasRemoved = true;
        break;
      }
      if (isCancelled()) {
        wasCancelled = true;
        break;
      }

      final handle = await httpPort.start(
        url: segmentUri,
        headers: task.headers,
        cookies: task.cookies,
      );

      if (!isTaskStillTracked()) {
        wasRemoved = true;
        handle.cancel();
        await handle.close();
        break;
      }
      if (isCancelled()) {
        wasCancelled = true;
        handle.cancel();
        await handle.close();
        break;
      }

      registerJob(
        ActiveHttpDownload(handle: handle, outputFile: outputFile, sink: sink),
      );

      try {
        await for (final chunk in handle.chunks) {
          if (!isTaskStillTracked()) {
            wasRemoved = true;
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
            task.progress = (finishedSegments / segmentCount * 100.0).clamp(
              0.0,
              100.0,
            );
            lastUpdate = now;
            lastReceived = received;
            onProgress();
          }
        }
      } finally {
        await handle.close();
        clearJob();
      }

      if (wasRemoved || wasCancelled) {
        break;
      }

      finishedSegments += 1;
      task.hlsCompletedSegmentCount = finishedSegments;
      task.hlsCheckpointBytes = received;
      task.progress = (finishedSegments / segmentCount * 100.0).clamp(
        0.0,
        100.0,
      );
      onProgress();
    }

    await sink.close();
    sink = null;

    if (wasRemoved || !isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }

    if (isCancelled() || wasCancelled) {
      // If the user already resumed (status flipped back to downloading), a
      // late pause exit from the previous run must not re-pause the task.
      if (task.status == DownloadTaskStatus.downloading ||
          task.status == DownloadTaskStatus.queued) {
        return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
      }
      task.status = DownloadTaskStatus.paused;
      task.downloadSpeed = 0;
      task.uploadSpeed = 0;
      debugPrint(
        '[DownloadManager] HLS download paused (partial): ${task.name}',
      );
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.paused);
    }

    task.status = DownloadTaskStatus.completed;
    task.progress = 100.0;
    task.hlsCompletedSegmentCount = segmentCount;
    task.downloadSpeed = 0;
    try {
      final fileLen = outputFile.lengthSync();
      task.downloaded = BigInt.from(fileLen);
    } catch (_) {}
    debugPrint('[DownloadManager] HLS download completed: ${task.name}');
    return const HttpDownloadJobResult(HttpDownloadJobOutcome.completed);
  } catch (e) {
    debugPrint('[DownloadManager] HLS download error: $e');
    if (!isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }
    if (isCancelled()) {
      if (task.status == DownloadTaskStatus.downloading ||
          task.status == DownloadTaskStatus.queued) {
        return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
      }
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
  }
}

/// Maps persisted segment progress to the next segment index to download.
@visibleForTesting
int estimateHlsResumeSegmentIndex(double progressPercent, int segmentCount) {
  return _estimateHlsResumeSegmentIndex(progressPercent, segmentCount);
}

int _estimateHlsResumeSegmentIndex(double progressPercent, int segmentCount) {
  if (segmentCount <= 0) return 0;
  if (progressPercent >= 100.0) return segmentCount;
  final completed = (progressPercent / 100.0 * segmentCount).floor();
  return completed.clamp(0, segmentCount);
}
