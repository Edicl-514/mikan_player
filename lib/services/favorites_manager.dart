import 'package:isar/isar.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:path_provider/path_provider.dart';

class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  Isar? _isar;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    final dir = await getApplicationSupportDirectory();
    // Use a separate database file for favorites to avoid accidental clearing
    _isar = await Isar.open(
      [LocalFavoriteSchema],
      directory: dir.path,
      name: 'favorites_db',
    );
    _isInitialized = true;
  }

  Future<void> addFavorite({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    int type = 1, // Default to "Want to Watch" or generic
  }) async {
    if (_isar == null) await init();

    final favorite = LocalFavorite()
      ..bangumiId = bangumiId
      ..title = title
      ..coverUrl = coverUrl
      ..score = score
      ..type = type
      ..createdAt = DateTime.now().millisecondsSinceEpoch;

    await _isar!.writeTxn(() async {
      await _isar!.localFavorites.put(favorite);
    });
  }

  Future<void> removeFavorite(int bangumiId) async {
    if (_isar == null) await init();

    await _isar!.writeTxn(() async {
      await _isar!.localFavorites
          .filter()
          .bangumiIdEqualTo(bangumiId)
          .deleteAll();
    });
  }

  Future<bool> isFavorite(int bangumiId) async {
    if (_isar == null) await init();
    final count = await _isar!.localFavorites
        .filter()
        .bangumiIdEqualTo(bangumiId)
        .count();
    return count > 0;
  }

  Future<List<LocalFavorite>> getAllFavorites() async {
    if (_isar == null) await init();
    return await _isar!.localFavorites.where().sortByCreatedAtDesc().findAll();
  }
}
