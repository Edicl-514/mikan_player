import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/native/mikan_libtorrent_native.dart';
import 'package:mikan_player/utils/app_directories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart';

/// Key for storing BT download tasks in SharedPreferences
/// This key is NOT cleared by the cache clearing function
const String _btTasksStorageKey = 'bt_download_tasks_v1';
const String _btBackendStorageKey = 'bt_backend_v1';

enum BtBackendKind { rqbit, libtorrent }

extension BtBackendKindX on BtBackendKind {
  String get storageValue => switch (this) {
    BtBackendKind.rqbit => 'rqbit',
    BtBackendKind.libtorrent => 'libtorrent',
  };

  String get label => switch (this) {
    BtBackendKind.rqbit => 'rqbit',
    BtBackendKind.libtorrent => 'libtorrent',
  };

  static BtBackendKind fromStorage(String? value) {
    return switch (value) {
      'libtorrent' => BtBackendKind.libtorrent,
      _ => BtBackendKind.rqbit,
    };
  }
}

class _BackendStartResult {
  final String infoHash;
  final String? streamUrl;
  final int? fileIdx;
  final int? fileSize;
  final int? torrentId;
  final int? streamId;

  const _BackendStartResult({
    required this.infoHash,
    this.streamUrl,
    this.fileIdx,
    this.fileSize,
    this.torrentId,
    this.streamId,
  });
}

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
  int?
  largestFileIdx; // Persisted so streamUrl can be synthesized after restart.
  BtBackendKind backend;
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
    this.backend = BtBackendKind.rqbit,
    this.errorMessage,
  }) : downloaded = downloaded ?? BigInt.zero,
       totalSize = totalSize ?? BigInt.zero;

  /// Create from JSON (for persistence)
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final largestFileIdx = (json['largestFileIdx'] as num?)?.toInt();
    final backend = BtBackendKindX.fromStorage(json['backend'] as String?);
    // Reconstruct the stream URL immediately when we know the file index.
    // The rqbit HTTP server is started synchronously during initEngine, and
    // once the torrent is re-added by [_resumeTorrentInBackground], this URL
    // is valid. For paused tasks it won't be hit until the user resumes.
    final streamUrl = backend == BtBackendKind.rqbit && largestFileIdx != null
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
      backend: backend,
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
      'backend': backend.storageValue,
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
  BtBackendKind _backendKind = BtBackendKind.rqbit;
  bool _libtorrentInitialized = false;
  Future<void>? _libtorrentInitialization;
  MikanLibtorrentSession? _nativeSession;
  String? _downloadDir;
  final Map<String, int> _ltTorrentIdsByHash = {};
  final Map<int, String> _ltInfoHashesByTorrentId = {};
  final Map<String, int> _ltStreamIdsByHash = {};
  final Map<String, int> _ltFileIdxByHash = {};
  final Map<String, int> _ltFileSizeByHash = {};
  final Set<String> _ltPriorityRecoveryHashes = {};
  final Set<String> _activeStreamHashes = {}; // Track active playback streams

  List<DownloadTask> get tasks => _tasks.values.toList();
  BtBackendKind get backendKind => _backendKind;

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

    final prefs = await SharedPreferences.getInstance();
    _backendKind = BtBackendKindX.fromStorage(
      prefs.getString(_btBackendStorageKey),
    );
    if (_backendKind == BtBackendKind.libtorrent) {
      unawaited(_ensureLibtorrentInitialized());
    }
    await _loadTasks();
    _isInitialized = true;
    _ensureStatsPolling();
  }

  Future<void> setBackendKind(BtBackendKind backend) async {
    if (_backendKind == backend) return;
    _backendKind = backend;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_btBackendStorageKey, backend.storageValue);
    if (backend == BtBackendKind.libtorrent) {
      unawaited(_ensureLibtorrentInitialized());
    }
    notifyListeners();
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
      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: task.id,
        backend: task.backend,
        startStream: false,
      );
      if (result.streamUrl != null) {
        task.streamUrl = result.streamUrl;
      }
      task.largestFileIdx = result.fileIdx ?? task.largestFileIdx;
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
      if (task.status != DownloadTaskStatus.seeding &&
          task.status != DownloadTaskStatus.completed) {
        task.status = DownloadTaskStatus.downloading;
      }
      await _saveTasks();
      notifyListeners();
      _ensureStatsPolling();
      debugPrint('[DownloadManager] Auto-resumed torrent: ${task.name}');
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

  Future<void> _ensureLibtorrentInitialized() async {
    if (_libtorrentInitialized) return;
    final pending = _libtorrentInitialization;
    if (pending != null) {
      await pending;
      return;
    }

    final initialization = _initializeLibtorrent();
    _libtorrentInitialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _libtorrentInitialization = null;
      rethrow;
    }
  }

  Future<void> _initializeLibtorrent() async {
    final appSupportDir = await AppDirectories.getUnifiedAppDataDirectory();
    _downloadDir = '${appSupportDir.path}/downloads';
    _nativeSession = MikanLibtorrentNative.instance.createSession(
      listenInterfaces: '0.0.0.0:6881',
    );
    _nativeSession!.configureSession(
      connectionsLimit: 50,
      enableDht: true,
      enableLsd: true,
      enableUpnp: true,
      enableNatPmp: true,
    );
    _libtorrentInitialized = true;
    debugPrint(
      '[DownloadManager] libtorrent initialized: '
      '${MikanLibtorrentNative.instance.version}',
    );
  }

  Future<_BackendStartResult> _startTorrentWithBackend(
    String magnet, {
    required String fallbackInfoHash,
    required BtBackendKind backend,
    bool startStream = true,
  }) async {
    if (backend == BtBackendKind.rqbit) {
      final streamUrl = await startTorrent(magnet: magnet);
      if (streamUrl.startsWith('Error')) {
        throw Exception(streamUrl);
      }
      return _BackendStartResult(
        infoHash: _extractInfoHashFromUrl(streamUrl) ?? fallbackInfoHash,
        streamUrl: streamUrl,
        fileIdx: _extractFileIdxFromUrl(streamUrl),
      );
    }

    await _ensureLibtorrentInitialized();
    final session = _nativeSession!;
    final infoHash = fallbackInfoHash.toLowerCase();
    var torrentId = _ltTorrentIdsByHash[infoHash];
    if (torrentId == null || !_isNativeTorrentValid(torrentId)) {
      torrentId = session.addMagnet(magnet, savePath: _downloadDir);
      _ltTorrentIdsByHash[infoHash] = torrentId;
      _ltInfoHashesByTorrentId[torrentId] = infoHash;
    }

    await _waitForLibtorrentMetadata(torrentId);
    final file = _selectLibtorrentFile(torrentId);
    if (file == null) {
      throw Exception('Error: No streamable files found in torrent');
    }

    await _prioritizeLibtorrentDownloadFile(torrentId, file.index);
    // Explicitly resume: without auto_managed the torrent won't start on its own.
    session.resumeTorrent(torrentId);

    if (!startStream) {
      _ltFileIdxByHash[infoHash] = file.index;
      _ltFileSizeByHash[infoHash] = file.size;
      return _BackendStartResult(
        infoHash: infoHash,
        fileIdx: file.index,
        fileSize: file.size,
        torrentId: torrentId,
      );
    }

    _stopLibtorrentStreamForHash(infoHash);
    final stream = session.startStream(
      torrentId,
      fileIndex: file.index,
      maxCacheBytes: 16 * 1024 * 1024,
    );
    _warmUpLibtorrentStream(stream);
    _ltStreamIdsByHash[infoHash] = stream.id;
    _ltFileIdxByHash[infoHash] = file.index;
    _ltFileSizeByHash[infoHash] = file.size;

    return _BackendStartResult(
      infoHash: infoHash,
      streamUrl: stream.url,
      fileIdx: file.index,
      fileSize: file.size,
      torrentId: torrentId,
      streamId: stream.id,
    );
  }

  Future<void> _waitForLibtorrentMetadata(int torrentId) async {
    final session = _nativeSession!;
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      final stats = session.getTorrentStats();
      final torrent = stats.where((s) => s.torrentId == torrentId).firstOrNull;
      if (torrent != null && torrent.hasMetadata) return;
      if (torrent != null && torrent.errorMessage.isNotEmpty) {
        throw Exception(
          'Error getting torrent metadata: ${torrent.errorMessage}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw Exception(
      'Error adding torrent: timed out waiting for torrent metadata',
    );
  }

  void _warmUpLibtorrentStream(MikanLtStreamInfo stream) {
    final session = _nativeSession!;
    try {
      session.setStreamCache(
        stream.id,
        capacity: 16 * 1024 * 1024,
        readAheadPct: 0,
        connectionsLimit: 50,
      );
      session.preloadStream(stream.id, preloadBytes: 4 * 1024 * 1024);
    } catch (e) {
      debugPrint('[DownloadManager] Error warming up libtorrent stream: $e');
    }
  }

  MikanLtFileInfo? _selectLibtorrentFile(int torrentId) {
    final files = _nativeSession!.getFiles(torrentId);
    final streamable = files.where((f) => f.isStreamable).toList();
    final candidates = streamable.isNotEmpty ? streamable : files;
    MikanLtFileInfo? largest;
    for (final file in candidates) {
      if (largest == null || file.size > largest.size) {
        largest = file;
      }
    }
    return largest;
  }

  bool _isNativeTorrentValid(int torrentId) {
    if (_nativeSession == null) return false;
    try {
      final stats = _nativeSession!.getTorrentStats();
      return stats.any((s) => s.torrentId == torrentId);
    } catch (_) {
      return false;
    }
  }

  /// Find a native torrent ID by info hash when the in-memory mapping is lost
  /// (e.g. after app restart before resume completes).
  int? _findNativeTorrentIdByHash(String infoHash) {
    if (_nativeSession == null) return null;
    try {
      final stats = _nativeSession!.getTorrentStats();
      for (final s in stats) {
        if (s.infoHash.toLowerCase() == infoHash.toLowerCase()) {
          // Rebuild the mapping so future lookups are fast
          _ltTorrentIdsByHash[infoHash] = s.torrentId;
          _ltInfoHashesByTorrentId[s.torrentId] = infoHash;
          return s.torrentId;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _prioritizeLibtorrentDownloadFile(
    int torrentId,
    int fileIndex,
  ) async {
    final files = _nativeSession!.getFiles(torrentId);
    if (files.isEmpty) return;

    final maxIndex = files.fold<int>(
      -1,
      (current, file) => file.index > current ? file.index : current,
    );
    if (fileIndex < 0 || fileIndex > maxIndex) return;

    final priorities = List<int>.filled(maxIndex + 1, 0);
    priorities[fileIndex] = 7;
    _nativeSession!.setFilePriorities(torrentId, priorities);
    // Native setFilePriorities uses libtorrent's async prioritize_files().
    // Let that settle before startStream installs its piece deadlines.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<List<TorrentStats>> _getTorrentStatsWithBackend() async {
    final results = <TorrentStats>[];
    final hasRqbitTasks = _tasks.values.any(
      (task) => task.backend == BtBackendKind.rqbit,
    );
    final hasLibtorrentTasks = _tasks.values.any(
      (task) => task.backend == BtBackendKind.libtorrent,
    );

    if (hasRqbitTasks) {
      results.addAll(await getTorrentStats());
    }

    if (!hasLibtorrentTasks || !_libtorrentInitialized) {
      return results;
    }

    final session = _nativeSession!;
    final nativeStats = session.getTorrentStats();
    for (final stats in nativeStats) {
      final infoHash = _ltInfoHashesByTorrentId[stats.torrentId];
      if (infoHash == null) continue;

      final task = _tasks[infoHash];
      final persistedTotal = task?.totalSize.toInt() ?? 0;
      final totalSize =
          _ltFileSizeByHash[infoHash] ??
          (persistedTotal > 0 ? persistedTotal : stats.totalWanted);
      final downloaded = totalSize > 0
          ? stats.totalDone.clamp(0, totalSize)
          : stats.totalDone;
      final progress = totalSize > 0
          ? (downloaded / totalSize * 100.0).clamp(0.0, 100.0)
          : stats.progress;
      results.add(
        TorrentStats(
          infoHash: infoHash,
          name: stats.name.isEmpty ? 'Torrent ${stats.torrentId}' : stats.name,
          state: _normalizeNativeLibtorrentState(stats),
          progress: progress,
          downloadSpeed: stats.downloadRate.toDouble(),
          uploadSpeed: stats.uploadRate.toDouble(),
          downloaded: BigInt.from(downloaded),
          totalSize: BigInt.from(totalSize),
          peers: stats.numPeers,
          seeders: stats.numSeeds,
        ),
      );
    }
    return results;
  }

  String _normalizeNativeLibtorrentState(MikanLtTorrentStats stats) {
    if (stats.isPaused) return 'paused';
    if (stats.errorMessage.isNotEmpty) return 'error';
    // libtorrent state_t: 0=queued_for_checking, 1=checking_files,
    // 2=downloading_metadata, 3=downloading, 4=finished, 5=seeding,
    // 6=allocating, 7=checking_resume_data
    switch (stats.state) {
      case 5: // seeding
      case 4: // finished
      case 3: // downloading
      case 2: // downloading_metadata
      case 6: // allocating
      case 1: // checking_files
      case 7: // checking_resume_data
        return 'live';
      default:
        return 'initializing';
    }
  }

  Future<bool> _pauseTorrentWithBackend(
    String infoHash, {
    required BtBackendKind backend,
  }) async {
    if (backend == BtBackendKind.rqbit) {
      return pauseTorrent(infoHash: infoHash);
    }
    if (!_libtorrentInitialized) return false;
    final hashLower = infoHash.toLowerCase();
    var torrentId =
        _ltTorrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return false;
    _nativeSession!.pauseTorrent(torrentId);
    return true;
  }

  Future<bool> _resumeTorrentWithBackend(
    String infoHash, {
    required BtBackendKind backend,
  }) async {
    if (backend == BtBackendKind.rqbit) {
      return resumeTorrent(infoHash: infoHash);
    }
    if (!_libtorrentInitialized) return false;
    final hashLower = infoHash.toLowerCase();
    var torrentId =
        _ltTorrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return false;
    _nativeSession!.resumeTorrent(torrentId);
    return true;
  }

  Future<bool> _stopTorrentWithBackend(
    String infoHash, {
    required BtBackendKind backend,
    required bool deleteFiles,
  }) async {
    if (backend == BtBackendKind.rqbit) {
      return stopTorrent(infoHash: infoHash, deleteFiles: deleteFiles);
    }
    if (!_libtorrentInitialized) return false;
    final hashLower = infoHash.toLowerCase();
    final session = _nativeSession!;
    final streamId = _ltStreamIdsByHash.remove(hashLower);
    if (streamId != null) {
      try {
        session.stopStream(streamId);
      } catch (e) {
        debugPrint('[DownloadManager] Error stopping stream: $e');
      }
    }
    var torrentId = _ltTorrentIdsByHash.remove(hashLower);
    if (torrentId == null) {
      torrentId = _findNativeTorrentIdByHash(hashLower);
      if (torrentId == null) return false;
      _ltTorrentIdsByHash.remove(hashLower);
    }
    _ltInfoHashesByTorrentId.remove(torrentId);
    _ltFileIdxByHash.remove(hashLower);
    _ltFileSizeByHash.remove(hashLower);
    session.removeTorrent(torrentId, deleteFiles: deleteFiles);
    return true;
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
    bool forPlayback = false,
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
        if (!resumed) return null;
      }
      if (existingTask.streamUrl != null &&
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
    final task = DownloadTask(
      id: tempId,
      name: name,
      magnet: magnet,
      animeName: animeName,
      episodeNumber: episodeNumber,
      startTime: DateTime.now(),
      status: DownloadTaskStatus.pending,
      backend: _backendKind,
    );

    _tasks[tempId] = task;
    await _saveTasks();
    notifyListeners();
    _ensureStatsPolling();

    try {
      final result = await _startTorrentWithBackend(
        magnet,
        fallbackInfoHash: tempId,
        backend: task.backend,
        startStream: forPlayback,
      );
      final streamUrl = result.streamUrl;

      final currentTask = _tasks[tempId];
      if (!identical(currentTask, task) || _removedTaskIds.contains(tempId)) {
        if (_removedTaskIds.contains(tempId)) {
          _removedTaskIds.add(result.infoHash);
        }
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
        task.status = DownloadTaskStatus.downloading;
        _tasks[actualId] = task;
      } else {
        task.streamUrl = streamUrl;
        task.largestFileIdx = fileIdx ?? task.largestFileIdx;
        task.status = DownloadTaskStatus.downloading;
      }
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
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

  /// Create a streaming URL for an existing task only when playback needs it.
  ///
  /// For the libtorrent backend this avoids starting the HTTP streaming engine
  /// during plain downloads. The stream engine deliberately reprioritizes
  /// pieces around the playback window, which is good for watching but bad for
  /// full-file background downloading.
  Future<String?> getOrCreateStreamUrl(String id) async {
    final task = _tasks[id];
    if (task == null) return null;
    if (task.streamUrl != null && task.streamUrl!.isNotEmpty) {
      if (task.backend == BtBackendKind.libtorrent) {
        final streamId = _ltStreamIdsByHash[task.id.toLowerCase()];
        if (streamId == null) {
          task.streamUrl = null;
        } else if (task.status == DownloadTaskStatus.paused) {
          final resumed = await resumeTask(id);
          if (!resumed) return null;
          return task.streamUrl;
        } else {
          return task.streamUrl;
        }
      } else {
        if (task.status == DownloadTaskStatus.paused) {
          final resumed = await resumeTask(id);
          if (!resumed) return null;
        }
        return task.streamUrl;
      }
    }
    if (task.magnet.isEmpty) return null;

    try {
      if (task.status == DownloadTaskStatus.paused) {
        final resumed = await resumeTask(id);
        if (!resumed) return null;
      }

      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: task.id,
        backend: task.backend,
        startStream: true,
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
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
      if (task.status != DownloadTaskStatus.seeding &&
          task.status != DownloadTaskStatus.completed) {
        task.status = DownloadTaskStatus.downloading;
      }
      await _saveTasks();
      notifyListeners();
      _ensureStatsPolling();
      return task.streamUrl;
    } catch (e) {
      debugPrint('[DownloadManager] Error creating stream URL: $e');
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
      final stats = await _getTorrentStatsWithBackend();
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
        if (shouldRecoverAutoPausedLibtorrent) {
          unawaited(_restoreLibtorrentBackgroundDownload(hashLower));
        }
        final nextStatus = stat.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : shouldRecoverAutoPausedLibtorrent
            ? DownloadTaskStatus.downloading
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
      final stats = await _getTorrentStatsWithBackend();
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
    _statsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
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
      final success = await _pauseTorrentWithBackend(
        id,
        backend: _tasks[id]!.backend,
      );
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
      final resumed = await _resumeTorrentWithBackend(
        id,
        backend: task.backend,
      );
      if (resumed) {
        _pausedTaskIds.remove(id);
        task.status = task.progress >= 100.0
            ? DownloadTaskStatus.seeding
            : DownloadTaskStatus.downloading;
        if (task.backend == BtBackendKind.libtorrent) {
          unawaited(_restoreLibtorrentBackgroundDownload(task.id));
        }
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

      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: id,
        backend: task.backend,
        startStream: false,
      );
      final actualId = result.infoHash;
      final fileIdx = result.fileIdx;
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
      if (result.streamUrl != null) {
        task.streamUrl = result.streamUrl;
      }
      task.largestFileIdx = fileIdx ?? task.largestFileIdx;
      if (result.fileSize != null && result.fileSize! > 0) {
        task.totalSize = BigInt.from(result.fileSize!);
      }
      _pausedTaskIds.remove(task.id);
      await _saveTasks();
      notifyListeners();
      _ensureStatsPolling();
      debugPrint('[DownloadManager] Restarted paused task: ${task.id}');
      return true;
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
      final stopped = await _stopTorrentWithBackend(
        id,
        backend: task?.backend ?? _backendKind,
        deleteFiles: deleteFiles,
      );
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

  String _resolveStreamHash(String infoHash) {
    final hashLower = infoHash.toLowerCase();
    if (_tasks.containsKey(hashLower) ||
        _ltStreamIdsByHash.containsKey(hashLower)) {
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
    final streamId = _ltStreamIdsByHash.remove(hashLower);
    if (streamId == null) return;

    final task = _tasks[hashLower];
    if (task?.backend == BtBackendKind.libtorrent) {
      task?.streamUrl = null;
    }

    if (!_libtorrentInitialized) return;
    try {
      _nativeSession!.stopStream(streamId);
      debugPrint(
        '[DownloadManager] Stopped libtorrent stream $streamId for $hashLower',
      );
    } catch (e) {
      debugPrint(
        '[DownloadManager] Error stopping libtorrent stream $streamId: $e',
      );
    }
  }

  Future<void> _restoreLibtorrentBackgroundDownload(
    String infoHash, {
    Duration delay = Duration.zero,
  }) async {
    final hashLower = _resolveStreamHash(infoHash);
    if (_ltPriorityRecoveryHashes.contains(hashLower)) return;
    _ltPriorityRecoveryHashes.add(hashLower);

    try {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      if (!_libtorrentInitialized ||
          _removedTaskIds.contains(hashLower) ||
          _pausedTaskIds.contains(hashLower)) {
        return;
      }

      final task = _tasks[hashLower];
      if (task == null || task.backend != BtBackendKind.libtorrent) {
        return;
      }

      if (!_activeStreamHashes.contains(hashLower)) {
        _stopLibtorrentStreamForHash(hashLower);
      }

      final session = _nativeSession!;
      var torrentId =
          _ltTorrentIdsByHash[hashLower] ??
          _findNativeTorrentIdByHash(hashLower);
      if (torrentId == null || !_isNativeTorrentValid(torrentId)) {
        if (task.magnet.isEmpty) return;
        final result = await _startTorrentWithBackend(
          task.magnet,
          fallbackInfoHash: task.id,
          backend: task.backend,
          startStream: false,
        );
        torrentId = result.torrentId;
        task.largestFileIdx = result.fileIdx ?? task.largestFileIdx;
        if (result.fileSize != null && result.fileSize! > 0) {
          task.totalSize = BigInt.from(result.fileSize!);
        }
      } else {
        var fileIdx = _ltFileIdxByHash[hashLower] ?? task.largestFileIdx;
        if (fileIdx == null) {
          await _waitForLibtorrentMetadata(torrentId);
          final file = _selectLibtorrentFile(torrentId);
          if (file == null) return;
          fileIdx = file.index;
          _ltFileIdxByHash[hashLower] = file.index;
          _ltFileSizeByHash[hashLower] = file.size;
          task.largestFileIdx = file.index;
          if (file.size > 0) {
            task.totalSize = BigInt.from(file.size);
          }
        }

        await _prioritizeLibtorrentDownloadFile(torrentId, fileIdx);
        session.resumeTorrent(torrentId);
      }

      if (task.status != DownloadTaskStatus.seeding &&
          task.status != DownloadTaskStatus.completed) {
        task.status = DownloadTaskStatus.downloading;
      }
      _ensureStatsPolling();
      await _saveTasks();
      notifyListeners();
      debugPrint(
        '[DownloadManager] Restored libtorrent background download: $hashLower',
      );
    } catch (e) {
      debugPrint(
        '[DownloadManager] Error restoring libtorrent background download: $e',
      );
    } finally {
      _ltPriorityRecoveryHashes.remove(hashLower);
    }
  }

  /// Notify that a BT stream is now active (being played) or inactive.
  ///
  /// When a libtorrent HTTP reader goes away, the native streaming backend may
  /// leave piece priorities focused around the old playback window. Reset the
  /// selected file priority so the download keeps progressing in the background.
  void setActiveStream(String? infoHash, {bool active = true}) {
    if (infoHash == null) {
      final hashes = _activeStreamHashes.toList(growable: false);
      _activeStreamHashes.clear();
      for (final hash in hashes) {
        _stopLibtorrentStreamForHash(hash);
        unawaited(
          _restoreLibtorrentBackgroundDownload(
            hash,
            delay: const Duration(milliseconds: 300),
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
          delay: const Duration(milliseconds: 300),
        ),
      );
      debugPrint('[DownloadManager] Deactivated BT stream for: $hashLower');
      return;
    }

    _activeStreamHashes.add(hashLower);
    debugPrint('[DownloadManager] Activated BT stream for: $hashLower');

    // Native libtorrent streams are kept alive by the HTTP server itself. Avoid
    // periodic synchronous FFI calls on the UI isolate while video is playing.
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
        final task = _tasks[id];
        await _stopTorrentWithBackend(
          id,
          backend: task?.backend ?? _backendKind,
          deleteFiles: deleteFiles,
        );
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
