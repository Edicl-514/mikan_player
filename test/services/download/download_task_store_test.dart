// Tests for the `DownloadTaskStore` persistence layer extracted from
// `lib/services/download_manager.dart` (Phase 3 revised immediate order
// step 2).
//
// The store is exercised against an in-memory `FakeDownloadTaskKeyValueStore`
// so no platform channels / `SharedPreferences` are involved. `DownloadTask`
// is reused as-is; its JSON round-trip is covered separately by
// `download_task_test.dart`. These tests assert the store's read/write +
// encode/decode contract and that the persisted key stays frozen.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/download_task.dart';
import 'package:mikan_player/services/download/download_task_store.dart';

/// In-memory key-value backing store used to drive the tests without
/// `SharedPreferences` / platform channels.
class FakeDownloadTaskKeyValueStore implements DownloadTaskKeyValueStore {
  FakeDownloadTaskKeyValueStore({Map<String, String>? initial})
    : _data = Map<String, String>.from(initial ?? const <String, String>{});

  final Map<String, String> _data;

  @override
  Future<String?> getString(String key) async => _data[key];

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }
}

void main() {
  DownloadTask makeTask({
    String id = 't1',
    String name = 'Episode 01',
    String magnet = 'magnet:?xt=urn:btih:DEADBEEFCAFE&dn=episode01',
    DownloadTaskType taskType = DownloadTaskType.bt,
    DownloadTaskStatus status = DownloadTaskStatus.downloading,
    BtBackendKind backend = BtBackendKind.rqbit,
    double progress = 42.5,
    BigInt? downloaded,
  }) {
    return DownloadTask(
      id: id,
      name: name,
      magnet: magnet,
      animeName: 'Foo Anime',
      episodeNumber: 1,
      startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      taskType: taskType,
      status: status,
      progress: progress,
      downloadSpeed: 1024,
      uploadSpeed: 512,
      downloaded: downloaded ?? BigInt.parse('123456'),
      totalSize: BigInt.parse('9999999'),
      peers: 8,
      largestFileIdx: 0,
      largestFilePath: 'episode01.mkv',
      backend: backend,
      downloadDir: '/data/downloads',
      headers: {'referer': 'https://example.com'},
      cookies: 'session=abc',
      localFilePath: '/data/downloads/episode01.mkv',
    );
  }

  /// Two task lists are considered equal when their elements' [DownloadTask
  /// .toJson] maps match position-by-position. Comparing `toJson` (not
  /// operator==, since DownloadTask is mutable) verifies that the full
  /// persisted field set survives the round-trip while ignoring the
  /// process-local fields that `fromJson` intentionally resets.
  void expectRoundTripEqual(
    List<DownloadTask> actual,
    List<DownloadTask> expected,
  ) {
    expect(actual.length, expected.length, reason: 'list length mismatch');
    for (var i = 0; i < expected.length; i++) {
      expect(
        actual[i].toJson(),
        equals(expected[i].toJson()),
        reason: 'toJson() mismatch at index $i',
      );
    }
  }

  group('frozen storage key', () {
    test('btTasksStorageKey equals the persisted literal', () {
      // Plan Stop Condition: persisted JSON keys are frozen. A rename here
      // would orphan every existing user's saved tasks.
      expect(btTasksStorageKey, 'bt_download_tasks_v1');
    });

    test(
      'a default-constructed store reads/writes under the frozen key',
      () async {
        // Constructing a store with NO explicit storageKey must default to
        // [btTasksStorageKey]. Prove it by saving a task with a default-key
        // store and loading it back with a SECOND default-key store over the
        // same backing map; if the two used different keys the load would be
        // empty.
        final fake = FakeDownloadTaskKeyValueStore();
        await DownloadTaskStore(prefs: fake).saveTasks([makeTask(id: 'a')]);
        final loaded = await DownloadTaskStore(prefs: fake).loadTasks();
        expect(loaded, hasLength(1));
        expect(loaded.single.id, 'a');
      },
    );
  });

  group('loadTasks', () {
    test('returns const [] when the store has never been written', () async {
      final store = DownloadTaskStore(prefs: FakeDownloadTaskKeyValueStore());
      final loaded = await store.loadTasks();
      expect(loaded, isEmpty);
      expect(
        loaded,
        same(const <DownloadTask>[]),
        reason: 'contract is to return the canonical const empty list',
      );
    });

    test(
      'does not throw on a corrupt JSON string and returns const []',
      () async {
        final fake = FakeDownloadTaskKeyValueStore(
          initial: const {'bt_download_tasks_v1': 'not valid json {'},
        );
        final store = DownloadTaskStore(prefs: fake);
        final loaded = await store.loadTasks();
        expect(loaded, isEmpty);
        expect(loaded, same(const <DownloadTask>[]));
      },
    );

    test(
      'does not throw on a non-object element array and returns const []',
      () async {
        // `[1, 2, 3]` is valid JSON but cannot be cast to task JSON maps.
        // The store surfaces this as an empty list (contract: loadTasks
        // never throws), matching the manager's pre-extraction swallow
        // behaviour for the same input (the `as Map<String, dynamic>` cast
        // threw inside the original loop and was caught by the outer try).
        final fake = FakeDownloadTaskKeyValueStore(
          initial: const {'bt_download_tasks_v1': '[1, 2, 3]'},
        );
        final store = DownloadTaskStore(prefs: fake);
        final loaded = await store.loadTasks();
        expect(loaded, isEmpty);
      },
    );
  });

  group('saveTasks / loadTasks round-trip', () {
    test('preserves a varied set of tasks through save then load', () async {
      final tasks = <DownloadTask>[
        makeTask(
          id: 'a',
          name: 'Episode A',
          status: DownloadTaskStatus.downloading,
        ),
        makeTask(
          id: 'b',
          name: 'Episode B (http, empty magnet)',
          // HTTP tasks have no magnet. The store performs NO validation, so
          // an empty-magnet HTTP task must survive the round-trip (the
          // "skip BT tasks with empty magnet" rule lives in the manager).
          magnet: '',
          taskType: DownloadTaskType.http,
          status: DownloadTaskStatus.paused,
          backend: BtBackendKind.libtorrent,
        ),
        makeTask(
          id: 'c',
          name: 'Episode C (seeding, 100%)',
          status: DownloadTaskStatus.seeding,
          progress: 100.0,
          downloaded: BigInt.parse('9999999'),
        ),
      ];

      final fake = FakeDownloadTaskKeyValueStore();
      // Save through one store instance, then load through a FRESH store over
      // the same backing map to prove the persisted blob is self-contained
      // and does not depend on in-memory state from the saver.
      await DownloadTaskStore(prefs: fake).saveTasks(tasks);
      final loaded = await DownloadTaskStore(prefs: fake).loadTasks();

      expectRoundTripEqual(loaded, tasks);
    });
  });

  group('saveTasks overwrite', () {
    test('a second save replaces the first under the same key', () async {
      final fake = FakeDownloadTaskKeyValueStore();
      final store = DownloadTaskStore(prefs: fake);

      final a = <DownloadTask>[makeTask(id: 'a', name: 'A')];
      final b = <DownloadTask>[
        makeTask(id: 'b1', name: 'B1'),
        makeTask(id: 'b2', name: 'B2'),
      ];

      await store.saveTasks(a);
      await store.saveTasks(b);

      final loaded = await store.loadTasks();
      // Returns B (two tasks), not A, not A+B.
      expectRoundTripEqual(loaded, b);
    });
  });

  group('saveTasks empty', () {
    test(
      'writes the literal "[]" JSON array string, not null/absence',
      () async {
        const key = btTasksStorageKey;
        final fake = FakeDownloadTaskKeyValueStore();
        final store = DownloadTaskStore(prefs: fake);

        await store.saveTasks(const <DownloadTask>[]);

        final written = await fake.getString(key);
        expect(
          written,
          isNotNull,
          reason: 'empty writes must be present, not absent',
        );
        expect(
          written,
          '[]',
          reason:
              'an empty task list must serialise to "[]" so a later '
              'load reads "[]" rather than null',
        );
      },
    );

    test('a load following an empty write returns an empty list', () async {
      final store = DownloadTaskStore(prefs: FakeDownloadTaskKeyValueStore());
      await store.saveTasks(const <DownloadTask>[]);
      final loaded = await store.loadTasks();
      expect(loaded, isEmpty);
    });
  });
}
