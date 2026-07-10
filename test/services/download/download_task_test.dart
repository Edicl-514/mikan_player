import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/download_task.dart';

void main() {
  group('DownloadTask JSON', () {
    test('round-trip preserves persisted keys', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
      final original = DownloadTask(
        id: 'abc123',
        name: 'Episode 01',
        magnet: 'magnet:?xt=urn:btih:DEADBEEFCAFE&dn=episode01',
        animeName: 'Foo Anime',
        episodeNumber: 1,
        startTime: start,
        taskType: DownloadTaskType.bt,
        status: DownloadTaskStatus.downloading,
        progress: 42.5,
        downloadSpeed: 1024,
        uploadSpeed: 512,
        downloaded: BigInt.parse('123456'),
        totalSize: BigInt.parse('9999999'),
        peers: 8,
        streamUrl: 'http://localhost:8080/torrents/DEADBEEF/stream/0',
        largestFileIdx: 0,
        largestFilePath: 'episode01.mkv',
        backend: BtBackendKind.libtorrent,
        errorMessage: 'something went wrong',
        downloadDir: '/data/downloads',
        videoUrl: null,
        headers: {'referer': 'https://example.com'},
        cookies: 'session=abc',
        localFilePath: '/data/downloads/episode01.mkv',
      );

      final json = original.toJson();
      // Spot-check every persisted key is present in the produced map.
      const expectedKeys = {
        'id',
        'name',
        'magnet',
        'animeName',
        'episodeNumber',
        'startTime',
        'taskType',
        'status',
        'progress',
        'downloaded',
        'totalSize',
        'largestFileIdx',
        'largestFilePath',
        'backend',
        'downloadDir',
        'videoUrl',
        'headers',
        'cookies',
        'localFilePath',
      };
      expect(json.keys.toSet(), expectedKeys);
      // streamUrl is intentionally not persisted.
      expect(json.containsKey('streamUrl'), isFalse);

      final restored = DownloadTask.fromJson(json);

      // Identity / persisted fields match.
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.magnet, original.magnet);
      expect(restored.animeName, original.animeName);
      expect(restored.episodeNumber, original.episodeNumber);
      expect(restored.startTime, original.startTime);
      expect(restored.taskType, original.taskType);
      expect(restored.status, original.status);
      expect(restored.progress, original.progress);
      expect(restored.downloaded, original.downloaded);
      expect(restored.totalSize, original.totalSize);
      expect(restored.largestFileIdx, original.largestFileIdx);
      expect(restored.largestFilePath, original.largestFilePath);
      expect(restored.backend, original.backend);
      expect(restored.downloadDir, original.downloadDir);
      expect(restored.cookies, original.cookies);
      expect(restored.localFilePath, original.localFilePath);
      expect(restored.headers, original.headers);

      // Process-local fields are intentionally reset.
      expect(restored.streamUrl, isNull);
      expect(restored.downloadSpeed, 0.0);
      expect(restored.uploadSpeed, 0.0);
      expect(restored.peers, 0);
      expect(restored.errorMessage, isNull);
    });

    test('persisted taskType value is the enum name', () {
      final task = DownloadTask(
        id: 't1',
        name: 'n',
        startTime: DateTime.fromMillisecondsSinceEpoch(0),
        taskType: DownloadTaskType.http,
      );
      expect(task.toJson()['taskType'], 'http');
    });

    test('persisted backend value uses storageValue', () {
      final bt = DownloadTask(
        id: 't1',
        name: 'n',
        startTime: DateTime.fromMillisecondsSinceEpoch(0),
        backend: BtBackendKind.libtorrent,
      );
      final rq = DownloadTask(
        id: 't2',
        name: 'n',
        startTime: DateTime.fromMillisecondsSinceEpoch(0),
        backend: BtBackendKind.rqbit,
      );
      expect(bt.toJson()['backend'], 'libtorrent');
      expect(rq.toJson()['backend'], 'rqbit');
    });

    test('fromJson defaults missing taskType to bt', () {
      // Old persisted record written before HTTP support existed.
      final old = <String, dynamic>{
        'id': 'legacy',
        'name': 'legacy task',
        'magnet': 'magnet:?xt=urn:btih:DEAD',
        'startTime': 0,
        'status': DownloadTaskStatus.pending.index,
        'progress': 0.0,
        'downloaded': '0',
        'totalSize': '0',
        'backend': 'rqbit',
      };
      final task = DownloadTask.fromJson(old);
      expect(task.taskType, DownloadTaskType.bt);
    });

    test('fromJson honors explicit taskType=http', () {
      final json = <String, dynamic>{
        'id': 'h1',
        'name': 'http task',
        'magnet': '',
        'startTime': 0,
        'status': DownloadTaskStatus.pending.index,
        'progress': 0.0,
        'downloaded': '0',
        'totalSize': '0',
        'taskType': 'http',
        'backend': 'rqbit',
        'videoUrl': 'https://example.com/video.mp4',
        'headers': {'referer': 'x'},
        'cookies': 'k=v',
        'localFilePath': '/tmp/x.mp4',
      };
      final task = DownloadTask.fromJson(json);
      expect(task.taskType, DownloadTaskType.http);
      expect(task.videoUrl, 'https://example.com/video.mp4');
      expect(task.headers, {'referer': 'x'});
      expect(task.cookies, 'k=v');
      expect(task.localFilePath, '/tmp/x.mp4');
    });

    test('fromJson treats out-of-range status index as pending', () {
      final json = <String, dynamic>{
        'id': 'a',
        'name': 'a',
        'magnet': '',
        'startTime': 0,
        'status': 999, // unknown
        'progress': 0.0,
        'downloaded': '0',
        'totalSize': '0',
        'backend': 'rqbit',
      };
      final task = DownloadTask.fromJson(json);
      expect(task.status, DownloadTaskStatus.pending);
    });

    test('fromJson tolerates missing downloaded/totalSize', () {
      final json = <String, dynamic>{
        'id': 'a',
        'name': 'a',
        'magnet': '',
        'startTime': 0,
        'status': DownloadTaskStatus.pending.index,
        'progress': 0.0,
        'backend': 'rqbit',
      };
      final task = DownloadTask.fromJson(json);
      expect(task.downloaded, BigInt.zero);
      expect(task.totalSize, BigInt.zero);
    });

    test('fromJson reads headers map values as strings', () {
      final json = <String, dynamic>{
        'id': 'a',
        'name': 'a',
        'magnet': '',
        'startTime': 0,
        'status': DownloadTaskStatus.pending.index,
        'progress': 0.0,
        'downloaded': '0',
        'totalSize': '0',
        'backend': 'rqbit',
        'headers': <String, dynamic>{'x': 7, 'y': true},
      };
      final task = DownloadTask.fromJson(json);
      expect(task.headers, equals({'x': '7', 'y': 'true'}));
    });
  });

  group('DownloadTask defaults', () {
    test('uses BT + rqbit + pending by default', () {
      final task = DownloadTask(
        id: 'a',
        name: 'a',
        startTime: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(task.taskType, DownloadTaskType.bt);
      expect(task.backend, BtBackendKind.rqbit);
      expect(task.status, DownloadTaskStatus.pending);
      expect(task.progress, 0.0);
      expect(task.downloaded, BigInt.zero);
      expect(task.totalSize, BigInt.zero);
      expect(task.magnet, '');
      expect(task.animeName, isNull);
      expect(task.episodeNumber, isNull);
    });

    test('isCompleted reflects progress', () {
      final task = DownloadTask(
        id: 'a',
        name: 'a',
        startTime: DateTime.fromMillisecondsSinceEpoch(0),
        progress: 99.999,
      );
      expect(task.isCompleted, isFalse);
      task.progress = 100.0;
      expect(task.isCompleted, isTrue);
    });

    test('isPlayable covers downloading/seeding/completed/paused/'
        'metadata/checking', () {
      DownloadTask taskWith(DownloadTaskStatus s) => DownloadTask(
        id: 'a',
        name: 'a',
        startTime: DateTime.fromMillisecondsSinceEpoch(0),
        status: s,
      );

      const playable = [
        DownloadTaskStatus.downloading,
        DownloadTaskStatus.seeding,
        DownloadTaskStatus.completed,
        DownloadTaskStatus.paused,
        DownloadTaskStatus.metadata,
        DownloadTaskStatus.checking,
      ];
      for (final s in playable) {
        expect(taskWith(s).isPlayable, isTrue, reason: '$s should be playable');
      }
      const notPlayable = [
        DownloadTaskStatus.pending,
        DownloadTaskStatus.error,
        DownloadTaskStatus.queued,
      ];
      for (final s in notPlayable) {
        expect(
          taskWith(s).isPlayable,
          isFalse,
          reason: '$s should not be playable',
        );
      }
    });
  });

  group('BtBackendKindX', () {
    test('fromStorage parses known values', () {
      expect(BtBackendKindX.fromStorage('rqbit'), BtBackendKind.rqbit);
      expect(
        BtBackendKindX.fromStorage('libtorrent'),
        BtBackendKind.libtorrent,
      );
    });

    test('fromStorage defaults to rqbit on null/unknown', () {
      expect(BtBackendKindX.fromStorage(null), BtBackendKind.rqbit);
      expect(BtBackendKindX.fromStorage(''), BtBackendKind.rqbit);
      expect(BtBackendKindX.fromStorage('garbage'), BtBackendKind.rqbit);
    });

    test('storageValue and label agree for known kinds', () {
      for (final kind in BtBackendKind.values) {
        expect(kind.storageValue, kind.label);
        expect(BtBackendKindX.fromStorage(kind.storageValue), kind);
      }
    });
  });
}
