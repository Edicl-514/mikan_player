// DT-2B: FavoritesManager CRUD against an in-memory Drift database.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';
import 'package:mikan_player/services/favorites_manager.dart';

import '../support/drift_in_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FavoritesManager manager;

  setUp(() async {
    db = AppDatabase.forTesting(driftInMemoryExecutor());
    manager = FavoritesManager()..debugBindForTest(db);
  });

  tearDown(() async {
    manager.debugResetForTest();
    await db.close();
  });

  group('lifecycle', () {
    test('db getter throws before init / bind', () {
      final unbound = FavoritesManager()..debugResetForTest();
      expect(() => unbound.db, throwsStateError);
      // Restore bind so tearDown can still reset cleanly.
      unbound.debugBindForTest(db);
    });

    test('init is idempotent once bound via production path', () async {
      // After debugBindForTest the manager is already initialized; calling
      // init() again must not swap the bound in-memory db for the file
      // singleton.
      await manager.init();
      expect(identical(manager.db, db), isTrue);
    });
  });

  group('add / query / remove', () {
    test('addFavorite inserts and isFavorite becomes true', () async {
      await manager.addFavorite(
        bangumiId: 42,
        title: 'Test Show',
        coverUrl: 'https://example.com/cover.jpg',
        score: 8.5,
        type: 3,
      );

      expect(await manager.isFavorite(42), isTrue);
      expect(await manager.isFavorite(99), isFalse);
      expect(await manager.getFavoriteType(42), 3);
      expect(await manager.getFavoriteType(99), isNull);

      final all = await manager.getAllFavorites();
      expect(all, hasLength(1));
      expect(all.single.bangumiId, 42);
      expect(all.single.title, 'Test Show');
      expect(all.single.coverUrl, 'https://example.com/cover.jpg');
      expect(all.single.score, 8.5);
      expect(all.single.type, 3);
      expect(all.single.createdAt, greaterThan(0));
      expect(all.single.id, greaterThan(0));
    });

    test('addFavorite with same bangumiId replaces previous row', () async {
      await manager.addFavorite(
        bangumiId: 1,
        title: 'Old',
        coverUrl: 'a',
        score: 1,
        type: 1,
      );
      await manager.addFavorite(
        bangumiId: 1,
        title: 'New',
        coverUrl: 'b',
        score: 9,
        type: 2,
      );

      final all = await manager.getAllFavorites();
      expect(all, hasLength(1));
      expect(all.single.title, 'New');
      expect(all.single.score, 9);
      expect(all.single.type, 2);
      expect(await manager.getFavoriteType(1), 2);
      expect(await manager.isFavorite(1), isTrue);
    });

    test('removeFavorite deletes only the matching bangumiId', () async {
      await manager.addFavorite(
        bangumiId: 1,
        title: 'A',
        coverUrl: '',
        score: 0,
      );
      await manager.addFavorite(
        bangumiId: 2,
        title: 'B',
        coverUrl: '',
        score: 0,
      );

      await manager.removeFavorite(1);

      expect(await manager.isFavorite(1), isFalse);
      expect(await manager.isFavorite(2), isTrue);
      expect(await manager.getAllFavorites(), hasLength(1));
    });

    test('removeFavorite is a no-op for missing ids', () async {
      await manager.removeFavorite(999);
      expect(await manager.getAllFavorites(), isEmpty);
    });

    test('getAllFavorites orders by createdAt descending', () async {
      await manager.addFavorite(
        bangumiId: 1,
        title: 'first',
        coverUrl: '',
        score: 0,
      );
      // Ensure a measurable gap so ordering is deterministic.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await manager.addFavorite(
        bangumiId: 2,
        title: 'second',
        coverUrl: '',
        score: 0,
      );

      final all = await manager.getAllFavorites();
      expect(all.map((f) => f.bangumiId).toList(), <int>[2, 1]);
    });

    test('accepts unicode titles and cover URLs', () async {
      await manager.addFavorite(
        bangumiId: 7,
        title: '🎌 日本語 — 中文 ✨',
        coverUrl: 'https://example.com/封面.jpg',
        score: 7.5,
      );
      final all = await manager.getAllFavorites();
      expect(all.single.title, '🎌 日本語 — 中文 ✨');
      expect(all.single.coverUrl, 'https://example.com/封面.jpg');
    });
  });

  group('collection metadata and sync baseline', () {
    test('addFavorite keeps existing metadata and baseline intact', () async {
      await manager.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'Show',
        coverUrl: 'cover',
        score: 8,
        type: 3,
        accountId: 77,
        rate: 9,
        comment: 'great',
        tags: const ['sci-fi'],
        private: true,
        remoteUpdatedAt: '2026-07-27T00:00:00Z',
      );

      // A status-only change must not wipe rate/comment/tags/private, which is
      // what the previous insertOrReplace did.
      await manager.addFavorite(
        bangumiId: 1,
        title: 'Show',
        coverUrl: 'cover',
        score: 8,
        type: 2,
      );

      final favorite = (await manager.getFavorite(1))!;
      expect(favorite.type, 2);
      expect(favorite.rate, 9);
      expect(favorite.comment, 'great');
      expect(favorite.tags, ['sci-fi']);
      expect(favorite.private, isTrue);
      // Baseline still describes the server state, so the merge can see that
      // only the local status moved away from it.
      expect(favorite.baseType, 3);
      expect(favorite.baseRate, 9);
      expect(favorite.updatedAt, isNotNull);
    });

    test('applyRemoteSnapshot clears the local-edit marker', () async {
      await manager.addFavorite(
        bangumiId: 5,
        title: 'A',
        coverUrl: '',
        score: 0,
      );
      expect((await manager.getFavorite(5))!.updatedAt, isNotNull);

      await manager.applyRemoteSnapshot(
        bangumiId: 5,
        title: 'A',
        coverUrl: '',
        score: 0,
        type: 4,
        accountId: 1,
        rate: 0,
        comment: '',
        tags: const [],
      );

      final favorite = (await manager.getFavorite(5))!;
      expect(favorite.updatedAt, isNull);
      expect(favorite.type, 4);
      // Empty is a real value, distinct from "unknown".
      expect(favorite.comment, '');
      expect(favorite.tags, isEmpty);
      expect(favorite.baseTags, isEmpty);
      expect(favorite.hasBaselineFor(1), isTrue);
      expect(favorite.hasBaselineFor(2), isFalse);
    });

    test('setLocalMetadata stamps updatedAt and leaves baseline alone', () async {
      await manager.applyRemoteSnapshot(
        bangumiId: 3,
        title: 'B',
        coverUrl: '',
        score: 0,
        type: 3,
        accountId: 9,
        rate: 5,
        comment: 'old',
        tags: const ['a'],
        private: false,
      );

      await manager.setLocalMetadata(
        bangumiId: 3,
        rate: 8,
        comment: 'new',
        tags: const [],
        private: true,
      );

      final favorite = (await manager.getFavorite(3))!;
      expect(favorite.rate, 8);
      expect(favorite.comment, 'new');
      expect(favorite.tags, isEmpty);
      expect(favorite.private, isTrue);
      expect(favorite.updatedAt, isNotNull);
      expect(favorite.baseRate, 5);
      expect(favorite.baseComment, 'old');
      expect(favorite.baseTags, ['a']);
      expect(favorite.basePrivate, isFalse);
    });

    test('confirmBaseline promotes current local values', () async {
      await manager.addFavorite(
        bangumiId: 4,
        title: 'C',
        coverUrl: '',
        score: 0,
        type: 1,
      );
      await manager.setLocalMetadata(bangumiId: 4, rate: 7, comment: 'mine');

      await manager.confirmBaseline(
        bangumiId: 4,
        accountId: 42,
        remoteUpdatedAt: '2026-07-28T00:00:00Z',
      );

      final favorite = (await manager.getFavorite(4))!;
      expect(favorite.updatedAt, isNull);
      expect(favorite.baseType, 1);
      expect(favorite.baseRate, 7);
      expect(favorite.baseComment, 'mine');
      expect(favorite.ownerAccountId, 42);
      expect(favorite.remoteUpdatedAt, '2026-07-28T00:00:00Z');
    });

    test('confirmBaseline is a no-op for a missing subject', () async {
      await manager.confirmBaseline(bangumiId: 404, accountId: 1);
      expect(await manager.getFavorite(404), isNull);
    });

    test('clearBaselinesForOtherAccounts keeps only the active account', () async {
      await manager.applyRemoteSnapshot(
        bangumiId: 1,
        title: 'mine',
        coverUrl: '',
        score: 0,
        type: 3,
        accountId: 1,
        rate: 6,
      );
      await manager.applyRemoteSnapshot(
        bangumiId: 2,
        title: 'theirs',
        coverUrl: '',
        score: 0,
        type: 3,
        accountId: 2,
        rate: 7,
      );

      await manager.clearBaselinesForOtherAccounts(1);

      final kept = (await manager.getFavorite(1))!;
      expect(kept.hasBaselineFor(1), isTrue);
      expect(kept.baseRate, 6);

      final dropped = (await manager.getFavorite(2))!;
      expect(dropped.ownerAccountId, isNull);
      expect(dropped.lastSyncedAt, isNull);
      expect(dropped.baseRate, isNull);
      // The other account's metadata goes too. Keeping it would leave values
      // with no baseline, which the merge would read as this account's own
      // unsynced edits and upload into the wrong collection.
      expect(dropped.rate, isNull);
      expect(dropped.comment, isNull);
      expect(dropped.updatedAt, isNull);
      // The status stays so the entry remains visible locally until the next
      // sync reconciles it.
      expect(dropped.type, 3);
      expect(dropped.title, 'theirs');
    });

    test('tags round-trip distinguishes null from empty', () async {
      await manager.addFavorite(
        bangumiId: 8,
        title: 'D',
        coverUrl: '',
        score: 0,
      );
      expect((await manager.getFavorite(8))!.tags, isNull);

      await manager.setLocalMetadata(bangumiId: 8, tags: const []);
      expect((await manager.getFavorite(8))!.tags, isEmpty);

      await manager.setLocalMetadata(bangumiId: 8, tags: const ['x', 'y']);
      expect((await manager.getFavorite(8))!.tags, ['x', 'y']);
    });

    test('applyMergedValues writes a mixed field-level result', () async {
      await manager.applyRemoteSnapshot(
        bangumiId: 6,
        title: 'E',
        coverUrl: '',
        score: 0,
        type: 3,
        accountId: 5,
        rate: 4,
        comment: 'remote',
        tags: const ['r'],
        private: false,
      );

      await manager.applyMergedValues(
        bangumiId: 6,
        type: 2,
        rate: 4,
        comment: 'local wins',
        tags: const ['r'],
        private: true,
      );

      final favorite = (await manager.getFavorite(6))!;
      expect(favorite.type, 2);
      expect(favorite.comment, 'local wins');
      expect(favorite.private, isTrue);
      // Baseline untouched: the caller confirms it after the upload succeeds.
      expect(favorite.baseComment, 'remote');
      expect(favorite.updatedAt, isNotNull);
    });
  });

  group('concurrency', () {
    test('parallel adds of distinct ids all land', () async {
      await Future.wait(
        List.generate(
          10,
          (i) => manager.addFavorite(
            bangumiId: i + 1,
            title: 'Show $i',
            coverUrl: '',
            score: i.toDouble(),
          ),
        ),
      );
      final all = await manager.getAllFavorites();
      expect(all, hasLength(10));
      expect(all.map((f) => f.bangumiId).toSet(), {
        for (var i = 1; i <= 10; i++) i,
      });
    });
  });
}
