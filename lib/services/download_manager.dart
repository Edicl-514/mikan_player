import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/native/mikan_libtorrent_native.dart';
import 'package:mikan_player/services/download/download_file_cleanup.dart';
import 'package:mikan_player/services/download/download_queue.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/download_task_store.dart';
import 'package:mikan_player/services/download/http_file_download_port.dart';
import 'package:mikan_player/services/download/m3u8_playlist_port.dart';
import 'package:mikan_player/services/download/magnet_helpers.dart';
import 'package:mikan_player/utils/app_directories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust_api;

// Re-export the extracted model, enums, and helpers so existing
// `import 'package:mikan_player/services/download_manager.dart';` callers
// keep working unchanged.
export 'package:mikan_player/services/download/download_task.dart'
    show
        DownloadTask,
        DownloadTaskType,
        DownloadTaskStatus,
        BtBackendKind,
        BtBackendKindX;

const String _btBackendStorageKey = 'bt_backend_v1';
const String _maxConcurrentKey = 'download_max_concurrent';
const String _downloadLimitKey = 'download_limit_mbps';
const String _uploadLimitKey = 'upload_limit_mbps';
const String _allowBackgroundDownloadKey = 'allow_background_download';
const String _keepSeedingInBackgroundKey = 'keep_seeding_in_background';
const String _customDownloadDirKey = 'download_dir_custom';

class _BackendStartResult {
  final String infoHash;
  final String? streamUrl;
  final int? fileIdx;
  final int? fileSize;
  final String? filePath;
  final int? torrentId;
  final int? streamId;

  const _BackendStartResult({
    required this.infoHash,
    this.streamUrl,
    this.fileIdx,
    this.fileSize,
    this.filePath,
    this.torrentId,
    this.streamId,
  });
}

/// Internal helper to track an active HTTP download so it can be cancelled.
///
/// The legacy m3u8 segment-downloading path passes the raw [request] so it
/// can be aborted per segment; the HTTP file-download path passes the
/// [handle] returned by [HttpFileDownloadPort] so the port's `cancel`
/// aborts the underlying request. [cancel] dispatches to whichever is
/// set, sets the [cancelled] bool (checked inside the chunk loop), and
/// closes the file sink. Both paths keep the [cancelled] flag in scope
/// so the manager's chunk loop checks `_httpDownloadJobs[task.id]
/// ?.cancelled` exactly as before.
class _HttpDownloadJob {
  final HttpClientRequest? request;
  final HttpFileDownloadHandle? handle;
  final File outputFile;
  final IOSink sink;
  bool cancelled = false;

  _HttpDownloadJob({
    this.request,
    this.handle,
    required this.outputFile,
    required this.sink,
  });

  void cancel() {
    cancelled = true;
    if (handle != null) {
      handle!.cancel();
    } else if (request != null) {
      try {
        request!.abort();
      } catch (_) {}
    }
    try {
      sink.close();
    } catch (_) {}
  }
}

