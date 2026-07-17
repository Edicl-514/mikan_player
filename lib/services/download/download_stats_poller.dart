part of '../download_manager.dart';

extension _DownloadStatsPoller on DownloadManager {
  List<DownloadTask> get _expectedActiveTasks => _tasks.values
      .where(
        (task) =>
            !_removedTaskIds.contains(task.id) &&
            !_pausedTaskIds.contains(task.id) &&
            task.taskType == DownloadTaskType.bt &&
            task.magnet.isNotEmpty &&
            (_isActiveStatus(task.status) ||
                task.status == DownloadTaskStatus.seeding),
      )
      .toList();

  bool get _hasPollingTasks => _tasks.values.any(
    (task) =>
        task.taskType == DownloadTaskType.bt &&
        (_isActiveStatus(task.status) ||
            task.status == DownloadTaskStatus.seeding),
  );

  /// Update stats from Rust backend
  Future<void> _updateStats() async {
    if (_isUpdatingStats) {
      return;
    }

    if (!_hasPollingTasks) {
      _ensureStatsPolling();
      return;
    }

    _isUpdatingStats = true;

    try {
      final stats = await _getTorrentStatsWithBackend();
      var hasChanges = false;
      var persistImmediately = false;
      final completedLibtorrentHashes = <String>[];

      for (final task in _tasks.values) {
        if (task.backend == BtBackendKind.rqbit &&
            task.status == DownloadTaskStatus.pending) {
          task.status = DownloadTaskStatus.metadata;
          hasChanges = true;
        }
      }

      for (final stat in stats) {
        final hashLower = stat.infoHash.toLowerCase();
        if (_removedTaskIds.contains(hashLower)) continue;

        if (!_tasks.containsKey(hashLower)) {
          debugPrint(
            '[DownloadManager] Skipping external torrent $hashLower — no magnet available',
          );
          continue;
        }

        final task = _tasks[hashLower]!;

        // Paused tasks: still let peers/totalSize/downloaded reflect reality,
        // but never flip the status or speed fields from the poll.
        if (_pausedTaskIds.contains(hashLower)) {
          final changed =
              task.downloaded != stat.downloaded ||
              task.totalSize != stat.totalSize ||
              task.peers != stat.peers;
          if (changed) {
            task.downloaded = stat.downloaded;
            task.totalSize = stat.totalSize;
            task.peers = stat.peers;
            hasChanges = true;
          }
          continue;
        }

        // Rust now returns a lowercase, stable state token.
        final state = stat.state;
        final shouldRecoverAutoPausedLibtorrent =
            task.backend == BtBackendKind.libtorrent && state == 'paused';
        final initializingStatus = task.backend == BtBackendKind.rqbit
            ? DownloadTaskStatus.metadata
            : DownloadTaskStatus.pending;
        if (shouldRecoverAutoPausedLibtorrent) {
          unawaited(_restoreLibtorrentBackgroundDownload(hashLower));
        }
        final nextStatus = stat.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : shouldRecoverAutoPausedLibtorrent
            ? DownloadTaskStatus.downloading
            : state == 'paused'
            ? DownloadTaskStatus.paused
            : state == 'metadata'
            ? DownloadTaskStatus.metadata
            : state == 'checking'
            ? DownloadTaskStatus.checking
            : state == 'initializing'
            ? initializingStatus
            : state == 'live'
            ? DownloadTaskStatus.downloading
            : state == 'error'
            ? DownloadTaskStatus.error
            : task.status;
        final completedNow =
            task.backend == BtBackendKind.libtorrent &&
            nextStatus == DownloadTaskStatus.seeding &&
            task.status != DownloadTaskStatus.seeding;

        // Use epsilon comparisons; otherwise FP noise makes every poll look
        // like a change and fires _notifyChanged() → a full UI rebuild every
        // 2 s, even for torrents whose speed is steady.
        const progressEps = 0.05; // 0.05 %
        const speedEps = 1024.0; // 1 KB/s
        final taskChanged =
            (task.progress - stat.progress).abs() > progressEps ||
            (task.downloadSpeed - stat.downloadSpeed).abs() > speedEps ||
            (task.uploadSpeed - stat.uploadSpeed).abs() > speedEps ||
            task.downloaded != stat.downloaded ||
            task.totalSize != stat.totalSize ||
            task.peers != stat.peers ||
            task.status != nextStatus;

        if (!taskChanged) continue;

        task.progress = stat.progress;
        task.downloadSpeed = stat.downloadSpeed;
        task.uploadSpeed = stat.uploadSpeed;
        task.downloaded = stat.downloaded;
        task.totalSize = stat.totalSize;
        task.peers = stat.peers;
        task.status = nextStatus;
        // Release download slot when BT task reaches a terminal state
        if (nextStatus == DownloadTaskStatus.seeding ||
            nextStatus == DownloadTaskStatus.paused ||
            nextStatus == DownloadTaskStatus.error) {
          _releaseSlotForTask(hashLower);
        }
        if (completedNow &&
            !_ltCompletionResumeSavedHashes.contains(hashLower)) {
          completedLibtorrentHashes.add(hashLower);
          persistImmediately = true;
        }
        hasChanges = true;
      }

      _ensureStatsPolling();

      if (hasChanges) {
        _notifyChanged();

        final now = DateTime.now();
        if (persistImmediately ||
            _lastStatsPersistenceAt == null ||
            now.difference(_lastStatsPersistenceAt!) >=
                const Duration(seconds: 10)) {
          _lastStatsPersistenceAt = now;
          await _saveTasks();
        }
      }

      for (final hash in completedLibtorrentHashes) {
        if (await _saveLibtorrentResumeDataForHash(hash, 'completed')) {
          _ltCompletionResumeSavedHashes.add(hash);
        }
      }

      _maybeSavePeriodicLibtorrentResumeData();
    } catch (e) {
      debugPrint('Error updating torrent stats: $e');
    } finally {
      _isUpdatingStats = false;
    }
  }

