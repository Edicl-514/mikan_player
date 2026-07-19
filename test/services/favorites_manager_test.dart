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
