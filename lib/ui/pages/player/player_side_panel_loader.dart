import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';

/// Phase 1.1 player-page responsibility split: comments / recommendations /
/// onair-sites side-panel state.
///
/// Mirrors [PlayerSourceController] / [PlayerEpisodeController]: pure Dart
/// mutators + read-only views, no `BuildContext`, no `setState`, no Flutter
/// widgets. Async fetch bodies (`fetchBangumiEpisodeComments`,
/// `fetchBangumiRelations`, `fetchBangumiBrowser`,
/// `BangumiDataService.getSites*`) stay on the page and feed results here
/// through the mutator surface; pure tag extraction / sort / relation
/// prioritization live here so they can be unit-tested without network.
///
/// **Sort mode:** `'default'` sorts by comment `id` ascending (historic
/// bangumi site order); anything else (currently `'time'`) sorts by `time`
/// descending. [setCommentSortMode] re-sorts in place when the mode changes.
///
/// **Recommendations:** [appendRelationRecommendations] prioritizes
/// 前传/续集 before other relations and skips ids already in [addedIds].
/// [appendTagRecommendations] enforces the per-tag cap and de-dupes via the
/// same id set. Callers own the async tag resolution and browser fetches.
///
/// List views return a fresh [UnmodifiableListView] per call so a later
/// mutator that replaces the backing list cannot leak a stale view.
class PlayerSidePanelLoader {
  PlayerSidePanelLoader();

  List<BangumiEpisodeComment> _comments = <BangumiEpisodeComment>[];
  bool _isLoadingComments = false;
  String? _commentsError;
  String _commentSortMode = 'default'; // 'default' or 'time'

  List<RankingAnime> _recommendations = <RankingAnime>[];
  bool _isLoadingRecommendations = false;

  List<BangumiDataSiteEntry> _onairSites = <BangumiDataSiteEntry>[];

  // ── Read-only views ──────────────────────────────────────────────────────

  List<BangumiEpisodeComment> get comments =>
      UnmodifiableListView<BangumiEpisodeComment>(_comments);

  bool get isLoadingComments => _isLoadingComments;

  String? get commentsError => _commentsError;

  String get commentSortMode => _commentSortMode;

  List<RankingAnime> get recommendations =>
      UnmodifiableListView<RankingAnime>(_recommendations);

  bool get isLoadingRecommendations => _isLoadingRecommendations;

  List<BangumiDataSiteEntry> get onairSites =>
      UnmodifiableListView<BangumiDataSiteEntry>(_onairSites);

  // ── Comments ─────────────────────────────────────────────────────────────

  /// Start a comments load: clears error and marks loading.
  void beginCommentsLoad() {
    _isLoadingComments = true;
    _commentsError = null;
  }

  /// Replace comments, apply the current sort mode, clear loading/error.
  void setComments(List<BangumiEpisodeComment> comments) {
    _comments = List<BangumiEpisodeComment>.from(comments);
    sortComments();
    _isLoadingComments = false;
    _commentsError = null;
  }

  /// Record a comments load failure and clear loading.
  void setCommentsError(String error) {
    _commentsError = error;
    _isLoadingComments = false;
  }

  /// Reset comments when switching episode (page `_onEpisodeSelected`).
  void resetComments() {
    _comments = <BangumiEpisodeComment>[];
    _isLoadingComments = false;
    _commentsError = null;
  }

  /// Change sort mode and re-sort when it actually differs.
  ///
  /// Returns `true` when the mode changed (caller may `setState`).
  bool setCommentSortMode(String mode) {
    if (_commentSortMode == mode) return false;
    _commentSortMode = mode;
    sortComments();
    return true;
  }

  /// Sort [_comments] in place by the current [commentSortMode].
  void sortComments() {
    sortCommentsList(_comments, mode: _commentSortMode);
  }

  // ── Recommendations ──────────────────────────────────────────────────────

  void beginRecommendationsLoad() {
    _isLoadingRecommendations = true;
  }

  void setRecommendations(List<RankingAnime> items) {
    _recommendations = List<RankingAnime>.from(items);
    _isLoadingRecommendations = false;
  }

  void markRecommendationsLoadFailed() {
    _isLoadingRecommendations = false;
  }

  // ── Onair sites ──────────────────────────────────────────────────────────

  void setOnairSites(List<BangumiDataSiteEntry> sites) {
    _onairSites = List<BangumiDataSiteEntry>.from(sites);
  }

