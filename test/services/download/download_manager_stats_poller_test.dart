// DT-7 regression: `DownloadManager._updateStats` race / state-transition
// branches that the existing single happy-path stats test does not cover.
//
// Priority #2 from the DT-7 plan: pause/resume/remove vs stats polling races.
// The poller runs every 500ms and merges backend stats into task fields; a
// task can be paused or removed between polls, and the poll must respect that
// (never resurrect a removed task, never overwrite a paused task's status).
//
// Uses the injected FakeBtBackend (rqbit) — no real Rust engine / FFI.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kInfoHash = '0123456789abcdef0123456789abcdef01234567';
const _kMagnet = 'magnet:?xt=urn:btih:$_kInfoHash&dn=test';

void main() {
  late FakeBtBackend fakeRqbit;
  late DownloadManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeRqbit = FakeBtBackend(kind: BtBackendKind.rqbit);
    await fakeRqbit.ensureInitialized();
    manager = DownloadManager.forTesting(rqbitBackend: fakeRqbit);
    manager.setDownloadDirForTesting('/tmp/mikan_stats_poll');
  });

  tearDown(() {
    manager.dispose();
  });

  DownloadTask seedTask({
    DownloadTaskStatus status = DownloadTaskStatus.downloading,
    double progress = 10.0,
  }) {
    final task = DownloadTask(
      id: _kInfoHash,
      name: 'BT Episode',
      magnet: _kMagnet,
      animeName: 'Test Anime',
      episodeNumber: 1,
      startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      taskType: DownloadTaskType.bt,
      status: status,
      progress: progress,
      backend: BtBackendKind.rqbit,
      downloadDir: '/tmp/mikan_stats_poll',
    );
    manager.seedBtTaskForTesting(task);
    return task;
  }

  FakeBtTorrent seedBackendTorrent({
    String state = 'live',
    double progress = 10.0,
    int downloadRate = 1000,
    int uploadRate = 0,
    int numPeers = 2,
    int fileSize = 10_000,
    bool isPaused = false,
  }) {
    final torrent = FakeBtTorrent(
      infoHash: _kInfoHash,
      torrentId: 1,
      state: state,
      progress: progress,
      downloadRate: downloadRate,
      uploadRate: uploadRate,
      numPeers: numPeers,
      isPaused: isPaused,
    )..fileSize = fileSize;
    fakeRqbit.torrents[_kInfoHash] = torrent;
    return torrent;
  }

  group('paused-task race', () {
    test(
      'a poll for a paused task updates byte counters but never flips status '
      'back to downloading',
      () async {
        // The stats poller only runs while at least one BT task is still in a
        // pollable (active/seeding) state, so seed a second live task to keep
        // the poll alive alongside the paused one — this is exactly the real
        // race: task B is downloading while the user pauses task A mid-poll.
        const otherHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final paused = seedTask(status: DownloadTaskStatus.paused, progress: 30);
        seedBackendTorrent(state: 'paused', progress: 30, isPaused: true);

        final keepAlive = DownloadTask(
          id: otherHash,
          name: 'Other',
          magnet: 'magnet:?xt=urn:btih:$otherHash&dn=other',
          startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          taskType: DownloadTaskType.bt,
          status: DownloadTaskStatus.downloading,
          progress: 5,
          backend: BtBackendKind.rqbit,
          downloadDir: '/tmp/mikan_stats_poll',
        );
        manager.seedBtTaskForTesting(keepAlive);
        fakeRqbit.torrents[otherHash] = FakeBtTorrent(
          infoHash: otherHash,
          torrentId: 2,
          state: 'live',
          progress: 5,
        )..fileSize = 10_000;

        // Pause task A the way production does (populates the paused set).
        await manager.pauseBtTaskForTesting(_kInfoHash);
        expect(paused.status, DownloadTaskStatus.paused);

        // The backend reports task A as 'live' again (a stale pre-pause stat
        // still in flight). The poll must respect the local pause and keep the
        // status paused while still reflecting real byte/peer counts.
        fakeRqbit.torrents[_kInfoHash]!
          ..state = 'live'
          ..isPaused = false
          ..progress = 45
          ..downloadRate = 5000
          ..numPeers = 9
          ..fileSize = 10_000;

        await manager.updateStatsForTesting();

        expect(
          paused.status,
          DownloadTaskStatus.paused,
          reason: 'a paused task must not be flipped to downloading by a poll',
        );
        expect(paused.downloadSpeed, 0, reason: 'paused speed stays zeroed');
        // Byte/peer reality still tracked for the paused task.
        expect(paused.peers, 9);
        expect(paused.totalSize, BigInt.from(10_000));
      },
    );
  });

  group('removed-task race', () {
    test(
      'a poll never resurrects a task removed between polls',
      () async {
        seedTask(progress: 10);
        seedBackendTorrent(progress: 50);

        // User removes the task. removeTask drops it from _tasks and marks the
        // id in _removedTaskIds, but a stale backend stat for that hash can
        // still arrive on the next poll.
        await manager.removeBtTaskForTesting(_kInfoHash);
        expect(manager.tasks.where((t) => t.id == _kInfoHash), isEmpty);

        // Re-add a backend stat for the removed hash to simulate a stale poll.
        seedBackendTorrent(progress: 60);

        await manager.updateStatsForTesting();

        expect(
          manager.tasks.where((t) => t.id == _kInfoHash),
          isEmpty,
          reason: 'a removed task must not be re-added by a stale poll stat',
        );
      },
    );
  });

  group('terminal-state transitions release the slot', () {
    test('progress >= 100 flips the task to seeding', () async {
      final task = seedTask(progress: 90);
      seedBackendTorrent(state: 'live', progress: 100, fileSize: 10_000);

      await manager.updateStatsForTesting();

      expect(task.status, DownloadTaskStatus.seeding);
    });

    test('a backend error state surfaces as task error', () async {
      final task = seedTask(progress: 40);
      seedBackendTorrent(state: 'error', progress: 40, fileSize: 10_000);

      await manager.updateStatsForTesting();

      expect(task.status, DownloadTaskStatus.error);
    });

    test('a checking state maps to checking', () async {
      final task = seedTask(progress: 40);
      seedBackendTorrent(state: 'checking', progress: 40, fileSize: 10_000);

      await manager.updateStatsForTesting();

      expect(task.status, DownloadTaskStatus.checking);
    });
  });

  group('no-op poll', () {
    test(
      'a poll whose stats match the task within epsilon leaves it unchanged',
      () async {
        final task = seedTask(status: DownloadTaskStatus.downloading);
        task.progress = 42.5;
        task.downloadSpeed = 2048;
        task.peers = 3;
        task.totalSize = BigInt.from(10_000);
        task.downloaded = BigInt.from(4250);
        seedBackendTorrent(
          state: 'live',
          progress: 42.5,
          downloadRate: 2048,
          numPeers: 3,
          fileSize: 10_000,
        );

        await manager.updateStatsForTesting();

        // Status unchanged (still downloading), no exception. The epsilon path
        // is exercised; we assert the visible fields are stable.
        expect(task.status, DownloadTaskStatus.downloading);
        expect(task.peers, 3);
      },
    );
  });
}
