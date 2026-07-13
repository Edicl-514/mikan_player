// Manager-side characterization of the libtorrent HTTP streaming lifecycle
// (Phase 3 BtStreamCapability follow-up).
//
// Injects [LibtorrentBackend] with a fake [LibtorrentSessionPort] so create-
// stream, stop → background restore, pause/remove races, and stats/size merge
// are deterministic without native FFI. Playback policy (_activeStreamHashes,
// restore delay/guards) stays on DownloadManager.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/native/mikan_libtorrent_native.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download/bt_stream_capability.dart';
import 'package:mikan_player/services/download/libtorrent_backend.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHash = '0123456789abcdef0123456789abcdef01234567';
const _kMagnet =
    'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test';

class _RestoreDelayGate {
  final List<Duration> requested = [];
  final List<Completer<void>> _waiters = [];

  Future<void> call(Duration duration) {
    requested.add(duration);
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void releaseNext() {
    _waiters.removeAt(0).complete();
  }
}

class _FakeLibtorrentBtBackend extends FakeBtBackend
    implements LibtorrentBtBackend {
  @override
  int? fileIdxForHash(String infoHash) => null;

  @override
  int? fileSizeForHash(String infoHash) => null;

  @override
  Future<BtTorrentHandle?> restoreBackgroundDownload(
    String infoHash, {
    int? preferredFileIdx,
  }) async => null;

  @override
  int? streamIdForHash(String infoHash) => null;

  @override
  void stopStreamForHash(String infoHash) {}
}

class _StreamSession implements LibtorrentSessionPort {
  final List<String> calls = [];
  int nextTorrentId = 1;
  int nextStreamId = 10;
  final Map<int, MikanLtTorrentStats> torrents = {};
  final Map<int, List<MikanLtFileInfo>> files = {};
  final Map<int, List<int>> priorities = {};
  final List<int> stoppedStreams = [];

  @override
  int addMagnetEx(
    String magnet, {
    String? savePath,
    String? resumePath,
    bool seedMode = false,
  }) {
    calls.add('addMagnetEx');
    final id = nextTorrentId++;
    torrents[id] = MikanLtTorrentStats(
      torrentId: id,
      name: 'T$id',
      infoHash: _kHash,
      errorMessage: '',
      state: 3,
      isPaused: false,
      hasMetadata: true,
      progress: 10,
      totalWanted: 2048,
      totalDone: 512,
      downloadRate: 100,
      uploadRate: 10,
      numPeers: 2,
      numSeeds: 1,
    );
    files[id] ??= [
      const MikanLtFileInfo(
        index: 0,
        path: 'small.txt',
        size: 100,
        isStreamable: false,
      ),
      const MikanLtFileInfo(
        index: 1,
        path: 'video.mkv',
        size: 2048,
        isStreamable: true,
      ),
    ];
    return id;
  }

  @override
  void saveResumeData(int torrentId, {required String resumePath}) {
    calls.add('saveResumeData:$torrentId');
  }

  @override
  List<MikanLtFileInfo> getFiles(int torrentId) {
    calls.add('getFiles:$torrentId');
    return files[torrentId] ?? const [];
  }

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {
    calls.add('setFilePriorities:$torrentId');
    this.priorities[torrentId] = List<int>.from(priorities);
  }

  @override
  void pauseTorrent(int torrentId) {
    calls.add('pauseTorrent:$torrentId');
    final t = torrents[torrentId];
    if (t == null) return;
    torrents[torrentId] = MikanLtTorrentStats(
      torrentId: t.torrentId,
      name: t.name,
      infoHash: t.infoHash,
      errorMessage: t.errorMessage,
      state: t.state,
      isPaused: true,
      hasMetadata: t.hasMetadata,
      progress: t.progress,
      totalWanted: t.totalWanted,
      totalDone: t.totalDone,
      downloadRate: 0,
      uploadRate: 0,
      numPeers: t.numPeers,
      numSeeds: t.numSeeds,
    );
  }

