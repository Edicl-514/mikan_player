import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/services/favorites_manager.dart';

enum BangumiCollectionConflictChoice { local, bangumi }

class BangumiCollectionConflict {
  const BangumiCollectionConflict({required this.local, required this.bangumi});

  final LocalFavorite local;
  final BangumiUserCollection bangumi;
}

class BangumiCollectionSyncResult {
  const BangumiCollectionSyncResult({
    required this.favorites,
    required this.conflicts,
    required this.uploadedCount,
    required this.downloadedCount,
  });

  final List<LocalFavorite> favorites;
  final List<BangumiCollectionConflict> conflicts;
  final int uploadedCount;
  final int downloadedCount;
}

/// Reconciles the app's local collection with the authenticated Bangumi
/// collection. Only status mismatches require user input; one-sided entries
/// are copied to the missing side and equal entries are left untouched.
class BangumiCollectionSyncService {
  BangumiCollectionSyncService({
    FavoritesManager? favoritesManager,
    BangumiCollectionsRepository? repository,
  }) : _favoritesManager = favoritesManager ?? FavoritesManager(),
       _repository = repository ?? BangumiCollectionsRepository();

  final FavoritesManager _favoritesManager;
  final BangumiCollectionsRepository _repository;

  Future<BangumiCollectionSyncResult> synchronize(String username) async {
    await _favoritesManager.init();
    final results = await Future.wait<Object>([
      _favoritesManager.getAllFavorites(),
      _repository.fetchMine(username),
    ]);
    final local = results[0] as List<LocalFavorite>;
    final remote = (results[1] as List<BangumiUserCollection>)
        .where((item) => LocalFavoriteType.isValid(item.type))
        .toList(growable: false);
    final localById = {for (final item in local) item.bangumiId: item};
    final remoteById = {for (final item in remote) item.subjectId: item};
    final conflicts = <BangumiCollectionConflict>[];
    var uploadedCount = 0;
    var downloadedCount = 0;

    for (final item in local) {
      final cloud = remoteById[item.bangumiId];
      if (cloud == null) {
        await _repository.update(subjectId: item.bangumiId, type: item.type);
        uploadedCount++;
      } else if (cloud.type != item.type) {
        conflicts.add(BangumiCollectionConflict(local: item, bangumi: cloud));
      }
    }

    for (final item in remote) {
      if (localById.containsKey(item.subjectId)) continue;
      await _writeRemoteToLocal(item);
      downloadedCount++;
    }

    return BangumiCollectionSyncResult(
      favorites: await _favoritesManager.getAllFavorites(),
      conflicts: conflicts,
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
    );
  }

  Future<List<LocalFavorite>> resolveConflicts(
    List<BangumiCollectionConflict> conflicts,
    Map<int, BangumiCollectionConflictChoice> choices,
  ) async {
    for (final conflict in conflicts) {
      final choice = choices[conflict.local.bangumiId];
      if (choice == null) continue;
      if (choice == BangumiCollectionConflictChoice.local) {
        await _repository.update(
          subjectId: conflict.local.bangumiId,
          type: conflict.local.type,
        );
      } else {
        await _writeRemoteToLocal(conflict.bangumi);
      }
    }
    return _favoritesManager.getAllFavorites();
  }

  Future<void> deleteFavorite(int subjectId) async {
    // Delete remotely first so a network failure cannot leave the merged local
    // view claiming success while Bangumi still owns the collection entry.
    await _repository.delete(subjectId);
    await _favoritesManager.removeFavorite(subjectId);
  }

  Future<void> _writeRemoteToLocal(BangumiUserCollection item) {
    final subject = item.subject;
    return _favoritesManager.addFavorite(
      bangumiId: item.subjectId,
      title: subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
      coverUrl: subject.images.large.isNotEmpty
          ? subject.images.large
          : subject.images.common,
      score: subject.score,
      type: item.type,
    );
  }
}
