abstract final class LocalFavoriteType {
  static const int wish = 1;
  static const int watched = 2;
  static const int watching = 3;
  static const int onHold = 4;
  static const int dropped = 5;

  static const List<int> values = [wish, watched, watching, onHold, dropped];

  static bool isValid(int type) => values.contains(type);
}

class LocalFavorite {
  int id = 0;

  late int bangumiId;

  late String title;
  late String coverUrl;

  // See [LocalFavoriteType] for the Bangumi-compatible values.
  late int type;

  late double score;

  late int createdAt;

  /// Helper to create a new favorite
  static LocalFavorite create({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    int type = LocalFavoriteType.wish,
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
