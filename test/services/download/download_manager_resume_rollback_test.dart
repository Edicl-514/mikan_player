// DT-7 regression: `DownloadManager.resumeTask` state rollback when the BT
// backend fails mid-resume.
//
// Priority #5 from the DT-7 plan: "native backend 异常时 Dart 状态能回滚并允许重试".
// When the user resumes a paused BT torrent and the backend `resumeTorrent`
// call throws, the manager must leave the task in a consistent, retryable
// state: the visible status must NOT be stuck showing an active
// (metadata/pending/downloading) spinner, and the paused-set membership must
// agree with the visible status so a later resume is still offered.
//
// Uses the injected FakeBtBackend (rqbit) with a configured resumeException,
// so no real Rust engine / FFI is touched.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kMagnet =
    'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test';
const _kInfoHash = '0123456789abcdef0123456789abcdef01234567';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  DownloadTask seedPausedTask(DownloadManager manager, {double progress = 20}) {
    final task = DownloadTask(
      id: _kInfoHash,
      name: 'BT Episode',
      magnet: _kMagnet,
      animeName: 'Test Anime',
      episodeNumber: 1,
      startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      taskType: DownloadTaskType.bt,
      status: DownloadTaskStatus.paused,
      progress: progress,
      backend: BtBackendKind.rqbit,
      downloadDir: '/tmp/mikan_bt_rollback',
    );
    manager.seedBtTaskForTesting(task);
    return task;
  }

  test(
    'resumeTask returns false and does not throw when the backend resume '
    'throws',
    () async {
      final fakeRqbit = FakeBtBackend(
        kind: BtBackendKind.rqbit,
        resumeException: Exception('resume boom'),
      );
      await fakeRqbit.ensureInitialized();
      final manager = DownloadManager.forTesting(rqbitBackend: fakeRqbit);
      manager.setDownloadDirForTesting('/tmp/mikan_bt_rollback');
      try {
        seedPausedTask(manager);
        // Torrent is still managed by the backend (app not restarted), so the
        // resume path calls resumeTorrent — which throws.
        fakeRqbit.torrents[_kInfoHash] = FakeBtTorrent(
          infoHash: _kInfoHash,
          torrentId: 1,
          state: 'paused',
          progress: 20,
          isPaused: true,
        );

        final ok = await manager.resumeBtTaskForTesting(_kInfoHash);
        expect(ok, isFalse);
        expect(
          fakeRqbit.callLog,
          contains('resumeTorrent:$_kInfoHash'),
          reason: 'the resume path must have reached the throwing backend call',
        );
      } finally {
        manager.dispose();
      }
    },
  );

  test(
    'after a failed backend resume the task is left retryable (paused status '
    'agrees with the paused set)',
    () async {
      final fakeRqbit = FakeBtBackend(
        kind: BtBackendKind.rqbit,
        resumeException: Exception('resume boom'),
      );
      await fakeRqbit.ensureInitialized();
      final manager = DownloadManager.forTesting(rqbitBackend: fakeRqbit);
      manager.setDownloadDirForTesting('/tmp/mikan_bt_rollback');
      try {
        final task = seedPausedTask(manager);
        fakeRqbit.torrents[_kInfoHash] = FakeBtTorrent(
          infoHash: _kInfoHash,
          torrentId: 1,
          state: 'paused',
          progress: 20,
          isPaused: true,
        );

        await manager.resumeBtTaskForTesting(_kInfoHash);

        // The task must not be stranded showing an active spinner
        // (metadata/pending/downloading) while the resume actually failed.
        expect(
          task.status,
          DownloadTaskStatus.paused,
          reason:
              'a failed backend resume must roll the status back to paused, '
              'not leave it stuck at the transient active status',
        );
        // Paused-set membership must agree with the visible status so the UI
        // still offers a manual resume and no slot is silently held.
        expect(
          manager.isPausedForTesting(_kInfoHash),
          isTrue,
          reason:
              'the paused set must stay consistent with the paused status so '
              'the task remains retryable',
        );
        expect(task.downloadSpeed, 0);
      } finally {
        manager.dispose();
      }
    },
  );

  test('a second resume attempt after a transient backend failure can '
      'succeed', () async {
    final fakeRqbit = FakeBtBackend(
      kind: BtBackendKind.rqbit,
      resumeException: Exception('resume boom'),
    );
    await fakeRqbit.ensureInitialized();
    final manager = DownloadManager.forTesting(rqbitBackend: fakeRqbit);
    manager.setDownloadDirForTesting('/tmp/mikan_bt_rollback');
    try {
      final task = seedPausedTask(manager);
      fakeRqbit.torrents[_kInfoHash] = FakeBtTorrent(
        infoHash: _kInfoHash,
        torrentId: 1,
        state: 'paused',
        progress: 20,
        isPaused: true,
      );

      // First attempt fails inside the backend.
      final first = await manager.resumeBtTaskForTesting(_kInfoHash);
      expect(first, isFalse);

      // Clear the injected failure to simulate the transient error clearing,
      // then retry. The rolled-back state must allow the retry to run and
      // land the task in a live/downloading state.
      fakeRqbit.clearResumeException();
      final second = await manager.resumeBtTaskForTesting(_kInfoHash);

      expect(second, isTrue);
      expect(task.status, DownloadTaskStatus.downloading);
      expect(manager.isPausedForTesting(_kInfoHash), isFalse);
    } finally {
      manager.dispose();
    }
  });
}
