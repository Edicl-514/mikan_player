// Production [BtBackend] wrapping the Rust `rust_api` (rqbit) surface.
//
// Phase 3 commit 2 of 3 — pure production impl; the manager still inlines
// the rqbit branch until commit 3 wires this class in. Injectable [RqbitApi]
// lets unit tests exercise the mapping without a real Rust engine (mirrors
// `HttpFileDownloadPort` / `IoHttpFileDownloadPort`).

import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/magnet_helpers.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust_api;

/// Injectable seam for the rqbit Rust API used by [RqbitBackend].
///
/// Production default is [RustRqbitApi]; tests inject a fake.
abstract interface class RqbitApi {
  Future<void> setDownloadDir({required String dir});
  Future<String> startTorrent({required String magnet});
  Future<bool> pauseTorrent({required String infoHash});
  Future<bool> resumeTorrent({required String infoHash});
  Future<bool> stopTorrent({
    required String infoHash,
    required bool deleteFiles,
  });
  Future<List<rust_api.TorrentStats>> getTorrentStats();
}

/// Production [RqbitApi] that forwards to `rust_api` top-level functions.
class RustRqbitApi implements RqbitApi {
  const RustRqbitApi();

  @override
  Future<void> setDownloadDir({required String dir}) =>
      rust_api.setDownloadDir(dir: dir);

  @override
  Future<String> startTorrent({required String magnet}) =>
      rust_api.startTorrent(magnet: magnet);

  @override
  Future<bool> pauseTorrent({required String infoHash}) =>
      rust_api.pauseTorrent(infoHash: infoHash);

  @override
  Future<bool> resumeTorrent({required String infoHash}) =>
      rust_api.resumeTorrent(infoHash: infoHash);

  @override
  Future<bool> stopTorrent({
    required String infoHash,
    required bool deleteFiles,
  }) => rust_api.stopTorrent(infoHash: infoHash, deleteFiles: deleteFiles);

  @override
  Future<List<rust_api.TorrentStats>> getTorrentStats() =>
      rust_api.getTorrentStats();
}

/// Production [BtBackend] for [BtBackendKind.rqbit].
class RqbitBackend implements BtBackend {
  RqbitBackend({RqbitApi? api}) : _api = api ?? const RustRqbitApi();

  final RqbitApi _api;

  @override
  BtBackendKind get kind => BtBackendKind.rqbit;

  @override
  Future<void> ensureInitialized() async {
    // rqbit engine init lives elsewhere (`rust_api.initEngine`); per-add
    // `setDownloadDir` is applied inside [addTorrent].
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
    // seedMode / resumePath are libtorrent-only; ignored for rqbit.
    final effectiveDownloadDir = downloadDir;
    if (effectiveDownloadDir != null && effectiveDownloadDir.isNotEmpty) {
      await _api.setDownloadDir(dir: effectiveDownloadDir);
    }
    final streamUrl = await _api.startTorrent(magnet: magnet);
    if (streamUrl.startsWith('Error')) {
      throw Exception(streamUrl);
    }
    final infoHash =
        extractInfoHashFromStreamUrl(streamUrl) ?? fallbackInfoHash;
    return BtTorrentHandle(
      infoHash: infoHash.toLowerCase(),
      streamUrl: streamUrl,
      fileIdx: _extractFileIdxFromUrl(streamUrl),
    );
  }

  @override
  Future<bool> pauseTorrent(String infoHash) =>
      _api.pauseTorrent(infoHash: infoHash);

  @override
  Future<bool> resumeTorrent(String infoHash) =>
      _api.resumeTorrent(infoHash: infoHash);

  @override
  Future<bool> removeTorrent(
    String infoHash, {
    bool deleteFiles = false,
    String? resumePath,
  }) => _api.stopTorrent(infoHash: infoHash, deleteFiles: deleteFiles);

  @override
  Future<List<BtTorrentStats>> getStats() async {
    final stats = await _api.getTorrentStats();
    return stats
        .map(
          (s) => BtTorrentStats(
            infoHash: s.infoHash.toLowerCase(),
            name: s.name,
            state: s.state,
            progress: s.progress,
            downloadSpeed: s.downloadSpeed,
            uploadSpeed: s.uploadSpeed,
            downloaded: s.downloaded,
            totalSize: s.totalSize,
            peers: s.peers,
            seeders: s.seeders,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> isTorrentManaged(String infoHash) async {
    try {
      final hashLower = infoHash.toLowerCase();
      final stats = await _api.getTorrentStats();
      return stats.any(
        (stat) =>
            stat.infoHash.toLowerCase() == hashLower && stat.state != 'error',
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setFilePriorities(String infoHash, List<int> priorities) async {
    // rqbit has no per-file priority API.
  }

  @override
  Future<bool> saveResumeData(String infoHash, String resumePath) async {
    // rqbit persists resume internally on the Rust side.
    return false;
  }

  @override
  Future<void> applySpeedLimits({
    int downloadLimitBytesPerSecond = 0,
    int uploadLimitBytesPerSecond = 0,
  }) async {
    // rqbit speed limits go through `rust_api.updateConfig` elsewhere.
  }

  /// Extract file index from stream URL (e.g. `.../stream/0` → 0).
  /// Mirrors `download_manager.dart:_extractFileIdxFromUrl`.
  static int? _extractFileIdxFromUrl(String url) {
    final regex = RegExp(r'/stream/(\d+)(?:[/?#]|$)');
    final match = regex.firstMatch(url);
    final raw = match?.group(1);
    return raw == null ? null : int.tryParse(raw);
  }
}
