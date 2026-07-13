import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/native/mikan_libtorrent_native.dart';
import 'package:mikan_player/services/download/libtorrent_backend.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hashOne = '0123456789abcdef0123456789abcdef01234567';
const _hashTwo = '89abcdef0123456789abcdef0123456789abcdef';

class _ResumeSaveSession implements LibtorrentSessionPort {
  _ResumeSaveSession(this._torrents);

  final Map<int, MikanLtTorrentStats> _torrents;
  final List<int> resumeSaves = [];

  @override
  int addMagnetEx(
    String magnet, {
    String? savePath,
    String? resumePath,
    bool seedMode = false,
  }) => throw UnsupportedError('not used by this test');

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
  }) {}

  @override
  List<MikanLtFileInfo> getFiles(int torrentId) => const [];

  @override
  List<MikanLtTorrentStats> getTorrentStats() =>
      _torrents.values.toList(growable: false);

  @override
  void pauseTorrent(int torrentId) {}

  @override
  void preloadStream(int streamId, {required int preloadBytes}) {}

  @override
  void removeTorrent(int torrentId, {bool deleteFiles = false}) {}

  @override
  void resumeTorrent(int torrentId) {}

  @override
  void saveResumeData(int torrentId, {required String resumePath}) {
    resumeSaves.add(torrentId);
  }

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {}

  @override
  void setStreamCache(
    int streamId, {
    required int capacity,
    required int readAheadPct,
    required int connectionsLimit,
  }) {}

  @override
  MikanLtStreamInfo startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = 512 * 1024 * 1024,
  }) => const MikanLtStreamInfo(id: 1, url: 'http://localhost/stream');

  @override
  void stopStream(int streamId) {}
}

MikanLtTorrentStats _stats(int torrentId, String infoHash) =>
    MikanLtTorrentStats(
      torrentId: torrentId,
      name: 'torrent-$torrentId',
      infoHash: infoHash,
      errorMessage: '',
      state: 3,
      isPaused: false,
      hasMetadata: true,
      progress: 10,
      totalWanted: 100,
      totalDone: 10,
      downloadRate: 0,
      uploadRate: 0,
      numPeers: 0,
      numSeeds: 0,
    );

DownloadTask _task(String id) => DownloadTask(
  id: id,
  name: 'torrent-$id',
  magnet: 'magnet:?xt=urn:btih:$id',
  startTime: DateTime.fromMillisecondsSinceEpoch(1),
  status: DownloadTaskStatus.downloading,
  backend: BtBackendKind.libtorrent,
  downloadDir: r'C:\mikan-test-downloads',
);

void main() {
  test(
    'shutdown starts every active libtorrent resume save before yielding',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = _ResumeSaveSession({
        1: _stats(1, _hashOne),
        2: _stats(2, _hashTwo),
      });
      final backend = LibtorrentBackend(sessionFactory: () => session);
      await backend.ensureInitialized();
      final manager = DownloadManager.forTesting(libtorrentBackend: backend);
      manager.seedBtTaskForTesting(_task(_hashOne));
      manager.seedBtTaskForTesting(_task(_hashTwo));

      manager.saveLibtorrentResumeDataForShutdown();

      // The lifecycle callback cannot await this API. Both native save calls
      // must therefore be dispatched synchronously before it returns.
      expect(session.resumeSaves, [1, 2]);
      manager.dispose();
    },
  );
}
