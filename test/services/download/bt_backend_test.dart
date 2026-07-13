// Contract tests for the `BtBackend` interface + `FakeBtBackend`
// (Phase 3 commit 1 of 3 — the `download_manager.dart` BT-layer refactor).
//
// These tests verify the core-BT-op contract surface + the Fake used by the
// future manager-side characterization tests
// (`download_manager_bt_test.dart`). They do NOT touch a real libtorrent
// FFI session, a real Rust rqbit engine, platform channels, or Flutter
// widgets — `FakeBtBackend` is pure in-memory state with `Future.value`
// returns so the contract is exercised deterministically and fast.
//
// The production `RqbitBackend` (wrapping `rust_api`) and `LibtorrentBackend`
// (wrapping `mikan_libtorrent_native.dart`) are intentionally NOT exercised
// here because doing so would require a real native library + a real socket;
// their byte-for-byte behavior is preserved by reading the prod impl against
// the original inline manager code and by the manager-side characterization
// tests asserting on the resulting `DownloadTask.status` / `.progress` via
// the Fake. Mirrors the precedent established by
// `http_file_download_port_test.dart` (which never opens a real `HttpClient`).

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/bt_backend.dart';
import 'package:mikan_player/services/download/download_task.dart';

/// Canonical test magnet with a parseable 40-char hex SHA-1 info-hash.
const _kTestMagnet =
    'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test';

/// Lowercased info-hash parsed from [_kTestMagnet] by
/// `extractInfoHashFromMagnet`.
const _kTestInfoHash = '0123456789abcdef0123456789abcdef01234567';

/// Magnet whose `xt` is not a real hash — exercises the
/// `fallbackInfoHash` branch of `FakeBtBackend.addTorrent`.
const _kUnparseableMagnet = 'magnet:?xt=urn:btih:NOTAHASH&dn=bad';

