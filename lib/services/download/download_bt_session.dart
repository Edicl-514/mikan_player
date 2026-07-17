part of '../download_manager.dart';

extension _DownloadBtSession on DownloadManager {
  String _taskDownloadDir(DownloadTask? task) {
    final dir = task?.downloadDir ?? _downloadDir;
    if (dir == null || dir.isEmpty) {
      throw StateError('Download directory is not initialized');
    }
    return dir;
  }

  String _ltResumePath(String infoHash, {DownloadTask? task, String? baseDir}) {
    final dir = baseDir ?? _taskDownloadDir(task);
    return '$dir/${infoHash.toLowerCase()}.resume';
  }

  Future<bool> _saveLibtorrentResumeDataForHash(
    String infoHash,
    String reason,
  ) async {
    final hashLower = infoHash.toLowerCase();
    final task = _tasks[hashLower] ?? _tasks[infoHash];
    if (task == null || task.backend != BtBackendKind.libtorrent) {
      return false;
    }

    try {
      final ok = await _libtorrentBackend.saveResumeData(
        hashLower,
        _ltResumePath(hashLower, task: task),
      );
      if (ok) {
        debugPrint(
          '[DownloadManager] Saved libtorrent resume data ($reason): $hashLower',
        );
      }
      return ok;
    } catch (e) {
      debugPrint(
        '[DownloadManager] Error saving libtorrent resume data ($reason): $e',
      );
      return false;
    }
  }

  Future<void> _saveActiveLibtorrentResumeData(String reason) async {
    if (_isSavingLibtorrentResumeData) return;

    final hashes = _tasks.entries
        .where(
          (entry) =>
              entry.value.backend == BtBackendKind.libtorrent &&
              !_removedTaskIds.contains(entry.key) &&
              entry.value.magnet.isNotEmpty &&
              entry.value.status != DownloadTaskStatus.paused &&
              entry.value.status != DownloadTaskStatus.error,
        )
        .map((entry) => entry.key.toLowerCase())
        .toList(growable: false);
    if (hashes.isEmpty) return;

    _isSavingLibtorrentResumeData = true;
    try {
      // Start every native save before awaiting any completion. Lifecycle
      // callbacks (especially `detached` / `dispose`) cannot await this
      // method; a serial await would otherwise dispatch only the first save
      // before the process is allowed to exit.
      await Future.wait<bool>([
        for (final hash in hashes)
          _saveLibtorrentResumeDataForHash(hash, reason),
      ]);
    } finally {
      _isSavingLibtorrentResumeData = false;
    }
  }

  void _maybeSavePeriodicLibtorrentResumeData() {
    final now = DateTime.now();
    if (_lastLibtorrentResumeSaveAt != null &&
        now.difference(_lastLibtorrentResumeSaveAt!) <
            DownloadManager._ltResumeSaveInterval) {
      return;
    }
    _lastLibtorrentResumeSaveAt = now;
    unawaited(_saveActiveLibtorrentResumeData('periodic'));
  }

  void _saveLibtorrentResumeDataForShutdownImpl() {
    unawaited(_saveActiveLibtorrentResumeData('shutdown'));
    unawaited(_saveTasks());
  }

  /// Load tasks from SharedPreferences.
  ///
  /// Raw string read + JSON decode live in [_taskStore]; this method runs
  /// the domain logic (validation, status transitions, paused-id tracking,
  /// and the cold-start resume queue) over the decoded list.
  Future<void> _loadTasks() async {
    final loaded = await _taskStore.loadTasks();
    if (loaded.isNotEmpty) {
      try {
        var removedInvalidTasks = false;
        final toResume = <DownloadTask>[];
        for (final task in loaded) {
          task.downloadDir ??= _downloadDir;

          // Only skip BT tasks with empty magnet; HTTP tasks have no magnet
          if (task.taskType == DownloadTaskType.bt && task.magnet.isEmpty) {
            removedInvalidTasks = true;
            continue;
          }

          // Verify HTTP task local file still exists if completed
          if (task.taskType == DownloadTaskType.http) {
            if (task.status == DownloadTaskStatus.completed &&
                task.localFilePath != null) {
              final file = File(task.localFilePath!);
              if (!file.existsSync()) {
                task.status = DownloadTaskStatus.error;
                task.errorMessage = '本地文件已删除';
                removedInvalidTasks = true;
              }
            } else if (_isActiveStatus(task.status)) {
              task.status = DownloadTaskStatus.paused;
              task.downloadSpeed = 0;
              task.uploadSpeed = 0;
              _pausedTaskIds.add(task.id);
              removedInvalidTasks = true;
            }
          }

          // Keep rqbit startup semantics aligned with libtorrent-style metadata stage.
          if (task.taskType == DownloadTaskType.bt &&
              task.backend == BtBackendKind.rqbit &&
              task.status == DownloadTaskStatus.pending) {
            task.status = DownloadTaskStatus.metadata;
          }

          _tasks[task.id] = task;

          // Track paused tasks
          if (task.status == DownloadTaskStatus.paused) {
            _pausedTaskIds.add(task.id);
          }

          // Auto-resume BT torrents that were downloading or seeding
          // This ensures they continue after app restart
          // HTTP tasks are NOT auto-resumed; user must manually resume them
          if (task.taskType == DownloadTaskType.bt &&
              task.magnet.isNotEmpty &&
              (_isActiveStatus(task.status) ||
                  task.status == DownloadTaskStatus.seeding ||
                  task.status == DownloadTaskStatus.completed)) {
            toResume.add(task);
          }
        }
        if (removedInvalidTasks) {
          await _saveTasks();
        }
        debugPrint(
          '[DownloadManager] Loaded ${_tasks.length} tasks from storage',
        );

        // Cold-start resume: run at most 3 backend `startTorrent` calls in
        // parallel to avoid hammering librqbit and overwhelming trackers when
        // the user has many persisted tasks. Fire-and-forget so [initialize]
        // can complete and the UI can render immediately.
        if (toResume.isNotEmpty) {
          unawaited(_runResumeQueue(toResume, _maxConcurrentDownloads));
        }
      } catch (e) {
        debugPrint('[DownloadManager] Error loading tasks: $e');
      }
    }
    _notifyChanged();
  }

