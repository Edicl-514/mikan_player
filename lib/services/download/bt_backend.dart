// Injectable BitTorrent backend seam (Phase 3 commit 1 of 3 — the
// `download_manager.dart` BT-layer refactor).
//
// The production [DownloadManager] currently inlines two parallel BT-backend
// branches (`BtBackendKind.rqbit` vs `BtBackendKind.libtorrent`) at ~77
// call sites in `download_manager.dart` (2660 lines). This file introduces
// a pure `abstract interface class BtBackend` that captures the core BT
// operation surface (init, add, pause, resume, cancel, status,
// file-priorities, resume-data, speed-limits) so the manager can hold a
// single backend instance per kind and dispatch on `DownloadTask.backend`
// without re-checking `_libtorrentInitialized` / `_nativeSession` /
// `_ltTorrentIdsByHash` everywhere.
//
// Mirrors the "interface + result DTOs + production impl + Fake for tests"
// commit shape established by `http_file_download_port.dart` (138 lines)
// and `m3u8_playlist_port.dart`. The production `RqbitBackend` (wrapping the
// Rust `rust_api` surface) and `LibtorrentBackend` (wrapping
// `mikan_libtorrent_native.dart`) are wired into the manager in a follow-up
// commit (3 of 3); this commit is PURELY ADDITIVE and does NOT edit
// `download_manager.dart`.
//
// Streaming control (the libtorrent HTTP streaming engine: reattach-to-
// stream, stop-stream-only, stream-cache warmup/preload, playback→
// background re-prioritization, active-stream lifecycle) is deliberately
// DEFERRED to a follow-up `BtStreamBackend` interface because it has its
// own lifecycle (active/inactive playback windows, piece-priority recovery
// around the read cursor) that is orthogonal to the torrent's download
// lifecycle. See the class-level doc on [BtBackend] for the explicit list.

import 'dart:async';

import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/magnet_helpers.dart';

/// Pure BitTorrent backend interface capturing the core BT operations the
/// `DownloadManager` currently dispatches across `BtBackendKind.rqbit` vs
/// `BtBackendKind.libtorrent`.
///
/// Implementable by:
/// (a) a `RqbitBackend` wrapping the Rust `rust_api.startTorrent` /
///     `pauseTorrent` / `resumeTorrent` / `stopTorrent` / `getTorrentStats`
///     surface (`lib/src/rust/api/simple.dart`);
/// (b) a `LibtorrentBackend` wrapping `mikan_libtorrent_native.dart`
///     (`MikanLibtorrentSession.addMagnetEx` / `pauseTorrent` /
///     `resumeTorrent` / `removeTorrent` / `getTorrentStats` /
///     `setFilePriorities` / `saveResumeData` / `configureSession`);
/// (c) the [FakeBtBackend] defined below, used by contract tests and the
///     future manager-side characterization tests.
///
/// Keyed by lowercased info-hash wherever a torrent handle is needed: the
/// manager already maintains `_ltTorrentIdsByHash` + `_ltInfoHashesByTorrentId`
/// maps and `_extractInfoHashFromMagnet`, so info-hash is the cross-backend
/// natural key (rqbit is hash-keyed; libtorrent is torrentId-keyed but the
/// backend impl translates internally). The manager rewrite (commit 3)
/// absorbs the `_ltTorrentIdsByHash` translation into the `LibtorrentBackend`
/// impl so the manager stops tracking native ids.
///
/// **Streaming control is DEFERRED to a follow-up `BtStreamBackend`
/// interface** because the libtorrent HTTP streaming engine has its own
/// lifecycle (active/inactive playback windows, piece-priority recovery
/// around the read cursor) that is orthogonal to the torrent's download
/// lifecycle. Operations deferred to `BtStreamBackend`:
///
///   - `getOrCreateStreamUrl` — reattach to an existing torrent's stream for
///     playback (`download_manager.dart:1518-1594`). It has its own
///     resume-paused-then-stream orchestration + side-effect fan-out
///     (notifyListeners / saveTasks) that belongs in the manager; only the
///     pure "start stream for an existing tracked torrent" half is a
///     stream-backend op.
///   - `_stopLibtorrentStreamForHash` — stop a libtorrent stream WITHOUT
///     removing the torrent (`download_manager.dart:2364-2385`). The
///     streaming active/inactive lifecycle is orthogonal to torrent removal
///     (which [removeTorrent] handles, including stopping any active stream).
///   - `_warmUpLibtorrentStream` — `setStreamCache` + `preloadStream` after
///     a stream starts or seeks (`download_manager.dart:945-958`). Pure
///     streaming-cache tuning the manager drives around playback windows.
///     The INITIAL warmup that [addTorrent] performs inline (when
///     `startStream: true`) stays inside [addTorrent]'s libtorrent impl;
///     the post-seek RE-warmup becomes a `BtStreamBackend` op.
///   - `_restoreLibtorrentBackgroundDownload` — re-prioritize files for
///     background download when playback ends
///     (`download_manager.dart:2387-2471`). Playback→background
///     transition with its own delay + guard state that crosses the
///     torrent/stream boundary.
///   - `setActiveStream` — playback active/inactive lifecycle
///     (`download_manager.dart:2478-2514`). Tracks active playback streams
///     and drives the restore-background path.
///   - `setStreamCache` / `preloadStream` — fine-grained cache control
///     (`download_manager.dart:948-955`). Called only from
///     `_warmUpLibtorrentStream`; owned by the stream backend.
///   - The libtorrent HTTP reader teardown at
///     `download_manager.dart:2475-2512` — the reader lifecycle is part of
///     the HTTP streaming engine, not the torrent's download lifecycle.
abstract interface class BtBackend {
  /// The backend kind (`rqbit` or `libtorrent`) this instance implements.
  /// Lets the manager route a task to the right backend instance without
  /// `is`-checks, matching the per-task `DownloadTask.backend` field.
  BtBackendKind get kind;

