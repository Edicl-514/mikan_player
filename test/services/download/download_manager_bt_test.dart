// BT dispatch characterization tests for `DownloadManager`
// (Phase 3 commit 3 of 3).
//
// Injects [FakeBtBackend] (as rqbit) so manager BT paths call the backend
// seam without a real Rust engine or libtorrent FFI.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTestMagnet =
    'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test';
const _kTestInfoHash = '0123456789abcdef0123456789abcdef01234567';

void main() {
  late FakeBtBackend fakeRqbit;
  late DownloadManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeRqbit = FakeBtBackend(kind: BtBackendKind.rqbit);
    await fakeRqbit.ensureInitialized();
    manager = DownloadManager.forTesting(rqbitBackend: fakeRqbit);
    manager.setDownloadDirForTesting('/tmp/mikan_bt_test');
  });

  tearDown(() {
    manager.dispose();
  });

  DownloadTask seedLiveTask({
    String id = _kTestInfoHash,
    DownloadTaskStatus status = DownloadTaskStatus.downloading,
    double progress = 10.0,
  }) {
    final task = DownloadTask(
      id: id,
      name: 'BT Episode',
      magnet: _kTestMagnet,
      animeName: 'Test Anime',
      episodeNumber: 1,
      startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      taskType: DownloadTaskType.bt,
      status: status,
      progress: progress,
      backend: BtBackendKind.rqbit,
      downloadDir: '/tmp/mikan_bt_test',
    );
    manager.seedBtTaskForTesting(task);
    return task;
  }

  group('DownloadManager BT backend dispatch', () {
    test('startDownload calls rqbit addTorrent', () async {
      final streamUrl = await manager.startBtDownloadForTesting(
        magnet: _kTestMagnet,
        name: 'BT Episode',
      );

      expect(fakeRqbit.callLog.any((c) => c.startsWith('addTorrent:')), isTrue);
      expect(fakeRqbit.torrents.containsKey(_kTestInfoHash), isTrue);
      // rqbit's startTorrent is stream-URL-centric, including for background
      // downloads (`forPlayback:false`). Keep the fake aligned with that
      // production behavior so this path cannot mask a missing URL.
      expect(streamUrl, isNotNull);
      final task = manager.tasks
          .where((t) => t.id == _kTestInfoHash)
          .firstOrNull;
      expect(task, isNotNull);
      expect(task!.status, DownloadTaskStatus.downloading);
      expect(task.streamUrl, streamUrl);
    });

    test('pauseTask dispatches pauseTorrent', () async {
      seedLiveTask();
      fakeRqbit.torrents[_kTestInfoHash] = FakeBtTorrent(
        infoHash: _kTestInfoHash,
        torrentId: 1,
        state: 'live',
        progress: 10,
      );

      final ok = await manager.pauseBtTaskForTesting(_kTestInfoHash);
      expect(ok, isTrue);
      expect(fakeRqbit.callLog, contains('pauseTorrent:$_kTestInfoHash'));
      final task = manager.tasks.firstWhere((t) => t.id == _kTestInfoHash);
      expect(task.status, DownloadTaskStatus.paused);
    });

    test('resumeTask dispatches resumeTorrent when still managed', () async {
      seedLiveTask(status: DownloadTaskStatus.paused);
      fakeRqbit.torrents[_kTestInfoHash] = FakeBtTorrent(
        infoHash: _kTestInfoHash,
        torrentId: 1,
        state: 'paused',
        progress: 10,
        isPaused: true,
      );

      final ok = await manager.resumeBtTaskForTesting(_kTestInfoHash);
      expect(ok, isTrue);
      expect(fakeRqbit.callLog, contains('resumeTorrent:$_kTestInfoHash'));
      final task = manager.tasks.firstWhere((t) => t.id == _kTestInfoHash);
      expect(task.status, DownloadTaskStatus.downloading);
    });

    test('removeTask dispatches removeTorrent', () async {
      seedLiveTask();
      fakeRqbit.torrents[_kTestInfoHash] = FakeBtTorrent(
        infoHash: _kTestInfoHash,
        torrentId: 1,
      );

      await manager.removeBtTaskForTesting(_kTestInfoHash);
      expect(
        fakeRqbit.callLog.any(
          (c) => c.startsWith('removeTorrent:$_kTestInfoHash:'),
        ),
        isTrue,
      );
      expect(manager.tasks.where((t) => t.id == _kTestInfoHash), isEmpty);
    });

    test('updateStats merges backend getStats into task fields', () async {
      seedLiveTask(progress: 0);
      fakeRqbit.torrents[_kTestInfoHash] = FakeBtTorrent(
        infoHash: _kTestInfoHash,
        torrentId: 1,
        state: 'live',
        progress: 42.5,
        downloadRate: 2048,
        uploadRate: 512,
        numPeers: 3,
      )..fileSize = 10_000;

      await manager.updateStatsForTesting();

      expect(fakeRqbit.callLog, contains('getStats'));
      final task = manager.tasks.firstWhere((t) => t.id == _kTestInfoHash);
      expect(task.progress, closeTo(42.5, 0.01));
      expect(task.downloadSpeed, 2048);
      expect(task.peers, 3);
      expect(task.status, DownloadTaskStatus.downloading);
    });
  });
}