void main() {
  group('BtTorrentHandle (DTO immutability)', () {
    test('can be constructed with all required fields and is fully final', () {
      const handle = BtTorrentHandle(
        infoHash: _kTestInfoHash,
        torrentId: 7,
        streamUrl: 'http://127.0.0.1:8181/t',
        streamId: 3,
        fileIdx: 0,
        fileSize: 1024,
        filePath: 'fake/file.mkv',
      );
      expect(handle.infoHash, _kTestInfoHash);
      expect(handle.torrentId, 7);
      expect(handle.streamUrl, 'http://127.0.0.1:8181/t');
      expect(handle.streamId, 3);
      expect(handle.fileIdx, 0);
      expect(handle.fileSize, 1024);
      expect(handle.filePath, 'fake/file.mkv');
    });

    test('accepts nulls for the optional native-id / stream / file fields', () {
      const handle = BtTorrentHandle(infoHash: _kTestInfoHash);
      expect(handle.infoHash, _kTestInfoHash);
      expect(handle.torrentId, isNull);
      expect(handle.streamUrl, isNull);
      expect(handle.streamId, isNull);
      expect(handle.fileIdx, isNull);
      expect(handle.fileSize, isNull);
      expect(handle.filePath, isNull);
    });
  });

  group('BtTorrentStats (DTO value equality)', () {
    test('two instances with identical fields are equal', () {
      final a = BtTorrentStats(
        infoHash: _kTestInfoHash,
        name: 'Torrent 1',
        state: 'live',
        progress: 50.0,
        downloadSpeed: 100.0,
        uploadSpeed: 10.0,
        downloaded: BigInt.from(512),
        totalSize: BigInt.from(1024),
        peers: 5,
        seeders: 2,
      );
      final b = BtTorrentStats(
        infoHash: _kTestInfoHash,
        name: 'Torrent 1',
        state: 'live',
        progress: 50.0,
        downloadSpeed: 100.0,
        uploadSpeed: 10.0,
        downloaded: BigInt.from(512),
        totalSize: BigInt.from(1024),
        peers: 5,
        seeders: 2,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('differing progress breaks equality', () {
      final a = BtTorrentStats(
        infoHash: _kTestInfoHash,
        name: 'Torrent 1',
        state: 'live',
        progress: 50.0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        downloaded: BigInt.zero,
        totalSize: BigInt.zero,
        peers: 0,
        seeders: 0,
      );
      final b = BtTorrentStats(
        infoHash: _kTestInfoHash,
        name: 'Torrent 1',
        state: 'live',
        progress: 51.0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        downloaded: BigInt.zero,
        totalSize: BigInt.zero,
        peers: 0,
        seeders: 0,
      );
      expect(a == b, isFalse);
    });
  });

  group('FakeBtBackend init', () {
    test(
      'ensureInitialized sets initialized=true and records the call',
      () async {
        final backend = FakeBtBackend();
        expect(backend.initialized, isFalse);
        expect(backend.callLog, isEmpty);

        await backend.ensureInitialized();

        expect(backend.initialized, isTrue);
        expect(backend.callLog, ['ensureInitialized']);
      },
    );

    test('ensureInitialized is idempotent on the second call', () async {
      final backend = FakeBtBackend();
      await backend.ensureInitialized();
      await backend.ensureInitialized();
      expect(backend.initialized, isTrue);
      expect(backend.callLog, ['ensureInitialized', 'ensureInitialized']);
    });

    test('ensureInitialized throws initException when configured', () async {
      final backend = FakeBtBackend(
        initException: Exception('native load fail'),
      );
      Object? caught;
      try {
        await backend.ensureInitialized();
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<Exception>());
      // init failed → initialized stays false (matches the manager's reset
      // of `_libtorrentInitialization = null` on error at :794-797).
      expect(backend.initialized, isFalse);
      expect(backend.callLog, ['ensureInitialized']);
    });
  });

  group('FakeBtBackend add torrent', () {
    test(
      'parses the info-hash from the magnet and tracks the torrent',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        final handle = await backend.addTorrent(
          _kTestMagnet,
          fallbackInfoHash: 'fallback',
        );
        expect(handle.infoHash, _kTestInfoHash);
        expect(handle.torrentId, 1);
        expect(backend.torrents, contains(_kTestInfoHash));
        expect(backend.torrents[_kTestInfoHash]!.torrentId, 1);
        expect(backend.callLog.last, 'addTorrent:$_kTestMagnet');
      },
    );

    test(
      'falls back to fallbackInfoHash when the magnet has no parseable hash',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        final handle = await backend.addTorrent(
          _kUnparseableMagnet,
          fallbackInfoHash: 'FALLBACKHASH',
        );
        expect(handle.infoHash, 'fallbackhash');
        expect(backend.torrents, contains('fallbackhash'));
      },
    );

    test(
      'libtorrent backend selects a synthetic largest file + path',
      () async {
        final backend = FakeBtBackend(kind: BtBackendKind.libtorrent)
          ..initialized = true;
        final handle = await backend.addTorrent(
          _kTestMagnet,
          fallbackInfoHash: 'fallback',
        );
        expect(handle.fileIdx, 0);
        expect(handle.fileSize, 1024);
        expect(handle.filePath, 'fake/$_kTestInfoHash/file.mkv');
      },
    );

    test('startStream=true populates streamUrl and streamId', () async {
      final backend = FakeBtBackend()..initialized = true;
      final handle = await backend.addTorrent(
        _kTestMagnet,
        fallbackInfoHash: 'fallback',
        startStream: true,
      );
      expect(handle.streamUrl, isNotNull);
      expect(handle.streamId, 1);
      final tracked = backend.torrents[_kTestInfoHash]!;
      expect(tracked.streamUrl, handle.streamUrl);
      expect(tracked.streamId, 1);
    });

    test('startStream=false leaves streamUrl/streamId null', () async {
      final backend = FakeBtBackend()..initialized = true;
      final handle = await backend.addTorrent(
        _kTestMagnet,
        fallbackInfoHash: 'fallback',
      );
      expect(handle.streamUrl, isNull);
      expect(handle.streamId, isNull);
    });

    test('throws StateError when called before ensureInitialized', () async {
      final backend = FakeBtBackend();
      expect(
        () => backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback'),
        throwsA(isA<StateError>()),
      );
      expect(backend.torrents, isEmpty);
    });

    test(
      'throws addException when configured (before tracking the torrent)',
      () async {
        final backend = FakeBtBackend(addException: Exception('add boom'))
          ..initialized = true;
        expect(
          () => backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback'),
          throwsA(isA<Exception>()),
        );
        expect(backend.torrents, isEmpty);
      },
    );

    test(
      'duplicate add returns the existing tracked torrent (re-using torrentId)',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        final first = await backend.addTorrent(
          _kTestMagnet,
          fallbackInfoHash: 'fallback',
        );
        // Second add with the same magnet returns a fresh handle for the
        // SAME tracked torrent (matching the libtorrent short-circuit at
        // download_manager.dart:856-880) — no second torrent entry, same id.
        await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
        expect(backend.torrents.length, 1);
        expect(backend.torrents[_kTestInfoHash]!.torrentId, first.torrentId);
        expect(
          backend.callLog.where((e) => e.startsWith('addTorrent:')).length,
          2,
        );
      },
    );

    test('torrent ids increment across distinct torrents', () async {
      final backend = FakeBtBackend()..initialized = true;
      final a = await backend.addTorrent(
        _kTestMagnet,
        fallbackInfoHash: 'fallback',
      );
      final b = await backend.addTorrent(
        'magnet:?xt=urn:btih:fedcba9876543210fedcba9876543210fedcba98&dn=two',
        fallbackInfoHash: 'fallback',
      );
      expect(a.torrentId, 1);
      expect(b.torrentId, 2);
      expect(a.infoHash, _kTestInfoHash);
      expect(b.infoHash, 'fedcba9876543210fedcba9876543210fedcba98');
    });
  });

  group('FakeBtBackend pause/resume/cancel', () {
    FakeBtBackend newBackendWithTorrent() {
      final backend = FakeBtBackend()..initialized = true;
      backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
      backend.callLog.clear();
      return backend;
    }

    test('pause marks the torrent paused and records the call', () async {
      final backend = newBackendWithTorrent();
      final ok = await backend.pauseTorrent(_kTestInfoHash);
      expect(ok, isTrue);
      final tracked = backend.torrents[_kTestInfoHash]!;
      expect(tracked.isPaused, isTrue);
      expect(tracked.state, 'paused');
      expect(backend.callLog, ['pauseTorrent:$_kTestInfoHash']);
    });

    test(
      'resume clears the paused flag and transitions state to live',
      () async {
        final backend = newBackendWithTorrent();
        await backend.pauseTorrent(_kTestInfoHash);
        backend.callLog.clear();

        final ok = await backend.resumeTorrent(_kTestInfoHash);
        expect(ok, isTrue);
        final tracked = backend.torrents[_kTestInfoHash]!;
        expect(tracked.isPaused, isFalse);
        expect(tracked.state, 'live');
        expect(backend.callLog, ['resumeTorrent:$_kTestInfoHash']);
      },
    );

    test('pause then resume is recorded in call order', () async {
      final backend = newBackendWithTorrent();
      await backend.pauseTorrent(_kTestInfoHash);
      await backend.resumeTorrent(_kTestInfoHash);
      expect(backend.callLog, [
        'pauseTorrent:$_kTestInfoHash',
        'resumeTorrent:$_kTestInfoHash',
      ]);
    });

    test('pause on an untracked torrent returns false (no throw)', () async {
      final backend = newBackendWithTorrent();
      final ok = await backend.pauseTorrent('untrackedhash');
      expect(ok, isFalse);
      expect(backend.torrents, contains(_kTestInfoHash));
    });

    test(
      'removeTorrent deletes the tracked torrent and removes it from the map',
      () async {
        final backend = newBackendWithTorrent();
        final ok = await backend.removeTorrent(_kTestInfoHash);
        expect(ok, isTrue);
        expect(backend.torrents, isNot(contains(_kTestInfoHash)));
        expect(backend.callLog.first, 'removeTorrent:$_kTestInfoHash:false');
      },
    );

    test(
      'removeTorrent with deleteFiles=true records the flag in the log',
      () async {
        final backend = newBackendWithTorrent();
        await backend.removeTorrent(_kTestInfoHash, deleteFiles: true);
        expect(backend.callLog.first, 'removeTorrent:$_kTestInfoHash:true');
        expect(backend.torrents, isEmpty);
      },
    );

    test(
      'removeTorrent with resumePath (deleteFiles=false) records the resume save',
      () async {
        final backend = newBackendWithTorrent();
        final tracked = backend.torrents[_kTestInfoHash]!;
        await backend.removeTorrent(
          _kTestInfoHash,
          resumePath: '/dl/$_kTestInfoHash.resume',
        );
        expect(tracked.resumeDataSaves, ['/dl/$_kTestInfoHash.resume']);
        expect(tracked.removed, isTrue);
      },
    );

    test(
      'removeTorrent with deleteFiles=true does NOT save resume data',
      () async {
        final backend = newBackendWithTorrent();
        final tracked = backend.torrents[_kTestInfoHash]!;
        await backend.removeTorrent(
          _kTestInfoHash,
          deleteFiles: true,
          resumePath: '/dl/$_kTestInfoHash.resume',
        );
        expect(tracked.resumeDataSaves, isEmpty);
      },
    );

    test('removeTorrent on an untracked torrent returns false', () async {
      final backend = newBackendWithTorrent();
      final ok = await backend.removeTorrent('untrackedhash');
      expect(ok, isFalse);
    });

    test('pause/resume/remove each throw their injected exception', () {
      final base = newBackendWithTorrent();
      // pause path
      final withPauseErr = FakeBtBackend(
        pauseException: Exception('pause boom'),
      )..initialized = true;
      withPauseErr.torrents[_kTestInfoHash] = base.torrents[_kTestInfoHash]!;
      expect(
        () => withPauseErr.pauseTorrent(_kTestInfoHash),
        throwsA(isA<Exception>()),
      );

      // resume path
      final withResumeErr = FakeBtBackend(
        resumeException: Exception('resume boom'),
      )..initialized = true;
      withResumeErr.torrents[_kTestInfoHash] = base.torrents[_kTestInfoHash]!;
      expect(
        () => withResumeErr.resumeTorrent(_kTestInfoHash),
        throwsA(isA<Exception>()),
      );

      // remove path
      final withRemoveErr = FakeBtBackend(
        removeException: Exception('remove boom'),
      )..initialized = true;
      withRemoveErr.torrents[_kTestInfoHash] = base.torrents[_kTestInfoHash]!;
      expect(
        () => withRemoveErr.removeTorrent(_kTestInfoHash),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FakeBtBackend status query', () {
    test(
      'getStats returns one entry per tracked torrent with normalized state',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
        final stats = await backend.getStats();
        expect(stats.length, 1);
        expect(stats.single.infoHash, _kTestInfoHash);
        expect(stats.single.state, 'live');
        expect(stats.single.progress, 0.0);
      },
    );

    test('getStats reflects paused state after pause', () async {
      final backend = FakeBtBackend()..initialized = true;
      await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
      await backend.pauseTorrent(_kTestInfoHash);
      final stats = await backend.getStats();
      expect(stats.single.state, 'paused');
    });

    test(
      'getStats reflects seeded progress/fileSize when configured',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
        final tracked = backend.torrents[_kTestInfoHash]!;
        tracked.progress = 50.0;
        // fileSize is set by the libtorrent fake (1024 bytes) so downloaded
        // should be 512.
        final stats = await backend.getStats();
        expect(stats.single.progress, 50.0);
        expect(stats.single.downloaded, BigInt.from(512));
        expect(stats.single.totalSize, BigInt.from(1024));
      },
    );

    test('getStats is empty after all torrents are removed', () async {
      final backend = FakeBtBackend()..initialized = true;
      await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
      await backend.removeTorrent(_kTestInfoHash);
      final stats = await backend.getStats();
      expect(stats, isEmpty);
    });

    test('getStats throws statsException when configured', () async {
      final backend = FakeBtBackend(statsException: Exception('stats boom'))
        ..initialized = true;
      expect(() => backend.getStats(), throwsA(isA<Exception>()));
    });

    test(
      'isTorrentManaged true for a tracked live torrent, false after remove',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
        expect(await backend.isTorrentManaged(_kTestInfoHash), isTrue);
        await backend.removeTorrent(_kTestInfoHash);
        expect(await backend.isTorrentManaged(_kTestInfoHash), isFalse);
      },
    );

    test('isTorrentManaged false for an untracked torrent', () async {
      final backend = FakeBtBackend()..initialized = true;
      expect(await backend.isTorrentManaged('neveradded'), isFalse);
    });

    test('isTorrentManaged false when state is error', () async {
      final backend = FakeBtBackend()..initialized = true;
      await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
      backend.torrents[_kTestInfoHash]!.state = 'error';
      expect(await backend.isTorrentManaged(_kTestInfoHash), isFalse);
    });
  });

  group('FakeBtBackend file priorities', () {
    test(
      'setFilePriorities records priorities on the tracked torrent',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
        await backend.setFilePriorities(_kTestInfoHash, [0, 7, 0]);
        expect(backend.torrents[_kTestInfoHash]!.priorities, [0, 7, 0]);
      },
    );

    test(
      'setFilePriorities on an untracked torrent is a no-op (no throw)',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        await backend.setFilePriorities('untracked', [7]);
        expect(backend.callLog.last, 'setFilePriorities:untracked');
      },
    );

    test(
      'setFilePriorities throws setFilePrioritiesException when configured',
      () async {
        final backend = FakeBtBackend(
          setFilePrioritiesException: Exception('prio boom'),
        )..initialized = true;
        expect(
          () => backend.setFilePriorities(_kTestInfoHash, [7]),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('FakeBtBackend saveResumeData / applySpeedLimits', () {
    test('saveResumeData records the resumePath and returns true', () async {
      final backend = FakeBtBackend()..initialized = true;
      await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
      final ok = await backend.saveResumeData(
        _kTestInfoHash,
        '/dl/$_kTestInfoHash.resume',
      );
      expect(ok, isTrue);
      final tracked = backend.torrents[_kTestInfoHash]!;
      expect(tracked.resumeDataSaves, ['/dl/$_kTestInfoHash.resume']);
      expect(tracked.lastResumePath, '/dl/$_kTestInfoHash.resume');
    });

    test(
      'saveResumeData on an untracked torrent returns false (no throw)',
      () async {
        final backend = FakeBtBackend()..initialized = true;
        final ok = await backend.saveResumeData('untracked', '/dl/x.resume');
        expect(ok, isFalse);
      },
    );

    test(
      'saveResumeData throws saveResumeDataException when configured',
      () async {
        final backend = FakeBtBackend(
          saveResumeDataException: Exception('save boom'),
        )..initialized = true;
        expect(
          () => backend.saveResumeData(_kTestInfoHash, '/dl/x.resume'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('applySpeedLimits records the limits verbatim', () async {
      final backend = FakeBtBackend();
      await backend.applySpeedLimits(
        downloadLimitBytesPerSecond: 1048576,
        uploadLimitBytesPerSecond: 524288,
      );
      expect(backend.lastDownloadLimitBytesPerSecond, 1048576);
      expect(backend.lastUploadLimitBytesPerSecond, 524288);
      expect(backend.callLog.single, 'applySpeedLimits:1048576:524288');
    });

    test(
      'applySpeedLimits throws applySpeedLimitsException when configured',
      () async {
        final backend = FakeBtBackend(
          applySpeedLimitsException: Exception('limit boom'),
        );
        expect(
          () => backend.applySpeedLimits(
            downloadLimitBytesPerSecond: 0,
            uploadLimitBytesPerSecond: 0,
          ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('abstract BtBackend conforms', () {
    test('FakeBtBackend is a BtBackend (compile-time contract)', () {
      expect(FakeBtBackend(), isA<BtBackend>());
    });

    test('kind getter returns the configured backend kind', () {
      expect(FakeBtBackend().kind, BtBackendKind.libtorrent);
      expect(
        FakeBtBackend(kind: BtBackendKind.rqbit).kind,
        BtBackendKind.rqbit,
      );
    });

    test(
      'the BtBackend interface method shape is fixed by an anonymous impl',
      () {
        // Static contract check mirroring m3u8_playlist_port_test.dart's
        // `_ContractPort`: an anonymous impl with the exact method signatures
        // compiles, proving the contract shape is stable.
        final BtBackend backend = _ContractBackend();
        expect(backend, isA<BtBackend>());
      },
    );
  });

  group('FakeBtBackend callLog ordering (end-to-end)', () {
    test('init → add → pause → resume → remove records in order', () async {
      final backend = FakeBtBackend();
      await backend.ensureInitialized();
      await backend.addTorrent(_kTestMagnet, fallbackInfoHash: 'fallback');
      await backend.pauseTorrent(_kTestInfoHash);
      await backend.resumeTorrent(_kTestInfoHash);
      await backend.removeTorrent(_kTestInfoHash);
      expect(backend.callLog, [
        'ensureInitialized',
        'addTorrent:$_kTestMagnet',
        'pauseTorrent:$_kTestInfoHash',
        'resumeTorrent:$_kTestInfoHash',
        'removeTorrent:$_kTestInfoHash:false',
      ]);
    });
  });
}

/// Anonymous impl proving the `BtBackend` contract shape (see the contract
/// test). Every method has the exact signature the interface declares so the
/// analyzer proves the contract is stable; the body is irrelevant.
class _ContractBackend implements BtBackend {
  @override
  BtBackendKind get kind => BtBackendKind.libtorrent;

  @override
  Future<void> applySpeedLimits({
    int downloadLimitBytesPerSecond = 0,
    int uploadLimitBytesPerSecond = 0,
  }) async {}

  @override
  Future<BtTorrentHandle> addTorrent(
    String magnet, {
    required String fallbackInfoHash,
    String? downloadDir,
    bool startStream = false,
    bool seedMode = false,
    String? resumePath,
  }) async => const BtTorrentHandle(infoHash: '');

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<bool> isTorrentManaged(String infoHash) async => false;

  @override
  Future<bool> pauseTorrent(String infoHash) async => false;

  @override
  Future<bool> removeTorrent(
    String infoHash, {
    bool deleteFiles = false,
    String? resumePath,
  }) async => false;

  @override
  Future<bool> resumeTorrent(String infoHash) async => false;

  @override
  Future<bool> saveResumeData(String infoHash, String resumePath) async =>
      false;

  @override
  Future<void> setFilePriorities(String infoHash, List<int> priorities) async {}

  @override
  Future<List<BtTorrentStats>> getStats() async => const [];
}