  /// Lazily initialize the backend session.
  ///
  /// Mirrors `download_manager.dart:782-828`
  /// (`_ensureLibtorrentInitialized` + `_initializeLibtorrent`). For the
  /// rqbit backend this is a no-op (rqbit's Rust engine is initialized
  /// elsewhere via `rust_api.initEngine` and `rust_api.setDownloadDir` is
  /// applied per-add inside [addTorrent]). For the libtorrent backend this
  /// creates the native `MikanLibtorrentSession`, configures it (DHT/LSD/
  /// UPnP/NAT-PMP, 200-connection limit), and applies the current speed
  /// limits. Idempotent: a second call after success returns immediately;
  /// after a failure the next call retries (matching the
  /// `_libtorrentInitialization = null` reset on error at :794-797).
  Future<void> ensureInitialized();

  /// Add a magnet to the active session, wait for metadata, select the
  /// largest streamable file, prioritize it, and resume the torrent.
  ///
  /// Mirrors `download_manager.dart:830-924`
  /// (`_startTorrentWithBackend`). The current manager bundles add +
  /// metadata-wait + file-select + prioritize + explicit-resume +
  /// (optional) startStream into one call; this method preserves that
  /// bundle so the manager rewrite is mechanical.
  ///
  /// [fallbackInfoHash] is used when the magnet's info-hash can't be parsed
  /// (matches the manager's `_extractInfoHashFromUrl(streamUrl) ??
  /// fallbackInfoHash` fallback for rqbit and the
  /// `fallbackInfoHash.toLowerCase()` seed for libtorrent). The returned
  /// [BtTorrentHandle.infoHash] is the lowercased resolved hash.
  ///
  /// When [startStream] is `true`, the libtorrent impl also starts the
  /// HTTP stream engine (`session.startStream`) and returns
  /// [BtTorrentHandle.streamUrl] / [BtTorrentHandle.streamId] (and runs
  /// the initial `_warmUpLibtorrentStream` warmup inline); when `false`,
  /// those are `null`. The rqbit impl always starts a stream (rqbit's
  /// `rust_api.startTorrent` is stream-URL-centric and has no
  /// "add-without-streaming" API), so `streamUrl` is populated regardless
  /// of [startStream] — matching the current manager behavior.
  ///
  /// Deliberate adaptation (documented for commit 3): the manager passes
  /// `downloadDir` per-call; the backend impl falls back to its own
  /// configured default when `null` (replacing the manager's
  /// `_downloadDir ?? task?.downloadDir ?? _downloadDir` resolution at
  /// :859-861).
  /// Optional [seedMode] / [resumePath] are libtorrent-only fast-resume
  /// knobs (mirrors `session.addMagnetEx(..., seedMode:, resumePath:)` at
  /// `download_manager.dart:872-877`). The rqbit impl ignores them. Defaults
  /// keep existing Fake / call sites compiling unchanged.
  Future<BtTorrentHandle> addTorrent(
    String magnet, {
    required String fallbackInfoHash,
    String? downloadDir,
    bool startStream = false,
    bool seedMode = false,
    String? resumePath,
  });

