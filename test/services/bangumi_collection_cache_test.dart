import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_collection_cache.dart';
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
  late BangumiSyncQueue queue;
  late BangumiCollectionCache cache;

  setUp(() {
    db = AppDatabase.forTesting(driftInMemoryExecutor());
    favorites = FavoritesManager()..debugBindForTest(db);
    backend = FakeBangumiCollectionsBackend();
    final repository = BangumiCollectionsRepository(
      backend: backend,
      ensureAuthenticated: () async => true,
      apiHostResolver: () async => 'api.bgm.tv',
    );
    queue = BangumiSyncQueue(database: db, repository: repository);
    cache = BangumiCollectionCache(
      favoritesManager: favorites,
      repository: repository,
      queue: queue,
      canSync: () => true,
      accountId: () => account,
      username: () => 'alice',
      freshness: Duration.zero,
    );
  });

  tearDown(() async {
    cache.refreshed.dispose();
    favorites.debugResetForTest();
    await db.close();
  });

  test('a local edit made during refresh is not overwritten', () async {
    await favorites.applyRemoteSnapshot(
      bangumiId: 1,
      title: 'Show',
      coverUrl: '',
      score: 7,
      type: 1,
      accountId: account,
    );
    backend.entries.add(fakeCollectionEntry(1, 2));
    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();
    backend.beforeCall = (operation, _) async {
      if (operation != FakeBackendOperation.fetchMineOne) return;
      requestStarted.complete();
      await releaseRequest.future;
    };

    final refresh = cache.refreshInBackground(1);
    await requestStarted.future;
    await favorites.addFavorite(
      bangumiId: 1,
      title: 'Show',
      coverUrl: '',
      score: 7,
      type: 3,
    );
    releaseRequest.complete();
    await refresh;

    final stored = (await favorites.getFavorite(1))!;
    expect(stored.type, 3);
    expect(stored.updatedAt, isNotNull);
  });

  test(
    'a successful queued write clears only the local dirty marker',
    () async {
      await favorites.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 1,
        accountId: account,
      );

      await cache.setStatus(
        bangumiId: 1,
        title: 'Show',
        coverUrl: '',
        score: 7,
        type: 3,
      );

      final stored = (await favorites.getFavorite(1))!;
      expect(backend.statusUpdates, [(1, 3)]);
      expect(stored.baseType, 1);
      expect(stored.updatedAt, isNull);
      expect(await queue.pendingCount(account), 0);
    },
  );

  test('a fresh local snapshot avoids a collection request', () async {
    await favorites.applyRemoteSnapshot(
      bangumiId: 1,
      title: 'Show',
      coverUrl: '',
      score: 7,
      type: 1,
      accountId: account,
    );
    cache = BangumiCollectionCache(
      favoritesManager: favorites,
      queue: queue,
      canSync: () => true,
      accountId: () => account,
      username: () => 'alice',
    );

    await cache.refreshInBackground(1);

    expect(backend.fetchedOne, isEmpty);
  });
}
