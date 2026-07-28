import 'dart:convert';

abstract final class LocalFavoriteType {
  static const int wish = 1;
  static const int watched = 2;
  static const int watching = 3;
  static const int onHold = 4;
  static const int dropped = 5;

  static const List<int> values = [wish, watched, watching, onHold, dropped];

  static bool isValid(int type) => values.contains(type);
}

/// Encodes a tag list for the `tags_json` / `base_tags_json` columns.
///
/// `null` means "no value known" and stays `null` — it must not collapse to
/// `[]`, which Bangumi treats as "clear every tag".
String? encodeFavoriteTags(List<String>? tags) =>
    tags == null ? null : jsonEncode(tags);

List<String>? decodeFavoriteTags(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded.map((tag) => tag.toString()).toList(growable: false);
  } on FormatException {
    return null;
  }
}

class LocalFavorite {
  int id = 0;

  late int bangumiId;

  late String title;
  late String coverUrl;

  // See [LocalFavoriteType] for the Bangumi-compatible values.
  late int type;

  /// Subject-wide public score. Distinct from [rate], which is the user's own
  /// rating; the two must never be merged into each other.
  late double score;

  late int createdAt;

  // ── User collection metadata ───────────────────────────────────────────────
  // Null means this app has never known a value for the field, which the merge
  // engine treats differently from an explicit empty value.
  int? rate;
  String? comment;
  List<String>? tags;
  bool? private;

  /// Local last-modified time (ms since epoch) of the metadata above.
  int? updatedAt;

  // ── Sync baseline ──────────────────────────────────────────────────────────
  int? baseType;
  int? baseRate;
  String? baseComment;
  List<String>? baseTags;
  bool? basePrivate;

  /// Server ISO timestamp; display / diagnostics only, never a merge input.
  String? remoteUpdatedAt;
  int? lastSyncedAt;

  /// Bangumi account the baseline belongs to.
  int? ownerAccountId;

  /// True when a baseline recorded under [accountId] is available, so
  /// three-way merge can distinguish local edits from remote edits.
  bool hasBaselineFor(int accountId) =>
      lastSyncedAt != null && ownerAccountId == accountId;

  /// Helper to create a new favorite
  static LocalFavorite create({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    int type = LocalFavoriteType.wish,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
    int? updatedAt,
  }) {
    return LocalFavorite()
      ..bangumiId = bangumiId
      ..title = title
      ..coverUrl = coverUrl
      ..score = score
      ..type = type
      ..rate = rate
      ..comment = comment
      ..tags = tags
      ..private = private
      ..updatedAt = updatedAt
      ..createdAt = DateTime.now().millisecondsSinceEpoch;
  }
}