  /// Pause a tracked torrent.
  ///
  /// Mirrors `download_manager.dart:1115-1129`
  /// (`_pauseTorrentWithBackend`). rqbit: `rust_api.pauseTorrent(infoHash)`.
  /// libtorrent: translates the lowercased info-hash to the native
  /// torrentId (via the impl's tracked id↔hash map, replacing the
  /// manager's `_ltTorrentIdsByHash[hash] ?? _findNativeTorrentIdByHash`)
  /// and calls `session.pauseTorrent(torrentId)`.
  ///
  /// Returns `true` if the torrent was tracked and paused; `false` if not
  /// tracked or the backend session is not initialized (matching the
  /// manager's `if (!_libtorrentInitialized) return false` early return).
  ///
  /// The manager currently inlines a try/catch around the rqbit path's
  /// `rust_api.pauseTorrent` (logging `Error checking rqbit torrent state`
  /// at :1086-1090 is a sibling helper, not this call); the interface
  /// propagates the exception and the manager retains the catch.
  Future<bool> pauseTorrent(String infoHash);

  /// Resume a paused torrent.
  ///
  /// Mirrors `download_manager.dart:1131-1145`
  /// (`_resumeTorrentWithBackend`). rqbit: `rust_api.resumeTorrent`.`
  /// libtorrent: `session.resumeTorrent(torrentId)`. Returns `true` if the
  /// torrent was tracked and resumed; `false` if not tracked or the
  /// backend session is not initialized.
  Future<bool> resumeTorrent(String infoHash);

  /// Stop and remove a torrent from the backend session.
  ///
  /// Mirrors `download_manager.dart:1147-1195`
  /// (`_stopTorrentWithBackend`). The backend:
  ///   1. stops any active stream for this hash (libtorrent:
  ///      `session.stopStream(streamId)` if a stream id is tracked, matching
  ///      :1159-1166; the streaming-engine teardown itself is deferred to
  ///      `BtStreamBackend` but the torrent-removal path keeps its
  ///      stop-active-stream step so removal is self-contained);
  ///   2. when [resumePath] is non-null and [deleteFiles] is `false`, saves
  ///      resume data (libtorrent: `session.saveResumeData`, matching
  ///      :1184-1191) so the next start can fast-resume;
  ///   3. removes the torrent (libtorrent:
  ///      `session.removeTorrent(torrentId, deleteFiles:)`; rqbit:
  ///      `rust_api.stopTorrent(infoHash, deleteFiles:)`).
  ///
  /// Returns `true` if the torrent was tracked and removed; `false` if not
  /// tracked or the backend session is not initialized.
  ///
  /// Manager-level file cleanup (deleting the downloaded media file + empty
  /// parent directories via the Dart-side
  /// `_deleteLibtorrentFilesForTask` at `download_manager.dart:1240-1284`,
  /// and the native `.resume` file Dart-level deletion at :1177-1182) stays
  /// in the manager — only the native `removeTorrent(deleteFiles: true)`
  /// handles its own file deletion; the Dart file IO is the manager's
  /// concern.
  Future<bool> removeTorrent(
    String infoHash, {
    bool deleteFiles = false,
    String? resumePath,
  });