  /// Resume a torrent in the background after app restart
  Future<void> _resumeTorrentInBackground(DownloadTask task) async {
    if (task.status == DownloadTaskStatus.seeding ||
        task.status == DownloadTaskStatus.completed) {
      await _reattachTerminalTorrentInBackground(task);
      return;
    }

    if (!_hasAvailableDownloadSlot) {
      await _markTaskQueued(task);
    }
    final acquiredSlot = await _acquireDownloadSlot(task.id);
    if (!acquiredSlot) return;
    final currentTask = _tasks[task.id];
    if (!identical(currentTask, task) ||
        _removedTaskIds.contains(task.id) ||
        !_isActiveStatus(task.status)) {
      _releaseSlotForTask(task.id);
      return;
    }
    if (task.status == DownloadTaskStatus.queued) {
      task.status = task.backend == BtBackendKind.rqbit
          ? DownloadTaskStatus.metadata
          : DownloadTaskStatus.pending;
      await _saveTasks();
      _notifyChanged();
    }
    try {
      debugPrint('[DownloadManager] Auto-resuming torrent: ${task.name}');
      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: task.id,
        backendKind: task.backend,
        startStream: false,
        downloadDir: task.downloadDir,
      );
      final actualId = result.infoHash;
      if (actualId != task.id) {
        final previousId = task.id;
        _tasks.remove(task.id);
        task.id = actualId;
        _tasks[actualId] = task;
        _transferDownloadSlot(previousId, actualId);
      }
      if (result.streamUrl != null) {
        task.streamUrl = result.streamUrl;
      }
      task.largestFileIdx = result.fileIdx ?? task.largestFileIdx;
      task.largestFilePath = result.filePath ?? task.largestFilePath;
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
      if (task.status != DownloadTaskStatus.seeding &&
          task.status != DownloadTaskStatus.completed) {
        task.status = DownloadTaskStatus.downloading;
      }
      await _saveTasks();
      _notifyChanged();
      _ensureStatsPolling();
      debugPrint('[DownloadManager] Auto-resumed torrent: ${task.name}');
    } catch (e) {
      debugPrint('[DownloadManager] Error auto-resuming torrent: $e');
      _releaseSlotForTask(task.id);
    }
  }

  Future<void> _reattachTerminalTorrentInBackground(DownloadTask task) async {
    final currentTask = _tasks[task.id];
    if (!identical(currentTask, task) ||
        _removedTaskIds.contains(task.id) ||
        task.magnet.isEmpty) {
      return;
    }

    try {
      debugPrint(
        '[DownloadManager] Re-attaching completed torrent: ${task.name}',
      );
      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: task.id,
        backendKind: task.backend,
        startStream: false,
        downloadDir: task.downloadDir,
      );
      final actualId = result.infoHash;
      if (actualId != task.id) {
        _tasks.remove(task.id);
        task.id = actualId;
        _tasks[actualId] = task;
      }
      if (result.streamUrl != null) {
        task.streamUrl = result.streamUrl;
      }
      task.largestFileIdx = result.fileIdx ?? task.largestFileIdx;
      task.largestFilePath = result.filePath ?? task.largestFilePath;
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
      await _saveTasks();
      _notifyChanged();
      _ensureStatsPolling();
      debugPrint(
        '[DownloadManager] Re-attached completed torrent: ${task.name}',
      );
    } catch (e) {
      debugPrint('[DownloadManager] Error re-attaching completed torrent: $e');
    }
  }

  /// Drive cold-start resume with a bounded worker pool so we don't fire
  /// dozens of [startTorrent] calls in parallel.
  Future<void> _runResumeQueue(
    List<DownloadTask> tasks,
    int maxConcurrent,
  ) async {
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= tasks.length) return;
        await _resumeTorrentInBackground(tasks[i]);
      }
    }

    final workers = <Future<void>>[
      for (var w = 0; w < maxConcurrent; w++) worker(),
    ];
    await Future.wait(workers);
    if (_downloadDir != null && _downloadDir!.isNotEmpty) {
      try {
        await rust_api.setDownloadDir(dir: _downloadDir!);
      } catch (e) {
        debugPrint('[DownloadManager] Failed to restore Rust download dir: $e');
      }
    }
  }

  /// Save tasks to SharedPreferences via the persistence store. The store
  /// performs the JSON encode + write and swallows/logs encode/write errors
  /// the same way this method did before extraction.
  Future<void> _saveTasks() => _taskStore.saveTasks(_tasks.values);

  Future<BtTorrentHandle> _startTorrentWithBackend(
    String magnet, {
    required String fallbackInfoHash,
    required BtBackendKind backendKind,
    bool startStream = true,
    String? downloadDir,
  }) async {
    final backend = _backendFor(backendKind);
    final hashLower = fallbackInfoHash.toLowerCase();
    final task = _tasks[hashLower] ?? _tasks[fallbackInfoHash];
    final effectiveDir = downloadDir ?? task?.downloadDir ?? _downloadDir;
    final seed =
        task != null &&
        task.progress >= 100.0 &&
        task.status != DownloadTaskStatus.paused;
    final resumePath = backendKind == BtBackendKind.libtorrent
        ? _ltResumePath(
            hashLower,
            baseDir: effectiveDir ?? _taskDownloadDir(task),
          )
        : null;
    return backend.addTorrent(
      magnet,
      fallbackInfoHash: fallbackInfoHash,
      downloadDir: effectiveDir,
      startStream: startStream,
      seedMode: seed,
      resumePath: resumePath,
    );
  }

  Future<List<BtTorrentStats>> _getTorrentStatsWithBackend() async {
    final results = <BtTorrentStats>[];
    final hasRqbitTasks = _tasks.values.any(
      (task) =>
          task.taskType == DownloadTaskType.bt &&
          task.backend == BtBackendKind.rqbit,
    );
    final hasLibtorrentTasks = _tasks.values.any(
      (task) =>
          task.taskType == DownloadTaskType.bt &&
          task.backend == BtBackendKind.libtorrent,
    );

    if (hasRqbitTasks) {
      results.addAll(await _rqbitBackend.getStats());
    }

    if (hasLibtorrentTasks) {
      final ltStats = await _libtorrentBackend.getStats();
      for (final stats in ltStats) {
        final task = _tasks[stats.infoHash];
        final persistedTotal = task?.totalSize.toInt() ?? 0;
        final backendFileSize = _libtorrentBackend.fileSizeForHash(
          stats.infoHash,
        );
        final totalSize =
            backendFileSize ??
            (persistedTotal > 0 ? persistedTotal : stats.totalSize.toInt());
        final downloaded = totalSize > 0
            ? stats.downloaded.toInt().clamp(0, totalSize)
            : stats.downloaded.toInt();
        final progress = totalSize > 0
            ? (downloaded / totalSize * 100.0).clamp(0.0, 100.0)
            : stats.progress;
        results.add(
          BtTorrentStats(
            infoHash: stats.infoHash,
            name: stats.name,
            state: stats.state,
            progress: progress,
            downloadSpeed: stats.downloadSpeed,
            uploadSpeed: stats.uploadSpeed,
            downloaded: BigInt.from(downloaded),
            totalSize: BigInt.from(totalSize),
            peers: stats.peers,
            seeders: stats.seeders,
          ),
        );
      }
    }
    return results;
  }

  Future<bool> _isRqbitTorrentManaged(String infoHash) async {
    try {
      return await _rqbitBackend.isTorrentManaged(infoHash);
    } catch (e) {
      debugPrint('[DownloadManager] Error checking rqbit torrent state: $e');
      return false;
    }
  }

  Future<bool> _pauseTorrentWithBackend(
    String infoHash, {
    required BtBackendKind backend,
  }) => _backendFor(backend).pauseTorrent(infoHash);

  Future<bool> _resumeTorrentWithBackend(
    String infoHash, {
    required BtBackendKind backend,
  }) => _backendFor(backend).resumeTorrent(infoHash);

  Future<bool> _stopTorrentWithBackend(
    String infoHash, {
    required BtBackendKind backend,
    required bool deleteFiles,
    DownloadTask? task,
  }) async {
    final hashLower = infoHash.toLowerCase();
    if (backend == BtBackendKind.libtorrent) {
      _ltCompletionResumeSavedHashes.remove(hashLower);
      final resumePath = _ltResumePath(hashLower, task: task);
      if (deleteFiles) {
        try {
          final file = File(resumePath);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
      return _libtorrentBackend.removeTorrent(
        infoHash,
        deleteFiles: deleteFiles,
        resumePath: deleteFiles ? null : resumePath,
      );
    }
    return _rqbitBackend.removeTorrent(infoHash, deleteFiles: deleteFiles);
  }

  bool _isPathUnderDownloadDir(String path, {String? baseDir}) {
    final downloadDir = baseDir ?? _downloadDir;
    if (downloadDir == null || downloadDir.isEmpty) return false;
    return isPathUnderDownloadDir(path, downloadDir: downloadDir);
  }

  String? _resolveDownloadChildPath(String relativePath, {String? baseDir}) {
    final downloadDir = baseDir ?? _downloadDir;
    if (downloadDir == null || downloadDir.isEmpty) return null;
    if (relativePath.isEmpty || isAbsolutePath(relativePath)) {
      return null;
    }

    final parts = relativePath
        .split(RegExp(r'[\\/]'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return null;
    if (parts.any(
      (part) => part == '.' || part == '..' || part.contains(':'),
    )) {
      return null;
    }

    var path = Directory(downloadDir).absolute.path;
    for (final part in parts) {
      path = '$path${Platform.pathSeparator}$part';
    }
    return _isPathUnderDownloadDir(path, baseDir: downloadDir) ? path : null;
  }

  File? _findUniqueDownloadedFileCandidate(DownloadTask task) {
    final downloadDir = task.downloadDir ?? _downloadDir;
    if (downloadDir == null || downloadDir.isEmpty) return null;
    return findUniqueDownloadedFileCandidate(task, downloadDir: downloadDir);
  }

  void _deleteEmptyParentsUnderDownloadDir(File file, {String? baseDir}) {
    final downloadDir = baseDir ?? _downloadDir;
    if (downloadDir == null || downloadDir.isEmpty) return;
    deleteEmptyParentsUnderDownloadDir(file, downloadDir: downloadDir);
  }

  Future<void> _deleteLibtorrentFilesForTask(DownloadTask task) async {
    if (task.backend != BtBackendKind.libtorrent) return;
    final downloadDir = task.downloadDir ?? _downloadDir;
    if (downloadDir == null || downloadDir.isEmpty) return;

    try {
      final resumeFile = File(_ltResumePath(task.id, task: task));
      if (resumeFile.existsSync()) {
        resumeFile.deleteSync();
      }
    } catch (_) {}

    File? target;
    final relativePath = task.largestFilePath;
    if (relativePath != null) {
      final path = _resolveDownloadChildPath(
        relativePath,
        baseDir: downloadDir,
      );
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          target = file;
        }
      }
    }

    target ??= _findUniqueDownloadedFileCandidate(task);
    if (target == null) {
      debugPrint(
        '[DownloadManager] No safe fallback file path for ${task.id}; '
        'native delete may already have handled it.',
      );
      return;
    }

    try {
      final deletedPath = target.path;
      target.deleteSync();
      _deleteEmptyParentsUnderDownloadDir(target, baseDir: downloadDir);
      debugPrint('[DownloadManager] Deleted libtorrent file: $deletedPath');
    } catch (e) {
      debugPrint('[DownloadManager] Error deleting libtorrent file: $e');
    }
  }

  /// Start a new download/streaming task
  Future<String?> _startDownloadImpl({
    required String magnet,
    required String name,
    String? animeName,
    int? episodeNumber,
    bool forPlayback = false,
  }) async {
    await _ensureDownloadDir();

    // Generate a temporary ID from magnet hash
    final tempId =
        _extractInfoHash(magnet) ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // If this task was previously removed, allow it to be re-added
    _removedTaskIds.remove(tempId);

    // Check if already downloading and has valid stream URL
    if (_tasks.containsKey(tempId)) {
      final existingTask = _tasks[tempId]!;
      if (existingTask.status == DownloadTaskStatus.paused) {
        final resumed = await resumeTask(tempId);
        if (!resumed) return null;
      }
      if (!forPlayback &&
          existingTask.streamUrl != null &&
          existingTask.streamUrl!.isNotEmpty) {
        debugPrint(
          '[DownloadManager] Torrent already active: ${existingTask.name}',
        );
        return existingTask.streamUrl;
      }
      if (!forPlayback) {
        return null;
      }

      return getOrCreateStreamUrl(tempId);
    }

    // Create new task
    final backendInitialStatus = _backendKind == BtBackendKind.rqbit
        ? DownloadTaskStatus.metadata
        : DownloadTaskStatus.pending;
    final task = DownloadTask(
      id: tempId,
      name: name,
      magnet: magnet,
      animeName: animeName,
      episodeNumber: episodeNumber,
      startTime: DateTime.now(),
      status: _hasAvailableDownloadSlot
          ? backendInitialStatus
          : DownloadTaskStatus.queued,
      backend: _backendKind,
      downloadDir: _downloadDir,
    );

    _tasks[tempId] = task;
    await _saveTasks();
    _notifyChanged();
    _ensureStatsPolling();

    if (!_hasAvailableDownloadSlot) {
      await _markTaskQueued(task);
    }
    final acquiredSlot = await _acquireDownloadSlot(tempId);
    if (!acquiredSlot) return null;
    if (!identical(_tasks[tempId], task) ||
        _removedTaskIds.contains(tempId) ||
        !_isActiveStatus(task.status)) {
      _releaseSlotForTask(tempId);
      return null;
    }
    if (task.status == DownloadTaskStatus.queued) {
      task.status = backendInitialStatus;
      await _saveTasks();
      _notifyChanged();
    }

    try {
      final result = await _startTorrentWithBackend(
        magnet,
        fallbackInfoHash: tempId,
        backendKind: task.backend,
        startStream: forPlayback,
        downloadDir: task.downloadDir,
      );
      final streamUrl = result.streamUrl;

      final currentTask = _tasks[tempId];
      if (!identical(currentTask, task) || _removedTaskIds.contains(tempId)) {
        if (_removedTaskIds.contains(tempId)) {
          _removedTaskIds.add(result.infoHash);
        }
        _releaseSlotForTask(tempId);
        return null;
      }

      // Update task with actual info
      final actualId = result.infoHash;
      final fileIdx = result.fileIdx;
      if (actualId != tempId) {
        _tasks.remove(tempId);
        _removedTaskIds.remove(
          tempId,
        ); // Also remove the temp ID from removed set
        task.id = actualId; // Update the task's ID to the actual info hash
        // Remove actual ID from removed set in case it was previously deleted
        _removedTaskIds.remove(actualId);
        task.streamUrl = streamUrl;
        task.largestFileIdx = fileIdx ?? task.largestFileIdx;
        task.largestFilePath = result.filePath ?? task.largestFilePath;
        task.status = DownloadTaskStatus.downloading;
        _tasks[actualId] = task;
        _transferDownloadSlot(tempId, actualId);
      } else {
        task.streamUrl = streamUrl;
        task.largestFileIdx = fileIdx ?? task.largestFileIdx;
        task.largestFilePath = result.filePath ?? task.largestFilePath;
        task.status = DownloadTaskStatus.downloading;
      }
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }

      _notifyChanged();
      await _saveTasks();
      return streamUrl;
    } catch (e) {
      final currentTask = _tasks[tempId];
      if (!identical(currentTask, task) || _removedTaskIds.contains(tempId)) {
        _releaseSlotForTask(tempId);
        return null;
      }
      task.status = DownloadTaskStatus.error;
      task.errorMessage = e.toString();
      _releaseSlotForTask(tempId);
      await _saveTasks();
      _notifyChanged();
      return null;
    }
  }

  /// Create a streaming URL for an existing task only when playback needs it.
  ///
  /// For the libtorrent backend this avoids starting the HTTP streaming engine
  /// during plain downloads. The stream engine deliberately reprioritizes
  /// pieces around the playback window, which is good for watching but bad for
  /// full-file background downloading.
  ///
  /// For HTTP tasks, returns the local file path directly.
  Future<String?> _getOrCreateStreamUrlImpl(String id) async {
    final task = _tasks[id];
    if (task == null) return null;

    // A delayed post-playback restore belongs to the stream that just ended.
    // Once playback asks for a stream again, that old restore must not touch
    // the replacement stream or reset its piece priorities.
    if (task.backend == BtBackendKind.libtorrent) {
      _cancelLibtorrentBackgroundRestore(task.id);
    }

    // HTTP completed tasks: play from local file
    if (task.taskType == DownloadTaskType.http) {
      if (task.status == DownloadTaskStatus.completed &&
          task.localFilePath != null) {
        final file = File(task.localFilePath!);
        if (file.existsSync()) return task.localFilePath;
      }
      return null;
    }

    if (task.magnet.isEmpty) return null;

    try {
      final hashLower = task.id.toLowerCase();
      if (task.backend == BtBackendKind.libtorrent &&
          task.streamUrl != null &&
          task.streamUrl!.isNotEmpty) {
        final streamId = _libtorrentBackend.streamIdForHash(hashLower);
        if (streamId != null && task.status != DownloadTaskStatus.paused) {
          return task.streamUrl;
        }
        task.streamUrl = null;
      } else if (task.backend == BtBackendKind.rqbit &&
          task.streamUrl != null &&
          task.streamUrl!.isNotEmpty &&
          task.status != DownloadTaskStatus.paused &&
          await _isRqbitTorrentManaged(hashLower)) {
        return task.streamUrl;
      } else if (task.backend == BtBackendKind.rqbit) {
        task.streamUrl = null;
      }

      if (task.status == DownloadTaskStatus.paused) {
        final resumed = await resumeTask(id);
        if (!resumed) return null;
      }

      if (task.backend == BtBackendKind.libtorrent) {
        _cancelLibtorrentBackgroundRestore(task.id);
      }

      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: task.id,
        backendKind: task.backend,
        startStream: true,
        downloadDir: task.downloadDir,
      );
      final actualId = result.infoHash;
      if (actualId != task.id) {
        _tasks.remove(task.id);
        _pausedTaskIds.remove(task.id);
        task.id = actualId;
        _tasks[actualId] = task;
      }

      if (result.streamUrl != null) {
        task.streamUrl = result.streamUrl;
      }
      task.largestFileIdx = result.fileIdx ?? task.largestFileIdx;
      task.largestFilePath = result.filePath ?? task.largestFilePath;
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
      if (task.status != DownloadTaskStatus.seeding &&
          task.status != DownloadTaskStatus.completed) {
        task.status = DownloadTaskStatus.downloading;
      }
      await _saveTasks();
      _notifyChanged();
      _ensureStatsPolling();
      return task.streamUrl;
    } catch (e) {
      debugPrint('[DownloadManager] Error creating stream URL: $e');
      return null;
    }
  }

  /// Extract info hash from magnet link.
  String? _extractInfoHash(String magnet) => extractInfoHashFromMagnet(magnet);

  /// Pause a download task
  /// This stops the torrent without deleting files
  Future<bool> _pauseTaskImpl(String id) async {
    if (!_tasks.containsKey(id)) return false;

    final task = _tasks[id]!;

    if (task.status == DownloadTaskStatus.queued) {
      task.status = DownloadTaskStatus.paused;
      task.downloadSpeed = 0;
      task.uploadSpeed = 0;
      _pausedTaskIds.add(id);
      await _saveTasks();
      _notifyChanged();
      debugPrint('[DownloadManager] Paused queued download: $id');
      return true;
    }

    // HTTP tasks: cancel the active download job
    if (task.taskType == DownloadTaskType.http) {
      final job = _httpDownloadJobs[id];
      if (job != null) {
        job.cancel();
      }
      task.status = DownloadTaskStatus.paused;
      task.downloadSpeed = 0;
      task.uploadSpeed = 0;
      _pausedTaskIds.add(id);
      await _saveTasks();
      _notifyChanged();
      debugPrint('[DownloadManager] Paused HTTP download: $id');
      return true;
    }

    try {
      // Pause by calling the Rust pause_torrent function
      // which internally stops the torrent without deleting files
      final success = await _pauseTorrentWithBackend(id, backend: task.backend);
      if (success) {
        task.status = DownloadTaskStatus.paused;
        task.downloadSpeed = 0;
        task.uploadSpeed = 0;
        _pausedTaskIds.add(id);
        _releaseSlotForTask(id);
        // Save resume data so the next restart can fast-resume.
        if (task.backend == BtBackendKind.libtorrent) {
          await _saveLibtorrentResumeDataForHash(id, 'pause');
        }
        await _saveTasks();
        _notifyChanged();
        _ensureStatsPolling();
        debugPrint('[DownloadManager] Paused task: $id');
      }
      return success;
    } catch (e) {
      debugPrint('[DownloadManager] Error pausing task: $e');
      return false;
    }
  }

  /// Resume a paused download task, or retry a failed HTTP download.
  ///
  /// HTTP/HLS: works for both [DownloadTaskStatus.paused] and
  /// [DownloadTaskStatus.error]. Partial bytes / HLS segment checkpoints are
  /// kept so a network blip does not force a full re-download.
  ///
  /// BT: uses the backend pause/unpause path when possible. If the app was
  /// restarted and the paused torrent is no longer in the backend session,
  /// it falls back to restarting the torrent from the saved magnet link.
  Future<bool> _resumeTaskImpl(String id) async {
    if (!_tasks.containsKey(id)) return false;

    final task = _tasks[id]!;

    // HTTP tasks resume / retry in place. Plain files use a byte Range
    // request and HLS skips completed segments; neither path deletes a
    // valid partial file before it has had a chance to resume.
    if (task.taskType == DownloadTaskType.http) {
      if (task.status != DownloadTaskStatus.paused &&
          task.status != DownloadTaskStatus.error &&
          task.status != DownloadTaskStatus.queued) {
        // Already running (or completed/seeding) — nothing to resume.
        if (task.status == DownloadTaskStatus.downloading) return true;
        return false;
      }
      _pausedTaskIds.remove(id);
      task.status = DownloadTaskStatus.downloading;
      task.downloadSpeed = 0;
      task.errorMessage = null;

      // Free any slot still held by a winding-down previous run so the
      // restarted body can acquire immediately.
      _releaseSlotForTask(id);
      await _saveTasks();
      _notifyChanged();
      unawaited(_downloadHttpFile(task));
      debugPrint('[DownloadManager] Resumed HTTP download: $id');
      return true;
    }

    try {
      final backendInitialStatus = task.backend == BtBackendKind.rqbit
          ? DownloadTaskStatus.metadata
          : DownloadTaskStatus.pending;
      final hasAvailableSlot = _hasAvailableDownloadSlot;
      if (task.status == DownloadTaskStatus.paused) {
        task.status = hasAvailableSlot
            ? backendInitialStatus
            : DownloadTaskStatus.queued;
        await _saveTasks();
        _notifyChanged();
      } else if (!hasAvailableSlot) {
        await _markTaskQueued(task);
      }
      final acquiredSlot = await _acquireDownloadSlot(id);
      if (!acquiredSlot) return false;
      if (!identical(_tasks[id], task) ||
          _removedTaskIds.contains(id) ||
          !_isActiveStatus(task.status)) {
        _releaseSlotForTask(id);
        return false;
      }
      if (task.status == DownloadTaskStatus.queued) {
        task.status = backendInitialStatus;
        await _saveTasks();
        _notifyChanged();
      }
      final resumed = await _resumeTorrentWithBackend(
        id,
        backend: task.backend,
      );
      if (resumed) {
        _pausedTaskIds.remove(id);
        task.status = task.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : DownloadTaskStatus.downloading;
        if (task.status == DownloadTaskStatus.seeding) {
          _releaseSlotForTask(id);
        }
        if (task.backend == BtBackendKind.libtorrent) {
          unawaited(_restoreLibtorrentBackgroundDownload(task.id));
        }
        await _saveTasks();
        _notifyChanged();
        _ensureStatsPolling();
        debugPrint('[DownloadManager] Resumed task: $id');
        return true;
      }

      if (task.magnet.isEmpty) {
        debugPrint('[DownloadManager] Cannot resume task without magnet link');
        _releaseSlotForTask(id);
        return false;
      }

      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: id,
        backendKind: task.backend,
        startStream: false,
        downloadDir: task.downloadDir,
      );
      final actualId = result.infoHash;
      final fileIdx = result.fileIdx;
      if (actualId != id) {
        _tasks.remove(id);
        _pausedTaskIds.remove(id);
        task.id = actualId;
        _tasks[actualId] = task;
        _transferDownloadSlot(id, actualId);
      }
      _removedTaskIds.remove(task.id);
      task.status = task.progress >= 100.0
          ? DownloadTaskStatus.seeding
          : DownloadTaskStatus.downloading;
      if (task.status == DownloadTaskStatus.seeding) {
        _releaseSlotForTask(task.id);
      }
      if (result.streamUrl != null) {
        task.streamUrl = result.streamUrl;
      }
      task.largestFileIdx = fileIdx ?? task.largestFileIdx;
      task.largestFilePath = result.filePath ?? task.largestFilePath;
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
      _pausedTaskIds.remove(task.id);
      await _saveTasks();
      _notifyChanged();
      _ensureStatsPolling();
      debugPrint('[DownloadManager] Restarted paused task: ${task.id}');
      return true;
    } catch (e) {
      debugPrint('[DownloadManager] Error resuming task: $e');
      _releaseSlotForTask(id);
      return false;
    }
  }

  /// Remove a download task
  Future<void> _removeTaskImpl(String id, {bool deleteFiles = false}) async {
    final task = _tasks[id];
    final effectiveDeleteFiles = _shouldDeleteFiles(deleteFiles);

    // Invalidate an HTTP/HLS body before dropping the task-map entry. A
    // handle can still yield one queued chunk after cancellation; generation
    // invalidation makes that old body stop before it writes or changes task
    // status. (The job owner closes its own IOSink in its finally block.)
    if (task?.taskType == DownloadTaskType.http) {
      _httpRunGeneration[id] = (_httpRunGeneration[id] ?? 0) + 1;
      _httpDownloadJobs[id]?.cancel();
    }

    // Remove from UI immediately so the task disappears right away.
    _tasks.remove(id);
    _pausedTaskIds.remove(id);
    _removedTaskIds.add(id); // Mark as removed to prevent re-adding
    _releaseSlotForTask(id);
    await _saveTasks();
    _notifyChanged();
    _ensureStatsPolling();

    // HTTP tasks: cancel download and optionally delete file
    if (task != null && task.taskType == DownloadTaskType.http) {
      _httpDownloadJobs.remove(id);
      if (effectiveDeleteFiles && task.localFilePath != null) {
        try {
          final file = File(task.localFilePath!);
          if (file.existsSync()) file.deleteSync();
        } catch (e) {
          debugPrint('[DownloadManager] Error deleting HTTP file: $e');
        }
      }
      debugPrint('[DownloadManager] Removed HTTP task: $id');
      return;
    }

    // Try to stop the torrent in the backend
    try {
      final stopped = await _stopTorrentWithBackend(
        id,
        backend: task?.backend ?? _backendKind,
        deleteFiles: effectiveDeleteFiles,
        task: task,
      );
      if (stopped) {
        debugPrint(
          '[DownloadManager] Successfully stopped torrent: $id (deleteFiles: $effectiveDeleteFiles)',
        );
      } else {
        debugPrint(
          '[DownloadManager] Failed to stop torrent (may not exist): $id',
        );
        if (effectiveDeleteFiles && task?.magnet.isNotEmpty == true) {
          _noteOrphanedFiles(task!);
        }
      }
    } catch (e) {
      debugPrint('[DownloadManager] Error stopping torrent: $e');
    }

    if (effectiveDeleteFiles && task != null) {
      await _deleteLibtorrentFilesForTask(task);
    }
  }

  /// Best-effort cleanup for tasks whose backend handle has already
  /// disappeared. We intentionally do NOT re-add the torrent just to delete
  /// it — doing so would reconnect to trackers, burn bandwidth and leave a
  /// phantom task in the backend after the user already asked us to get rid
  /// of it. Any leftover files on disk can be cleaned up manually; the next
  /// user-initiated download will `overwrite` them anyway.
  void _noteOrphanedFiles(DownloadTask task) {
    debugPrint(
      '[DownloadManager] Torrent ${task.id} not in backend session; '
      'skipping re-attach. Files (if any) remain in download directory.',
    );
  }

  String _resolveStreamHash(String infoHash) {
    final hashLower = infoHash.toLowerCase();
    if (_tasks.containsKey(hashLower) ||
        _libtorrentBackend.streamIdForHash(hashLower) != null) {
      return hashLower;
    }

    for (final entry in _tasks.entries) {
      final streamUrl = entry.value.streamUrl?.toLowerCase();
      if (streamUrl == null) continue;
      if (streamUrl.contains('/stream/$hashLower/') ||
          streamUrl.contains('/streams/$hashLower/') ||
          streamUrl.contains('/torrents/$hashLower/')) {
        return entry.key;
      }
    }
    return hashLower;
  }

  void _stopLibtorrentStreamForHash(String infoHash) {
    final hashLower = _resolveStreamHash(infoHash);
    final streamId = _libtorrentBackend.streamIdForHash(hashLower);
    if (streamId == null) return;

    final task = _tasks[hashLower];
    if (task?.backend == BtBackendKind.libtorrent) {
      task?.streamUrl = null;
    }

    _libtorrentBackend.stopStreamForHash(hashLower);
    debugPrint(
      '[DownloadManager] Stopped libtorrent stream $streamId for $hashLower',
    );
  }

  Future<void> _restoreLibtorrentBackgroundDownload(
    String infoHash, {
    Duration delay = Duration.zero,
  }) {
    final hashLower = _resolveStreamHash(infoHash);
    return _streamRestores.schedule(
      hashLower,
      delay: delay,
      operation: (isCurrent) =>
          _runLibtorrentBackgroundRestore(hashLower, isCurrent: isCurrent),
    );
  }

  Future<void> _runLibtorrentBackgroundRestore(
    String hashLower, {
    required bool Function() isCurrent,
  }) async {
    if (!_canContinueLibtorrentBackgroundRestore(hashLower, isCurrent)) {
      return;
    }

    final task = _tasks[hashLower];
    if (task == null || task.backend != BtBackendKind.libtorrent) {
      return;
    }

    _stopLibtorrentStreamForHash(hashLower);

    BtTorrentHandle? restored;
    try {
      restored = await _libtorrentBackend.restoreBackgroundDownload(
        hashLower,
        preferredFileIdx: task.largestFileIdx,
      );
    } catch (error, stackTrace) {
      await _recordLibtorrentRestoreFailure(hashLower, task, error, isCurrent);
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (!_canContinueLibtorrentBackgroundRestore(hashLower, isCurrent) ||
        !identical(_tasks[hashLower], task)) {
      return;
    }

    if (restored == null) {
      if (task.magnet.isEmpty) return;
      BtTorrentHandle result;
      try {
        result = await _startTorrentWithBackend(
          task.magnet,
          fallbackInfoHash: task.id,
          backendKind: task.backend,
          startStream: false,
          downloadDir: task.downloadDir,
        );
      } catch (error, stackTrace) {
        await _recordLibtorrentRestoreFailure(
          hashLower,
          task,
          error,
          isCurrent,
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (!_canContinueLibtorrentBackgroundRestore(hashLower, isCurrent) ||
          !identical(_tasks[hashLower], task)) {
        return;
      }
      task.largestFileIdx = result.fileIdx ?? task.largestFileIdx;
      task.largestFilePath = result.filePath ?? task.largestFilePath;
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
    } else {
      task.largestFileIdx = restored.fileIdx ?? task.largestFileIdx;
      task.largestFilePath = restored.filePath ?? task.largestFilePath;
      if (restored.fileSize != null && restored.fileSize! > 0) {
        task.totalSize = BigInt.from(restored.fileSize!);
      }
    }

    if (task.status != DownloadTaskStatus.seeding &&
        task.status != DownloadTaskStatus.completed) {
      task.status = DownloadTaskStatus.downloading;
    }
    task.errorMessage = null;
    _ensureStatsPolling();
    await _saveTasks();
    if (!_canContinueLibtorrentBackgroundRestore(hashLower, isCurrent) ||
        !identical(_tasks[hashLower], task)) {
      return;
    }
    _notifyChanged();
    debugPrint(
      '[DownloadManager] Restored libtorrent background download: $hashLower',
    );
  }

  Future<void> _recordLibtorrentRestoreFailure(
    String hashLower,
    DownloadTask task,
    Object error,
    bool Function() isCurrent,
  ) async {
    if (!_canContinueLibtorrentBackgroundRestore(hashLower, isCurrent) ||
        !identical(_tasks[hashLower], task)) {
      return;
    }
    task.status = DownloadTaskStatus.error;
    task.errorMessage = '后台下载恢复失败: $error';
    await _saveTasks();
    _notifyChanged();
  }

  bool _canContinueLibtorrentBackgroundRestore(
    String hashLower,
    bool Function() isCurrent,
  ) =>
      isCurrent() &&
      !_activeStreamHashes.contains(hashLower) &&
      !_removedTaskIds.contains(hashLower) &&
      !_pausedTaskIds.contains(hashLower);

  void _cancelLibtorrentBackgroundRestore(String infoHash) {
    final hashLower = _resolveStreamHash(infoHash);
    _streamRestores.cancel(hashLower);
  }

  /// Notify that a BT stream is now active (being played) or inactive.
  ///
  /// When a libtorrent HTTP reader goes away, the native streaming backend may
  /// leave piece priorities focused around the old playback window. Reset the
  /// selected file priority so the download keeps progressing in the background.
  void _setActiveStreamImpl(String? infoHash, {bool active = true}) {
    if (infoHash == null) {
      final hashes = _activeStreamHashes.toList(growable: false);
      _activeStreamHashes.clear();
      for (final hash in hashes) {
        _stopLibtorrentStreamForHash(hash);
        unawaited(
          _restoreLibtorrentBackgroundDownload(
            hash,
            delay: _streamRestoreDelay,
          ),
        );
      }
      debugPrint('[DownloadManager] Deactivated all BT streams');
      return;
    }

    final hashLower = _resolveStreamHash(infoHash);
    if (!active) {
      _activeStreamHashes.remove(hashLower);
      _stopLibtorrentStreamForHash(hashLower);
      unawaited(
        _restoreLibtorrentBackgroundDownload(
          hashLower,
          delay: _streamRestoreDelay,
        ),
      );
      debugPrint('[DownloadManager] Deactivated BT stream for: $hashLower');
      return;
    }

    _cancelLibtorrentBackgroundRestore(hashLower);
    _activeStreamHashes.add(hashLower);
    debugPrint('[DownloadManager] Activated BT stream for: $hashLower');

    // Native libtorrent streams are kept alive by the HTTP server itself. Avoid
    // periodic synchronous FFI calls on the UI isolate while video is playing.
  }

  /// Clear completed tasks
  Future<void> _clearCompletedImpl({bool deleteFiles = false}) async {
    final effectiveDeleteFiles = _shouldDeleteFiles(deleteFiles);
    final completedIds = _tasks.entries
        .where(
          (e) =>
              e.value.status == DownloadTaskStatus.completed ||
              e.value.status == DownloadTaskStatus.seeding,
        )
        .map((e) => e.key)
        .toList();

    // Stop each torrent in the backend
    for (final id in completedIds) {
      final task = _tasks[id];
      if (task?.taskType == DownloadTaskType.http) {
        if (effectiveDeleteFiles && task?.localFilePath != null) {
          try {
            final file = File(task!.localFilePath!);
            if (file.existsSync()) file.deleteSync();
          } catch (e) {
            debugPrint('[DownloadManager] Error deleting HTTP file: $e');
          }
        }
        _tasks.remove(id);
        _pausedTaskIds.remove(id);
        _removedTaskIds.add(id);
        _releaseSlotForTask(id);
        continue;
      }
      try {
        await _stopTorrentWithBackend(
          id,
          backend: task?.backend ?? _backendKind,
          deleteFiles: effectiveDeleteFiles,
          task: task,
        );
      } catch (e) {
        debugPrint('[DownloadManager] Error stopping torrent $id: $e');
      }
      if (effectiveDeleteFiles && task != null) {
        await _deleteLibtorrentFilesForTask(task);
      }
      _tasks.remove(id);
      _pausedTaskIds.remove(id);
      _removedTaskIds.add(id); // Mark as removed
      _releaseSlotForTask(id);
    }
    await _saveTasks();
    _notifyChanged();
    _ensureStatsPolling();
  }
}
