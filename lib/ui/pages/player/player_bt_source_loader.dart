import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/bangumi_data_service.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/ui/pages/player/player_source_controller.dart';

/// Phase 1.2 player-page responsibility split: BT / Mikan / DMHY source loading
/// helpers and async loader bodies.
///
/// Pure helpers (alias / search-name / stream hash) live as top-level functions
/// so they can be unit-tested without Flutter. Async loaders take explicit
/// inputs + a small [PlayerBtSourceLoadSink] so they can update
/// [PlayerSourceController] without importing the page State.
///
/// The page keeps: `setState` wrapping, `mounted` checks after await (via
/// [PlayerBtSourceLoadSink.isCurrent*]), BT/HTTP existing-download probe that
/// opens the media player, and UI for the resource list.

// ── Pure helpers ───────────────────────────────────────────────────────────

/// Extract alias strings from a Bangumi subject `fullJson` infobox.
List<String> extractAliasesFromBangumiJson(String? fullJson) {
  if (fullJson == null || fullJson.isEmpty) return [];

  try {
    final data = jsonDecode(fullJson);
    if (data is! Map) return [];

    final infobox = data['infobox'];
    if (infobox is! List) return [];

    final aliases = <String>[];
    for (final item in infobox) {
      if (item is! Map) continue;
      final key = item['key']?.toString() ?? '';
      final lowerKey = key.toLowerCase();
      // i18n-ignore: Bangumi infobox key tokens used for matching; do not localize.
      final isAliasKey =
          key.contains('别名') || // i18n-ignore
          key.contains('別名') || // i18n-ignore
          key.contains('别称') || // i18n-ignore
          lowerKey.contains('alias');
      if (!isAliasKey) continue;

      final value = item['value'];
      final values = <String>[];
      if (value is List) {
        for (final v in value) {
          if (v is Map && v['v'] != null) {
            values.add(v['v'].toString());
          } else if (v != null) {
            values.add(v.toString());
          }
        }
      } else if (value != null) {
        values.add(value.toString());
      }

      for (final raw in values) {
        for (final part in raw.split(RegExp(r'[\\/、,，;；·・]'))) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) {
            aliases.add(trimmed);
          }
        }
      }
    }

    return aliases;
  } catch (_) {
    return [];
  }
}

/// Build the multi-alias search name (`title||sub||alias…`) used by sample
/// search and captcha preflight keyword selection.
String buildSearchNameForSources({
  required String title,
  String? subTitle,
  String? fullJson,
}) {
  final trimmedTitle = title.trim();
  final candidates = <String>[];

  void addCandidate(String? value) {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    candidates.add(trimmed);
  }

  addCandidate(trimmedTitle);
  addCandidate(subTitle);
  for (final alias in extractAliasesFromBangumiJson(fullJson)) {
    addCandidate(alias);
  }

  final unique = <String>[];
  final seen = <String>{};
  for (final item in candidates) {
    final key = item.toLowerCase();
    if (seen.add(key)) {
      unique.add(item);
    }
  }

  if (unique.isEmpty) {
    return trimmedTitle;
  }

  return unique.join('||');
}