  /// Get normalized stats for all tracked torrents.
  ///
  /// Mirrors `download_manager.dart:1022-1076`
  /// (`_getTorrentStatsWithBackend`) + the libtorrent state normalization
  /// at `:1092-1113` (`_normalizeNativeLibtorrentState`). rqbit: returns
  /// `rust_api.getTorrentStats()` as-is (Rust already emits the normalized
  /// `state` tokens). libtorrent: enumerates `session.getTorrentStats()`
  /// and maps the native `state_t` integer to the same normalized tokens
  /// (`'metadata' | 'checking' | 'live' | 'paused' | 'error' |
  /// 'initializing'`) — see the consumer at `:1882-1907`.
  ///
  /// Returns one [BtTorrentStats] per tracked torrent with the lowercased
  /// info-hash in [BtTorrentStats.infoHash].
  Future<List<BtTorrentStats>> getStats();

  /// Check whether the backend session still tracks [infoHash] (and the
  /// torrent is not in an error state).
  ///
  /// Mirrors `download_manager.dart:1078-1090`
  /// (`_isRqbitTorrentManaged` — used by `getOrCreateStreamUrl` to decide
  /// whether to reattach to an existing rqbit stream or restart it). The
  /// libtorrent equivalent is `_findNativeTorrentIdByHash`
  /// (`:985-999`): a torrent is "managed" if its hash appears in
  /// `session.getTorrentStats()` (the `LibtorrentBackend` impl uses the
  /// tracked id↔hash map first, falling back to a stats scan).
  ///
  /// Returns `true` if the torrent is tracked and not in an error state.
  Future<bool> isTorrentManaged(String infoHash);

  /// Set per-file priorities for a tracked torrent.
  ///
  /// Mirrors `download_manager.dart:1001-1020`
  /// (`_prioritizeLibtorrentDownloadFile`) + the native
  /// `setFilePriorities` call at `:1016`. The manager currently keys the
  /// call by the native `torrentId` (int); the interface keys by
  /// [infoHash] and the `LibtorrentBackend` impl translates via its
  /// tracked id↔hash map (the manager's `_ltTorrentIdsByHash` map is
  /// absorbed into the backend impl in commit 3).
  ///
  /// [priorities] is a list where index = file index and value =
  /// libtorrent priority (0 = skip, 7 = max) — passed straight through to
  /// `session.setFilePriorities`. The rqbit impl is a no-op (rqbit has no
  /// per-file priority API). The manager's 300ms settle delay after the
  /// call (`:1019`) stays in the manager — the interface returns as soon
  /// as the native call completes.
  Future<void> setFilePriorities(String infoHash, List<int> priorities);

  /// Save resume data for a single tracked torrent.
  ///
  /// Mirrors `download_manager.dart:240-268`
  /// (`_saveLibtorrentResumeDataForHash`). rqbit persists resume internally
  /// on the Rust side (no Dart-callable single-torrent save API), so the
  /// rqbit impl is a no-op returning `false`. libtorrent: translates the
  /// info-hash to torrentId and calls `session.saveResumeData(torrentId,
  /// resumePath:)`.
  ///
  /// Returns `true` if resume data was saved; `false` if the torrent is
  /// not tracked or the backend session is not initialized. The manager
  /// currently inlines a try/catch that logs and returns `false`
  /// (`download_manager.dart:262-267`); the interface propagates the
  /// exception and the manager retains the catch. The manager's per-task
  /// resume-data save on completion (`:1241` → `:1965-1968`) and the
  /// save-all loop (`:270-295`) both reduce to repeated [saveResumeData]
  /// calls — no separate "save all" interface method is needed.
  Future<bool> saveResumeData(String infoHash, String resumePath);

