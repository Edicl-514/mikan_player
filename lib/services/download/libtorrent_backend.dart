// Production [BtBackend] wrapping `mikan_libtorrent_native.dart`.
//
// Phase 3 commit 2 of 3 — owns session lifecycle + id↔hash maps so commit 3
// can drop those fields from [DownloadManager]. Injectable session factory
// and default-download-dir resolver keep unit tests free of real FFI.

import 'package:flutter/foundation.dart';
import 'package:mikan_player/native/mikan_libtorrent_native.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/magnet_helpers.dart';
import 'package:mikan_player/utils/app_directories.dart';

/// Creates a configured [MikanLibtorrentSession].
typedef LibtorrentSessionFactory =
    MikanLibtorrentSession Function({String listenInterfaces});

/// Resolves the default download directory when [addTorrent] is called
/// without an explicit [downloadDir].
typedef LibtorrentDownloadDirResolver = Future<String> Function();

/// Abstract session surface used by [LibtorrentBackend] so tests can inject
/// a pure-Dart fake without loading the native DLL.
abstract interface class LibtorrentSessionPort {
  int addMagnetEx(
    String magnet, {
    String? savePath,
    String? resumePath,
    bool seedMode = false,
  });
  void saveResumeData(int torrentId, {required String resumePath});
  List<MikanLtFileInfo> getFiles(int torrentId);
  void setFilePriorities(int torrentId, List<int> priorities);
  void pauseTorrent(int torrentId);
  void resumeTorrent(int torrentId);
  void removeTorrent(int torrentId, {bool deleteFiles = false});
  List<MikanLtTorrentStats> getTorrentStats();
  void configureSession({
    int downloadLimitBytesPerSecond = -1,
    int uploadLimitBytesPerSecond = -1,
    int connectionsLimit = -1,
    bool? enableDht,
    bool? enableLsd,
    bool? enableUpnp,
    bool? enableNatPmp,
    int alertQueueSize = -1,
  });
  MikanLtStreamInfo startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = 512 * 1024 * 1024,
  });
  void stopStream(int streamId);
  void setStreamCache(
    int streamId, {
    required int capacity,
    required int readAheadPct,
    required int connectionsLimit,
  });
  void preloadStream(int streamId, {required int preloadBytes});
}

/// Adapter wrapping a real [MikanLibtorrentSession].
class NativeLibtorrentSessionPort implements LibtorrentSessionPort {
  NativeLibtorrentSessionPort(this._session);

  final MikanLibtorrentSession _session;

  @override
  int addMagnetEx(
    String magnet, {
    String? savePath,
    String? resumePath,
    bool seedMode = false,
  }) => _session.addMagnetEx(
    magnet,
    savePath: savePath,
    resumePath: resumePath,
    seedMode: seedMode,
  );

  @override
  void saveResumeData(int torrentId, {required String resumePath}) =>
      _session.saveResumeData(torrentId, resumePath: resumePath);

  @override
  List<MikanLtFileInfo> getFiles(int torrentId) => _session.getFiles(torrentId);

  @override
  void setFilePriorities(int torrentId, List<int> priorities) =>
      _session.setFilePriorities(torrentId, priorities);

  @override
  void pauseTorrent(int torrentId) => _session.pauseTorrent(torrentId);

  @override
  void resumeTorrent(int torrentId) => _session.resumeTorrent(torrentId);

  @override
  void removeTorrent(int torrentId, {bool deleteFiles = false}) =>
      _session.removeTorrent(torrentId, deleteFiles: deleteFiles);

  @override
  List<MikanLtTorrentStats> getTorrentStats() => _session.getTorrentStats();

  @override
  void configureSession({
    int downloadLimitBytesPerSecond = -1,
    int uploadLimitBytesPerSecond = -1,
    int connectionsLimit = -1,
    bool? enableDht,
    bool? enableLsd,
    bool? enableUpnp,
    bool? enableNatPmp,
    int alertQueueSize = -1,
  }) => _session.configureSession(
    downloadLimitBytesPerSecond: downloadLimitBytesPerSecond,
    uploadLimitBytesPerSecond: uploadLimitBytesPerSecond,
    connectionsLimit: connectionsLimit,
    enableDht: enableDht,
    enableLsd: enableLsd,
    enableUpnp: enableUpnp,
    enableNatPmp: enableNatPmp,
    alertQueueSize: alertQueueSize,
  );

