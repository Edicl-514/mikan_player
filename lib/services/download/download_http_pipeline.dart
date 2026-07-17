part of '../download_manager.dart';

extension _DownloadHttpPipeline on DownloadManager {
  Future<void> _throttleHttpChunk(int chunkBytes) async {
    if (_downloadLimitMbps <= 0) return; // unlimited
    final budgetBytes = (_downloadLimitMbps * 1024 * 1024).round();
    _httpThrottleBytesThisWindow += chunkBytes;
    final now = _now();
    final elapsed = now.difference(_httpThrottleWindowStart);
    if (elapsed.inMilliseconds >= 1000) {
      // New window
      _httpThrottleWindowStart = now;
      _httpThrottleBytesThisWindow = 0;
    } else if (_httpThrottleBytesThisWindow >= budgetBytes) {
      // Budget exhausted — sleep until the window resets
      final remaining = Duration(milliseconds: 1000 - elapsed.inMilliseconds);
      await _sleep(remaining);
      _httpThrottleWindowStart = _now();
      _httpThrottleBytesThisWindow = 0;
    }
  }

  /// Start a new HTTP download task for an online video source.
  /// Returns the task ID on success, null on failure.
  Future<String?> _startHttpDownloadImpl({
    required String url,
    required String name,
    Map<String, String>? headers,
    String? cookies,
    String? animeName,
    int? episodeNumber,
  }) async {
    final existingTask = _tasks.values
        .where((task) => task.taskType == DownloadTaskType.http)
        .where((task) => task.videoUrl == url)
        .firstOrNull;
    if (existingTask != null) {
      existingTask.headers = headers;
      existingTask.cookies = cookies;

      if (existingTask.status == DownloadTaskStatus.completed &&
          existingTask.localFilePath != null) {
        final file = File(existingTask.localFilePath!);
        if (file.existsSync()) {
          await _saveTasks();
          _notifyChanged();
          return existingTask.id;
        }
        existingTask.status = DownloadTaskStatus.error;
        existingTask.errorMessage = '本地文件已删除';
      }

      if (existingTask.status == DownloadTaskStatus.downloading ||
          existingTask.status == DownloadTaskStatus.queued) {
        await _saveTasks();
        _notifyChanged();
        return existingTask.id;
      }

      // Paused/error HTTP tasks resume in place. The download body asks the
      // origin for the existing byte offset and appends only after a verified
      // 206 response; a server that ignores Range safely falls back to a
      // clean restart. This applies to MP4 as well as HLS.
      if ((existingTask.status == DownloadTaskStatus.paused ||
              existingTask.status == DownloadTaskStatus.error) &&
          existingTask.localFilePath != null &&
          File(existingTask.localFilePath!).existsSync() &&
          File(existingTask.localFilePath!).lengthSync() > 0) {
        _pausedTaskIds.remove(existingTask.id);
        existingTask.errorMessage = null;
        existingTask.status = DownloadTaskStatus.downloading;
        existingTask.downloadSpeed = 0;
        existingTask.uploadSpeed = 0;
        _releaseSlotForTask(existingTask.id);
        await _saveTasks();
        _notifyChanged();
        unawaited(_downloadHttpFile(existingTask));
        return existingTask.id;
      }

      existingTask.errorMessage = null;
      _pausedTaskIds.remove(existingTask.id);
      existingTask.status = DownloadTaskStatus.downloading;
      existingTask.progress = 0.0;
      existingTask.downloaded = BigInt.zero;
      existingTask.totalSize = BigInt.zero;
      existingTask.hlsSegmentCount = null;
      existingTask.hlsCompletedSegmentCount = null;
      existingTask.hlsCheckpointBytes = null;
      existingTask.downloadSpeed = 0;
      existingTask.uploadSpeed = 0;
      if (existingTask.localFilePath != null) {
        try {
          final file = File(existingTask.localFilePath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
      await _saveTasks();
      _notifyChanged();
      unawaited(_downloadHttpFile(existingTask));
      return existingTask.id;
    }

    final id = 'http_${stableDownloadHash(url)}';

    if (_tasks.containsKey(id)) {
      return id; // Already exists
    }

    await _ensureDownloadDir();
    final httpDir = Directory('$_downloadDir/http');
    if (!await httpDir.exists()) {
      await httpDir.create(recursive: true);
    }

    // Sanitize name for filename
    final safeName = sanitizeDownloadFileName(name);
    final ext = guessVideoExtension(url);
    final localFilePath =
        '${httpDir.path}${Platform.pathSeparator}${safeName}_$id$ext';

    final task = DownloadTask(
      id: id,
      name: name,
      magnet: '',
      animeName: animeName,
      episodeNumber: episodeNumber,
      startTime: DateTime.now(),
      taskType: DownloadTaskType.http,
      status: DownloadTaskStatus.downloading,
      videoUrl: url,
      headers: headers,
      cookies: cookies,
      localFilePath: localFilePath,
      downloadDir: _downloadDir,
    );

    _tasks[id] = task;
    await _saveTasks();
    _notifyChanged();

    // Start download in background
    unawaited(_downloadHttpFile(task));
    return id;
  }

  Future<HttpDownloadJobResult> _downloadM3u8File(
    DownloadTask task, {
    required int runGeneration,
  }) async {
    if (task.videoUrl == null) {
      return const HttpDownloadJobResult(HttpDownloadJobOutcome.removed);
    }
    _syncAndroidDownloadService();

    return runM3u8Download(
      task: task,
      m3u8Port: _m3u8Port,
      httpPort: _httpPort,
      throttle: _throttleHttpChunk,
      // Pause sets job.cancelled and/or task.status + _pausedTaskIds; the
      // job entry is cleared between HLS segments, so status/paused-id must
      // still count as cancelled across segment boundaries. Generation
      // invalidates a run superseded by resume/restart.
      isCancelled: () =>
          (_httpDownloadJobs[task.id]?.cancelled ?? false) ||
          task.status == DownloadTaskStatus.paused ||
          _pausedTaskIds.contains(task.id) ||
          _httpRunGeneration[task.id] != runGeneration,
      registerJob: (job) => _httpDownloadJobs[task.id] = job,
      clearJob: () {
        if (_httpRunGeneration[task.id] == runGeneration) {
          _httpDownloadJobs.remove(task.id);
        }
      },
      onProgress: _notifyChanged,
      isTaskStillTracked: () =>
          _tasks.containsKey(task.id) &&
          _httpRunGeneration[task.id] == runGeneration,
    );
  }

  Future<void> _downloadHttpFile(DownloadTask task) async {
    final url = task.videoUrl;
    if (url == null) return;
    if (task.status != DownloadTaskStatus.downloading &&
        task.status != DownloadTaskStatus.queued) {
      return;
    }

    final runGeneration = (_httpRunGeneration[task.id] ?? 0) + 1;
    _httpRunGeneration[task.id] = runGeneration;

    // Cancel any in-flight segment/file handle from the previous run so it
    // observes isCancelled promptly and exits the chain.
    _httpDownloadJobs[task.id]?.cancel();

    final previous = _httpRunChain[task.id] ?? Future<void>.value();
    final gate = Completer<void>();
    _httpRunChain[task.id] = gate.future;
    try {
      await previous;
    } catch (_) {
      // A failed previous body must not block resume.
    }

    try {
      if (!identical(_tasks[task.id], task) ||
          _removedTaskIds.contains(task.id) ||
          _httpRunGeneration[task.id] != runGeneration ||
          (task.status != DownloadTaskStatus.downloading &&
              task.status != DownloadTaskStatus.queued)) {
        return;
      }

      _syncAndroidDownloadService();

      if (!_hasAvailableDownloadSlot) {
        await _markTaskQueued(task);
      }
      final acquiredSlot = await _acquireDownloadSlot(task.id);
      if (!acquiredSlot) return;
      try {
        if (!identical(_tasks[task.id], task) ||
            _removedTaskIds.contains(task.id) ||
            _httpRunGeneration[task.id] != runGeneration ||
            (task.status != DownloadTaskStatus.downloading &&
                task.status != DownloadTaskStatus.queued)) {
          return;
        }
        if (task.status == DownloadTaskStatus.queued) {
          task.status = DownloadTaskStatus.downloading;
          await _saveTasks();
          _notifyChanged();
        }

        // Auto-retry transient network failures in-process so a blip does not
        // force the user to delete and re-add the task. Permanent 4xx failures
        // (after header-strategy fallback) still surface as error immediately.
        // Manual resume via resumeTask remains available for any error.
        var autoAttempt = 0;
        while (true) {
          if (!identical(_tasks[task.id], task) ||
              _removedTaskIds.contains(task.id) ||
              _httpRunGeneration[task.id] != runGeneration ||
              (task.status != DownloadTaskStatus.downloading &&
                  task.status != DownloadTaskStatus.queued)) {
            return;
          }
          if (task.status == DownloadTaskStatus.queued) {
            task.status = DownloadTaskStatus.downloading;
            await _saveTasks();
            _notifyChanged();
          }

          final HttpDownloadJobResult result;
          if (isM3u8Url(url)) {
            result = await _downloadM3u8File(
              task,
              runGeneration: runGeneration,
            );
          } else {
            result = await runHttpFileDownload(
              task: task,
              httpPort: _httpPort,
              throttle: _throttleHttpChunk,
              isCancelled: () =>
                  (_httpDownloadJobs[task.id]?.cancelled ?? false) ||
                  task.status == DownloadTaskStatus.paused ||
                  _pausedTaskIds.contains(task.id) ||
                  _httpRunGeneration[task.id] != runGeneration,
              registerJob: (job) => _httpDownloadJobs[task.id] = job,
              clearJob: () {
                if (_httpRunGeneration[task.id] == runGeneration) {
                  _httpDownloadJobs.remove(task.id);
                }
              },
              onProgress: _notifyChanged,
              isTaskStillTracked: () =>
                  _tasks.containsKey(task.id) &&
                  _httpRunGeneration[task.id] == runGeneration,
            );
          }

          if (result.outcome == HttpDownloadJobOutcome.paused) {
            if (identical(_tasks[task.id], task) &&
                _httpRunGeneration[task.id] == runGeneration &&
                task.status != DownloadTaskStatus.downloading &&
                task.status != DownloadTaskStatus.queued) {
              _pausedTaskIds.add(task.id);
            }
            break;
          }

          if (result.outcome != HttpDownloadJobOutcome.error) {
            break;
          }

          final errorText = result.errorMessage ?? task.errorMessage ?? '';
          final canAutoRetry =
              autoAttempt < kHttpDownloadMaxAutoRetries &&
              isTransientHttpDownloadError(errorText) &&
              identical(_tasks[task.id], task) &&
              _httpRunGeneration[task.id] == runGeneration &&
              !_pausedTaskIds.contains(task.id) &&
              task.status != DownloadTaskStatus.paused;
          if (!canAutoRetry) {
            break;
          }

          final delay = httpDownloadAutoRetryDelay(autoAttempt);
          autoAttempt++;
          debugPrint(
            '[DownloadManager] Transient HTTP failure for ${task.name} '
            '($errorText); auto-retry $autoAttempt/'
            '$kHttpDownloadMaxAutoRetries in ${delay.inSeconds}s',
          );
          task.status = DownloadTaskStatus.downloading;
          task.errorMessage =
              '网络中断，${delay.inSeconds}s 后自动重试 '
              '($autoAttempt/$kHttpDownloadMaxAutoRetries)';
          task.downloadSpeed = 0;
          await _saveTasks();
          _notifyChanged();

          // Use the injectable sleeper so tests can compress backoff without
          // wall-clock waits, matching throttle / stream-restore seams.
          await _sleep(delay);
          if (!identical(_tasks[task.id], task) ||
              _removedTaskIds.contains(task.id) ||
              _httpRunGeneration[task.id] != runGeneration ||
              _pausedTaskIds.contains(task.id) ||
              task.status == DownloadTaskStatus.paused) {
            return;
          }
          task.errorMessage = null;
          task.status = DownloadTaskStatus.downloading;
          _notifyChanged();
        }

        if (_tasks.containsKey(task.id) &&
            _httpRunGeneration[task.id] == runGeneration) {
          await _saveTasks();
          _notifyChanged();
          _syncAndroidDownloadService();
        }
      } finally {
        _releaseSlotForTask(task.id);
        _syncAndroidDownloadService();
      }
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
      if (identical(_httpRunChain[task.id], gate.future)) {
        _httpRunChain.remove(task.id);
      }
    }
  }
}