  /// Apply download / upload speed limits to the backend session.
  ///
  /// Mirrors `download_manager.dart:543-552`
  /// (`_applyLibtorrentSpeedLimits`). Called from
  /// `setDownloadSettings` (`:538`) and at the end of libtorrent init
  /// (`:823`). rqbit applies speed limits via a different config path
  /// (`rust_api.updateConfig`), so the rqbit impl is a no-op for this
  /// method (the manager keeps its existing rqbit config wiring). Pass 0
  /// for unlimited.
  Future<void> applySpeedLimits({
    int downloadLimitBytesPerSecond,
    int uploadLimitBytesPerSecond,
  });
}

/// Result of [BtBackend.addTorrent]. Mirrors the manager's private
/// `_BackendStartResult` (`download_manager.dart:38-56`) — same fields, made
/// public and immutable so the manager and its tests can read the resolved
/// info-hash / selected file / stream URL / native ids after a start.
final class BtTorrentHandle {
  /// Resolved lowercased info-hash. May differ from the manager's temp id
  /// (parsed from the magnet or extracted from the rqbit stream URL).
  final String infoHash;

  /// Native libtorrent torrent id; `null` for the rqbit backend (which is
  /// hash-keyed, not id-keyed).
  final int? torrentId;

  /// HTTP stream URL produced by `addTorrent`. It is `null` for libtorrent
  /// when `startStream` is false; rqbit always returns one because its add
  /// operation is inherently stream-URL-centric. Streaming-engine lifecycle
  /// is otherwise deferred to `BtStreamBackend`.
  final String? streamUrl;

  /// Native libtorrent stream id produced when
  /// `addTorrent(startStream: true)`; `null` otherwise.
  final int? streamId;

  /// Selected largest streamable file index (libtorrent only; rqbit exposes
  /// files only via the stream URL and reports `null` here).
  final int? fileIdx;

  /// Selected largest streamable file size in bytes (libtorrent only).
  final int? fileSize;

  /// Selected largest streamable file relative path (libtorrent only).
  final String? filePath;

  const BtTorrentHandle({
    required this.infoHash,
    this.torrentId,
    this.streamUrl,
    this.streamId,
    this.fileIdx,
    this.fileSize,
    this.filePath,
  });
}

/// Normalized stats for one tracked torrent. Backend-agnostic mirror of
/// `rust_api.TorrentStats` (`lib/src/rust/api/simple.dart:156-209`) — the
/// manager already consumes this shape for the rqbit side
/// (`download_manager.dart:1852-1948`) and the libtorrent side maps onto it
/// (`:1045-1074`). Has value equality so the manager's stats-diff check
/// (`taskChanged` at `:1918-1925`) and future characterization tests can
/// compare snapshots deterministically.
final class BtTorrentStats {
  /// Lowercased info-hash (the cross-backend torrent key).
  final String infoHash;
  final String name;

  /// Normalized state token: `'metadata' | 'checking' | 'live' | 'paused' |
  /// 'error' | 'initializing'`. libtorrent side produced by
  /// `_normalizeNativeLibtorrentState` (`download_manager.dart:1092-1113`);
  /// rqbit side emitted already-normalized by Rust.
  final String state;
  final double progress;
  final double downloadSpeed;
  final double uploadSpeed;
  final BigInt downloaded;
  final BigInt totalSize;
  final int peers;
  final int seeders;

  const BtTorrentStats({
    required this.infoHash,
    required this.name,
    required this.state,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.downloaded,
    required this.totalSize,
    required this.peers,
    required this.seeders,
  });

  @override
  int get hashCode =>
      infoHash.hashCode ^
      name.hashCode ^
      state.hashCode ^
      progress.hashCode ^
      downloadSpeed.hashCode ^
      uploadSpeed.hashCode ^
      downloaded.hashCode ^
      totalSize.hashCode ^
      peers.hashCode ^
      seeders.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BtTorrentStats &&
          runtimeType == other.runtimeType &&
          infoHash == other.infoHash &&
          name == other.name &&
          state == other.state &&
          progress == other.progress &&
          downloadSpeed == other.downloadSpeed &&
          uploadSpeed == other.uploadSpeed &&
          downloaded == other.downloaded &&
          totalSize == other.totalSize &&
          peers == other.peers &&
          seeders == other.seeders;
}