  @override
  MikanLtStreamInfo startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = 512 * 1024 * 1024,
  }) => _session.startStream(
    torrentId,
    fileIndex: fileIndex,
    maxCacheBytes: maxCacheBytes,
  );

  @override
  void stopStream(int streamId) => _session.stopStream(streamId);

  @override
  void setStreamCache(
    int streamId, {
    required int capacity,
    required int readAheadPct,
    required int connectionsLimit,
  }) => _session.setStreamCache(
    streamId,
    capacity: capacity,
    readAheadPct: readAheadPct,
    connectionsLimit: connectionsLimit,
  );

  @override
  void preloadStream(int streamId, {required int preloadBytes}) =>
      _session.preloadStream(streamId, preloadBytes: preloadBytes);
}

/// Production [BtBackend] for [BtBackendKind.libtorrent].
class LibtorrentBackend implements BtBackend {
  LibtorrentBackend({
    LibtorrentSessionPort Function()? sessionFactory,
    LibtorrentDownloadDirResolver? defaultDownloadDirResolver,
    Duration metadataPollInterval = const Duration(milliseconds: 300),
    Duration metadataTimeout = const Duration(seconds: 90),
    Duration prioritySettleDelay = const Duration(milliseconds: 300),
  }) : _sessionFactory = sessionFactory,
       _defaultDownloadDirResolver =
           defaultDownloadDirResolver ?? _defaultResolveDownloadDir,
       _metadataPollInterval = metadataPollInterval,
       _metadataTimeout = metadataTimeout,
       _prioritySettleDelay = prioritySettleDelay;

  final LibtorrentSessionPort Function()? _sessionFactory;
  final LibtorrentDownloadDirResolver _defaultDownloadDirResolver;
  final Duration _metadataPollInterval;
  final Duration _metadataTimeout;
  final Duration _prioritySettleDelay;

  LibtorrentSessionPort? _session;
  bool _initialized = false;
  Future<void>? _initialization;

  final Map<String, int> _torrentIdsByHash = {};
  final Map<int, String> _infoHashesByTorrentId = {};
  final Map<String, int> _streamIdsByHash = {};
  final Map<String, int> _fileIdxByHash = {};
  final Map<String, int> _fileSizeByHash = {};

  int _lastDownloadLimitBytesPerSecond = 0;
  int _lastUploadLimitBytesPerSecond = 0;

  @override
  BtBackendKind get kind => BtBackendKind.libtorrent;

  /// Whether the native session has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Tracked torrent id for [infoHash], or null.
  int? torrentIdForHash(String infoHash) =>
      _torrentIdsByHash[infoHash.toLowerCase()];

  /// Tracked stream id for [infoHash], or null.
  ///
  /// Interim helper until [BtStreamBackend] owns stream lifecycle.
  int? streamIdForHash(String infoHash) =>
      _streamIdsByHash[infoHash.toLowerCase()];

  /// Tracked selected file index for [infoHash], or null.
  int? fileIdxForHash(String infoHash) =>
      _fileIdxByHash[infoHash.toLowerCase()];

  /// Tracked file size for progress math.
  int? fileSizeForHash(String infoHash) =>
      _fileSizeByHash[infoHash.toLowerCase()];

  /// Stop the HTTP stream for [infoHash] without removing the torrent.
  ///
  /// Interim helper until [BtStreamBackend] owns stream lifecycle. Clears the
  /// internal stream-id map entry.
  void stopStreamForHash(String infoHash) {
    final hashLower = infoHash.toLowerCase();
    final streamId = _streamIdsByHash.remove(hashLower);
    if (streamId == null || _session == null) return;
    try {
      _session!.stopStream(streamId);
      debugPrint('[LibtorrentBackend] Stopped stream $streamId for $hashLower');
    } catch (e) {
      debugPrint('[LibtorrentBackend] Error stopping stream $streamId: $e');
    }
  }