  @override
  void resumeTorrent(int torrentId) {
    calls.add('resumeTorrent:$torrentId');
    final t = torrents[torrentId];
    if (t == null) return;
    torrents[torrentId] = MikanLtTorrentStats(
      torrentId: t.torrentId,
      name: t.name,
      infoHash: t.infoHash,
      errorMessage: t.errorMessage,
      state: 3,
      isPaused: false,
      hasMetadata: t.hasMetadata,
      progress: t.progress,
      totalWanted: t.totalWanted,
      totalDone: t.totalDone,
      downloadRate: t.downloadRate,
      uploadRate: t.uploadRate,
      numPeers: t.numPeers,
      numSeeds: t.numSeeds,
    );
  }

  @override
  void removeTorrent(int torrentId, {bool deleteFiles = false}) {
    calls.add('removeTorrent:$torrentId:$deleteFiles');
    torrents.remove(torrentId);
    files.remove(torrentId);
    priorities.remove(torrentId);
  }

  @override
  List<MikanLtTorrentStats> getTorrentStats() {
    calls.add('getTorrentStats');
    return torrents.values.toList(growable: false);
  }

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
  }) {
    calls.add('configureSession');
  }

  @override
  MikanLtStreamInfo startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = 512 * 1024 * 1024,
  }) {
    calls.add('startStream:$torrentId:$fileIndex');
    final id = nextStreamId++;
    return MikanLtStreamInfo(
      id: id,
      url: 'http://127.0.0.1:8181/torrents/$_kHash/$fileIndex',
    );
  }

  @override
  void stopStream(int streamId) {
    calls.add('stopStream:$streamId');
    stoppedStreams.add(streamId);
  }

  @override
  void setStreamCache(
    int streamId, {
    required int capacity,
    required int readAheadPct,
    required int connectionsLimit,
  }) {
    calls.add('setStreamCache:$streamId');
  }

  @override
  void preloadStream(int streamId, {required int preloadBytes}) {
    calls.add('preloadStream:$streamId');
  }
}

