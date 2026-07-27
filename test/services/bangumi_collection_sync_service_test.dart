import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

import '../support/drift_in_memory.dart';

class _FakeBackend implements BangumiCollectionsBackend {
  _FakeBackend(this.entries);

  final List<BangumiUserCollectionEntry> entries;
  final List<(int, int)> updates = [];
  final List<int> deletes = [];

  @override
  Future<List<BangumiUserCollectionEntry>> fetchPublicPage({
    required String username,
    required int limit,
    required int offset,
  }) async => offset == 0 ? entries : const [];

  @override
  Future<List<BangumiUserCollectionEntry>> fetchMyPage({
    required String username,
    required int limit,
    required int offset,
  }) async => offset == 0 ? entries : const [];

  @override
  Future<void> update({required int subjectId, required int type}) async {
    updates.add((subjectId, type));
  }

  @override
  Future<void> delete({required int subjectId}) async {
    deletes.add(subjectId);
  }

  @override
  Future<int?> fetchType({required int subjectId}) async => entries
      .where((entry) => entry.subjectId == subjectId)
      .firstOrNull
      ?.collectionType;
}

BangumiUserCollectionEntry _entry(int id, int type, {String title = 'Cloud'}) =>
    BangumiUserCollectionEntry(
      updatedAt: '2026-07-27T00:00:00Z',
      comment: '',
      tags: const [],
      subjectId: id,
      collectionType: type,
      rate: 0,
      private: false,
      subjectName: title,
      subjectNameCn: '',
      subjectShortSummary: '',
      subjectScore: 8,
      subjectEps: 12,
      subjectCollectionTotal: 10,
      imageSmall: '',
      imageGrid: '',
      imageLarge: 'https://example.com/$id.jpg',
      imageMedium: '',
      imageCommon: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FavoritesManager favorites;

  setUp(() {
    db = AppDatabase.forTesting(driftInMemoryExecutor());
    favorites = FavoritesManager()..debugBindForTest(db);
  });

  tearDown(() async {
    favorites.debugResetForTest();
    await db.close();
  });

  test('merges one-sided entries and reports type conflicts', () async {
    await favorites.addFavorite(
      bangumiId: 1,
      title: 'Local only',
      coverUrl: '',
      score: 7,
      type: 1,
    );
    await favorites.addFavorite(
      bangumiId: 2,
      title: 'Conflict',
      coverUrl: '',
      score: 7,
      type: 2,
    );
    final backend = _FakeBackend([_entry(2, 3), _entry(3, 4)]);
    final repository = BangumiCollectionsRepository(
      backend: backend,
      ensureAuthenticated: () async => true,
      apiHostResolver: () async => 'api.bgm.tv',
    );
    final service = BangumiCollectionSyncService(
      favoritesManager: favorites,
      repository: repository,
    );

    final result = await service.synchronize('alice');

    expect(result.conflicts.single.local.bangumiId, 2);
    expect(result.uploadedCount, 1);
    expect(result.downloadedCount, 1);
    expect(backend.updates, [(1, 1)]);
    expect(
      (await favorites.getAllFavorites()).map((item) => item.bangumiId),
      containsAll(<int>[1, 2, 3]),
    );
    expect(await favorites.getFavoriteType(3), 4);
  });

  test('resolving each side writes only the selected source', () async {
    await favorites.addFavorite(
      bangumiId: 1,
      title: 'Local',
      coverUrl: '',
      score: 7,
      type: 2,
    );
    await favorites.addFavorite(
      bangumiId: 2,
      title: 'Local two',
      coverUrl: '',
      score: 7,
      type: 1,
    );
    final backend = _FakeBackend([_entry(1, 3), _entry(2, 4)]);
    final repository = BangumiCollectionsRepository(
      backend: backend,
      ensureAuthenticated: () async => true,
      apiHostResolver: () async => 'api.bgm.tv',
    );
    final service = BangumiCollectionSyncService(
      favoritesManager: favorites,
      repository: repository,
    );
    final result = await service.synchronize('alice');
    await service.resolveConflicts(result.conflicts, {
      1: BangumiCollectionConflictChoice.local,
      2: BangumiCollectionConflictChoice.bangumi,
    });

    expect(backend.updates, [(1, 2)]);
    expect(await favorites.getFavoriteType(1), 2);
    expect(await favorites.getFavoriteType(2), 4);
  });
}
