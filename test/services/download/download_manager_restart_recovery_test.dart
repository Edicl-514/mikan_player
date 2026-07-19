// DT-7 regression: app-restart recovery in `DownloadManager._loadTasks`.
//
// `_loadTasks` runs the domain transitions over the persisted task list on
// cold start. It is distinct from `DownloadTaskStore` (raw JSON IO, covered by
// download_task_store_test.dart) and was previously exercised only indirectly.
// These tests seed the persisted blob under the frozen [btTasksStorageKey] via
// `SharedPreferences.setMockInitialValues`, then drive the real recovery pass
// through `loadTasksForTesting()` and assert on the resulting task states.
//
// No platform channels / FFI: HTTP-recovery cases never enter the BT resume
// queue, and the BT auto-resume case leaves `_downloadDir` null so
// `_runResumeQueue`'s trailing `rust_api.setDownloadDir` FFI call is skipped.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download/download_task_store.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kInfoHash = '0123456789abcdef0123456789abcdef01234567';
const _kMagnet = 'magnet:?xt=urn:btih:$_kInfoHash&dn=test';

/// Build a persisted-JSON map for one task (mirrors [DownloadTask.toJson]).
Map<String, dynamic> persistedTask({
  required String id,
  required DownloadTaskType taskType,
  required DownloadTaskStatus status,
  String magnet = '',
  BtBackendKind backend = BtBackendKind.rqbit,
  double progress = 10.0,
  String? localFilePath,
  String? videoUrl,
}) {
  return DownloadTask(
    id: id,
    name: 'Task $id',
    magnet: magnet,
    animeName: 'Anime',
    episodeNumber: 1,
    startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
    taskType: taskType,
    status: status,
    progress: progress,
    backend: backend,
    localFilePath: localFilePath,
    videoUrl: videoUrl,
  ).toJson();
}

Future<void> seedPersistedTasks(List<Map<String, dynamic>> tasks) async {
  SharedPreferences.setMockInitialValues({
    btTasksStorageKey: jsonEncode(tasks),
  });
}