/// Global download manager singleton
class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  static const MethodChannel _androidDownloadServiceChannel = MethodChannel(
    'mikan_player/download_service',
  );
  factory DownloadManager() => _instance;

  /// Production constructor: uses the real [IoHttpFileDownloadPort] and
  /// the real [IoM3u8PlaylistPort]. The throttle clock/sleeper default to
  /// [DateTime.now] / [Future.delayed] so the budget-exhaustion branch of
  /// [_throttleHttpChunk] matches the original inline `DateTime.now()` +
  /// `Future.delayed` behavior.
  DownloadManager._internal()
    : _httpPort = IoHttpFileDownloadPort(),
      _m3u8Port = IoM3u8PlaylistPort(),
      _now = _defaultThrottleNow,
      _sleep = _defaultThrottleSleep;

  /// Test constructor: injects an [HttpFileDownloadPort] and a
  /// [M3u8PlaylistPort] so the HTTP file-download and m3u8 playlist-
  /// resolution paths can be exercised without real network sockets or a
  /// real `HttpClient`. The zero-arg [factory DownloadManager] still uses
  /// [DownloadManager._internal] so existing callers are unaffected.
  ///
  /// [clock] and [sleep] are optional overrides for the HTTP throttle's
  /// window clock and delay primitive so the budget-exhaustion branch of
  /// `_throttleHttpChunk` can be tested deterministically (no wall-clock
  /// delay, controllable `elapsed` math).
  @visibleForTesting
  DownloadManager.forTesting({
    HttpFileDownloadPort? httpPort,
    M3u8PlaylistPort? m3u8Port,
    DateTime Function()? clock,
    Future<void> Function(Duration)? sleep,
  }) : _httpPort = httpPort ?? IoHttpFileDownloadPort(),
       _m3u8Port = m3u8Port ?? IoM3u8PlaylistPort(),
       _now = clock ?? _defaultThrottleNow,
       _sleep = sleep ?? _defaultThrottleSleep {
    if (clock != null) {
      _httpThrottleWindowStart = clock();
    }
  }

  final HttpFileDownloadPort _httpPort;
  final M3u8PlaylistPort _m3u8Port;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;

  static DateTime _defaultThrottleNow() => DateTime.now();
  static Future<void> _defaultThrottleSleep(Duration d) => Future.delayed(d);

  final Map<String, DownloadTask> _tasks = {};
  final Set<String> _removedTaskIds =
      {}; // Track removed tasks to prevent re-adding
  final Set<String> _pausedTaskIds = {}; // Track paused tasks
  Timer? _statsTimer;
  bool _isInitialized = false;
  DateTime? _lastStatsPersistenceAt;
  bool _isUpdatingStats = false;
  bool _isRecoveringActiveTasks = false;
  bool _androidDownloadServiceRunning = false;
  DateTime? _lastForegroundRecoveryAt;
  DateTime? _lastLibtorrentResumeSaveAt;
  bool _isSavingLibtorrentResumeData = false;
  BtBackendKind _backendKind = BtBackendKind.rqbit;
  bool _libtorrentInitialized = false;
  Future<void>? _libtorrentInitialization;
  MikanLibtorrentSession? _nativeSession;
  String? _downloadDir;
  String? _customDownloadDir;
  final Map<String, int> _ltTorrentIdsByHash = {};
  final Map<int, String> _ltInfoHashesByTorrentId = {};
  final Map<String, int> _ltStreamIdsByHash = {};
  final Map<String, int> _ltFileIdxByHash = {};
  final Map<String, int> _ltFileSizeByHash = {};
  final Set<String> _ltPriorityRecoveryHashes = {};
  final Set<String> _activeStreamHashes = {}; // Track active playback streams
  final Set<String> _ltCompletionResumeSavedHashes = {};
  static const Duration _ltResumeSaveInterval = Duration(minutes: 1);

  // Download settings
  int _maxConcurrentDownloads = 3;
  double _downloadLimitMbps = 0; // 0 = unlimited
  double _uploadLimitMbps = 0; // 0 = unlimited
  bool _allowBackgroundDownload = true;
  bool _keepSeedingInBackground = false;

  // Parallel download control (slot acquire/release lives in DownloadQueue).
  late final DownloadQueue _slotQueue = DownloadQueue(
    maxConcurrent: _maxConcurrentDownloads,
    isTaskEligible: _canAcquireDownloadSlot,
  );

  // Persistence layer for download tasks: raw SharedPreferences string IO +
  // JSON encode/decode only. All domain logic (validation, status
  // transitions, resume queue, cold-start throttle) stays in
  // [DownloadManager]. Lazy so it is constructed on first use by
  // [_loadTasks]. The storage key is the frozen [btTasksStorageKey] const
  // so the persisted key stays defined in exactly one place.
  late final DownloadTaskStore _taskStore = DownloadTaskStore(
    prefs: SharedPreferencesDownloadTaskKeyValueStore(),
    storageKey: btTasksStorageKey,
  );

  // HTTP download tracking
  final Map<String, _HttpDownloadJob> _httpDownloadJobs = {};

  /// Simple HTTP download speed limiter.
  /// Tracks bytes written within the current 1-second window and sleeps
  /// when the budget is exhausted.
  int _httpThrottleBytesThisWindow = 0;
  DateTime _httpThrottleWindowStart = DateTime.now();

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

  bool _canAcquireDownloadSlot(String taskId) {
    final task = _tasks[taskId];
    return task != null &&
        !_removedTaskIds.contains(taskId) &&
        _isActiveStatus(task.status);
  }

  Future<bool> _acquireDownloadSlot(String taskId) =>
      _slotQueue.acquire(taskId);

  void _drainDownloadSlotQueue() => _slotQueue.drain();

  void _releaseSlotForTask(String taskId) => _slotQueue.release(taskId);

  void _transferDownloadSlot(String oldTaskId, String newTaskId) =>
      _slotQueue.transfer(oldTaskId, newTaskId);

  bool get _hasAvailableSlot => _slotQueue.hasAvailableSlot;

  /// Resolve the default download directory from app data path.
  Future<String> _resolveDefaultDownloadDir() async {
    final appSupportDir = await AppDirectories.getUnifiedAppDataDirectory();
    return '${appSupportDir.path}/downloads';
  }

  /// Ensure download directory is initialized (for HTTP downloads)
  Future<void> _ensureDownloadDir() async {
    if (_downloadDir == null) {
      if (_customDownloadDir != null) {
        _downloadDir = _customDownloadDir;
      } else {
        _downloadDir = await _resolveDefaultDownloadDir();
      }
    }
  }

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

  bool _saveLibtorrentResumeDataForHash(String infoHash, String reason) {
    if (!_libtorrentInitialized || _nativeSession == null) return false;

    final hashLower = infoHash.toLowerCase();
    final task = _tasks[hashLower] ?? _tasks[infoHash];
    if (task == null || task.backend != BtBackendKind.libtorrent) {
      return false;
    }

    final torrentId =
        _ltTorrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return false;

    try {
      _nativeSession!.saveResumeData(
        torrentId,
        resumePath: _ltResumePath(hashLower, task: task),
      );
      debugPrint(
        '[DownloadManager] Saved libtorrent resume data ($reason): $hashLower',
      );
      return true;
    } catch (e) {
      debugPrint(
        '[DownloadManager] Error saving libtorrent resume data ($reason): $e',
      );
      return false;
    }
  }

  void _saveActiveLibtorrentResumeData(String reason) {
    if (_isSavingLibtorrentResumeData) return;
    if (!_libtorrentInitialized || _nativeSession == null) return;

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
      for (final hash in hashes) {
        _saveLibtorrentResumeDataForHash(hash, reason);
      }
    } finally {
      _isSavingLibtorrentResumeData = false;
    }
  }

  void _maybeSavePeriodicLibtorrentResumeData() {
    final now = DateTime.now();
    if (_lastLibtorrentResumeSaveAt != null &&
        now.difference(_lastLibtorrentResumeSaveAt!) < _ltResumeSaveInterval) {
      return;
    }
    _lastLibtorrentResumeSaveAt = now;
    _saveActiveLibtorrentResumeData('periodic');
  }

  void saveLibtorrentResumeDataForShutdown() {
    _saveActiveLibtorrentResumeData('shutdown');
    unawaited(_saveTasks());
  }

  List<DownloadTask> get tasks => _tasks.values.toList();
  BtBackendKind get backendKind => _backendKind;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  double get downloadLimitMbps => _downloadLimitMbps;
  double get uploadLimitMbps => _uploadLimitMbps;
  bool get allowBackgroundDownload => _allowBackgroundDownload;
  bool get keepSeedingInBackground => _keepSeedingInBackground;

  /// Current download directory (custom if set, otherwise default).
  String get downloadDir => _downloadDir ?? '';

  /// Whether a custom download directory has been configured.
  bool get hasCustomDownloadDir => _customDownloadDir != null;

  /// Active tasks: downloading, metadata-fetching, checking (not seeding)
  List<DownloadTask> get activeTasks =>
      _tasks.values.where((t) => _isActiveStatus(t.status)).toList();

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

  bool get _shouldKeepAndroidDownloadServiceRunning =>
      !kIsWeb &&
      Platform.isAndroid &&
      _allowBackgroundDownload &&
      _tasks.values.any(
        (task) =>
            !_removedTaskIds.contains(task.id) &&
            (_isActiveStatus(task.status) ||
                (_keepSeedingInBackground &&
                    task.status == DownloadTaskStatus.seeding)),
      );

  void _syncAndroidDownloadService() {
    if (kIsWeb || !Platform.isAndroid) return;
    final shouldRun = _shouldKeepAndroidDownloadServiceRunning;
    if (shouldRun == _androidDownloadServiceRunning) return;

    _androidDownloadServiceRunning = shouldRun;
    unawaited(_setAndroidDownloadServiceRunning(shouldRun));
  }

  Future<void> _setAndroidDownloadServiceRunning(bool running) async {
    try {
      await _androidDownloadServiceChannel.invokeMethod<void>(
        running ? 'start' : 'stop',
      );
      debugPrint(
        '[DownloadManager] Android foreground download service '
        '${running ? 'started' : 'stopped'}',
      );
    } catch (e) {
      _androidDownloadServiceRunning = !running;
      debugPrint(
        '[DownloadManager] Failed to ${running ? 'start' : 'stop'} '
        'Android foreground download service: $e',
      );
    }
  }

  bool _isActiveStatus(DownloadTaskStatus status) =>
      status == DownloadTaskStatus.pending ||
      status == DownloadTaskStatus.downloading ||
      status == DownloadTaskStatus.metadata ||
      status == DownloadTaskStatus.checking ||
      status == DownloadTaskStatus.queued;

  bool _shouldDeleteFiles(bool deleteFiles) =>
      deleteFiles || (!kIsWeb && Platform.isAndroid);

  bool get _hasAvailableDownloadSlot => _hasAvailableSlot;

  Future<void> _markTaskQueued(DownloadTask task) async {
    if (!_isActiveStatus(task.status)) return;
    if (task.status == DownloadTaskStatus.queued) return;
    task.status = DownloadTaskStatus.queued;
    task.downloadSpeed = 0;
    task.uploadSpeed = 0;
    await _saveTasks();
    notifyListeners();
  }

  /// Initialize the download manager, load saved tasks
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _backendKind = BtBackendKindX.fromStorage(
      prefs.getString(_btBackendStorageKey),
    );
    _maxConcurrentDownloads = prefs.getInt(_maxConcurrentKey) ?? 3;
    _slotQueue.maxConcurrent = _maxConcurrentDownloads;
    _downloadLimitMbps = prefs.getDouble(_downloadLimitKey) ?? 0;
    _uploadLimitMbps = prefs.getDouble(_uploadLimitKey) ?? 0;
    _allowBackgroundDownload =
        prefs.getBool(_allowBackgroundDownloadKey) ?? true;
    _keepSeedingInBackground =
        _allowBackgroundDownload &&
        (prefs.getBool(_keepSeedingInBackgroundKey) ?? false);
    _customDownloadDir = prefs.getString(_customDownloadDirKey);
    if (_customDownloadDir != null) {
      _downloadDir = _customDownloadDir;
    }
    await _ensureDownloadDir();
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

  /// Set a custom download directory (or pass null to restore default).
  /// New downloads will immediately use the new path; existing tasks are
  /// unaffected and continue in their original location.
  Future<void> setDownloadDir(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    late final String nextDownloadDir;
    if (path != null && path.isNotEmpty) {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      nextDownloadDir = dir.path;
      _customDownloadDir = nextDownloadDir;
      _downloadDir = nextDownloadDir;
      await prefs.setString(_customDownloadDirKey, nextDownloadDir);
    } else {
      nextDownloadDir = await _resolveDefaultDownloadDir();
      final dir = Directory(nextDownloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _customDownloadDir = null;
      await prefs.remove(_customDownloadDirKey);
      _downloadDir = nextDownloadDir;
    }
    // Sync the Rust-side config so rqbit reads the new path for new torrents
    try {
      await rust_api.setDownloadDir(dir: _downloadDir!);
    } catch (e) {
      debugPrint('[DownloadManager] Failed to sync Rust download dir: $e');
    }
    notifyListeners();
  }

  /// Update download settings and apply them immediately.
  Future<void> setDownloadSettings({
    int? maxConcurrent,
    double? downloadLimitMbps,
    double? uploadLimitMbps,
    bool? allowBackgroundDownload,
    bool? keepSeedingInBackground,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (maxConcurrent != null) {
      _maxConcurrentDownloads = maxConcurrent.clamp(1, 10);
      _slotQueue.maxConcurrent = _maxConcurrentDownloads;
      await prefs.setInt(_maxConcurrentKey, _maxConcurrentDownloads);
      _drainDownloadSlotQueue();
    }
    if (downloadLimitMbps != null) {
      _downloadLimitMbps = downloadLimitMbps < 0 ? 0 : downloadLimitMbps;
      await prefs.setDouble(_downloadLimitKey, _downloadLimitMbps);
    }
    if (uploadLimitMbps != null) {
      _uploadLimitMbps = uploadLimitMbps < 0 ? 0 : uploadLimitMbps;
      await prefs.setDouble(_uploadLimitKey, _uploadLimitMbps);
    }
    if (allowBackgroundDownload != null) {
      _allowBackgroundDownload = allowBackgroundDownload;
      await prefs.setBool(
        _allowBackgroundDownloadKey,
        _allowBackgroundDownload,
      );
      if (!_allowBackgroundDownload) {
        _keepSeedingInBackground = false;
        await prefs.setBool(_keepSeedingInBackgroundKey, false);
      }
    }
    if (keepSeedingInBackground != null) {
      _keepSeedingInBackground =
          _allowBackgroundDownload && keepSeedingInBackground;
      await prefs.setBool(
        _keepSeedingInBackgroundKey,
        _keepSeedingInBackground,
      );
    }
    _applyLibtorrentSpeedLimits();
    _syncAndroidDownloadService();
    notifyListeners();
  }

  /// Apply current speed limits to the libtorrent session (if initialized).
  void _applyLibtorrentSpeedLimits() {
    if (!_libtorrentInitialized || _nativeSession == null) return;
    final dlBytes = (_downloadLimitMbps * 1024 * 1024).round();
    final ulBytes = (_uploadLimitMbps * 1024 * 1024).round();
    _nativeSession!.configureSession(
      downloadLimitBytesPerSecond: dlBytes,
      uploadLimitBytesPerSecond: ulBytes,
    );
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
    notifyListeners();
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
      notifyListeners();
    }
    try {
      debugPrint('[DownloadManager] Auto-resuming torrent: ${task.name}');
      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: task.id,
        backend: task.backend,
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
      notifyListeners();
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
        backend: task.backend,
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
      notifyListeners();
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
    // Respect custom download dir if already set; otherwise resolve default.
    if (_downloadDir == null) {
      if (_customDownloadDir != null) {
        _downloadDir = _customDownloadDir;
      } else {
        final appSupportDir = await AppDirectories.getUnifiedAppDataDirectory();
        _downloadDir = '${appSupportDir.path}/downloads';
      }
    }
    // Use a high listen port — the legacy 6881-6889 range is widely
    // throttled or blocked by ISPs; 49152 is in the IANA dynamic range.
    _nativeSession = MikanLibtorrentNative.instance.createSession(
      listenInterfaces: '0.0.0.0:49152',
    );
    _nativeSession!.configureSession(
      connectionsLimit: 200,
      enableDht: true,
      enableLsd: true,
      enableUpnp: true,
      enableNatPmp: true,
    );
    _libtorrentInitialized = true;
    _applyLibtorrentSpeedLimits();
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
    String? downloadDir,
  }) async {
    if (backend == BtBackendKind.rqbit) {
      final effectiveDownloadDir = downloadDir ?? _downloadDir;
      if (effectiveDownloadDir != null && effectiveDownloadDir.isNotEmpty) {
        await rust_api.setDownloadDir(dir: effectiveDownloadDir);
      }
      final streamUrl = await rust_api.startTorrent(magnet: magnet);
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
      final task = _tasks[infoHash];
      final effectiveDownloadDir =
          downloadDir ?? task?.downloadDir ?? _downloadDir;
      if (effectiveDownloadDir == null || effectiveDownloadDir.isEmpty) {
        throw StateError('Download directory is not initialized');
      }
      final resumePath = _ltResumePath(infoHash, baseDir: effectiveDownloadDir);
      final seed =
          task != null &&
          task.progress >= 100.0 &&
          task.status != DownloadTaskStatus.paused;
      // Inject a small, high-quality tracker set (same as rqbit backend).
      // This improves peer discovery, especially for magnets with few trackers.
      final enrichedMagnet = injectMagnetTrackers(magnet);
      torrentId = session.addMagnetEx(
        enrichedMagnet,
        savePath: effectiveDownloadDir,
        resumePath: resumePath,
        seedMode: seed,
      );
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
        filePath: file.path,
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
      filePath: file.path,
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
        connectionsLimit: 200,
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

  Future<List<rust_api.TorrentStats>> _getTorrentStatsWithBackend() async {
    final results = <rust_api.TorrentStats>[];
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
      results.addAll(await rust_api.getTorrentStats());
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
        rust_api.TorrentStats(
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

  Future<bool> _isRqbitTorrentManaged(String infoHash) async {
    try {
      final hashLower = infoHash.toLowerCase();
      final stats = await rust_api.getTorrentStats();
      return stats.any(
        (stat) =>
            stat.infoHash.toLowerCase() == hashLower && stat.state != 'error',
      );
    } catch (e) {
      debugPrint('[DownloadManager] Error checking rqbit torrent state: $e');
      return false;
    }
  }

  String _normalizeNativeLibtorrentState(MikanLtTorrentStats stats) {
    if (stats.isPaused) return 'paused';
    if (stats.errorMessage.isNotEmpty) return 'error';
    // libtorrent state_t: 0=queued_for_checking, 1=checking_files,
    // 2=downloading_metadata, 3=downloading, 4=finished, 5=seeding,
    // 6=allocating, 7=checking_resume_data
    switch (stats.state) {
      case 2: // downloading_metadata
        return 'metadata';
      case 0: // queued_for_checking
      case 1: // checking_files
      case 7: // checking_resume_data
        return 'checking';
      case 3: // downloading
      case 4: // finished
      case 5: // seeding
      case 6: // allocating
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
      return rust_api.pauseTorrent(infoHash: infoHash);
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
      return rust_api.resumeTorrent(infoHash: infoHash);
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
    DownloadTask? task,
  }) async {
    if (backend == BtBackendKind.rqbit) {
      return rust_api.stopTorrent(infoHash: infoHash, deleteFiles: deleteFiles);
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
    _ltCompletionResumeSavedHashes.remove(hashLower);
    final resumePath = _ltResumePath(hashLower, task: task);
    if (deleteFiles) {
      try {
        final file = File(resumePath);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    } else {
      // Save resume data before removing the torrent so we can fast-resume later.
      try {
        session.saveResumeData(torrentId, resumePath: resumePath);
      } catch (e) {
        debugPrint(
          '[DownloadManager] Error saving resume data before stop: $e',
        );
      }
    }
    session.removeTorrent(torrentId, deleteFiles: deleteFiles);
    return true;
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

  /// Check if there's an available BT task for the anime episode.
  /// BT is prioritized over HTTP for auto-play flows.
  DownloadTask? getAvailableBtTaskForEpisode(
    String? animeName,
    int? episodeNumber,
  ) {
    if (animeName == null) return null;

    for (final task in _tasks.values) {
      if (task.taskType != DownloadTaskType.bt) continue;
      if (task.animeName != animeName || task.episodeNumber != episodeNumber) {
        continue;
      }
      if (task.status == DownloadTaskStatus.downloading ||
          task.status == DownloadTaskStatus.seeding ||
          task.status == DownloadTaskStatus.completed ||
          (task.status == DownloadTaskStatus.paused && task.progress > 0)) {
        return task;
      }
    }
    return null;
  }

  /// Check if there's a completed HTTP download for this episode
  DownloadTask? getCompletedHttpTaskForEpisode(
    String? animeName,
    int? episodeNumber,
  ) {
    if (animeName == null) return null;
    for (final task in _tasks.values) {
      if (task.taskType != DownloadTaskType.http) continue;
      if (task.animeName != animeName || task.episodeNumber != episodeNumber) {
        continue;
      }
      if (task.status == DownloadTaskStatus.completed &&
          task.localFilePath != null) {
        final file = File(task.localFilePath!);
        if (file.existsSync()) return task;
      }
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
    notifyListeners();
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
      notifyListeners();
    }

    try {
      final result = await _startTorrentWithBackend(
        magnet,
        fallbackInfoHash: tempId,
        backend: task.backend,
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

      notifyListeners();
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
  ///
  /// For HTTP tasks, returns the local file path directly.
  Future<String?> getOrCreateStreamUrl(String id) async {
    final task = _tasks[id];
    if (task == null) return null;

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
        final streamId = _ltStreamIdsByHash[hashLower];
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

      final result = await _startTorrentWithBackend(
        task.magnet,
        fallbackInfoHash: task.id,
        backend: task.backend,
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
      notifyListeners();
      _ensureStatsPolling();
      return task.streamUrl;
    } catch (e) {
      debugPrint('[DownloadManager] Error creating stream URL: $e');
      return null;
    }
  }

  /// Start a new HTTP download task for an online video source.
  /// Returns the task ID on success, null on failure.
  Future<String?> startHttpDownload({
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
          notifyListeners();
          return existingTask.id;
        }
        existingTask.status = DownloadTaskStatus.error;
        existingTask.errorMessage = '本地文件已删除';
      }

      if (existingTask.status == DownloadTaskStatus.downloading ||
          existingTask.status == DownloadTaskStatus.queued) {
        await _saveTasks();
        notifyListeners();
        return existingTask.id;
      }

      existingTask.errorMessage = null;
      _pausedTaskIds.remove(existingTask.id);
      existingTask.status = DownloadTaskStatus.downloading;
      existingTask.progress = 0.0;
      existingTask.downloaded = BigInt.zero;
      existingTask.totalSize = BigInt.zero;
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
      notifyListeners();
      unawaited(_downloadHttpFile(existingTask));
      return existingTask.id;
    }

    final id = 'http_${_stableHash(url)}';

    if (_tasks.containsKey(id)) {
      return id; // Already exists
    }

    await _ensureDownloadDir();
    final httpDir = Directory('$_downloadDir/http');
    if (!await httpDir.exists()) {
      await httpDir.create(recursive: true);
    }

    // Sanitize name for filename
    final safeName = _sanitizeFileName(name);
    final ext = _guessVideoExtension(url);
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
    notifyListeners();

    // Start download in background
    unawaited(_downloadHttpFile(task));
    return id;
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final nonEmpty = sanitized.isEmpty ? 'download' : sanitized;
    return nonEmpty.length <= 80 ? nonEmpty : nonEmpty.substring(0, 80);
  }

  String _guessVideoExtension(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp4')) return '.mp4';
    if (lower.contains('.mkv')) return '.mkv';
    if (lower.contains('.m3u8')) return '.ts';
    if (lower.contains('.ts')) return '.ts';
    if (lower.contains('.flv')) return '.flv';
    if (lower.contains('.avi')) return '.avi';
    if (lower.contains('.mov')) return '.mov';
    if (lower.contains('.wmv')) return '.wmv';
    return '.mp4';
  }

  bool _isM3u8Url(String url) {
    final uri = Uri.tryParse(url);
    final normalizedPath = uri?.path.toLowerCase() ?? url.toLowerCase();
    return normalizedPath.contains('.m3u8');
  }

  void _applyHttpHeaders(
    HttpClientRequest request,
    Map<String, String>? headers,
    String? cookies,
  ) {
    if (headers != null) {
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }
    if (cookies != null && cookies.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookies);
    }
  }

  // `_fetchHttpText` was the inline playlist-text fetcher before the
  // m3u8 seam; its wire behavior now lives on `IoM3u8PlaylistPort.fetchText`
  // (byte-for-byte). Removed here per the plan's "remove unused after
  // extraction" rule; the per-segment loop in `_downloadM3u8File` keeps its
  // own `HttpClient` and still calls the manager's `_applyHttpHeaders`.

  Future<List<Uri>> _resolveHlsSegments(
    Uri playlistUri, {
    Map<String, String>? headers,
    String? cookies,
    int depth = 0,
  }) async {
    if (depth > 4) {
      throw Exception('m3u8层级过深，无法解析');
    }

    final content = await _m3u8Port.fetchText(
      url: playlistUri,
      headers: headers,
      cookies: cookies,
    );
    final parsed = parseM3u8Playlist(content, playlistUri);

    // Master playlist: recurse into the highest-BANDWIDTH variant. The
    // parser already sorted `variants` by `bandwidth` descending, so
    // `.first` is the original `variantCandidates.first.uri` after the
    // inline sort. Depth + headers/cookies forwarding are unchanged.
    if (parsed is M3u8MasterPlaylist) {
      return _resolveHlsSegments(
        parsed.variants.first.uri,
        headers: headers,
        cookies: cookies,
        depth: depth + 1,
      );
    }

    // Media playlist: the parser rejects encrypted media (`#EXT-X-KEY`
    // without `METHOD=NONE`) with `UnsupportedError('暂不支持下载加密HLS流')`
    // and an empty segment list with `Exception('未找到可下载的HLS分片')`,
    // so by here `segments` is non-empty. Both throws propagate verbatim
    // through this tail recursion, matching the original inline behavior.
    return (parsed as M3u8MediaPlaylist).segments;
  }

  Future<void> _downloadM3u8File(DownloadTask task) async {
    final url = task.videoUrl;
    if (url == null) return;
    _syncAndroidDownloadService();

    final client = HttpClient();
    final outputFile = File(task.localFilePath!);
    IOSink? sink;
    bool wasCancelled = false;

    try {
      final playlistUri = Uri.parse(url);
      final segments = await _resolveHlsSegments(
        playlistUri,
        headers: task.headers,
        cookies: task.cookies,
      );

      sink = outputFile.openWrite();
      task.totalSize = BigInt.zero;

      var received = 0;
      var lastReceived = 0;
      var finishedSegments = 0;
      var lastUpdate = DateTime.now();

      for (final segmentUri in segments) {
        if (_httpDownloadJobs[task.id]?.cancelled ?? false) {
          wasCancelled = true;
          break;
        }

        final request = await client.getUrl(segmentUri);
        _applyHttpHeaders(request, task.headers, task.cookies);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('HTTP ${response.statusCode}');
        }

        _httpDownloadJobs[task.id] = _HttpDownloadJob(
          request: request,
          outputFile: outputFile,
          sink: sink,
        );

        final contentLength = response.contentLength;
        if (contentLength > 0) {
          task.totalSize += BigInt.from(contentLength);
        }

        await for (final chunk in response) {
          if (_httpDownloadJobs[task.id]?.cancelled ?? false) {
            wasCancelled = true;
            break;
          }
          sink.add(chunk);
          received += chunk.length;
          task.downloaded = BigInt.from(received);
          await _throttleHttpChunk(chunk.length);

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
            notifyListeners();
          }
        }

        if (wasCancelled) {
          break;
        }

        finishedSegments += 1;
        task.progress = (finishedSegments / segments.length * 100.0).clamp(
          0.0,
          100.0,
        );
        notifyListeners();
      }

      await sink.close();
      sink = null;

      if ((_httpDownloadJobs[task.id]?.cancelled ?? false) || wasCancelled) {
        task.status = DownloadTaskStatus.paused;
        task.downloadSpeed = 0;
        task.uploadSpeed = 0;
        _pausedTaskIds.add(task.id);
        debugPrint(
          '[DownloadManager] HLS download paused (partial): ${task.name}',
        );
      } else {
        task.status = DownloadTaskStatus.completed;
        task.progress = 100.0;
        task.downloadSpeed = 0;
        try {
          final fileLen = outputFile.lengthSync();
          task.totalSize = BigInt.from(fileLen);
          task.downloaded = BigInt.from(fileLen);
        } catch (_) {}
        debugPrint('[DownloadManager] HLS download completed: ${task.name}');
      }
    } catch (e) {
      debugPrint('[DownloadManager] HLS download error: $e');
      if (!_tasks.containsKey(task.id)) {
        return;
      }
      if (_httpDownloadJobs[task.id]?.cancelled ?? false) {
        task.status = DownloadTaskStatus.paused;
        task.downloadSpeed = 0;
        task.uploadSpeed = 0;
        _pausedTaskIds.add(task.id);
        return;
      }
      task.status = DownloadTaskStatus.error;
      task.errorMessage = e.toString();
      try {
        sink?.close();
      } catch (_) {}
    } finally {
      _httpDownloadJobs.remove(task.id);
      client.close();
      if (_tasks.containsKey(task.id)) {
        await _saveTasks();
        notifyListeners();
        _syncAndroidDownloadService();
      }
    }
  }

  Future<void> _downloadHttpFile(DownloadTask task) async {
    final url = task.videoUrl;
    if (url == null) return;
    if (task.status != DownloadTaskStatus.downloading &&
        task.status != DownloadTaskStatus.queued) {
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
          (task.status != DownloadTaskStatus.downloading &&
              task.status != DownloadTaskStatus.queued)) {
        return;
      }
      if (task.status == DownloadTaskStatus.queued) {
        task.status = DownloadTaskStatus.downloading;
        await _saveTasks();
        notifyListeners();
      }

      if (_isM3u8Url(url)) {
        await _downloadM3u8File(task);
        return;
      }

      final outputFile = File(task.localFilePath!);
      IOSink? sink;
      HttpFileDownloadHandle? handle;
      bool wasCancelled = false;

      try {
        final uri = Uri.parse(url);
        handle = await _httpPort.start(
          url: uri,
          headers: task.headers,
          cookies: task.cookies,
        );

        sink = outputFile.openWrite();
        _httpDownloadJobs[task.id] = _HttpDownloadJob(
          handle: handle,
          outputFile: outputFile,
          sink: sink,
        );

        final contentLength = handle.contentLength;
        if (contentLength != null && contentLength > 0) {
          task.totalSize = BigInt.from(contentLength);
        }

        int received = 0;
        int lastReceived = 0;
        DateTime lastUpdate = DateTime.now();

        await for (final chunk in handle.chunks) {
          if (_httpDownloadJobs[task.id]?.cancelled ?? false) {
            wasCancelled = true;
            break;
          }
          sink.add(chunk);
          received += chunk.length;
          task.downloaded = BigInt.from(received);
          await _throttleHttpChunk(chunk.length);

          final now = DateTime.now();
          if (now.difference(lastUpdate).inMilliseconds >= 500) {
            final elapsed = now.difference(lastUpdate).inMilliseconds / 1000.0;
            if (elapsed > 0) {
              final bytesSince = received - lastReceived;
              task.downloadSpeed = bytesSince / elapsed;
            }
            if (contentLength != null && contentLength > 0) {
              task.progress = (received / contentLength * 100.0).clamp(
                0.0,
                100.0,
              );
            } else {
              task.progress = 0.0; // Unknown progress
            }
            lastUpdate = now;
            lastReceived = received;
            notifyListeners();
          }
        }

        await sink.close();
        sink = null;

        // Check if cancelled
        if ((_httpDownloadJobs[task.id]?.cancelled ?? false) || wasCancelled) {
          // Partial file remains; mark as paused
          task.status = DownloadTaskStatus.paused;
          task.downloadSpeed = 0;
          task.uploadSpeed = 0;
          _pausedTaskIds.add(task.id);
          debugPrint(
            '[DownloadManager] HTTP download paused (partial): ${task.name}',
          );
        } else {
          // Completed
          task.status = DownloadTaskStatus.completed;
          task.progress = 100.0;
          task.downloadSpeed = 0;
          if (contentLength == null || contentLength <= 0) {
            // Update total size from actual file size
            try {
              final fileLen = outputFile.lengthSync();
              task.totalSize = BigInt.from(fileLen);
            } catch (_) {}
          }
          debugPrint('[DownloadManager] HTTP download completed: ${task.name}');
        }
      } catch (e) {
        debugPrint('[DownloadManager] HTTP download error: $e');
        if (!_tasks.containsKey(task.id)) {
          return;
        }
        if (_httpDownloadJobs[task.id]?.cancelled ?? false) {
          task.status = DownloadTaskStatus.paused;
          task.downloadSpeed = 0;
          task.uploadSpeed = 0;
          _pausedTaskIds.add(task.id);
          return;
        }
        task.status = DownloadTaskStatus.error;
        task.errorMessage = e.toString();
        try {
          sink?.close();
        } catch (_) {}
      } finally {
        _httpDownloadJobs.remove(task.id);
        await handle?.close();
        if (_tasks.containsKey(task.id)) {
          await _saveTasks();
          notifyListeners();
          _syncAndroidDownloadService();
        }
      }
    } finally {
      _releaseSlotForTask(task.id);
      _syncAndroidDownloadService();
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
        notifyListeners();

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
        if (_saveLibtorrentResumeDataForHash(hash, 'completed')) {
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
      final statsByHash = <String, rust_api.TorrentStats>{
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

  void stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _syncAndroidDownloadService();
  }

  /// Extract info hash from magnet link.
  String? _extractInfoHash(String magnet) => extractInfoHashFromMagnet(magnet);

  /// Extract info hash from stream URL
  String? _extractInfoHashFromUrl(String url) =>
      extractInfoHashFromStreamUrl(url);

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

    final task = _tasks[id]!;

    if (task.status == DownloadTaskStatus.queued) {
      task.status = DownloadTaskStatus.paused;
      task.downloadSpeed = 0;
      task.uploadSpeed = 0;
      _pausedTaskIds.add(id);
      await _saveTasks();
      notifyListeners();
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
      notifyListeners();
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
          final hashLower = id.toLowerCase();
          final torrentId =
              _ltTorrentIdsByHash[hashLower] ??
              _findNativeTorrentIdByHash(hashLower);
          if (torrentId != null) {
            try {
              _nativeSession!.saveResumeData(
                torrentId,
                resumePath: _ltResumePath(hashLower, task: task),
              );
            } catch (e) {
              debugPrint(
                '[DownloadManager] Error saving resume data on pause: $e',
              );
            }
          }
        }
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

    // HTTP tasks: delete partial file and restart download from scratch
    if (task.taskType == DownloadTaskType.http) {
      _pausedTaskIds.remove(id);
      task.status = DownloadTaskStatus.downloading;
      task.progress = 0.0;
      task.downloaded = BigInt.zero;
      task.downloadSpeed = 0;
      task.errorMessage = null;
      // Delete partial file if it exists
      if (task.localFilePath != null) {
        try {
          final file = File(task.localFilePath!);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
      await _saveTasks();
      notifyListeners();
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
        notifyListeners();
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
        notifyListeners();
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
        notifyListeners();
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
        backend: task.backend,
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
      notifyListeners();
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
  Future<void> removeTask(String id, {bool deleteFiles = false}) async {
    final task = _tasks[id];
    final effectiveDeleteFiles = _shouldDeleteFiles(deleteFiles);

    // Remove from UI immediately so the task disappears right away.
    _tasks.remove(id);
    _pausedTaskIds.remove(id);
    _removedTaskIds.add(id); // Mark as removed to prevent re-adding
    _releaseSlotForTask(id);
    await _saveTasks();
    notifyListeners();
    _ensureStatsPolling();

    // HTTP tasks: cancel download and optionally delete file
    if (task != null && task.taskType == DownloadTaskType.http) {
      final job = _httpDownloadJobs.remove(id);
      if (job != null) job.cancel();
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
          downloadDir: task.downloadDir,
        );
        torrentId = result.torrentId;
        task.largestFileIdx = result.fileIdx ?? task.largestFileIdx;
        task.largestFilePath = result.filePath ?? task.largestFilePath;
        if (result.fileSize != null && result.fileSize! > 0) {
          task.totalSize = BigInt.from(result.fileSize!);
        }
      } else {
        await _waitForLibtorrentMetadata(torrentId);
        var fileIdx = _ltFileIdxByHash[hashLower] ?? task.largestFileIdx;
        if (fileIdx == null) {
          final file = _selectLibtorrentFile(torrentId);
          if (file == null) return;
          fileIdx = file.index;
          _ltFileIdxByHash[hashLower] = file.index;
          _ltFileSizeByHash[hashLower] = file.size;
          task.largestFileIdx = file.index;
          task.largestFilePath = file.path;
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
    notifyListeners();
    _ensureStatsPolling();
  }

  // --- HTTP file-download characterization test seam (Package B) ------------
  //
  // Exposes the minimum private surface required for characterizing the
  // HTTP file-download path in `test/services/download/
  // download_manager_http_test.dart` without real network sockets, real
  // `HttpClient`, or platform channels. Each helper is annotated
  // `@visibleForTesting` and named `...ForTesting` so accidental production
  // use is obvious in review. The public `DownloadManager` behavior and the
  // zero-arg factory are unchanged.

  /// Directly sets the in-memory download directory used by the HTTP path,
  /// bypassing `setDownloadDir`'s `SharedPreferences` + Rust-API calls so
  /// tests do not touch platform channels.
  @visibleForTesting
  void setDownloadDirForTesting(String dir) {
    _downloadDir = dir;
    _customDownloadDir = dir;
  }

  /// Sets the download-limit Mbps used by `_throttleHttpChunk`, bypassing
  /// `setDownloadSettings`'s `SharedPreferences` persist.
  @visibleForTesting
  void setDownloadLimitMbpsForTesting(double mbps) {
    _downloadLimitMbps = mbps;
  }

  /// Seeds an HTTP [DownloadTask] directly into the manager's task map so a
  /// test can drive `_downloadHttpFile` without going through
  /// `startHttpDownload`'s slot/dir/platform-channel path.
  @visibleForTesting
  void seedHttpTaskForTesting(DownloadTask task) {
    _tasks[task.id] = task;
  }

  /// Removes a seeded task (and its paused-id entry) so tests do not leak
  /// state between cases.
  @visibleForTesting
  void removeHttpTaskForTesting(String id) {
    _tasks.remove(id);
    _pausedTaskIds.remove(id);
    _removedTaskIds.add(id);
  }

  /// Drives `_downloadHttpFile` directly so tests can assert on the
  /// resulting `task.status` / `task.progress` / partial-file bytes
  /// produced by the injected [HttpFileDownloadPort].
  @visibleForTesting
  Future<void> downloadHttpFileForTesting(DownloadTask task) =>
      _downloadHttpFile(task);

  /// Exposes `_throttleHttpChunk` so its windowed byte-counter math can be
  /// exercised directly. The default `_downloadLimitMbps == 0` path must
  /// return immediately (no throttle).
  @visibleForTesting
  Future<void> throttleHttpChunkForTesting(int chunkBytes) =>
      _throttleHttpChunk(chunkBytes);

  /// Resets the throttle window state so each budget-exhaustion test case
  /// starts from a clean window. Tests that inject a `clock` into
  /// [DownloadManager.forTesting] should call this between cases to pin the
  /// window start to the current fake time.
  @visibleForTesting
  void resetHttpThrottleForTesting() {
    _httpThrottleBytesThisWindow = 0;
    _httpThrottleWindowStart = _now();
  }

  // --- m3u8 / HLS playlist-resolution characterization test seam --------
  //
  // Mirrors the Package B HTTP seam above: exposes the minimum private
  // surface required for characterizing the `_resolveHlsSegments` recursion
  // in `test/services/download/download_manager_m3u8_test.dart` without
  // real network sockets, a real `HttpClient`, or platform channels. The
  // injected `M3u8PlaylistPort` (default `IoM3u8PlaylistPort`) supplies
  // canned playlist text; the pure `parseM3u8Playlist` parser is covered
  // separately in `test/services/download/m3u8_playlist_port_test.dart`.
  // Per-segment download / progress / cancel behavior is owned by
  // `_downloadM3u8File` and is intentionally NOT exposed here — that path
  // keeps its own `HttpClient` per-segment loop and is a separate later
  // checkpoint. The public `DownloadManager` behavior and the zero-arg
  // factory are unchanged.

  /// Drives `_resolveHlsSegments` directly so the HLS playlist-resolution
  /// recursion, `depth > 4` throw, highest-BANDWIDTH variant selection,
  /// encrypted-key rejection, empty-segment rejection, and headers/cookies
  /// forwarding can be characterized through the injected
  /// [M3u8PlaylistPort]. Returns the resolved segment `Uri` list for a
  /// media playlist (after recursing through any master playlists).
  @visibleForTesting
  Future<List<Uri>> resolveHlsSegmentsForTesting(
    Uri playlistUri, {
    Map<String, String>? headers,
    String? cookies,
  }) => _resolveHlsSegments(playlistUri, headers: headers, cookies: cookies);

  @override
  void dispose() {
    stopStatsPolling();
    _saveTasks(); // Save before disposing
    super.dispose();
  }
}
