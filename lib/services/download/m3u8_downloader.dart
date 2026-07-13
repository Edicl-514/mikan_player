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
/// bytes in playlist order.
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

    // Resolving a playlist can take long enough for the manager to remove
    // this task. Do not create (or resume writing) the output file afterward.
    if (!isTaskStillTracked()) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }

    sink = outputFile.openWrite();
    task.totalSize = BigInt.zero;

    var received = 0;
    var lastReceived = 0;
    var finishedSegments = 0;
    var lastUpdate = DateTime.now();

    for (final segmentUri in segments) {
      // The active-job registration is intentionally cleared after every
      // segment. A remove can therefore happen between segments, after its
      // cancel flag has been discarded. Task membership is the durable signal
      // that prevents a later segment from being requested or written.
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

      // `start` is asynchronous. The task may have been removed (or paused)
      // while a segment connection was being opened, before a job could be
      // registered for manager-side cancellation.
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
        final contentLength = handle.contentLength;
        if (contentLength != null && contentLength > 0) {
          task.totalSize += BigInt.from(contentLength);
        }

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
            task.progress = (finishedSegments / segments.length * 100.0).clamp(
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
      task.progress = (finishedSegments / segments.length * 100.0).clamp(
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
    task.downloadSpeed = 0;
    try {
      final fileLen = outputFile.lengthSync();
      task.totalSize = BigInt.from(fileLen);
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
