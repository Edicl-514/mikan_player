// Unit tests for [LibtorrentBackend] with a fake [LibtorrentSessionPort].
// No real FFI / native session.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/native/mikan_libtorrent_native.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/libtorrent_backend.dart';
import 'package:mikan_player/services/download/magnet_helpers.dart';

const _kMagnet =
    'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test';
const _kHash = '0123456789abcdef0123456789abcdef01234567';

class FakeLibtorrentSession implements LibtorrentSessionPort {
  final List<String> calls = [];
  int nextTorrentId = 1;
  int nextStreamId = 10;
  final Map<int, MikanLtTorrentStats> torrents = {};
  final Map<int, List<MikanLtFileInfo>> files = {};
  final Map<int, List<int>> priorities = {};
  final List<String> resumeSaves = [];
  String? lastMagnet;
  String? lastSavePath;
  String? lastResumePath;
  bool? lastSeedMode;
  int? lastDlLimit;
  int? lastUlLimit;
  int? lastConnectionsLimit;
  bool? lastEnableDht;

  Exception? addException;
  Exception? saveResumeException;

  @override
  int addMagnetEx(
    String magnet, {
    String? savePath,
    String? resumePath,
    bool seedMode = false,
  }) {
    calls.add('addMagnetEx');
    if (addException != null) throw addException!;
    lastMagnet = magnet;
    lastSavePath = savePath;
    lastResumePath = resumePath;
    lastSeedMode = seedMode;
    final id = nextTorrentId++;
    torrents[id] = MikanLtTorrentStats(
      torrentId: id,
      name: 'T$id',
      infoHash: _kHash,
      errorMessage: '',
      state: 3,
      isPaused: false,
      hasMetadata: true,
      progress: 0,
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
    calls.add('saveResumeData:$torrentId:$resumePath');
    if (saveResumeException != null) throw saveResumeException!;
    resumeSaves.add(resumePath);
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
    if (t != null) {
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
  }

  @override
  void resumeTorrent(int torrentId) {
    calls.add('resumeTorrent:$torrentId');
    final t = torrents[torrentId];
    if (t != null) {
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
    if (downloadLimitBytesPerSecond >= 0) {
      lastDlLimit = downloadLimitBytesPerSecond;
    }
    if (uploadLimitBytesPerSecond >= 0) {
      lastUlLimit = uploadLimitBytesPerSecond;
    }
    if (connectionsLimit >= 0) lastConnectionsLimit = connectionsLimit;
    if (enableDht != null) lastEnableDht = enableDht;
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
  late FakeLibtorrentSession session;
  late LibtorrentBackend backend;

  setUp(() {
    session = FakeLibtorrentSession();
    backend = LibtorrentBackend(
      sessionFactory: () => session,
      defaultDownloadDirResolver: () async => r'C:\downloads',
      metadataPollInterval: Duration.zero,
      metadataTimeout: const Duration(seconds: 5),
      prioritySettleDelay: Duration.zero,
    );
  });

  test('kind is libtorrent', () {
    expect(backend.kind, BtBackendKind.libtorrent);
  });

  test('ensureInitialized is idempotent and configures session', () async {
    await backend.ensureInitialized();
    await backend.ensureInitialized();
    expect(backend.isInitialized, isTrue);
    expect(session.lastConnectionsLimit, 200);
    expect(session.lastEnableDht, isTrue);
    expect(
      session.calls.where((c) => c == 'configureSession').length,
      greaterThanOrEqualTo(1),
    );
  });

  test(
    'addTorrent injects trackers, selects largest streamable, prioritizes',
    () async {
      final handle = await backend.addTorrent(
        _kMagnet,
        fallbackInfoHash: _kHash,
        downloadDir: r'D:\dl',
        seedMode: true,
        resumePath: r'D:\dl\.resume',
      );
      expect(session.lastMagnet, injectMagnetTrackers(_kMagnet));
      expect(session.lastSavePath, r'D:\dl');
      expect(session.lastResumePath, r'D:\dl\.resume');
      expect(session.lastSeedMode, isTrue);
      expect(handle.infoHash, _kHash);
      expect(handle.torrentId, 1);
      expect(handle.fileIdx, 1);
      expect(handle.fileSize, 2048);
      expect(handle.filePath, 'video.mkv');
      expect(handle.streamUrl, isNull);
      expect(session.priorities[1], [0, 7]);
      expect(session.calls, contains('resumeTorrent:1'));
    },
  );

  test('addTorrent startStream starts stream and warms up', () async {
    final handle = await backend.addTorrent(
      _kMagnet,
      fallbackInfoHash: _kHash,
      startStream: true,
    );
    expect(handle.streamId, 10);
    expect(handle.streamUrl, contains(_kHash));
    expect(session.calls, contains('startStream:1:1'));
    expect(session.calls, contains('setStreamCache:10'));
    expect(session.calls, contains('preloadStream:10'));
  });

  test('addTorrent reuses valid existing torrent id', () async {
    final first = await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
    session.calls.clear();
    final second = await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
    expect(second.torrentId, first.torrentId);
    expect(session.calls.where((c) => c == 'addMagnetEx'), isEmpty);
  });

  test(
    'restoreBackgroundDownload keeps the runtime file selection over persisted preference',
    () async {
      await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
      session.calls.clear();

      final handle = await backend.restoreBackgroundDownload(
        _kHash,
        preferredFileIdx: 0,
      );

      expect(handle, isNotNull);
      expect(handle!.fileIdx, 1);
      expect(session.priorities[1], [0, 7]);
      expect(session.calls, contains('resumeTorrent:1'));
    },
  );

  test('addTorrent throws when no files', () async {
    final noFiles = _EmptyFilesSession();
    final backendNoFiles = LibtorrentBackend(
      sessionFactory: () => noFiles,
      defaultDownloadDirResolver: () async => r'C:\dl',
      metadataPollInterval: Duration.zero,
      prioritySettleDelay: Duration.zero,
    );
    await expectLater(
      () => backendNoFiles.addTorrent(_kMagnet, fallbackInfoHash: _kHash),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'msg',
          contains('No streamable files'),
        ),
      ),
    );
  });

  test('pause/resume/remove by hash', () async {
    await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
    expect(await backend.pauseTorrent(_kHash), isTrue);
    expect(session.calls, contains('pauseTorrent:1'));
    expect(await backend.resumeTorrent(_kHash), isTrue);
    expect(session.calls, contains('resumeTorrent:1'));
    expect(
      await backend.removeTorrent(
        _kHash,
        deleteFiles: false,
        resumePath: r'C:\r.resume',
      ),
      isTrue,
    );
    expect(session.resumeSaves, contains(r'C:\r.resume'));
    expect(session.calls, contains('removeTorrent:1:false'));
    expect(await backend.pauseTorrent(_kHash), isFalse);
  });

  test('removeTorrent with deleteFiles skips saveResumeData', () async {
    await backend.addTorrent(
      _kMagnet,
      fallbackInfoHash: _kHash,
      startStream: true,
    );
    session.calls.clear();
    await backend.removeTorrent(
      _kHash,
      deleteFiles: true,
      resumePath: r'C:\r.resume',
    );
    expect(session.resumeSaves, isEmpty);
    expect(session.calls, contains('stopStream:10'));
    expect(session.calls, contains('removeTorrent:1:true'));
  });

  test('getStats maps and normalizes state with tracked file size', () async {
    await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
    final stats = await backend.getStats();
    expect(stats, hasLength(1));
    final s = stats.single;
    expect(s.infoHash, _kHash);
    expect(s.state, 'live');
    expect(s.totalSize, BigInt.from(2048));
    expect(s.downloaded, BigInt.from(512));
    expect(s.progress, closeTo(25.0, 0.01));
    expect(s.downloadSpeed, 100);
    expect(s.peers, 2);
  });

  test('getStats normalizes paused and error', () async {
    await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
    session.torrents[1] = MikanLtTorrentStats(
      torrentId: 1,
      name: 'T1',
      infoHash: _kHash,
      errorMessage: '',
      state: 3,
      isPaused: true,
      hasMetadata: true,
      progress: 0,
      totalWanted: 100,
      totalDone: 0,
      downloadRate: 0,
      uploadRate: 0,
      numPeers: 0,
      numSeeds: 0,
    );
    expect((await backend.getStats()).single.state, 'paused');

    session.torrents[1] = MikanLtTorrentStats(
      torrentId: 1,
      name: 'T1',
      infoHash: _kHash,
      errorMessage: 'fail',
      state: 3,
      isPaused: false,
      hasMetadata: true,
      progress: 0,
      totalWanted: 100,
      totalDone: 0,
      downloadRate: 0,
      uploadRate: 0,
      numPeers: 0,
      numSeeds: 0,
    );
    expect((await backend.getStats()).single.state, 'error');
  });

  test('isTorrentManaged / setFilePriorities / saveResumeData', () async {
    expect(await backend.isTorrentManaged(_kHash), isFalse);
    await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
    expect(await backend.isTorrentManaged(_kHash), isTrue);

    await backend.setFilePriorities(_kHash, [7, 0]);
    expect(session.priorities[1], [7, 0]);

    expect(await backend.saveResumeData(_kHash, r'C:\x.resume'), isTrue);
    expect(session.resumeSaves, contains(r'C:\x.resume'));
  });

  test('applySpeedLimits stores and applies after init', () async {
    await backend.applySpeedLimits(
      downloadLimitBytesPerSecond: 1024,
      uploadLimitBytesPerSecond: 512,
    );
    // not initialized yet — limits stored
    await backend.ensureInitialized();
    // init reapplies stored limits
    await backend.applySpeedLimits(
      downloadLimitBytesPerSecond: 2048,
      uploadLimitBytesPerSecond: 256,
    );
    expect(session.lastDlLimit, 2048);
    expect(session.lastUlLimit, 256);
  });

  test('pause returns false when not initialized', () async {
    expect(await backend.pauseTorrent(_kHash), isFalse);
  });
}

/// Session whose [getFiles] always returns empty (still adds torrents).
class _EmptyFilesSession extends FakeLibtorrentSession {
  @override
  List<MikanLtFileInfo> getFiles(int torrentId) => const [];
}