  void clearOnairSites() {
    _onairSites = <BangumiDataSiteEntry>[];
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  void clearForDispose() {
    _comments = <BangumiEpisodeComment>[];
    _isLoadingComments = false;
    _commentsError = null;
    _commentSortMode = 'default';
    _recommendations = <RankingAnime>[];
    _isLoadingRecommendations = false;
    _onairSites = <BangumiDataSiteEntry>[];
  }

  /// Structural invariants for unit tests. Returns empty when consistent.
  List<String> validateInvariants() {
    final errors = <String>[];
    if (_isLoadingComments && _commentsError != null) {
      // beginCommentsLoad clears error, so this should never hold mid-flight.
      errors.add('loading comments with non-null error');
    }
    return errors;
  }
}

// ── Pure helpers (no state) ────────────────────────────────────────────────

/// Sort [comments] in place. `'default'` → id asc; otherwise time desc.
@visibleForTesting
void sortCommentsList(
  List<BangumiEpisodeComment> comments, {
  required String mode,
}) {
  if (mode == 'default') {
    comments.sort((a, b) => a.id.compareTo(b.id));
  } else {
    comments.sort((a, b) => b.time.compareTo(a.time));
  }
}

/// Extract recommendation tags from a Bangumi subject `fullJson` blob.
///
/// Prefer `meta_tags` then detail `tags` (map `name` or string); de-dupe
/// case-insensitively while preserving first-seen casing. Returns an empty
/// list on null/empty/parse failure.
List<String> extractRecommendationTagsFromBangumiJson(String? fullJson) {
  if (fullJson == null || fullJson.isEmpty) return const [];

  try {
    final data = jsonDecode(fullJson);
    if (data is! Map) return const [];

    final tags = <String>[];

    final metaTags = data['meta_tags'];
    if (metaTags is List) {
      for (final item in metaTags) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          tags.add(value);
        }
      }
    }

    final detailTags = data['tags'];
    if (detailTags is List) {
      for (final item in detailTags) {
        if (item is Map) {
          final value = item['name']?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            tags.add(value);
          }
        } else {
          final value = item?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            tags.add(value);
          }
        }
      }
    }

    final unique = <String>[];
    final seen = <String>{};
    for (final tag in tags) {
      final key = tag.toLowerCase();
      if (seen.add(key)) {
        unique.add(tag);
      }
    }
    return unique;
  } catch (_) {
    return const [];
  }
}

/// Historic per-tag browser limit: more tags → fewer items each (2..5).
int recommendationLimitPerTag(int tagCount) {
  if (tagCount <= 0) return 0;
  var limitPerTag = (12 / tagCount).ceil();
  if (limitPerTag < 2) limitPerTag = 2;
  if (limitPerTag > 5) limitPerTag = 5;
  return limitPerTag;
}

/// Append relation subjects into [results], prioritizing 前传/续集.
///
/// Mutates [results] and [addedIds]. Skips ids already in [addedIds].
void appendRelationRecommendations({
  required List<BangumiRelatedSubject> relations,
  required List<RankingAnime> results,
  required Set<String> addedIds,
}) {
  final pres = relations
      .where((r) => r.relation == '前传' || r.relation == '续集')
      .toList();
  final others = relations
      .where((r) => r.relation != '前传' && r.relation != '续集')
      .toList();

  for (final r in [...pres, ...others]) {
    final bid = r.id.toString();
    if (addedIds.contains(bid)) continue;

    results.add(
      RankingAnime(
        title: r.nameCn.isNotEmpty ? r.nameCn : r.name,
        bangumiId: bid,
        coverUrl: r.image,
        info: r.relation,
        rank: null,
        score: null,
        originalTitle: null,
      ),
    );
    addedIds.add(bid);
  }
}

/// Append browser/tag search hits into [results] with a per-group cap.
///
/// Mutates [results] and [addedIds].
void appendTagRecommendations({
  required List<List<RankingAnime>> tagGroups,
  required int limitPerTag,
  required List<RankingAnime> results,
  required Set<String> addedIds,
}) {
  for (final group in tagGroups) {
    var count = 0;
    for (final item in group) {
      if (count >= limitPerTag) break;
      if (!addedIds.contains(item.bangumiId)) {
        results.add(item);
        addedIds.add(item.bangumiId);
        count++;
      }
    }
  }
}

/// Keep only sites whose [BangumiDataSiteEntry.kind] is `'onair'`.
List<BangumiDataSiteEntry> filterOnairSites(
  List<BangumiDataSiteEntry> sites,
) {
  return sites.where((s) => s.kind == 'onair').toList();
}
