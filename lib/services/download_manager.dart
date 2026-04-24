import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart';

/// Key for storing BT download tasks in SharedPreferences
/// This key is NOT cleared by the cache clearing function
const String _btTasksStorageKey = 'bt_download_tasks_v1';

/// Represents a download task
class DownloadTask {
  String id; // info_hash
  final String name;
  final String magnet;
  final String? animeName;
  final int? episodeNumber;
  final DateTime startTime;

  DownloadTaskStatus status;
  double progress;
  double downloadSpeed; // bytes per second
  double uploadSpeed; // bytes per second
  BigInt downloaded;
  BigInt totalSize;
  int peers;
  String? streamUrl;
  String? errorMessage;

  DownloadTask({
    required this.id,
    required this.name,
    required this.magnet,
    this.animeName,
    this.episodeNumber,
    required this.startTime,
    this.status = DownloadTaskStatus.pending,
    this.progress = 0.0,
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    BigInt? downloaded,
    BigInt? totalSize,
    this.peers = 0,
    this.streamUrl,
    this.errorMessage,
  }) : downloaded = downloaded ?? BigInt.zero,
       totalSize = totalSize ?? BigInt.zero;

  /// Create from JSON (for persistence)
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      name: json['name'] as String,
      magnet: json['magnet'] as String,
      animeName: json['animeName'] as String?,
      episodeNumber: json['episodeNumber'] as int?,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      status: DownloadTaskStatus.values[json['status'] as int],
      progress: (json['progress'] as num).toDouble(),
      downloadSpeed: 0.0, // Reset speed on load
      uploadSpeed: 0.0,
      downloaded: BigInt.parse(json['downloaded'] as String? ?? '0'),
      totalSize: BigInt.parse(json['totalSize'] as String? ?? '0'),
      peers: 0,
      streamUrl: null, // Never restore streamUrl from disk; it expires on restart
      errorMessage: null,
    );
  }

  /// Convert to JSON (for persistence)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'magnet': magnet,
      'animeName': animeName,
      'episodeNumber': episodeNumber,
      'startTime': startTime.millisecondsSinceEpoch,
      'status': status.index,
      'progress': progress,
      'downloaded': downloaded.toString(),
      'totalSize': totalSize.toString(),
      // streamUrl intentionally omitted — it is session-only
    };
  }

  String get formattedSpeed {
    if (downloadSpeed < 1024) {
      return '${downloadSpeed.toStringAsFixed(1)} B/s';
    } else if (downloadSpeed < 1024 * 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(downloadSpeed / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
  }

  String get formattedUploadSpeed {
    if (uploadSpeed < 1024) {
      return '${uploadSpeed.toStringAsFixed(1)} B/s';
    } else if (uploadSpeed < 1024 * 1024) {
      return '${(uploadSpeed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(uploadSpeed / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
  }

  String get formattedSize {
    final total = totalSize.toInt();
    if (total < 1024) {
      return '$total B';
    } else if (total < 1024 * 1024) {
      return '${(total / 1024).toStringAsFixed(1)} KB';
    } else if (total < 1024 * 1024 * 1024) {
      return '${(total / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(total / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  String get formattedDownloaded {
    final dl = downloaded.toInt();
    if (dl < 1024) {
      return '$dl B';
    } else if (dl < 1024 * 1024) {
      return '${(dl / 1024).toStringAsFixed(1)} KB';
    } else if (dl < 1024 * 1024 * 1024) {
      return '${(dl / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(dl / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  /// Check if this task is completed (100% progress)
  bool get isCompleted => progress >= 100.0;

  /// Check if this task is actively downloading or seeding
  bool get isActive =>
      status == DownloadTaskStatus.downloading ||
      status == DownloadTaskStatus.seeding;
}

enum DownloadTaskStatus {
  pending,
  downloading,
  seeding,
  paused,
  completed,
  error,
}

/// Global download manager singleton
class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Map<String, DownloadTask> _tasks = {};
  final Set<String> _removedTaskIds =
      {}; // Track removed tasks to prevent re-adding
  final Set<String> _pausedTaskIds = {}; // Track paused tasks
  Timer? _statsTimer;
  bool _isInitialized = false;
  DateTime? _lastStatsPersistenceAt;

  List<DownloadTask> get tasks => _tasks.values.toList();

  /// Active tasks: downloading only (not seeding)
  List<DownloadTask> get activeTasks => _tasks.values
      .where(
        (t) =>
            t.status == DownloadTaskStatus.downloading ||
            t.status == DownloadTaskStatus.pending,
      )
      .toList();

  /// Seeding tasks (completed and uploading)
  List<DownloadTask> get seedingTasks => _tasks.values
      .where((t) => t.status == DownloadTaskStatus.seeding)
      .toList();

  /// All active or seeding tasks count (for badge)
  int get activeCount => activeTasks.length;

  /// Count of seeding tasks
  int get seedingCount => seedingTasks.length;

  bool get _hasPollingTasks => _tasks.values.any(
    (task) =>
        task.status == DownloadTaskStatus.pending ||
        task.status == DownloadTaskStatus.downloading ||
        task.status == DownloadTaskStatus.seeding,
  );

  /// Initialize the download manager, load saved tasks
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadTasks();
    _isInitialized = true;
    _ensureStatsPolling();
  }

  /// Load tasks from SharedPreferences
  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_btTasksStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        var removedInvalidTasks = false;
        for (final json in jsonList) {
          final task = DownloadTask.fromJson(json as Map<String, dynamic>);

          if (task.magnet.isEmpty) {
            removedInvalidTasks = true;
            continue;
          }

          _tasks[task.id] = task;

          // Track paused tasks
          if (task.status == DownloadTaskStatus.paused) {
            _pausedTaskIds.add(task.id);
          }

          // Auto-resume torrents that were downloading or seeding
          // This ensures they continue after app restart
          if (task.magnet.isNotEmpty &&
              (task.status == DownloadTaskStatus.downloading ||
                  task.status == DownloadTaskStatus.seeding ||
                  task.status == DownloadTaskStatus.completed)) {
            // Resume in background without blocking
            _resumeTorrentInBackground(task);
          }
        }
        if (removedInvalidTasks) {
          await _saveTasks();
        }
        debugPrint(
          '[DownloadManager] Loaded ${_tasks.length} tasks from storage',
        );
      }
    } catch (e) {
      debugPrint('[DownloadManager] Error loading tasks: $e');
    }
    notifyListeners();
  }

  /// Resume a torrent in the background after app restart
  Future<void> _resumeTorrentInBackground(DownloadTask task) async {
    try {
      debugPrint('[DownloadManager] Auto-resuming torrent: ${task.name}');
      final streamUrl = await startTorrent(magnet: task.magnet);
      if (!streamUrl.startsWith('Error')) {
        task.streamUrl = streamUrl;
        // Update status but don't change if it was completed/seeding
        if (task.status != DownloadTaskStatus.seeding &&
            task.status != DownloadTaskStatus.completed) {
          task.status = DownloadTaskStatus.downloading;
        }
        await _saveTasks();
        notifyListeners();
        _ensureStatsPolling();
        debugPrint('[DownloadManager] Auto-resumed torrent: ${task.name}');
      } else {
        debugPrint(
          '[DownloadManager] Failed to auto-resume torrent: $streamUrl',
        );
      }
    } catch (e) {
      debugPrint('[DownloadManager] Error auto-resuming torrent: $e');
    }
  }

  /// Save tasks to SharedPreferences
  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _tasks.values.map((t) => t.toJson()).toList();
      await prefs.setString(_btTasksStorageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[DownloadManager] Error saving tasks: $e');
    }
  }

  /// Find a task by anime name and episode number
  DownloadTask? findTaskByAnimeEpisode(String? animeName, int? episodeNumber) {
    if (animeName == null) return null;

    for (final task in _tasks.values) {
      if (task.animeName == animeName && task.episodeNumber == episodeNumber) {
        return task;
      }
    }
    return null;
  }

  /// Find all tasks for an anime
  List<DownloadTask> findTasksByAnime(String? animeName) {
    if (animeName == null) return [];

    return _tasks.values.where((t) => t.animeName == animeName).toList();
  }

  /// Check if there's an available (downloading/seeding/completed) task for the anime episode
  DownloadTask? getAvailableTaskForEpisode(
    String? animeName,
    int? episodeNumber,
  ) {
    final task = findTaskByAnimeEpisode(animeName, episodeNumber);
    if (task == null) return null;

    // Only return if the task is in a playable state
    if (task.status == DownloadTaskStatus.downloading ||
        task.status == DownloadTaskStatus.seeding ||
        task.status == DownloadTaskStatus.completed ||
        (task.status == DownloadTaskStatus.paused && task.progress > 0)) {
      return task;
    }
    return null;
  }

  /// Start a new download/streaming task
  Future<String?> startDownload({
    required String magnet,
    required String name,
    String? animeName,
    int? episodeNumber,
  }) async {
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
        if (resumed) {
          return existingTask.streamUrl;
        }
      }
      if (existingTask.streamUrl != null &&
          existingTask.streamUrl!.isNotEmpty) {
        debugPrint(
          '[DownloadManager] Torrent already active: ${existingTask.name}',
        );
        return existingTask.streamUrl;
      }
    }

    // Create new task
    final task = DownloadTask(
      id: tempId,
      name: name,
      magnet: magnet,
      animeName: animeName,
      episodeNumber: episodeNumber,
      startTime: DateTime.now(),
      status: DownloadTaskStatus.pending,
    );

    _tasks[tempId] = task;
    await _saveTasks();
    notifyListeners();
    _ensureStatsPolling();

    try {
      // Call Rust backend to start torrent
      final streamUrl = await startTorrent(magnet: magnet);

      final currentTask = _tasks[tempId];
      if (!identical(currentTask, task) || _removedTaskIds.contains(tempId)) {
        final actualId = _extractInfoHashFromUrl(streamUrl);
        if (_removedTaskIds.contains(tempId) && actualId != null) {
          _removedTaskIds.add(actualId);
        }
        return null;
      }

      if (streamUrl.startsWith('Error')) {
        task.status = DownloadTaskStatus.error;
        task.errorMessage = streamUrl;
        await _saveTasks();
        notifyListeners();
        return null;
      }

      // Update task with actual info
      final actualId = _extractInfoHashFromUrl(streamUrl) ?? tempId;
      if (actualId != tempId) {
        _tasks.remove(tempId);
        _removedTaskIds.remove(
          tempId,
        ); // Also remove the temp ID from removed set
        task.id = actualId; // Update the task's ID to the actual info hash
        // Remove actual ID from removed set in case it was previously deleted
        _removedTaskIds.remove(actualId);
        task.streamUrl = streamUrl;
        task.status = DownloadTaskStatus.downloading;
        _tasks[actualId] = task;
      } else {
        task.streamUrl = streamUrl;
        task.status = DownloadTaskStatus.downloading;
      }

      notifyListeners();
      await _saveTasks();
      return streamUrl;
    } catch (e) {
      final currentTask = _tasks[tempId];
      if (!identical(currentTask, task) || _removedTaskIds.contains(tempId)) {
        return null;
      }
      task.status = DownloadTaskStatus.error;
      task.errorMessage = e.toString();
      await _saveTasks();
      notifyListeners();
      return null;
    }
  }

  /// Update stats from Rust backend
  Future<void> _updateStats() async {
    if (!_hasPollingTasks) {
      _ensureStatsPolling();
      return;
    }

    try {
      final stats = await getTorrentStats();
      var hasChanges = false;

      for (final stat in stats) {
        final hashLower = stat.infoHash.toLowerCase();

        // Skip if this task was manually removed
        if (_removedTaskIds.contains(hashLower)) {
          continue;
        }

        if (_tasks.containsKey(hashLower)) {
          final task = _tasks[hashLower]!;

          // Skip status update if task is paused (user explicitly paused it)
          if (_pausedTaskIds.contains(hashLower)) {
            continue;
          }

          final nextStatus = stat.progress >= 100.0
              ? DownloadTaskStatus.seeding
              : stat.state.contains('Paused')
                  ? DownloadTaskStatus.paused
                  : stat.state.contains('Live')
                      ? DownloadTaskStatus.downloading
                      : task.status;

          final taskChanged = task.progress != stat.progress ||
              task.downloadSpeed != stat.downloadSpeed ||
              task.uploadSpeed != stat.uploadSpeed ||
              task.downloaded != stat.downloaded ||
              task.totalSize != stat.totalSize ||
              task.peers != stat.peers ||
              task.status != nextStatus;

          if (!taskChanged) {
            continue;
          }

          task.progress = stat.progress;
          task.downloadSpeed = stat.downloadSpeed;
          task.uploadSpeed = stat.uploadSpeed;
          task.downloaded = stat.downloaded;
          task.totalSize = stat.totalSize;
          task.peers = stat.peers;
          task.status = nextStatus;
          hasChanges = true;
        } else {
          // Skip auto-creating tasks from external stats without a known magnet.
          // A task with magnet: '' cannot be resumed and pollutes the list.
          debugPrint(
            '[DownloadManager] Skipping external torrent $hashLower — no magnet available',
          );
        }
      }

      _ensureStatsPolling();

      if (hasChanges) {
        notifyListeners();

        final now = DateTime.now();
        if (_lastStatsPersistenceAt == null ||
            now.difference(_lastStatsPersistenceAt!) >=
                const Duration(seconds: 10)) {
          _lastStatsPersistenceAt = now;
          await _saveTasks();
        }
      }
    } catch (e) {
      debugPrint('Error updating torrent stats: $e');
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateStats();
    });
  }

  /// Starts polling if pollable tasks exist and timer is not running.
  void _ensureStatsPolling() {
    if (!_hasPollingTasks) {
      stopStatsPolling();
    } else if (_statsTimer == null || !_statsTimer!.isActive) {
      _startStatsPolling();
    }
  }

  void stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  /// Extract info hash from magnet link.
  String? _extractInfoHash(String magnet) {
    final btmh = RegExp(r'btmh:1220([a-fA-F0-9]{64})');
    final hex64 = RegExp(r'btih:([a-fA-F0-9]{64})');
    final base32 = RegExp(r'btih:([A-Za-z2-7]{32})');
    final hex40 = RegExp(r'btih:([a-fA-F0-9]{40})(?![a-fA-F0-9])');

    for (final regex in [btmh, hex64, base32, hex40]) {
      final match = regex.firstMatch(magnet);
      if (match != null) {
        return match.group(1)!.toLowerCase();
      }
    }
    return null;
  }

  /// Extract info hash from stream URL
  String? _extractInfoHashFromUrl(String url) {
    final regex = RegExp(r'/torrents/([a-fA-F0-9]+)/');
    final match = regex.firstMatch(url);
    return match?.group(1)?.toLowerCase();
  }

  /// Pause a download task
  /// This stops the torrent without deleting files
  Future<bool> pauseTask(String id) async {
    if (!_tasks.containsKey(id)) return false;

    try {
      // Pause by calling the Rust pause_torrent function
      // which internally stops the torrent without deleting files
      final success = await pauseTorrent(infoHash: id);
      if (success) {
        _tasks[id]!.status = DownloadTaskStatus.paused;
        _tasks[id]!.downloadSpeed = 0;
        _tasks[id]!.uploadSpeed = 0;
        _pausedTaskIds.add(id);
        await _saveTasks();
        notifyListeners();
        _ensureStatsPolling();
        debugPrint('[DownloadManager] Paused task: $id');
      }
      return success;
    } catch (e) {
      debugPrint('[DownloadManager] Error pausing task: $e');
      return false;
    }
  }

  /// Resume a paused download task
  /// Uses the backend pause/unpause path when possible. If the app was
  /// restarted and the paused torrent is no longer in the backend session,
  /// it falls back to restarting the torrent from the saved magnet link.
  Future<bool> resumeTask(String id) async {
    if (!_tasks.containsKey(id)) return false;

    final task = _tasks[id]!;

    try {
      final resumed = await resumeTorrent(infoHash: id);
      if (resumed) {
        task.status = task.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : DownloadTaskStatus.downloading;
        _pausedTaskIds.remove(id);
        await _saveTasks();
        notifyListeners();
        _ensureStatsPolling();
        debugPrint('[DownloadManager] Resumed task: $id');
        return true;
      }

      if (task.magnet.isEmpty) {
        debugPrint('[DownloadManager] Cannot resume task without magnet link');
        return false;
      }

      final streamUrl = await startTorrent(magnet: task.magnet);
      if (!streamUrl.startsWith('Error')) {
        final actualId = _extractInfoHashFromUrl(streamUrl) ?? id;
        if (actualId != id) {
          _tasks.remove(id);
          _pausedTaskIds.remove(id);
          _removedTaskIds.remove(id);
          task.id = actualId;
          _tasks[actualId] = task;
        }
        task.status = task.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : DownloadTaskStatus.downloading;
        task.streamUrl = streamUrl;
        _pausedTaskIds.remove(task.id);
        await _saveTasks();
        notifyListeners();
        _ensureStatsPolling();
        debugPrint('[DownloadManager] Restarted paused task: ${task.id}');
        return true;
      } else {
        debugPrint('[DownloadManager] Failed to resume task: $streamUrl');
      }
      return false;
    } catch (e) {
      debugPrint('[DownloadManager] Error resuming task: $e');
      return false;
    }
  }

  /// Remove a download task
  Future<void> removeTask(String id, {bool deleteFiles = false}) async {
    final task = _tasks[id];

    // Remove from UI immediately so the task disappears right away.
    _tasks.remove(id);
    _pausedTaskIds.remove(id);
    _removedTaskIds.add(id); // Mark as removed to prevent re-adding
    await _saveTasks();
    notifyListeners();
    _ensureStatsPolling();

    // Try to stop the torrent in the backend
    try {
      final stopped = await stopTorrent(infoHash: id, deleteFiles: deleteFiles);
      if (stopped) {
        debugPrint(
          '[DownloadManager] Successfully stopped torrent: $id (deleteFiles: $deleteFiles)',
        );
      } else {
        debugPrint(
          '[DownloadManager] Failed to stop torrent (may not exist): $id',
        );
        if (deleteFiles && task?.magnet.isNotEmpty == true) {
          await _deleteFilesForMissingTorrent(task!);
        }
      }
    } catch (e) {
      debugPrint('[DownloadManager] Error stopping torrent: $e');
    }
  }

  /// Best-effort cleanup for paused tasks restored from storage.
  /// After an app restart, a paused torrent may not exist in the backend
  /// session anymore, so rqbit needs the magnet metadata before it can remove
  /// the files it created.
  Future<void> _deleteFilesForMissingTorrent(DownloadTask task) async {
    try {
      debugPrint(
        '[DownloadManager] Re-attaching missing torrent for file cleanup: ${task.id}',
      );
      final streamUrl = await startTorrent(magnet: task.magnet);
      if (streamUrl.startsWith('Error')) {
        debugPrint(
          '[DownloadManager] Failed to re-attach torrent for cleanup: $streamUrl',
        );
        return;
      }

      final actualId = _extractInfoHashFromUrl(streamUrl) ?? task.id;
      await stopTorrent(infoHash: actualId, deleteFiles: true);
      _removedTaskIds.add(actualId);
      debugPrint(
        '[DownloadManager] Cleaned up files for missing torrent: $actualId',
      );
    } catch (e) {
      debugPrint('[DownloadManager] Error cleaning up missing torrent: $e');
    }
  }

  /// Clear completed tasks
  Future<void> clearCompleted({bool deleteFiles = false}) async {
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
      try {
        await stopTorrent(infoHash: id, deleteFiles: deleteFiles);
      } catch (e) {
        debugPrint('[DownloadManager] Error stopping torrent $id: $e');
      }
      _tasks.remove(id);
      _pausedTaskIds.remove(id);
      _removedTaskIds.add(id); // Mark as removed
    }
    await _saveTasks();
    notifyListeners();
    _ensureStatsPolling();
  }

  @override
  void dispose() {
    stopStatsPolling();
    _saveTasks(); // Save before disposing
    super.dispose();
  }
}