void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('mikan_restart_');
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('HTTP task restart recovery', () {
    test(
      'an active HTTP task is demoted to paused (never auto-resumed)',
      () async {
        // A downloading HTTP task cannot survive a process restart — the
        // socket is gone — so recovery must park it as paused for the user to
        // resume manually, and track it in the paused set.
        await seedPersistedTasks([
          persistedTask(
            id: 'http_a',
            taskType: DownloadTaskType.http,
            status: DownloadTaskStatus.downloading,
            videoUrl: 'https://example.com/a.mp4',
          ),
        ]);
        final manager = DownloadManager.forTesting();
        try {
          await manager.loadTasksForTesting();

          final task = manager.tasks.firstWhere((t) => t.id == 'http_a');
          expect(task.status, DownloadTaskStatus.paused);
          expect(task.downloadSpeed, 0);
          expect(manager.isPausedForTesting('http_a'), isTrue);
        } finally {
          manager.dispose();
        }
      },
    );

    test(
      'a completed HTTP task whose local file is gone becomes error',
      () async {
        final missingPath = '${tempRoot.path}/gone.mp4';
        await seedPersistedTasks([
          persistedTask(
            id: 'http_done',
            taskType: DownloadTaskType.http,
            status: DownloadTaskStatus.completed,
            progress: 100.0,
            localFilePath: missingPath,
          ),
        ]);
        final manager = DownloadManager.forTesting();
        try {
          await manager.loadTasksForTesting();

          final task = manager.tasks.firstWhere((t) => t.id == 'http_done');
          expect(task.status, DownloadTaskStatus.error);
          expect(task.errorMessage, '本地文件已删除');
          expect(manager.isPausedForTesting('http_done'), isFalse);
        } finally {
          manager.dispose();
        }
      },
    );

    test(
      'a completed HTTP task whose local file still exists stays completed',
      () async {
        final presentFile = File('${tempRoot.path}/present.mp4')
          ..writeAsBytesSync([1, 2, 3]);
        await seedPersistedTasks([
          persistedTask(
            id: 'http_ok',
            taskType: DownloadTaskType.http,
            status: DownloadTaskStatus.completed,
            progress: 100.0,
            localFilePath: presentFile.path,
          ),
        ]);
        final manager = DownloadManager.forTesting();
        try {
          await manager.loadTasksForTesting();

          final task = manager.tasks.firstWhere((t) => t.id == 'http_ok');
          expect(task.status, DownloadTaskStatus.completed);
          expect(task.errorMessage, isNull);
        } finally {
          manager.dispose();
        }
      },
    );

    test('a persisted paused HTTP task is tracked in the paused set', () async {
      await seedPersistedTasks([
        persistedTask(
          id: 'http_paused',
          taskType: DownloadTaskType.http,
          status: DownloadTaskStatus.paused,
          videoUrl: 'https://example.com/p.mp4',
        ),
      ]);
      final manager = DownloadManager.forTesting();
      try {
        await manager.loadTasksForTesting();

        final task = manager.tasks.firstWhere((t) => t.id == 'http_paused');
        expect(task.status, DownloadTaskStatus.paused);
        expect(manager.isPausedForTesting('http_paused'), isTrue);
      } finally {
        manager.dispose();
      }
    });
  });

  group('BT task restart recovery', () {
    test('a BT task with an empty magnet is dropped on load', () async {
      await seedPersistedTasks([
        persistedTask(
          id: 'bt_bad',
          taskType: DownloadTaskType.bt,
          status: DownloadTaskStatus.downloading,
          // Empty magnet — corrupt/unresumable, must be discarded.
        ),
      ]);
      final manager = DownloadManager.forTesting();
      try {
        await manager.loadTasksForTesting();
        expect(manager.tasks.where((t) => t.id == 'bt_bad'), isEmpty);
      } finally {
        manager.dispose();
      }
    });

    test(
      'a persisted rqbit pending task is promoted to metadata on load',
      () async {
        // rqbit has no "pending" native stage; startup aligns it with the
        // libtorrent-style metadata stage. Use the fake rqbit backend so the
        // auto-resume path resolves without real FFI.
        final fakeRqbit = FakeBtBackend(kind: BtBackendKind.rqbit);
        await fakeRqbit.ensureInitialized();
        await seedPersistedTasks([
          persistedTask(
            id: _kInfoHash,
            taskType: DownloadTaskType.bt,
            status: DownloadTaskStatus.pending,
            magnet: _kMagnet,
            backend: BtBackendKind.rqbit,
          ),
        ]);
        // NOTE: no setDownloadDirForTesting → `_downloadDir` stays null so the
        // resume queue's trailing rust_api.setDownloadDir FFI call is skipped.
        final manager = DownloadManager.forTesting(rqbitBackend: fakeRqbit);
        try {
          await manager.loadTasksForTesting();
          // Auto-resume runs on a fire-and-forget queue; drain it.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final task = manager.tasks.firstWhere((t) => t.id == _kInfoHash);
          // pending → metadata at load; auto-resume then drives it to
          // downloading once the backend re-attaches.
          expect(
            task.status,
            anyOf(
              DownloadTaskStatus.metadata,
              DownloadTaskStatus.downloading,
            ),
          );
          expect(
            fakeRqbit.callLog.any((c) => c.startsWith('addTorrent:')),
            isTrue,
            reason: 'an active BT task must be auto-resumed on restart',
          );
        } finally {
          manager.dispose();
        }
      },
    );

    test('a persisted paused BT task is NOT auto-resumed on load', () async {
      final fakeRqbit = FakeBtBackend(kind: BtBackendKind.rqbit);
      await fakeRqbit.ensureInitialized();
      await seedPersistedTasks([
        persistedTask(
          id: _kInfoHash,
          taskType: DownloadTaskType.bt,
          status: DownloadTaskStatus.paused,
          magnet: _kMagnet,
          backend: BtBackendKind.rqbit,
        ),
      ]);
      final manager = DownloadManager.forTesting(rqbitBackend: fakeRqbit);
      try {
        await manager.loadTasksForTesting();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final task = manager.tasks.firstWhere((t) => t.id == _kInfoHash);
        expect(task.status, DownloadTaskStatus.paused);
        expect(manager.isPausedForTesting(_kInfoHash), isTrue);
        expect(
          fakeRqbit.callLog.any((c) => c.startsWith('addTorrent:')),
          isFalse,
          reason: 'paused BT tasks must wait for a manual resume',
        );
      } finally {
        manager.dispose();
      }
    });
  });

  group('load with no persisted data', () {
    test('an empty store leaves the manager with no tasks', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = DownloadManager.forTesting();
      try {
        await manager.loadTasksForTesting();
        expect(manager.tasks, isEmpty);
      } finally {
        manager.dispose();
      }
    });
  });
}
