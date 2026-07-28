// Two-way collection reconciliation: field-level merges, conflict surfacing,
// and offline behavior (local applies immediately, the queue catches up).

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/bangumi_collection_merge.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/services/bangumi_sync_queue.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';
import 'package:mikan_player/services/favorites_manager.dart';

import '../support/drift_in_memory.dart';
import '../support/fake_bangumi_collections_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const account = 42;

  late AppDatabase db;
  late FavoritesManager favorites;
  late FakeBangumiCollectionsBackend backend;
  late DateTime now;

  /// Moves the test clock forward so tasks parked by retry backoff become
  /// eligible again. Without this a post-failure drain is a no-op and a test
  /// asserting on the retry would be testing nothing.
  void advance(Duration by) => now = now.add(by);

  BangumiCollectionSyncService buildService() {
    final repository = BangumiCollectionsRepository(
      backend: backend,
      ensureAuthenticated: () async => true,
      apiHostResolver: () async => 'api.bgm.tv',
    );
    final queue = BangumiSyncQueue(database: db, repository: repository)
      ..clock = () => now;
    return BangumiCollectionSyncService(
      favoritesManager: favorites,
      repository: repository,
      queue: queue,
      accountId: account,
    );
  }

  setUp(() {
    now = DateTime.utc(2026, 7, 28, 12);
    db = AppDatabase.forTesting(driftInMemoryExecutor());
    favorites = FavoritesManager()..debugBindForTest(db);
    backend = FakeBangumiCollectionsBackend();
  });

  tearDown(() async {
    favorites.debugResetForTest();
    await db.close();
  });

  group('one-sided entries', () {
    test('a local-only entry uploads status and metadata in one request', () async {
      await favorites.addFavorite(
        bangumiId: 1,
        title: 'Local only',
        coverUrl: '',
        score: 7,
        type: 3,
      );
      await favorites.setLocalMetadata(
        bangumiId: 1,
        rate: 9,
        comment: 'great',
        tags: const ['sci-fi'],
        private: true,
      );

      final result = await buildService().synchronize('alice');

      expect(result.uploadedCount, 1);
      expect(backend.statusUpdates, isEmpty);
      final upsert = backend.upserts.single;
      expect(upsert.subjectId, 1);
      expect(upsert.type, 3);
      expect(upsert.rate, 9);
      expect(upsert.comment, 'great');
      expect(upsert.tags, ['sci-fi']);
      expect(upsert.private, isTrue);
      expect(result.pendingCount, 0);
    });

    test('a remote-only entry is written locally with its metadata', () async {
      backend.entries.add(
        fakeCollectionEntry(
          3,
          4,
          title: 'Cloud only',
          rate: 6,
          comment: 'ok',
          tags: const ['drama'],
        ),
      );

      final result = await buildService().synchronize('alice');

      expect(result.downloadedCount, 1);
      final stored = await favorites.getFavorite(3);
      expect(stored!.type, 4);
      expect(stored.rate, 6);
      expect(stored.comment, 'ok');
      expect(stored.tags, ['drama']);
      // Downloading records a baseline, so the next run can tell a later edit
      // apart from this state.
      expect(stored.hasBaselineFor(account), isTrue);
      expect(stored.updatedAt, isNull);
    });

    test('an entry synced before and now missing remotely is a conflict', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 5,
        title: 'Was synced',
        coverUrl: '',
        score: 7,
        type: 2,
        accountId: account,
        rate: 5,
      );

      final result = await buildService().synchronize('alice');

      final conflict = result.conflicts.single;
      expect(conflict.subjectId, 5);
      expect(conflict.isRemoteDeleted, isTrue);
      expect(conflict.bangumi, isNull);
      // Nothing is uploaded or deleted until the user decides.
      expect(backend.upserts, isEmpty);
      expect(backend.deletes, isEmpty);
      expect(await favorites.isFavorite(5), isTrue);
    });
  });

  group('field-level merge', () {
    test('a remote-only edit lands locally without uploading', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
        rate: 5,
        comment: 'base',
      );
      backend.entries.add(fakeCollectionEntry(1, 3, rate: 8, comment: 'base'));

      final result = await buildService().synchronize('alice');

      expect(result.conflicts, isEmpty);
      expect(backend.statusUpdates, isEmpty);
      expect(backend.metadataPatches, isEmpty);
      final stored = await favorites.getFavorite(1);
      expect(stored!.rate, 8);
      expect(stored.comment, 'base');
      expect(stored.baseRate, 8);
    });

    test('a local-only edit uploads without a status change', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
        rate: 5,
        comment: 'base',
      );
      await favorites.setLocalMetadata(
        bangumiId: 1,
        rate: 5,
        comment: 'my new take',
        tags: null,
        private: null,
      );
      backend.entries.add(fakeCollectionEntry(1, 3, rate: 5, comment: 'base'));

      final result = await buildService().synchronize('alice');

      expect(result.conflicts, isEmpty);
      final patch = backend.metadataPatches.single;
      expect(patch.subjectId, 1);
      expect(patch.comment, 'my new take');
      // Only the field the user actually changed is sent. The rating already
      // matches on both sides, and "leave tags alone" must stay null — `[]`
      // would delete every tag the user has.
      expect(patch.rate, isNull);
      expect(patch.tags, isNull);
    });

    test('edits to different fields merge with no conflict', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
        rate: 5,
        comment: 'base',
        tags: const ['a'],
        private: false,
      );
      // Local changed the comment only.
      await favorites.setLocalMetadata(
        bangumiId: 1,
        rate: 5,
        comment: 'local comment',
        tags: const ['a'],
        private: false,
      );
      // Remote changed the rating only.
      backend.entries.add(
        fakeCollectionEntry(
          1,
          3,
          rate: 10,
          comment: 'base',
          tags: const ['a'],
        ),
      );

      final result = await buildService().synchronize('alice');

      expect(result.conflicts, isEmpty);
      final stored = await favorites.getFavorite(1);
      expect(stored!.rate, 10, reason: 'remote edit applied locally');
      expect(stored.comment, 'local comment', reason: 'local edit kept');
      // Only the locally-changed field is uploaded. The rating resolved to the
      // remote side, so Bangumi already holds 10 and re-sending it would be
      // pointless write traffic.
      final patch = backend.metadataPatches.single;
      expect(patch.comment, 'local comment');
      expect(patch.rate, isNull);
    });

    test('the same field changed on both sides is a conflict', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
        rate: 5,
      );
      await favorites.setLocalMetadata(bangumiId: 1, rate: 9);
      backend.entries.add(fakeCollectionEntry(1, 3, rate: 2));

      final result = await buildService().synchronize('alice');

      final conflict = result.conflicts.single;
      expect(conflict.fields.map((f) => f.field), [
        BangumiCollectionField.rate,
      ]);
      expect(conflict.fields.single.localValue, 9);
      expect(conflict.fields.single.remoteValue, 2);
      // Nothing is written on either side while the decision is outstanding.
      expect(backend.metadataPatches, isEmpty);
      expect((await favorites.getFavorite(1))!.rate, 9);
    });

    test('identical values on both sides need no write at all', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
        rate: 5,
        comment: 'same',
      );
      backend.entries.add(fakeCollectionEntry(1, 3, rate: 5, comment: 'same'));

      final result = await buildService().synchronize('alice');

      expect(result.conflicts, isEmpty);
      expect(result.uploadedCount, 0);
      expect(result.downloadedCount, 0);
      expect(backend.statusUpdates, isEmpty);
      expect(backend.metadataPatches, isEmpty);
      expect(backend.upserts, isEmpty);
    });

    test('a status difference merges like any other field', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
      );
      backend.entries.add(fakeCollectionEntry(1, 2));

      final result = await buildService().synchronize('alice');

      expect(result.conflicts, isEmpty);
      expect(await favorites.getFavoriteType(1), 2);
    });

    test('the subject public score never becomes the user rating', () async {
      backend.entries.add(
        fakeCollectionEntry(1, 3, rate: 0, subjectScore: 9.1),
      );

      await buildService().synchronize('alice');

      final stored = await favorites.getFavorite(1);
      expect(stored!.score, 9.1);
      expect(stored.rate, 0);
    });
  });

  group('conflict resolution', () {
    Future<(BangumiCollectionSyncService, BangumiCollectionSyncResult)>
    seedRateConflict() async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
        rate: 5,
        comment: 'base',
      );
      await favorites.setLocalMetadata(
        bangumiId: 1,
        rate: 9,
        comment: 'base',
      );
      backend.entries.add(fakeCollectionEntry(1, 3, rate: 2, comment: 'base'));
      final service = buildService();
      return (service, await service.synchronize('alice'));
    }

    test('choosing local uploads the local value', () async {
      final (service, result) = await seedRateConflict();

      await service.resolveFieldConflicts(result.conflicts, {
        1: const BangumiCollectionResolution(
          fields: {BangumiCollectionField.rate: MergeSide.local},
        ),
      });

      expect(backend.metadataPatches.single.rate, 9);
      expect((await favorites.getFavorite(1))!.rate, 9);
    });

    test('choosing Bangumi writes locally and uploads nothing', () async {
      final (service, result) = await seedRateConflict();

      await service.resolveFieldConflicts(result.conflicts, {
        1: const BangumiCollectionResolution(
          fields: {BangumiCollectionField.rate: MergeSide.remote},
        ),
      });

      expect(backend.metadataPatches, isEmpty);
      final stored = await favorites.getFavorite(1);
      expect(stored!.rate, 2);
      // Local and remote now agree, so this is a fresh baseline.
      expect(stored.baseRate, 2);
      expect(stored.updatedAt, isNull);
    });

    test('an unresolved subject is left completely untouched', () async {
      final (service, result) = await seedRateConflict();

      await service.resolveFieldConflicts(result.conflicts, const {});

      expect(backend.metadataPatches, isEmpty);
      expect((await favorites.getFavorite(1))!.rate, 9);
    });

    test('the whole-entry API resolves every conflicting field', () async {
      final (service, result) = await seedRateConflict();

      await service.resolveConflicts(result.conflicts, {
        1: BangumiCollectionConflictChoice.bangumi,
      });

      expect((await favorites.getFavorite(1))!.rate, 2);
    });

    test('a remote deletion can be accepted', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 5,
        title: 'Gone',
        coverUrl: '',
        score: 7,
        type: 2,
        accountId: account,
      );
      final service = buildService();
      final result = await service.synchronize('alice');

      await service.resolveFieldConflicts(result.conflicts, {
        5: const BangumiCollectionResolution(remoteDeleted: MergeSide.remote),
      });

      expect(await favorites.isFavorite(5), isFalse);
      expect(backend.upserts, isEmpty);
    });

    test('a remote deletion can be re-uploaded instead', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 5,
        title: 'Gone',
        coverUrl: '',
        score: 7,
        type: 2,
        accountId: account,
        rate: 7,
      );
      final service = buildService();
      final result = await service.synchronize('alice');

      await service.resolveFieldConflicts(result.conflicts, {
        5: const BangumiCollectionResolution(remoteDeleted: MergeSide.local),
      });

      expect(await favorites.isFavorite(5), isTrue);
      final upsert = backend.upserts.single;
      expect(upsert.subjectId, 5);
      expect(upsert.type, 2);
      expect(upsert.rate, 7);
    });
  });

  group('offline behavior', () {
    test('an unreachable Bangumi keeps the edit locally and queues it', () async {
      await favorites.addFavorite(
        bangumiId: 1,
        title: 'Local',
        coverUrl: '',
        score: 7,
        type: 3,
      );
      backend.failWith = (operation, _) =>
          operation == FakeBackendOperation.upsert
          ? Exception('offline')
          : null;

      final service = buildService();
      final result = await service.synchronize('alice');

      expect(result.pendingCount, 1);
      expect(await favorites.isFavorite(1), isTrue);
      final queued = await service.queue.pendingTasks(account);
      expect(queued.single.operation, BangumiSyncOperation.upsert);

      // Once the network recovers the queued work goes out unchanged. The
      // failed attempt set a backoff, so move past it rather than asserting the
      // queue ignores its own retry schedule.
      backend.failWith = null;
      advance(const Duration(minutes: 1));
      final drain = await service.queue.drain(accountId: account);
      expect(drain.sentCount, 1);
      expect(backend.upserts.single.subjectId, 1);
    });

    test('deleting works offline and supersedes pending writes', () async {
      await favorites.addFavorite(
        bangumiId: 1,
        title: 'Local',
        coverUrl: '',
        score: 7,
        type: 3,
      );
      // Only writes fail: reading the remote collection still works, which is
      // what "Bangumi rejects our writes" looks like in practice.
      backend.failWith = (operation, _) =>
          operation == FakeBackendOperation.fetchMyPage
          ? null
          : Exception('offline');

      final service = buildService();
      await service.synchronize('alice');
      await service.deleteFavorite(1);

      expect(await favorites.isFavorite(1), isFalse);
      final queued = await service.queue.pendingTasks(account);
      expect(queued.single.operation, BangumiSyncOperation.delete);

      backend.failWith = null;
      advance(const Duration(minutes: 1));
      await service.queue.drain(accountId: account);
      expect(backend.deletes, [1]);
    });

    test('a pending local edit is sent before remote state is read', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: account,
        rate: 5,
      );
      await favorites.setLocalMetadata(bangumiId: 1, rate: 9);
      backend.entries.add(fakeCollectionEntry(1, 3, rate: 5));

      // First sync cannot reach Bangumi, so the edit stays queued.
      backend.failWith = (operation, _) =>
          operation == FakeBackendOperation.patchMetadata
          ? Exception('offline')
          : null;
      final service = buildService();
      await service.synchronize('alice');
      expect(await service.queue.pendingCount(account), greaterThan(0));

      // Second sync drains first, so the queued rating reaches Bangumi instead
      // of being overwritten by the stale remote value.
      backend.failWith = null;
      await service.synchronize('alice');

      expect(backend.metadataPatches.map((p) => p.rate), contains(9));
      expect((await favorites.getFavorite(1))!.rate, 9);
    });
  });

  group('account isolation', () {
    test('a baseline from another account is not treated as local edits', () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
        accountId: 999, // a different Bangumi account
        rate: 5,
      );
      backend.entries.add(fakeCollectionEntry(1, 3, rate: 8));

      final result = await buildService().synchronize('alice');

      // With the stale baseline discarded, the remote value wins rather than
      // account 999's data being uploaded into this account.
      expect(result.conflicts, isEmpty);
      expect(backend.metadataPatches, isEmpty);
      final stored = await favorites.getFavorite(1);
      expect(stored!.rate, 8);
      expect(stored.ownerAccountId, account);
    });

    test('queued work for another account is discarded', () async {
      final service = buildService();
      await service.queue.enqueueStatus(
        accountId: 999,
        subjectId: 77,
        type: 3,
      );

      await service.synchronize('alice');

      expect(await service.queue.pendingCount(999), 0);
      expect(backend.statusUpdates, isEmpty);
    });
  });

  test('unknown collection types from Bangumi are ignored', () async {
    backend.entries.add(fakeCollectionEntry(1, 9));

    final result = await buildService().synchronize('alice');

    expect(result.downloadedCount, 0);
    expect(await favorites.isFavorite(1), isFalse);
  });
}