  Future<void> _handleAppResumedImpl() async {
    _ensureStatsPolling();

    final now = DateTime.now();
    if (_isRecoveringActiveTasks) {
      return;
    }
    if (_lastForegroundRecoveryAt != null &&
        now.difference(_lastForegroundRecoveryAt!) <
            const Duration(seconds: 3)) {
      unawaited(_updateStats());
      return;
    }

    _isRecoveringActiveTasks = true;
    _lastForegroundRecoveryAt = now;

    try {
      final stats = await _getTorrentStatsWithBackend();
      final statsByHash = <String, BtTorrentStats>{
        for (final stat in stats) stat.infoHash.toLowerCase(): stat,
      };
      final missingTasks = <DownloadTask>[];
      final pausedTaskIds = <String>[];

      for (final task in _expectedActiveTasks) {
        final stat = statsByHash[task.id.toLowerCase()];
        if (stat == null || stat.state == 'error') {
          missingTasks.add(task);
          continue;
        }
        if (stat.state == 'paused') {
          pausedTaskIds.add(task.id);
        }
      }

      for (final id in pausedTaskIds) {
        await resumeTask(id);
      }

      if (missingTasks.isNotEmpty) {
        await _runResumeQueue(missingTasks, _maxConcurrentDownloads);
      }
    } catch (e) {
      debugPrint('[DownloadManager] Error recovering tasks on resume: $e');
    } finally {
      _isRecoveringActiveTasks = false;
      await _updateStats();
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateStats();
    });
  }

  /// Starts polling if pollable tasks exist and timer is not running.
  void _ensureStatsPolling() {
    _syncAndroidDownloadService();
    if (!_hasPollingTasks) {
      stopStatsPolling();
    } else if (_statsTimer == null || !_statsTimer!.isActive) {
      _startStatsPolling();
    }
  }

  void _stopStatsPollingImpl() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _syncAndroidDownloadService();
  }
}
