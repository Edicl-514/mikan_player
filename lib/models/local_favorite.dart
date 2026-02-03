import 'package:isar/isar.dart';

part 'local_favorite.g.dart';

@collection
class LocalFavorite {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int bangumiId;

  late String title;
  late String coverUrl;

  // 1: Want, 2: Watched, 3: Watching, 4: Hold, 5: Dropped
  late int type;

  late double score;

  late int createdAt;

  /// Helper to create a new favorite
  static LocalFavorite create({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    int type = 1,
  }) {
    return LocalFavorite()
      ..bangumiId = bangumiId
      ..title = title
      ..coverUrl = coverUrl
      ..score = score
      ..type = type
      ..createdAt = DateTime.now().millisecondsSinceEpoch;
  }
}