/// File metadata for one file in a torrent. Backend-agnostic mirror of
/// `MikanLtFileInfo` (`mikan_libtorrent_native.dart:864-876`). Exposed for
/// future file-listing ops; the current interface selects the largest
/// streamable file internally inside [BtBackend.addTorrent] and reports its
/// `index` / `size` / `path` back via [BtTorrentHandle], so this DTO is a
/// compatibility placeholder if explicit torrent file listing is added later.
final class BtFileInfo {
  final int index;
  final String path;
  final int size;
  final bool isStreamable;

  const BtFileInfo({
    required this.index,
    required this.path,
    required this.size,
    required this.isStreamable,
  });
}

/// In-memory fake [BtBackend] for contract tests and the future manager-side
/// characterization tests (`download_manager_bt_test.dart`).
///
/// Tracks added torrents in [torrents] (keyed by lowercased info-hash) and
/// their pause / status / priority / resume-save state, records every call
/// in [callLog] so tests can assert call ordering, and lets tests inject
/// failures via the `*Exception` fields (mirroring how
/// `http_file_download_port_test.dart` injects HTTP failures via
/// `FakeHttpFileDownloadPort.startException`).
///
/// Synchronous-when-possible: every method returns `Future.value(...)`
/// (or throws synchronously inside a `Future`) so tests are deterministic
/// and fast — there is no metadata-fetch wait, no 300ms settle delay, no
/// real FFI. A real backend would await metadata + settle before returning
/// from `addTorrent`; the fake just records the call and returns
/// immediately with a synthetic handle (with `hasMetadata: true` baked in).
class FakeBtBackend implements BtBackend {
  FakeBtBackend({
    this.kind = BtBackendKind.libtorrent,
    this.initException,
    this.addException,
    this.pauseException,
    this.resumeException,
    this.removeException,
    this.statsException,
    this.isManagedException,
    this.setFilePrioritiesException,
    this.saveResumeDataException,
    this.applySpeedLimitsException,
  });

  @override
  final BtBackendKind kind;

  /// Tracked torrents keyed by lowercased info-hash. Tests assert on this
  /// map directly to verify add/pause/resume/remove state transitions.
  final Map<String, FakeBtTorrent> torrents = {};

  /// True after a successful [ensureInitialized]; false until then or after
  /// an [initException] is thrown.
  bool initialized = false;

  /// Ordered log of every method invocation (e.g. `'ensureInitialized'`,
  /// `'addTorrent:<magnet>'`, `'pauseTorrent:<hash>'`). Tests assert on the
  /// prefix + ordering, not the exact magnet text.
  final List<String> callLog = [];

  /// Last-applied speed limits (mirrors `_applyLibtorrentSpeedLimits`
  /// state).
  int lastDownloadLimitBytesPerSecond = 0;
  int lastUploadLimitBytesPerSecond = 0;

  // Configurable failure injectors (mirrors FakeHttpFileDownloadPort's
  // startException pattern). Non-null → the method throws this instead of
  // doing its normal work. Settable via the constructor and mutable so a
  // test can flip an exception on/off mid-scenario.
  Exception? initException;
  Exception? addException;
  Exception? pauseException;
  Exception? resumeException;
  Exception? removeException;
  Exception? statsException;
  Exception? isManagedException;
  Exception? setFilePrioritiesException;
  Exception? saveResumeDataException;
  Exception? applySpeedLimitsException;

  /// Clears the injected [resumeException] so a later resume attempt runs its
  /// normal success path. Mirrors the "flip an exception on/off mid-scenario"
  /// contract documented above; used by resume-rollback retry tests.
  void clearResumeException() => resumeException = null;

  int _nextTorrentId = 1;
  int _nextStreamId = 1;

