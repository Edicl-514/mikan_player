part of '../download_manager.dart';

extension _DownloadManagerSettings on DownloadManager {
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

  /// Initialize the download manager, load saved tasks
  Future<void> _initializeImpl() async {
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
      unawaited(_libtorrentBackend.ensureInitialized());
    }
    await _loadTasks();
    _isInitialized = true;
    _ensureStatsPolling();
  }

  Future<void> _setBackendKindImpl(BtBackendKind backend) async {
    if (_backendKind == backend) return;
    _backendKind = backend;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_btBackendStorageKey, backend.storageValue);
    if (backend == BtBackendKind.libtorrent) {
      unawaited(_libtorrentBackend.ensureInitialized());
    }
    _notifyChanged();
  }

  /// Set a custom download directory (or pass null to restore default).
  /// New downloads will immediately use the new path; existing tasks are
  /// unaffected and continue in their original location.
  Future<void> _setDownloadDirImpl(String? path) async {
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
    _notifyChanged();
  }

  /// Update download settings and apply them immediately.
  Future<void> _setDownloadSettingsImpl({
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
    unawaited(_applyLibtorrentSpeedLimits());
    _syncAndroidDownloadService();
    _notifyChanged();
  }

  /// Apply current speed limits to the libtorrent session (if initialized).
  Future<void> _applyLibtorrentSpeedLimits() async {
    final dlBytes = (_downloadLimitMbps * 1024 * 1024).round();
    final ulBytes = (_uploadLimitMbps * 1024 * 1024).round();
    await _libtorrentBackend.applySpeedLimits(
      downloadLimitBytesPerSecond: dlBytes,
      uploadLimitBytesPerSecond: ulBytes,
    );
  }
}
