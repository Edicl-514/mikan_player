import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download/bt_stream_capability.dart';
import 'package:mikan_player/services/download/bt_stream_restore_coordinator.dart';
import 'package:mikan_player/services/download/download_file_cleanup.dart';
import 'package:mikan_player/services/download/download_path_utils.dart';
import 'package:mikan_player/services/download/download_queue.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/download_task_store.dart';
import 'package:mikan_player/services/download/http_download_job.dart';
import 'package:mikan_player/services/download/http_download_retry.dart';
import 'package:mikan_player/services/download/http_file_download_port.dart';
import 'package:mikan_player/services/download/libtorrent_backend.dart';
import 'package:mikan_player/services/download/m3u8_downloader.dart';
import 'package:mikan_player/services/download/m3u8_playlist_port.dart';
import 'package:mikan_player/services/download/magnet_helpers.dart';
import 'package:mikan_player/services/download/rqbit_backend.dart';
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

part 'download/download_manager_settings.dart';
part 'download/download_android_service_bridge.dart';
part 'download/download_stats_poller.dart';
part 'download/download_http_pipeline.dart';
part 'download/download_bt_session.dart';

const String _btBackendStorageKey = 'bt_backend_v1';
const String _maxConcurrentKey = 'download_max_concurrent';
const String _downloadLimitKey = 'download_limit_mbps';
const String _uploadLimitKey = 'upload_limit_mbps';
const String _allowBackgroundDownloadKey = 'allow_background_download';
const String _keepSeedingInBackgroundKey = 'keep_seeding_in_background';
const String _customDownloadDirKey = 'download_dir_custom';

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
      _sleep = _defaultThrottleSleep,
      _rqbitBackend = RqbitBackend(),
      _libtorrentBackend = LibtorrentBackend(),
      _streamRestoreDelay = const Duration(milliseconds: 300),
      _streamRestores = BtStreamRestoreCoordinator(
        onError: _logStreamRestoreError,
      );

  /// Test constructor: injects an [HttpFileDownloadPort] and a
  /// [M3u8PlaylistPort] so the HTTP file-download and m3u8 playlist-
  /// resolution paths can be exercised without real network sockets or a
  /// real `HttpClient`. Optional BT backends allow manager-side BT tests.
  /// The zero-arg [factory DownloadManager] still uses
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
    BtBackend? rqbitBackend,
    LibtorrentBtBackend? libtorrentBackend,
    Duration streamRestoreDelay = Duration.zero,
    Future<void> Function(Duration)? streamRestoreSleep,
  }) : _httpPort = httpPort ?? IoHttpFileDownloadPort(),
       _m3u8Port = m3u8Port ?? IoM3u8PlaylistPort(),
       _now = clock ?? _defaultThrottleNow,
       _sleep = sleep ?? _defaultThrottleSleep,
       _rqbitBackend = rqbitBackend ?? RqbitBackend(),
       _libtorrentBackend = libtorrentBackend ?? LibtorrentBackend(),
       _streamRestoreDelay = streamRestoreDelay,
       _streamRestores = BtStreamRestoreCoordinator(
         sleep: streamRestoreSleep,
         onError: _logStreamRestoreError,
       ) {
    if (clock != null) {
      _httpThrottleWindowStart = clock();
    }
  }

  final HttpFileDownloadPort _httpPort;
  final M3u8PlaylistPort _m3u8Port;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;
  final BtBackend _rqbitBackend;

  /// Core BT and HTTP-stream operations must share one backend instance.
  final LibtorrentBtBackend _libtorrentBackend;

  static DateTime _defaultThrottleNow() => DateTime.now();
  static Future<void> _defaultThrottleSleep(Duration d) => Future.delayed(d);
  static void _logStreamRestoreError(Object error, StackTrace stackTrace) {
    debugPrint(
      '[DownloadManager] Error restoring libtorrent background download: '
      '$error',
    );
  }

  void _notifyChanged() => notifyListeners();

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
  String? _downloadDir;
  String? _customDownloadDir;
  final Set<String> _activeStreamHashes = {}; // Track active playback streams
  final Set<String> _ltCompletionResumeSavedHashes = {};
  static const Duration _ltResumeSaveInterval = Duration(minutes: 1);

  /// Delay before post-playback background restore. Production uses 300ms so
  /// a quick re-activate can cancel the restore; tests inject [Duration.zero].
  final Duration _streamRestoreDelay;
  final BtStreamRestoreCoordinator _streamRestores;

  BtBackend _backendFor(BtBackendKind kind) =>
      kind == BtBackendKind.libtorrent ? _libtorrentBackend : _rqbitBackend;

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

  // HTTP / HLS active-job registry (cancel via pause/remove).
  final Map<String, ActiveHttpDownload> _httpDownloadJobs = {};

  /// Monotonic generation per HTTP/HLS task id. Bumped at the start of every
  /// `_downloadHttpFile` so a superseded run (pause→resume while the previous
  /// async body is still winding down) stops writing and cannot re-pause.
  final Map<String, int> _httpRunGeneration = {};

  /// Chains successive HTTP/HLS bodies for the same task id so only one run
  /// holds the slot / writes the file at a time. Pause→resume waits for the
  /// previous body to exit (and release its slot) before the new body starts.
  final Map<String, Future<void>> _httpRunChain = {};

  /// Simple HTTP download speed limiter.
  /// Tracks bytes written within the current 1-second window and sleeps
  /// when the budget is exhausted.
  int _httpThrottleBytesThisWindow = 0;
  DateTime _httpThrottleWindowStart = DateTime.now();

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

  void saveLibtorrentResumeDataForShutdown() =>
      _saveLibtorrentResumeDataForShutdownImpl();

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
  Future<void> initialize() => _initializeImpl();

  Future<void> setBackendKind(BtBackendKind backend) =>
      _setBackendKindImpl(backend);

  /// Set a custom download directory (or pass null to restore default).
  /// New downloads will immediately use the new path; existing tasks are
  /// unaffected and continue in their original location.
  Future<void> setDownloadDir(String? path) => _setDownloadDirImpl(path);

  /// Update download settings and apply them immediately.
  Future<void> setDownloadSettings({
    int? maxConcurrent,
    double? downloadLimitMbps,
    double? uploadLimitMbps,
    bool? allowBackgroundDownload,
    bool? keepSeedingInBackground,
  }) => _setDownloadSettingsImpl(
    maxConcurrent: maxConcurrent,
    downloadLimitMbps: downloadLimitMbps,
    uploadLimitMbps: uploadLimitMbps,
    allowBackgroundDownload: allowBackgroundDownload,
    keepSeedingInBackground: keepSeedingInBackground,
  );

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
  }) => _startDownloadImpl(
    magnet: magnet,
    name: name,
    animeName: animeName,
    episodeNumber: episodeNumber,
    forPlayback: forPlayback,
  );

  /// Create a streaming URL for an existing task only when playback needs it.
  ///
  /// For the libtorrent backend this avoids starting the HTTP streaming engine
  /// during plain downloads. The stream engine deliberately reprioritizes
  /// pieces around the playback window, which is good for watching but bad for
  /// full-file background downloading.
  ///
  /// For HTTP tasks, returns the local file path directly.
  Future<String?> getOrCreateStreamUrl(String id) =>
      _getOrCreateStreamUrlImpl(id);

  /// Start a new HTTP download task for an online video source.
  /// Returns the task ID on success, null on failure.
  Future<String?> startHttpDownload({
    required String url,
    required String name,
    Map<String, String>? headers,
    String? cookies,
    String? animeName,
    int? episodeNumber,
  }) => _startHttpDownloadImpl(
    url: url,
    name: name,
    headers: headers,
    cookies: cookies,
    animeName: animeName,
    episodeNumber: episodeNumber,
  );

  Future<void> handleAppResumed() => _handleAppResumedImpl();

  void stopStatsPolling() => _stopStatsPollingImpl();

  /// Pause a download task
  /// This stops the torrent without deleting files
  Future<bool> pauseTask(String id) => _pauseTaskImpl(id);

  /// Resume a paused download task, or retry a failed HTTP download.
  ///
  /// HTTP/HLS: works for both [DownloadTaskStatus.paused] and
  /// [DownloadTaskStatus.error]. Partial bytes / HLS segment checkpoints are
  /// kept so a network blip does not force a full re-download.
  ///
  /// BT: uses the backend pause/unpause path when possible. If the app was
  /// restarted and the paused torrent is no longer in the backend session,
  /// it falls back to restarting the torrent from the saved magnet link.
  Future<bool> resumeTask(String id) => _resumeTaskImpl(id);

  /// Remove a download task
  Future<void> removeTask(String id, {bool deleteFiles = false}) =>
      _removeTaskImpl(id, deleteFiles: deleteFiles);

  /// Notify that a BT stream is now active (being played) or inactive.
  ///
  /// When a libtorrent HTTP reader goes away, the native streaming backend may
  /// leave piece priorities focused around the old playback window. Reset the
  /// selected file priority so the download keeps progressing in the background.
  void setActiveStream(String? infoHash, {bool active = true}) =>
      _setActiveStreamImpl(infoHash, active: active);

  /// Clear completed tasks
  Future<void> clearCompleted({bool deleteFiles = false}) =>
      _clearCompletedImpl(deleteFiles: deleteFiles);

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
  // Thin wrapper around [resolveHlsSegments] so manager-side tests keep a
  // stable entry point while the recursion lives in `m3u8_downloader.dart`.

  /// Drives HLS playlist resolution through the injected [M3u8PlaylistPort].
  @visibleForTesting
  Future<List<Uri>> resolveHlsSegmentsForTesting(
    Uri playlistUri, {
    Map<String, String>? headers,
    String? cookies,
  }) => resolveHlsSegments(
    m3u8Port: _m3u8Port,
    playlistUri: playlistUri,
    headers: headers,
    cookies: cookies,
  );

  // --- BT backend characterization test seam (Phase 3 commit 3) -----------

  /// Seeds a BT [DownloadTask] into the manager without calling production
  /// start/resume paths.
  @visibleForTesting
  void seedBtTaskForTesting(DownloadTask task) {
    _tasks[task.id] = task;
  }

  /// Runs one stats poll so tests can assert backend→task status mapping.
  @visibleForTesting
  Future<void> updateStatsForTesting() => _updateStats();

  /// Direct pause dispatch for a seeded BT task (skips HTTP branch).
  @visibleForTesting
  Future<bool> pauseBtTaskForTesting(String id) => pauseTask(id);

  /// Direct resume dispatch for a seeded BT task.
  @visibleForTesting
  Future<bool> resumeBtTaskForTesting(String id) => resumeTask(id);

  /// Direct remove dispatch for a seeded BT task.
  @visibleForTesting
  Future<void> removeBtTaskForTesting(String id, {bool deleteFiles = false}) =>
      removeTask(id, deleteFiles: deleteFiles);

  /// Starts a BT download via the public path with injected backends.
  @visibleForTesting
  Future<String?> startBtDownloadForTesting({
    required String magnet,
    required String name,
    bool forPlayback = false,
  }) => startDownload(magnet: magnet, name: name, forPlayback: forPlayback);

  /// Forces the default backend kind used by new [startDownload] calls.
  @visibleForTesting
  void setBackendKindForTesting(BtBackendKind kind) {
    _backendKind = kind;
  }

  /// Playback-stream reattach path (public [getOrCreateStreamUrl]).
  @visibleForTesting
  Future<String?> getOrCreateStreamUrlForTesting(String id) =>
      getOrCreateStreamUrl(id);

  /// Whether [infoHash] is currently tracked as an active playback stream.
  @visibleForTesting
  bool isActiveStreamForTesting(String infoHash) =>
      _activeStreamHashes.contains(infoHash.toLowerCase());

  /// Awaits any in-flight stop→background restore jobs (deterministic tests).
  @visibleForTesting
  Future<void> waitPendingStreamRestoresForTesting() =>
      _streamRestores.waitForIdle();

  @override
  void dispose() {
    _streamRestores.dispose();
    _activeStreamHashes.clear();
    stopStatsPolling();
    _saveTasks(); // Save before disposing
    super.dispose();
  }
}