  @override
  Future<void> ensureInitialized() async {
    callLog.add('ensureInitialized');
    if (initException != null) throw initException!;
    initialized = true;
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
    callLog.add('addTorrent:$magnet');
    if (addException != null) throw addException!;
    if (!initialized) {
      throw StateError(
        'FakeBtBackend: not initialized — call ensureInitialized()',
      );
    }
    final hash = (extractInfoHashFromMagnet(magnet) ?? fallbackInfoHash)
        .toLowerCase();
    // Record libtorrent-only knobs so tests can assert they were accepted.
    if (seedMode || resumePath != null) {
      callLog.add('addTorrentOpts:seedMode=$seedMode:resumePath=$resumePath');
    }

    // Duplicate add: return a fresh handle for the EXISTING tracked torrent,
    // re-using its torrentId, matching the libtorrent short-circuit at
    // download_manager.dart:856-880 (if _ltTorrentIdsByHash[infoHash] is
    // non-null and valid, skip addMagnetEx). rqbit's Rust side dedups by
    // hash the same way. Does NOT create a second torrent entry.
    final existing = torrents[hash];
    if (existing != null) {
      return BtTorrentHandle(
        infoHash: existing.infoHash,
        torrentId: existing.torrentId,
        streamUrl: existing.streamUrl,
        streamId: existing.streamId,
        fileIdx: existing.fileIdx,
        fileSize: existing.fileSize,
        filePath: existing.filePath,
      );
    }

    final torrentId = _nextTorrentId++;
    final torrent = FakeBtTorrent(
      infoHash: hash,
      torrentId: torrentId,
      downloadDir: downloadDir,
    );
    if (kind == BtBackendKind.libtorrent) {
      // Synthetic largest streamable file (mirrors _selectLibtorrentFile).
      torrent.fileIdx = 0;
      torrent.fileSize = 1024;
      torrent.filePath = 'fake/$hash/file.mkv';
    }
    if (startStream || kind == BtBackendKind.rqbit) {
      // rqbit's add operation always produces a stream URL, even when the
      // caller is starting a background download. Only libtorrent owns a
      // separate native stream id.
      if (kind == BtBackendKind.libtorrent) {
        torrent.streamId = _nextStreamId++;
      }
      torrent.streamUrl = kind == BtBackendKind.rqbit
          ? 'http://127.0.0.1:3030/torrents/$hash/stream/0'
          : 'http://127.0.0.1:8181/torrents/$hash/0';
    }
    torrents[hash] = torrent;
    return BtTorrentHandle(
      infoHash: hash,
      torrentId: torrentId,
      streamUrl: torrent.streamUrl,
      streamId: torrent.streamId,
      fileIdx: torrent.fileIdx,
      fileSize: torrent.fileSize,
      filePath: torrent.filePath,
    );
  }

  @override
  Future<bool> pauseTorrent(String infoHash) async {
    callLog.add('pauseTorrent:$infoHash');
    if (pauseException != null) throw pauseException!;
    final torrent = torrents[infoHash.toLowerCase()];
    if (torrent == null) return false;
    torrent.isPaused = true;
    torrent.state = 'paused';
    return true;
  }

  @override
  Future<bool> resumeTorrent(String infoHash) async {
    callLog.add('resumeTorrent:$infoHash');
    if (resumeException != null) throw resumeException!;
    final torrent = torrents[infoHash.toLowerCase()];
    if (torrent == null) return false;
    torrent.isPaused = false;
    // After resume the native torrent returns to a downloading/seeding state,
    // which the normalizer maps to 'live' regardless of progress; the manager
    // maps 'live' → DownloadTaskStatus.downloading/seeding at :2207-2209.
    torrent.state = 'live';
    return true;
  }

