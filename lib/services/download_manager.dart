import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart';

/// Key for storing BT download tasks in SharedPreferences
/// This key is NOT cleared by the cache clearing function
const String _btTasksStorageKey = 'bt_download_tasks_v1';

/// Base URL of the local rqbit streaming HTTP server (defined in Rust init).
const String _streamBaseUrl = 'http://127.0.0.1:3000';

/// Build the HTTP stream URL for a torrent + file index pair.
String _buildStreamUrl(String infoHash, int fileIdx) =>
    '$_streamBaseUrl/torrents/$infoHash/stream/$fileIdx';

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
  int? largestFileIdx; // Persisted so streamUrl can be synthesized after restart.
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
    this.largestFileIdx,
    this.errorMessage,
  }) : downloaded = downloaded ?? BigInt.zero,
       totalSize = totalSize ?? BigInt.zero;

  /// Create from JSON (for persistence)
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final largestFileIdx = (json['largestFileIdx'] as num?)?.toInt();
    // Reconstruct the stream URL immediately when we know the file index.
    // The rqbit HTTP server is started synchronously during initEngine, and
    // once the torrent is re-added by [_resumeTorrentInBackground], this URL
    // is valid. For paused tasks it won't be hit until the user resumes.
    final streamUrl = largestFileIdx != null
        ? _buildStreamUrl(id, largestFileIdx)
        : null;
    return DownloadTask(
      id: id,
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
      streamUrl: streamUrl,
      largestFileIdx: largestFileIdx,
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
      'largestFileIdx': largestFileIdx,
      // streamUrl intentionally omitted — reconstructed from id + largestFileIdx
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
  bool _isUpdatingStats = false;
  bool _isRecoveringActiveTasks = false;
  DateTime? _lastForegroundRecoveryAt;

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

  List<DownloadTask> get _expectedActiveTasks => _tasks.values
      .where(
        (task) =>
            !_removedTaskIds.contains(task.id) &&
            !_pausedTaskIds.contains(task.id) &&
            task.magnet.isNotEmpty &&
            (task.status == DownloadTaskStatus.pending ||
                task.status == DownloadTaskStatus.downloading ||
                task.status == DownloadTaskStatus.seeding),
      )
      .toList();

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
        final toResume = <DownloadTask>[];
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
          unawaited(_runResumeQueue(toResume, 3));
        }
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
        task.largestFileIdx =
            _extractFileIdxFromUrl(streamUrl) ?? task.largestFileIdx;
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
      final fileIdx = _extractFileIdxFromUrl(streamUrl);
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
        task.status = DownloadTaskStatus.downloading;
        _tasks[actualId] = task;
      } else {
        task.streamUrl = streamUrl;
        task.largestFileIdx = fileIdx ?? task.largestFileIdx;
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
    if (_isUpdatingStats) {
      return;
    }

    if (!_hasPollingTasks) {
      _ensureStatsPolling();
      return;
    }

    _isUpdatingStats = true;

    try {
      final stats = await getTorrentStats();
      var hasChanges = false;

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
          final changed = task.downloaded != stat.downloaded ||
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
        final nextStatus = stat.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : state == 'paused'
                ? DownloadTaskStatus.paused
                : state == 'live'
                    ? DownloadTaskStatus.downloading
                    : state == 'error'
                        ? DownloadTaskStatus.error
                        : task.status;

        // Use epsilon comparisons; otherwise FP noise makes every poll look
        // like a change and fires notifyListeners() → a full UI rebuild every
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
        hasChanges = true;
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
    } finally {
      _isUpdatingStats = false;
    }
  }

  Future<void> handleAppResumed() async {
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
      final stats = await getTorrentStats();
      final statsByHash = <String, TorrentStats>{
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
        await _runResumeQueue(missingTasks, 2);
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

  /// Extract file index from stream URL (e.g. `.../stream/0` → 0)
  int? _extractFileIdxFromUrl(String url) {
    final regex = RegExp(r'/stream/(\d+)(?:[/?#]|$)');
    final match = regex.firstMatch(url);
    final raw = match?.group(1);
    return raw == null ? null : int.tryParse(raw);
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
        final fileIdx = _extractFileIdxFromUrl(streamUrl);
        if (actualId != id) {
          _tasks.remove(id);
          _pausedTaskIds.remove(id);
          task.id = actualId;
          _tasks[actualId] = task;
        }
        _removedTaskIds.remove(task.id);
        task.status = task.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : DownloadTaskStatus.downloading;
        task.streamUrl = streamUrl;
        task.largestFileIdx = fileIdx ?? task.largestFileIdx;
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
          _noteOrphanedFiles(task!);
        }
      }
    } catch (e) {
      debugPrint('[DownloadManager] Error stopping torrent: $e');
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