/// First non-empty segment of [buildSearchNameForSources], else [fallbackTitle].
String buildCaptchaPreflightKeyword({
  required String title,
  String? subTitle,
  String? fullJson,
}) {
  final fullSearchName = buildSearchNameForSources(
    title: title,
    subTitle: subTitle,
    fullJson: fullJson,
  );
  for (final item in fullSearchName.split('||')) {
    final trimmed = item.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return title.trim();
}

/// Extract a torrent info-hash from a local BT stream URL
/// (libtorrent `/stream(s)/HASH/` or rqbit `/torrents/HASH/`).
String? extractBtHashFromStreamUrl(String streamUrl) {
  // libtorrent: http://127.0.0.1:PORT/stream/HASH/INDEX
  // rqbit: http://127.0.0.1:3000/torrents/HASH/stream/INDEX
  final ltRegex = RegExp(r'/streams?/([a-fA-F0-9]+)/');
  final rqbitRegex = RegExp(r'/torrents/([a-fA-F0-9]+)/');

  for (final regex in [ltRegex, rqbitRegex]) {
    final match = regex.firstMatch(streamUrl);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

// ── Async load sink ────────────────────────────────────────────────────────

/// Callback surface the page implements so loaders can mutate controller state
/// under `setState` and drop stale responses after episode/anime switches.
class PlayerBtSourceLoadSink {
  const PlayerBtSourceLoadSink({
    required this.isMikanCurrent,
    required this.isDmhyCurrent,
    required this.apply,
  });

  /// Whether [token] is still the latest Mikan request *and* the page is mounted.
  final bool Function(int token) isMikanCurrent;

  /// Whether [token] is still the latest DMHY request *and* the page is mounted.
  final bool Function(int token) isDmhyCurrent;

  /// Run [mutation] under the page's `setState` (or equivalent).
  final void Function(void Function() mutation) apply;
}

// ── Async loaders ──────────────────────────────────────────────────────────

/// Load DMHY resources for [subjectId] / [targetEpisode] into [controller].
Future<void> loadDmhySource({
  required PlayerSourceController controller,
  required PlayerBtSourceLoadSink sink,
  required String? subjectId,
  required int targetEpisode,
}) async {
  final requestToken = controller.beginDmhyRequest();
  if (subjectId == null || !sink.isDmhyCurrent(requestToken)) return;

  sink.apply(controller.markDmhyLoading);

  try {
    final resources = await fetchDmhyResources(
      subjectId: subjectId,
      targetEpisode: targetEpisode,
    );
    if (!sink.isDmhyCurrent(requestToken)) return;

    sink.apply(() => controller.setDmhyResources(resources));
  } catch (e) {
    debugPrint('Error loading DMHY source: $e');
    if (!sink.isDmhyCurrent(requestToken)) return;

    sink.apply(() => controller.setDmhyError(e.toString()));
  }
}

/// Load Mikan anime + episode resources (fast path via bangumi-data, else search).
Future<void> loadMikanSource({
  required PlayerSourceController controller,
  required PlayerBtSourceLoadSink sink,
  required String animeTitle,
  required String? animeMikanId,
  required String? animeBangumiId,
  required dynamic episodeId,
  required int targetEpisode,
}) async {
  final requestToken = controller.beginMikanRequest();
  if (!sink.isMikanCurrent(requestToken)) return;

  debugPrint('[Mikan] Starting search for playback sources...');
  debugPrint('[Mikan] Target anime title: $animeTitle');
  debugPrint('[Mikan] Current episode sort: $targetEpisode');

  sink.apply(controller.markMikanLoading);

  try {
    final isNonLegacy =
        BangumiRequestModeService.notifier.value != BangumiRequestMode.legacy;

    String? resolvedMikanId;

    if (isNonLegacy) {
      if (animeMikanId != null && animeMikanId.isNotEmpty) {
        resolvedMikanId = animeMikanId;
        debugPrint(
          '[Mikan] Fast path: using mikanId from AnimeInfo: $resolvedMikanId',
        );
      } else if (animeBangumiId != null && animeBangumiId.isNotEmpty) {
        resolvedMikanId = await BangumiDataService.getMikanId(animeBangumiId);
        if (!sink.isMikanCurrent(requestToken)) return;

        if (resolvedMikanId != null) {
          debugPrint(
            '[Mikan] Fast path: resolved mikanId=$resolvedMikanId from bangumiId=$animeBangumiId',
          );
        }
      }
    }

    if (resolvedMikanId != null) {
      final mikanId = resolvedMikanId;
      final result = MikanSearchResult(
        id: mikanId,
        name: animeTitle,
        imageUrl: '',
      );

      if (!sink.isMikanCurrent(requestToken)) return;
      sink.apply(() => controller.setMikanAnime(result));

      if (episodeId != 0) {
        final resources = await getMikanResources(
          mikanId: mikanId,
          currentEpisodeSort: targetEpisode,
        );
        if (!sink.isMikanCurrent(requestToken)) return;

        debugPrint(
          '[Mikan] Fast path: Found ${resources.length} resources for EP $targetEpisode',
        );
        sink.apply(() => controller.setMikanResources(resources));
      } else {
        if (!sink.isMikanCurrent(requestToken)) return;
        sink.apply(controller.markMikanIdle);
      }
      return;
    }

    final result = await searchMikanAnime(nameCn: animeTitle);
    if (!sink.isMikanCurrent(requestToken)) return;

    if (result == null) {
      debugPrint('[Mikan] No anime found on Mikan for title: $animeTitle');
      sink.apply(controller.setMikanNotFound);
      return;
    }

    debugPrint(
      '[Mikan] Found matching anime: ${result.name} (ID: ${result.id})',
    );

    sink.apply(() => controller.setMikanAnime(result));

    if (episodeId != 0) {
      final resources = await getMikanResources(
        mikanId: result.id,
        currentEpisodeSort: targetEpisode,
      );
      if (!sink.isMikanCurrent(requestToken)) return;

      debugPrint(
        '[Mikan] Initial load: Found ${resources.length} resources for EP $targetEpisode',
      );

      sink.apply(() => controller.setMikanResources(resources));
    } else {
      if (!sink.isMikanCurrent(requestToken)) return;
      sink.apply(controller.markMikanIdle);
    }
  } catch (e) {
    debugPrint('Error loading Mikan source: $e');
    if (!sink.isMikanCurrent(requestToken)) return;

    sink.apply(() => controller.setMikanError(e.toString()));
  }
}

/// Reload Mikan resources for a new episode using the already-bound anime.
Future<void> reloadMikanResourcesForEpisode({
  required PlayerSourceController controller,
  required PlayerBtSourceLoadSink sink,
  required int targetEpisode,
}) async {
  final mikanAnime = controller.mikanAnime;
  if (mikanAnime == null) return;

  final requestToken = controller.beginMikanRequest();
  if (!sink.isMikanCurrent(requestToken)) return;

  debugPrint('[Mikan] Reloading resources for new episode: $targetEpisode');
  debugPrint('[Mikan] Using existing anime ID: ${mikanAnime.id}');

  sink.apply(controller.markMikanReloadForEpisode);
  try {
    final resources = await getMikanResources(
      mikanId: mikanAnime.id,
      currentEpisodeSort: targetEpisode,
    );
    if (!sink.isMikanCurrent(requestToken)) return;

    sink.apply(() => controller.setMikanResources(resources));
  } catch (e) {
    debugPrint('[Mikan] Error reloading resources: $e');
    if (!sink.isMikanCurrent(requestToken)) return;

    sink.apply(() => controller.setMikanError(e.toString()));
  }
}