  @override
  Future<bool> removeTorrent(
    String infoHash, {
    bool deleteFiles = false,
    String? resumePath,
  }) async {
    callLog.add('removeTorrent:$infoHash:$deleteFiles');
    if (removeException != null) throw removeException!;
    final key = infoHash.toLowerCase();
    final torrent = torrents[key];
    if (torrent == null) return false;
    torrent.removed = true;
    if (resumePath != null && !deleteFiles) {
      torrent.resumeDataSaves.add(resumePath);
    }
    // Mild simplification vs the native libtorrent path: the native
    // removeTorrent(deleteFiles: true) deletes the raw downloaded
    // bytes; this fake just forgets the torrent. Manager-level file
    // cleanup (_deleteLibtorrentFilesForTask) is separate and stays in
    // the manager regardless.
    torrents.remove(key);
    return true;
  }

  @override
  Future<List<BtTorrentStats>> getStats() async {
    callLog.add('getStats');
    if (statsException != null) throw statsException!;
    return torrents.values
        .map(
          (t) => BtTorrentStats(
            infoHash: t.infoHash,
            name: t.name,
            state: t.state,
            progress: t.progress,
            downloadSpeed: t.downloadRate.toDouble(),
            uploadSpeed: t.uploadRate.toDouble(),
            downloaded: BigInt.from(
              (t.progress / 100.0 * (t.fileSize ?? 0)).round(),
            ),
            totalSize: BigInt.from(t.fileSize ?? 0),
            peers: t.numPeers,
            seeders: t.numSeeds,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> isTorrentManaged(String infoHash) async {
    callLog.add('isTorrentManaged:$infoHash');
    if (isManagedException != null) throw isManagedException!;
    final torrent = torrents[infoHash.toLowerCase()];
    return torrent != null && !torrent.removed && torrent.state != 'error';
  }

  @override
  Future<void> setFilePriorities(String infoHash, List<int> priorities) async {
    callLog.add('setFilePriorities:$infoHash');
    if (setFilePrioritiesException != null) throw setFilePrioritiesException!;
    final torrent = torrents[infoHash.toLowerCase()];
    if (torrent == null) return;
    torrent.priorities = List<int>.unmodifiable(priorities);
  }

  @override
  Future<bool> saveResumeData(String infoHash, String resumePath) async {
    callLog.add('saveResumeData:$infoHash');
    if (saveResumeDataException != null) throw saveResumeDataException!;
    final torrent = torrents[infoHash.toLowerCase()];
    if (torrent == null) return false;
    torrent.resumeDataSaves.add(resumePath);
    torrent.lastResumePath = resumePath;
    return true;
  }

  @override
  Future<void> applySpeedLimits({
    int downloadLimitBytesPerSecond = 0,
    int uploadLimitBytesPerSecond = 0,
  }) async {
    callLog.add(
      'applySpeedLimits:$downloadLimitBytesPerSecond:$uploadLimitBytesPerSecond',
    );
    if (applySpeedLimitsException != null) throw applySpeedLimitsException!;
    lastDownloadLimitBytesPerSecond = downloadLimitBytesPerSecond;
    lastUploadLimitBytesPerSecond = uploadLimitBytesPerSecond;
  }
}

/// In-memory tracked-torrent record behind [FakeBtBackend]. Tests reach into
/// these fields to assert state transitions (pause/resume, removed,
/// priorities, resume saves, progress) without a real backend.
class FakeBtTorrent {
  final String infoHash;
  final int torrentId;
  final String? downloadDir;

  bool isPaused;
  bool removed;
  bool hasMetadata;
  double progress;
  String state; // normalized: 'live' | 'paused' | 'error' | 'metadata' | ...
  int downloadRate;
  int uploadRate;
  int numPeers;
  int numSeeds;
  String name;

  int? fileIdx;
  int? fileSize;
  String? filePath;
  int? streamId;
  String? streamUrl;

  List<int> priorities;
  List<String> resumeDataSaves;
  String? lastResumePath;

  FakeBtTorrent({
    required this.infoHash,
    required this.torrentId,
    this.downloadDir,
    this.isPaused = false,
    this.removed = false,
    this.hasMetadata = true,
    this.progress = 0.0,
    this.state = 'live',
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    String? name,
    this.priorities = const [],
    List<String>? resumeDataSaves,
  }) : name = name ?? 'Torrent $torrentId',
       resumeDataSaves = resumeDataSaves ?? [];
}
