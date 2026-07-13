// Unit tests for [RqbitBackend] with a fake [RqbitApi] seam.
// No real Rust engine / FFI.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/rqbit_backend.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust_api;

const _kMagnet =
    'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test';
const _kHash = '0123456789abcdef0123456789abcdef01234567';

class FakeRqbitApi implements RqbitApi {
  final List<String> calls = [];
  String? lastDownloadDir;
  String? startResult = 'http://127.0.0.1:3030/torrents/$_kHash/stream/0';
  Exception? startException;
  bool pauseResult = true;
  bool resumeResult = true;
  bool stopResult = true;
  List<rust_api.TorrentStats> stats = [];
  Exception? statsException;

  @override
  Future<void> setDownloadDir({required String dir}) async {
    calls.add('setDownloadDir:$dir');
    lastDownloadDir = dir;
  }

  @override
  Future<String> startTorrent({required String magnet}) async {
    calls.add('startTorrent:$magnet');
    if (startException != null) throw startException!;
    return startResult!;
  }

  @override
  Future<bool> pauseTorrent({required String infoHash}) async {
    calls.add('pauseTorrent:$infoHash');
    return pauseResult;
  }

  @override
  Future<bool> resumeTorrent({required String infoHash}) async {
    calls.add('resumeTorrent:$infoHash');
    return resumeResult;
  }

  @override
  Future<bool> stopTorrent({
    required String infoHash,
    required bool deleteFiles,
  }) async {
    calls.add('stopTorrent:$infoHash:$deleteFiles');
    return stopResult;
  }

  @override
  Future<List<rust_api.TorrentStats>> getTorrentStats() async {
    calls.add('getTorrentStats');
    if (statsException != null) throw statsException!;
    return stats;
  }
}

void main() {
  late FakeRqbitApi api;
  late RqbitBackend backend;

  setUp(() {
    api = FakeRqbitApi();
    backend = RqbitBackend(api: api);
  });

  test('kind is rqbit', () {
    expect(backend.kind, BtBackendKind.rqbit);
  });

  test('ensureInitialized is idempotent no-op', () async {
    await backend.ensureInitialized();
    await backend.ensureInitialized();
    expect(api.calls, isEmpty);
  });

  test('addTorrent sets download dir, starts torrent, maps handle', () async {
    final handle = await backend.addTorrent(
      _kMagnet,
      fallbackInfoHash: 'fallback',
      downloadDir: r'C:\dl',
      startStream: true,
    );
    expect(api.lastDownloadDir, r'C:\dl');
    expect(api.calls, contains('setDownloadDir:C:\\dl'));
    expect(api.calls.any((c) => c.startsWith('startTorrent:')), isTrue);
    expect(handle.infoHash, _kHash);
    expect(handle.streamUrl, api.startResult);
    expect(handle.fileIdx, 0);
    expect(handle.torrentId, isNull);
  });

  test('addTorrent skips setDownloadDir when null/empty', () async {
    await backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash);
    expect(api.calls.where((c) => c.startsWith('setDownloadDir')), isEmpty);
  });

  test('addTorrent returns a stream URL when startStream is false', () async {
    final handle = await backend.addTorrent(
      _kMagnet,
      fallbackInfoHash: _kHash,
      startStream: false,
    );

    expect(handle.streamUrl, api.startResult);
    expect(api.calls.any((c) => c.startsWith('startTorrent:')), isTrue);
  });

  test('addTorrent throws when streamUrl starts with Error', () async {
    api.startResult = 'Error: boom';
    await expectLater(
      () => backend.addTorrent(_kMagnet, fallbackInfoHash: _kHash),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'msg',
          contains('Error: boom'),
        ),
      ),
    );
  });

  test('addTorrent uses fallbackInfoHash when URL has no hash', () async {
    api.startResult = 'http://127.0.0.1:3030/stream/2';
    final handle = await backend.addTorrent(
      _kMagnet,
      fallbackInfoHash: 'DEADBEEF',
    );
    expect(handle.infoHash, 'deadbeef');
    expect(handle.fileIdx, 2);
  });

  test('pause/resume/remove forward to api', () async {
    expect(await backend.pauseTorrent(_kHash), isTrue);
    expect(await backend.resumeTorrent(_kHash), isTrue);
    expect(await backend.removeTorrent(_kHash, deleteFiles: true), isTrue);
    expect(api.calls, contains('pauseTorrent:$_kHash'));
    expect(api.calls, contains('resumeTorrent:$_kHash'));
    expect(api.calls, contains('stopTorrent:$_kHash:true'));
  });

  test('getStats maps rust TorrentStats to BtTorrentStats', () async {
    api.stats = [
      rust_api.TorrentStats(
        infoHash: _kHash.toUpperCase(),
        name: 'Ep01',
        state: 'live',
        progress: 42.5,
        downloadSpeed: 1000,
        uploadSpeed: 10,
        downloaded: BigInt.from(100),
        totalSize: BigInt.from(200),
        peers: 3,
        seeders: 1,
      ),
    ];
    final list = await backend.getStats();
    expect(list, hasLength(1));
    expect(
      list.single,
      BtTorrentStats(
        infoHash: _kHash,
        name: 'Ep01',
        state: 'live',
        progress: 42.5,
        downloadSpeed: 1000,
        uploadSpeed: 10,
        downloaded: BigInt.from(100),
        totalSize: BigInt.from(200),
        peers: 3,
        seeders: 1,
      ),
    );
  });

  test('isTorrentManaged true when hash present and not error', () async {
    api.stats = [
      rust_api.TorrentStats(
        infoHash: _kHash,
        name: 'n',
        state: 'live',
        progress: 0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        downloaded: BigInt.zero,
        totalSize: BigInt.zero,
        peers: 0,
        seeders: 0,
      ),
    ];
    expect(await backend.isTorrentManaged(_kHash), isTrue);
  });

  test('isTorrentManaged false for error state or missing', () async {
    api.stats = [
      rust_api.TorrentStats(
        infoHash: _kHash,
        name: 'n',
        state: 'error',
        progress: 0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        downloaded: BigInt.zero,
        totalSize: BigInt.zero,
        peers: 0,
        seeders: 0,
      ),
    ];
    expect(await backend.isTorrentManaged(_kHash), isFalse);
    expect(await backend.isTorrentManaged('other'), isFalse);
  });

  test('isTorrentManaged returns false on stats exception', () async {
    api.statsException = Exception('down');
    expect(await backend.isTorrentManaged(_kHash), isFalse);
  });

  test(
    'setFilePriorities / saveResumeData / applySpeedLimits are no-ops',
    () async {
      await backend.setFilePriorities(_kHash, [7]);
      expect(await backend.saveResumeData(_kHash, '/tmp/r'), isFalse);
      await backend.applySpeedLimits(
        downloadLimitBytesPerSecond: 100,
        uploadLimitBytesPerSecond: 50,
      );
      expect(api.calls, isEmpty);
    },
  );
}
