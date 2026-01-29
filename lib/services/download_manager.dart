import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/src/rust/api/simple.dart';

/// Represents a download task
class DownloadTask {
  final String id; // info_hash
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

  String get formattedSpeed {
    if (downloadSpeed < 1024) {
      return '${downloadSpeed.toStringAsFixed(1)} B/s';
    } else if (downloadSpeed < 1024 * 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(downloadSpeed / 1024 / 1024).toStringAsFixed(2)} MB/s';
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
  Timer? _statsTimer;

  List<DownloadTask> get tasks => _tasks.values.toList();
  List<DownloadTask> get activeTasks => _tasks.values
      .where(
        (t) =>
            t.status == DownloadTaskStatus.downloading ||
            t.status == DownloadTaskStatus.seeding ||
            t.status == DownloadTaskStatus.pending,
      )
      .toList();

  int get activeCount => activeTasks.length;

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

    // Check if already downloading
    if (_tasks.containsKey(tempId)) {
      final existingTask = _tasks[tempId]!;
      if (existingTask.streamUrl != null) {
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
    notifyListeners();
    _startStatsPolling();

    try {
      // Call Rust backend to start torrent
      final streamUrl = await startTorrent(magnet: magnet);

      if (streamUrl.startsWith('Error')) {
        task.status = DownloadTaskStatus.error;
        task.errorMessage = streamUrl;
        notifyListeners();
        return null;
      }

      // Update task with actual info
      final actualId = _extractInfoHashFromUrl(streamUrl) ?? tempId;
      if (actualId != tempId) {
        _tasks.remove(tempId);
        task.streamUrl = streamUrl;
        task.status = DownloadTaskStatus.downloading;
        _tasks[actualId] = task;
      } else {
        task.streamUrl = streamUrl;
        task.status = DownloadTaskStatus.downloading;
      }

      notifyListeners();
      return streamUrl;
    } catch (e) {
      task.status = DownloadTaskStatus.error;
      task.errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Update stats from Rust backend
  Future<void> _updateStats() async {
    try {
      final stats = await getTorrentStats();

      for (final stat in stats) {
        // Skip if this task was manually removed
        if (_removedTaskIds.contains(stat.infoHash)) {
          continue;
        }

        if (_tasks.containsKey(stat.infoHash)) {
          final task = _tasks[stat.infoHash]!;
          task.progress = stat.progress;
          task.downloadSpeed = stat.downloadSpeed;
          task.uploadSpeed = stat.uploadSpeed;
          task.downloaded = stat.downloaded;
          task.totalSize = stat.totalSize;
          task.peers = stat.peers;

          // Update status based on progress
          if (stat.progress >= 100.0) {
            task.status = DownloadTaskStatus.seeding;
          } else if (stat.state.contains('Live')) {
            task.status = DownloadTaskStatus.downloading;
          }
        } else {
          // Add task that was started externally or from a previous session
          final newTask = DownloadTask(
            id: stat.infoHash,
            name: stat.name,
            magnet: '', // Unknown
            startTime: DateTime.now(),
            status: stat.progress >= 100.0
                ? DownloadTaskStatus.seeding
                : DownloadTaskStatus.downloading,
            progress: stat.progress,
            downloadSpeed: stat.downloadSpeed,
            uploadSpeed: stat.uploadSpeed,
            downloaded: stat.downloaded,
            totalSize: stat.totalSize,
            peers: stat.peers,
            streamUrl:
                'http://127.0.0.1:3000/torrents/${stat.infoHash}/stream/0',
          );
          _tasks[stat.infoHash] = newTask;
        }
      }

      notifyListeners();
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

  void stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  /// Extract info hash from magnet link
  String? _extractInfoHash(String magnet) {
    final regex = RegExp(r'btih:([a-fA-F0-9]{40})');
    final match = regex.firstMatch(magnet);
    return match?.group(1)?.toLowerCase();
  }

  /// Extract info hash from stream URL
  String? _extractInfoHashFromUrl(String url) {
    final regex = RegExp(r'/torrents/([a-fA-F0-9]+)/');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Remove a download task
  Future<void> removeTask(String id, {bool deleteFiles = false}) async {
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
      }
    } catch (e) {
      debugPrint('[DownloadManager] Error stopping torrent: $e');
    }

    // Remove from UI regardless of backend result
    _tasks.remove(id);
    _removedTaskIds.add(id); // Mark as removed to prevent re-adding
    notifyListeners();
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
      _removedTaskIds.add(id); // Mark as removed
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stopStatsPolling();
    super.dispose();
  }
}