void main() {
  late _StreamSession session;
  late LibtorrentBackend backend;
  late DownloadManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = _StreamSession();
    backend = LibtorrentBackend(
      sessionFactory: () => session,
      defaultDownloadDirResolver: () async => r'C:\mikan-test-downloads',
      metadataPollInterval: Duration.zero,
      metadataTimeout: const Duration(seconds: 5),
      prioritySettleDelay: Duration.zero,
    );
    manager = DownloadManager.forTesting(
      libtorrentBackend: backend,
      // Deterministic: no 300ms wall delay before background restore.
      streamRestoreDelay: Duration.zero,
    );
    manager.setDownloadDirForTesting(r'C:\mikan-test-downloads');
    manager.setBackendKindForTesting(BtBackendKind.libtorrent);
  });

  tearDown(() {
    manager.dispose();
  });

  group('DownloadManager BT stream capability', () {
    test(
      'startDownload(forPlayback:true) creates stream URL via libtorrent',
      () async {
        final streamUrl = await manager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );

        expect(streamUrl, isNotNull);
        expect(streamUrl, contains(_kHash));
        expect(session.calls, contains('startStream:1:1'));
        expect(session.calls, contains('setStreamCache:10'));
        expect(session.calls, contains('preloadStream:10'));
        expect(backend.streamIdForHash(_kHash), 10);

        final task = manager.tasks.firstWhere((t) => t.id == _kHash);
        expect(task.streamUrl, streamUrl);
        expect(task.backend, BtBackendKind.libtorrent);
        expect(task.largestFileIdx, 1);
        expect(task.totalSize, BigInt.from(2048));
        expect(task.status, DownloadTaskStatus.downloading);
      },
    );

    test(
      'startDownload(forPlayback:false) does not start HTTP stream engine',
      () async {
        final streamUrl = await manager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: false,
        );

        expect(streamUrl, isNull);
        expect(
          session.calls.where((c) => c.startsWith('startStream:')),
          isEmpty,
        );
        expect(backend.streamIdForHash(_kHash), isNull);

        final task = manager.tasks.firstWhere((t) => t.id == _kHash);
        expect(task.streamUrl, isNull);
        expect(task.status, DownloadTaskStatus.downloading);
      },
    );

    test(
      'getOrCreateStreamUrl reuses live stream; recreates after stop',
      () async {
        await manager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );
        final first = await manager.getOrCreateStreamUrlForTesting(_kHash);
        expect(first, isNotNull);
        expect(backend.streamIdForHash(_kHash), 10);

        // Stop-only path clears stream id + task.streamUrl.
        manager.setActiveStream(_kHash, active: true);
        manager.setActiveStream(_kHash, active: false);
        await manager.waitPendingStreamRestoresForTesting();
        expect(backend.streamIdForHash(_kHash), isNull);
        final stoppedTask = manager.tasks.firstWhere((t) => t.id == _kHash);
        expect(stoppedTask.streamUrl, isNull);

        session.calls.clear();
        final second = await manager.getOrCreateStreamUrlForTesting(_kHash);
        expect(second, isNotNull);
        expect(second, contains(_kHash));
        expect(session.calls, contains('startStream:1:1'));
        expect(backend.streamIdForHash(_kHash), 11);
        expect(
          manager.tasks.firstWhere((t) => t.id == _kHash).streamUrl,
          second,
        );
      },
    );

    test(
      'setActiveStream(false) stops stream and restores background priorities',
      () async {
        await manager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );
        expect(backend.streamIdForHash(_kHash), 10);

        manager.setActiveStream(_kHash, active: true);
        expect(manager.isActiveStreamForTesting(_kHash), isTrue);

        session.calls.clear();
        manager.setActiveStream(_kHash, active: false);
        expect(manager.isActiveStreamForTesting(_kHash), isFalse);
        await manager.waitPendingStreamRestoresForTesting();

        expect(session.stoppedStreams, contains(10));
        expect(backend.streamIdForHash(_kHash), isNull);
        // restoreBackgroundDownload re-prioritizes selected file + resumes.
        expect(session.calls, contains('setFilePriorities:1'));
        expect(session.calls, contains('resumeTorrent:1'));
        expect(session.priorities[1], [0, 7]);

        final task = manager.tasks.firstWhere((t) => t.id == _kHash);
        expect(task.streamUrl, isNull);
        expect(task.status, DownloadTaskStatus.downloading);
        expect(task.largestFileIdx, 1);
      },
    );

    test(
      'setActiveStream(null) deactivates all streams and restores each',
      () async {
        await manager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );
        manager.setActiveStream(_kHash, active: true);

        manager.setActiveStream(null);
        expect(manager.isActiveStreamForTesting(_kHash), isFalse);
        await manager.waitPendingStreamRestoresForTesting();

        expect(session.stoppedStreams, contains(10));
        expect(backend.streamIdForHash(_kHash), isNull);
        expect(session.calls, contains('resumeTorrent:1'));
      },
    );

    test('zero-delay early return clears pending restore bookkeeping', () async {
      manager.setActiveStream(_kHash, active: false);
      await manager.waitPendingStreamRestoresForTesting();

      // A second call must schedule and finish normally instead of returning a
      // stale completed Future left behind by the first early return.
      manager.setActiveStream(_kHash, active: false);
      await manager.waitPendingStreamRestoresForTesting();
    });

    test('manager accepts an abstract LibtorrentBtBackend fake', () async {
      final fakeManager = DownloadManager.forTesting(
        libtorrentBackend: _FakeLibtorrentBtBackend(),
      );
      addTearDown(fakeManager.dispose);

      fakeManager.setActiveStream(_kHash, active: false);
      await fakeManager.waitPendingStreamRestoresForTesting();
    });

    test(
      'reactivation cancels delayed restore for the replacement stream',
      () async {
        final gate = _RestoreDelayGate();
        final delayedManager = DownloadManager.forTesting(
          libtorrentBackend: backend,
          streamRestoreDelay: const Duration(milliseconds: 300),
          streamRestoreSleep: gate.call,
        );
        delayedManager.setDownloadDirForTesting(r'C:\mikan-test-downloads');
        delayedManager.setBackendKindForTesting(BtBackendKind.libtorrent);
        addTearDown(delayedManager.dispose);

        await delayedManager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );
        delayedManager.setActiveStream(_kHash, active: true);
        delayedManager.setActiveStream(_kHash, active: false);
        expect(gate.requested, [const Duration(milliseconds: 300)]);

        final replacement = await delayedManager.getOrCreateStreamUrlForTesting(
          _kHash,
        );
        expect(replacement, isNotNull);
        expect(backend.streamIdForHash(_kHash), 11);
        delayedManager.setActiveStream(_kHash, active: true);

        session.calls.clear();
        gate.releaseNext();
        await delayedManager.waitPendingStreamRestoresForTesting();

        expect(backend.streamIdForHash(_kHash), 11);
        expect(
          session.calls.where((c) => c.startsWith('setFilePriorities:')),
          isEmpty,
        );
        expect(
          session.calls.where((c) => c.startsWith('resumeTorrent:')),
          isEmpty,
        );
      },
    );

    test(
      'deactivate after reactivation schedules a new restore generation',
      () async {
        final gate = _RestoreDelayGate();
        final delayedManager = DownloadManager.forTesting(
          libtorrentBackend: backend,
          streamRestoreDelay: const Duration(milliseconds: 300),
          streamRestoreSleep: gate.call,
        );
        delayedManager.setDownloadDirForTesting(r'C:\mikan-test-downloads');
        delayedManager.setBackendKindForTesting(BtBackendKind.libtorrent);
        addTearDown(delayedManager.dispose);

        await delayedManager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );
        delayedManager.setActiveStream(_kHash, active: true);
        delayedManager.setActiveStream(_kHash, active: false);
        await delayedManager.getOrCreateStreamUrlForTesting(_kHash);
        delayedManager.setActiveStream(_kHash, active: true);
        delayedManager.setActiveStream(_kHash, active: false);
        expect(gate.requested, [
          const Duration(milliseconds: 300),
          const Duration(milliseconds: 300),
        ]);

        session.calls.clear();
        gate.releaseNext();
        gate.releaseNext();
        await delayedManager.waitPendingStreamRestoresForTesting();

        expect(backend.streamIdForHash(_kHash), isNull);
        expect(
          session.calls.where((c) => c.startsWith('setFilePriorities:1')),
          hasLength(1),
        );
        expect(
          session.calls.where((c) => c.startsWith('resumeTorrent:1')),
          hasLength(1),
        );
      },
    );

    test(
      'pause during pending restore skips restore body (race guard)',
      () async {
        final gate = _RestoreDelayGate();
        final delayedManager = DownloadManager.forTesting(
          libtorrentBackend: backend,
          streamRestoreDelay: const Duration(milliseconds: 300),
          streamRestoreSleep: gate.call,
        );
        delayedManager.setDownloadDirForTesting(r'C:\mikan-test-downloads');
        delayedManager.setBackendKindForTesting(BtBackendKind.libtorrent);
        addTearDown(delayedManager.dispose);

        await delayedManager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );
        delayedManager.setActiveStream(_kHash, active: true);

        session.calls.clear();
        delayedManager.setActiveStream(_kHash, active: false);
        // Pause while restore delay is still ticking.
        final paused = await delayedManager.pauseBtTaskForTesting(_kHash);
        expect(paused, isTrue);
        gate.releaseNext();
        await delayedManager.waitPendingStreamRestoresForTesting();

        // Stream was stopped immediately on deactivate; restore body aborted
        // on _pausedTaskIds and must NOT re-prioritize / resume.
        expect(session.stoppedStreams, contains(10));
        expect(
          session.calls.where((c) => c.startsWith('setFilePriorities:')),
          isEmpty,
        );
        expect(
          session.calls.where((c) => c.startsWith('resumeTorrent:')),
          isEmpty,
        );
        final task = delayedManager.tasks.firstWhere((t) => t.id == _kHash);
        expect(task.status, DownloadTaskStatus.paused);
      },
    );

    test(
      'remove during pending restore skips restore body (race guard)',
      () async {
        final gate = _RestoreDelayGate();
        final delayedManager = DownloadManager.forTesting(
          libtorrentBackend: backend,
          streamRestoreDelay: const Duration(milliseconds: 300),
          streamRestoreSleep: gate.call,
        );
        delayedManager.setDownloadDirForTesting(r'C:\mikan-test-downloads');
        delayedManager.setBackendKindForTesting(BtBackendKind.libtorrent);
        addTearDown(delayedManager.dispose);

        await delayedManager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: true,
        );
        delayedManager.setActiveStream(_kHash, active: true);

        session.calls.clear();
        delayedManager.setActiveStream(_kHash, active: false);
        await delayedManager.removeBtTaskForTesting(_kHash);
        gate.releaseNext();
        await delayedManager.waitPendingStreamRestoresForTesting();

        expect(delayedManager.tasks.where((t) => t.id == _kHash), isEmpty);
        // removeTorrent stops the stream as part of teardown; restore must
        // not re-add or re-prioritize after removal.
        expect(
          session.calls.where((c) => c.startsWith('setFilePriorities:')),
          isEmpty,
        );
      },
    );

    test('dispose cancels pending restore side effects', () async {
      final gate = _RestoreDelayGate();
      final disposableManager = DownloadManager.forTesting(
        libtorrentBackend: backend,
        streamRestoreDelay: const Duration(milliseconds: 300),
        streamRestoreSleep: gate.call,
      );
      disposableManager.setDownloadDirForTesting(r'C:\mikan-test-downloads');
      disposableManager.setBackendKindForTesting(BtBackendKind.libtorrent);

      await disposableManager.startBtDownloadForTesting(
        magnet: _kMagnet,
        name: 'Episode 1',
        forPlayback: true,
      );
      disposableManager.setActiveStream(_kHash, active: true);
      disposableManager.setActiveStream(_kHash, active: false);

      session.calls.clear();
      disposableManager.dispose();
      gate.releaseNext();
      await disposableManager.waitPendingStreamRestoresForTesting();

      expect(
        session.calls.where((c) => c.startsWith('setFilePriorities:')),
        isEmpty,
      );
      expect(
        session.calls.where((c) => c.startsWith('resumeTorrent:')),
        isEmpty,
      );
    });

    test(
      'updateStats merges libtorrent fileSizeForHash into task.totalSize',
      () async {
        await manager.startBtDownloadForTesting(
          magnet: _kMagnet,
          name: 'Episode 1',
          forPlayback: false,
        );
        // Backend selected file size is 2048; stats totalWanted is also 2048.
        // Force a smaller persisted total so the merge prefers backend size.
        final task = manager.tasks.firstWhere((t) => t.id == _kHash);
        task.totalSize = BigInt.from(100);

        await manager.updateStatsForTesting();

        final updated = manager.tasks.firstWhere((t) => t.id == _kHash);
        expect(updated.totalSize, BigInt.from(2048));
        expect(updated.progress, closeTo(25.0, 0.1)); // 512/2048
        expect(updated.downloadSpeed, 100);
        expect(updated.peers, 2);
        expect(updated.status, DownloadTaskStatus.downloading);
      },
    );

    test('LibtorrentBackend implements BtStreamCapability surface', () async {
      await backend.ensureInitialized();
      expect(backend.streamIdForHash(_kHash), isNull);
      expect(backend.fileIdxForHash(_kHash), isNull);
      expect(backend.fileSizeForHash(_kHash), isNull);

      await backend.addTorrent(
        _kMagnet,
        fallbackInfoHash: _kHash,
        startStream: true,
      );
      expect(backend.streamIdForHash(_kHash), 10);
      expect(backend.fileIdxForHash(_kHash), 1);
      expect(backend.fileSizeForHash(_kHash), 2048);

      backend.stopStreamForHash(_kHash);
      expect(backend.streamIdForHash(_kHash), isNull);
      expect(session.stoppedStreams, contains(10));

      final restored = await backend.restoreBackgroundDownload(_kHash);
      expect(restored, isNotNull);
      expect(restored!.fileIdx, 1);
      expect(session.priorities[1], [0, 7]);
    });
  });
}
