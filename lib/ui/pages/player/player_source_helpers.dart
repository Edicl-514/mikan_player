import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/ui/pages/player/widgets/bt_resource.dart';

/// Phase 2 step 1: pure helpers extracted from `_PlayerPageState` for BT
/// resource dedup/sort and recommendation tag normalization.
///
/// All functions are top-level and pure (no `this`, no scheduler state).
/// Algorithm bodies are preserved verbatim from `lib/ui/pages/player_page.dart`.

/// info-hash pattern used to dedupe BT resources by magnet.
final RegExp btihRegex = RegExp(r'urn:btih:([a-fA-F0-9]{40}|[2-7A-Z]{32})');

enum PlayerResourceContent { hidden, bt, sample }

PlayerResourceContent resolvePlayerResourceContent({
  required bool isExpanded,
  required String activeSource,
}) {
  if (!isExpanded) return PlayerResourceContent.hidden;
  if (activeSource == 'sample') return PlayerResourceContent.sample;
  return PlayerResourceContent.bt;
}

String magnetOf(dynamic r) => r is MikanEpisodeResource
    ? r.magnet
    : r is DmhyResource
    ? r.magnet
    : '';

String titleOf(dynamic r) => r is MikanEpisodeResource
    ? r.title
    : r is DmhyResource
    ? r.title
    : '';

String sizeOf(dynamic r) => r is MikanEpisodeResource
    ? r.size
    : r is DmhyResource
    ? r.size
    : '';

String timeOf(dynamic r) => r is MikanEpisodeResource
    ? r.updateTime
    : r is DmhyResource
    ? r.publishDate
    : '';

int? episodeOf(dynamic r) => r is MikanEpisodeResource
    ? r.episode
    : r is DmhyResource
    ? r.episode
    : null;

BtResource toBtResource(dynamic r) => BtResource(
  title: titleOf(r),
  magnet: magnetOf(r),
  size: sizeOf(r),
  time: timeOf(r),
  episode: episodeOf(r),
);

List<BtResource> toBtResourceViewModels(List<dynamic> raw) =>
    raw.map(toBtResource).toList();

List<dynamic> dedupBtResources(List<dynamic> resources) {
  final seenHashes = <String>{};
  final seenFallback = <String>{};
  final result = <dynamic>[];
  for (final r in resources) {
    final magnet = magnetOf(r);
    final hash = magnet.isNotEmpty
        ? (btihRegex.firstMatch(magnet)?.group(1)?.toLowerCase() ?? '')
        : '';
    if (hash.isNotEmpty) {
      if (!seenHashes.add(hash)) continue;
    } else {
      final key = '${titleOf(r)}|${sizeOf(r)}';
      if (!seenFallback.add(key)) continue;
    }
    result.add(r);
  }
  return result;
}

List<dynamic> sortBtResourcesByTitle(List<dynamic> resources) {
  final sorted = List<dynamic>.from(resources);
  sorted.sort((a, b) {
    final ta = titleOf(a).trim();
    final tb = titleOf(b).trim();
    final c = ta.compareTo(tb);
    if (c != 0) return c;
    final sa = sizeOf(a);
    final sb = sizeOf(b);
    return sa.compareTo(sb);
  });
  return sorted;
}

List<String> normalizeRecommendationTags(Iterable<String> rawTags) {
  const invalidTags = {'tv', 'web', 'ova', '日本', '中国', '动画', 'anime'};

  final unique = <String>[];
  final seen = <String>{};
  for (final raw in rawTags) {
    final tag = raw.trim();
    if (tag.isEmpty || tag.length <= 1) continue;
    if (RegExp(r'^\d{4}([-/]\d{1,2})?$').hasMatch(tag)) continue;
    final lower = tag.toLowerCase();
    if (invalidTags.contains(lower) || invalidTags.contains(tag)) continue;
    if (seen.add(lower)) {
      unique.add(tag);
    }
  }
  return unique;
}