  /// Re-prioritize the selected file and resume after playback ends.
  ///
  /// Returns a handle with the selected file metadata when the torrent is
  /// already tracked; `null` if the torrent is not in the session (caller
  /// should [addTorrent] instead).
  Future<BtTorrentHandle?> restoreBackgroundDownload(
    String infoHash, {
    int? preferredFileIdx,
  }) async {
    if (!_initialized || _session == null) return null;
    final hashLower = infoHash.toLowerCase();
    final torrentId =
        _torrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null || !_isNativeTorrentValid(torrentId)) {
      return null;
    }

    await _waitForMetadata(torrentId);
    var fileIdx = preferredFileIdx ?? _fileIdxByHash[hashLower];
    String? filePath;
    int? fileSize = _fileSizeByHash[hashLower];
    if (fileIdx == null) {
      final file = _selectFile(torrentId);
      if (file == null) return null;
      fileIdx = file.index;
      fileSize = file.size;
      filePath = file.path;
      _fileIdxByHash[hashLower] = file.index;
      _fileSizeByHash[hashLower] = file.size;
    }

    await _prioritizeDownloadFile(torrentId, fileIdx);
    _session!.resumeTorrent(torrentId);

    return BtTorrentHandle(
      infoHash: hashLower,
      torrentId: torrentId,
      fileIdx: fileIdx,
      fileSize: fileSize,
      filePath: filePath,
    );
  }

  @override
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final pending = _initialization;
    if (pending != null) {
      await pending;
      return;
    }

    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final factory = _sessionFactory;
    if (factory != null) {
      _session = factory();
    } else {
      final native = MikanLibtorrentNative.instance.createSession(
        listenInterfaces: '0.0.0.0:49152',
      );
      _session = NativeLibtorrentSessionPort(native);
    }
    _session!.configureSession(
      connectionsLimit: 200,
      enableDht: true,
      enableLsd: true,
      enableUpnp: true,
      enableNatPmp: true,
    );
    _initialized = true;
    await applySpeedLimits(
      downloadLimitBytesPerSecond: _lastDownloadLimitBytesPerSecond,
      uploadLimitBytesPerSecond: _lastUploadLimitBytesPerSecond,
    );
    debugPrint('[LibtorrentBackend] libtorrent session initialized');
  }

  static Future<String> _defaultResolveDownloadDir() async {
    final appSupportDir = await AppDirectories.getUnifiedAppDataDirectory();
    return '${appSupportDir.path}/downloads';
  }

  @override
  Future<BtTorrentHandle> addTorrent(
    String magnet, {
    required String fallbackInfoHash,
    String? downloadDir,
    bool startStream = false,
    bool seedMode = false,
    String? resumePath,
  }) async {
    await ensureInitialized();
    final session = _session!;
    final infoHash = fallbackInfoHash.toLowerCase();
    var torrentId = _torrentIdsByHash[infoHash];
    if (torrentId == null || !_isNativeTorrentValid(torrentId)) {
      final effectiveDownloadDir =
          (downloadDir != null && downloadDir.isNotEmpty)
          ? downloadDir
          : await _defaultDownloadDirResolver();
      if (effectiveDownloadDir.isEmpty) {
        throw StateError('Download directory is not initialized');
      }
      final enrichedMagnet = injectMagnetTrackers(magnet);
      torrentId = session.addMagnetEx(
        enrichedMagnet,
        savePath: effectiveDownloadDir,
        resumePath: resumePath,
        seedMode: seedMode,
      );
      _torrentIdsByHash[infoHash] = torrentId;
      _infoHashesByTorrentId[torrentId] = infoHash;
    }

    await _waitForMetadata(torrentId);
    final file = _selectFile(torrentId);
    if (file == null) {
      throw Exception('Error: No streamable files found in torrent');
    }

    await _prioritizeDownloadFile(torrentId, file.index);
    // Explicitly resume: without auto_managed the torrent won't start on its own.
    session.resumeTorrent(torrentId);

    _fileIdxByHash[infoHash] = file.index;
    _fileSizeByHash[infoHash] = file.size;

    if (!startStream) {
      return BtTorrentHandle(
        infoHash: infoHash,
        fileIdx: file.index,
        fileSize: file.size,
        filePath: file.path,
        torrentId: torrentId,
      );
    }

    final existingStreamId = _streamIdsByHash.remove(infoHash);
    if (existingStreamId != null) {
      try {
        session.stopStream(existingStreamId);
      } catch (e) {
        debugPrint('[LibtorrentBackend] Error stopping prior stream: $e');
      }
    }

    final stream = session.startStream(
      torrentId,
      fileIndex: file.index,
      maxCacheBytes: 16 * 1024 * 1024,
    );
    _warmUpStream(stream);
    _streamIdsByHash[infoHash] = stream.id;

    return BtTorrentHandle(
      infoHash: infoHash,
      streamUrl: stream.url,
      fileIdx: file.index,
      fileSize: file.size,
      filePath: file.path,
      torrentId: torrentId,
      streamId: stream.id,
    );
  }

  Future<void> _waitForMetadata(int torrentId) async {
    final session = _session!;
    final deadline = DateTime.now().add(_metadataTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final stats = session.getTorrentStats();
      final torrent = stats.where((s) => s.torrentId == torrentId).firstOrNull;
      if (torrent != null && torrent.hasMetadata) return;
      if (torrent != null && torrent.errorMessage.isNotEmpty) {
        throw Exception(
          'Error getting torrent metadata: ${torrent.errorMessage}',
        );
      }
      await Future<void>.delayed(_metadataPollInterval);
    }
    throw Exception(
      'Error adding torrent: timed out waiting for torrent metadata',
    );
  }

  void _warmUpStream(MikanLtStreamInfo stream) {
    final session = _session!;
    try {
      session.setStreamCache(
        stream.id,
        capacity: 16 * 1024 * 1024,
        readAheadPct: 0,
        connectionsLimit: 200,
      );
      session.preloadStream(stream.id, preloadBytes: 4 * 1024 * 1024);
    } catch (e) {
      debugPrint('[LibtorrentBackend] Error warming up stream: $e');
    }
  }

  MikanLtFileInfo? _selectFile(int torrentId) {
    final files = _session!.getFiles(torrentId);
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
    if (_session == null) return false;
    try {
      final stats = _session!.getTorrentStats();
      return stats.any((s) => s.torrentId == torrentId);
    } catch (_) {
      return false;
    }
  }

  int? _findNativeTorrentIdByHash(String infoHash) {
    if (_session == null) return null;
    try {
      final stats = _session!.getTorrentStats();
      for (final s in stats) {
        if (s.infoHash.toLowerCase() == infoHash.toLowerCase()) {
          _torrentIdsByHash[infoHash] = s.torrentId;
          _infoHashesByTorrentId[s.torrentId] = infoHash;
          return s.torrentId;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _prioritizeDownloadFile(int torrentId, int fileIndex) async {
    final files = _session!.getFiles(torrentId);
    if (files.isEmpty) return;

    final maxIndex = files.fold<int>(
      -1,
      (current, file) => file.index > current ? file.index : current,
    );
    if (fileIndex < 0 || fileIndex > maxIndex) return;

    final priorities = List<int>.filled(maxIndex + 1, 0);
    priorities[fileIndex] = 7;
    _session!.setFilePriorities(torrentId, priorities);
    await Future<void>.delayed(_prioritySettleDelay);
  }

  @override
  Future<bool> pauseTorrent(String infoHash) async {
    if (!_initialized) return false;
    final hashLower = infoHash.toLowerCase();
    final torrentId =
        _torrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return false;
    _session!.pauseTorrent(torrentId);
    return true;
  }

  @override
  Future<bool> resumeTorrent(String infoHash) async {
    if (!_initialized) return false;
    final hashLower = infoHash.toLowerCase();
    final torrentId =
        _torrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return false;
    _session!.resumeTorrent(torrentId);
    return true;
  }

  @override
  Future<bool> removeTorrent(
    String infoHash, {
    bool deleteFiles = false,
    String? resumePath,
  }) async {
    if (!_initialized) return false;
    final hashLower = infoHash.toLowerCase();
    final session = _session!;
    final streamId = _streamIdsByHash.remove(hashLower);
    if (streamId != null) {
      try {
        session.stopStream(streamId);
      } catch (e) {
        debugPrint('[LibtorrentBackend] Error stopping stream: $e');
      }
    }
    var torrentId = _torrentIdsByHash.remove(hashLower);
    if (torrentId == null) {
      torrentId = _findNativeTorrentIdByHash(hashLower);
      if (torrentId == null) return false;
      _torrentIdsByHash.remove(hashLower);
    }
    _infoHashesByTorrentId.remove(torrentId);
    _fileIdxByHash.remove(hashLower);
    _fileSizeByHash.remove(hashLower);

    if (!deleteFiles && resumePath != null && resumePath.isNotEmpty) {
      try {
        session.saveResumeData(torrentId, resumePath: resumePath);
      } catch (e) {
        debugPrint(
          '[LibtorrentBackend] Error saving resume data before stop: $e',
        );
      }
    }
    session.removeTorrent(torrentId, deleteFiles: deleteFiles);
    return true;
  }

  @override
  Future<List<BtTorrentStats>> getStats() async {
    if (!_initialized || _session == null) return const [];
    final session = _session!;
    final nativeStats = session.getTorrentStats();
    final results = <BtTorrentStats>[];
    for (final stats in nativeStats) {
      final infoHash = _infoHashesByTorrentId[stats.torrentId];
      if (infoHash == null) continue;

      final totalSize = _fileSizeByHash[infoHash] ?? stats.totalWanted;
      final downloaded = totalSize > 0
          ? stats.totalDone.clamp(0, totalSize)
          : stats.totalDone;
      final progress = totalSize > 0
          ? (downloaded / totalSize * 100.0).clamp(0.0, 100.0)
          : stats.progress;
      results.add(
        BtTorrentStats(
          infoHash: infoHash,
          name: stats.name.isEmpty ? 'Torrent ${stats.torrentId}' : stats.name,
          state: _normalizeNativeState(stats),
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

  String _normalizeNativeState(MikanLtTorrentStats stats) {
    if (stats.isPaused) return 'paused';
    if (stats.errorMessage.isNotEmpty) return 'error';
    // libtorrent state_t: 0=queued_for_checking, 1=checking_files,
    // 2=downloading_metadata, 3=downloading, 4=finished, 5=seeding,
    // 6=allocating, 7=checking_resume_data
    switch (stats.state) {
      case 2:
        return 'metadata';
      case 0:
      case 1:
      case 7:
        return 'checking';
      case 3:
      case 4:
      case 5:
      case 6:
        return 'live';
      default:
        return 'initializing';
    }
  }

  @override
  Future<bool> isTorrentManaged(String infoHash) async {
    if (!_initialized) return false;
    final hashLower = infoHash.toLowerCase();
    final torrentId =
        _torrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return false;
    try {
      final stats = _session!.getTorrentStats();
      final match = stats.where((s) => s.torrentId == torrentId).firstOrNull;
      if (match == null) return false;
      return match.errorMessage.isEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setFilePriorities(String infoHash, List<int> priorities) async {
    if (!_initialized) return;
    final hashLower = infoHash.toLowerCase();
    final torrentId =
        _torrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return;
    _session!.setFilePriorities(torrentId, priorities);
  }

  @override
  Future<bool> saveResumeData(String infoHash, String resumePath) async {
    if (!_initialized || _session == null) return false;
    final hashLower = infoHash.toLowerCase();
    final torrentId =
        _torrentIdsByHash[hashLower] ?? _findNativeTorrentIdByHash(hashLower);
    if (torrentId == null) return false;
    _session!.saveResumeData(torrentId, resumePath: resumePath);
    return true;
  }

  @override
  Future<void> applySpeedLimits({
    int downloadLimitBytesPerSecond = 0,
    int uploadLimitBytesPerSecond = 0,
  }) async {
    _lastDownloadLimitBytesPerSecond = downloadLimitBytesPerSecond;
    _lastUploadLimitBytesPerSecond = uploadLimitBytesPerSecond;
    if (!_initialized || _session == null) return;
    _session!.configureSession(
      downloadLimitBytesPerSecond: downloadLimitBytesPerSecond,
      uploadLimitBytesPerSecond: uploadLimitBytesPerSecond,
    );
  }
}
