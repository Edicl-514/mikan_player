// Pure parsing/sorting helpers extracted from BangumiDetailsPage.
// These are top-level functions so they can be unit tested without a
// Flutter binding or a page instance.

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

/// Bangumi-style summary separator marker. Kept as protocol token for
/// matching server payloads; never show this token as UI chrome.
// i18n-ignore: upstream Bangumi summary separator used for matching
const bangumiSummaryOriginalSeparator = '[简介原文]';

/// Splits a bangumi summary into the user-facing translation and the
/// original Chinese text using the `[简介原文]` separator.
Map<String, String?> parseBangumiSummary(String? summary) {
  if (summary == null || summary.isEmpty) {
    return {'translation': null, 'original': null};
  }

  // Check if summary contains the separator
  final separatorIndex = summary.indexOf(bangumiSummaryOriginalSeparator);
  if (separatorIndex == -1) {
    // No separator, treat entire text as translation
    return {'translation': summary, 'original': null};
  }

  // Split into translation and original
  final translation = summary.substring(0, separatorIndex).trim();
  final original = summary
      .substring(separatorIndex + bangumiSummaryOriginalSeparator.length)
      .trim();

  return {'translation': translation, 'original': original};
}

/// Flattens an infobox value (string, number, or list of `{v: ...}` maps)
/// into a single human-readable string for preview/collapse heuristics.
String summarizeInfoboxValue(dynamic value) {
  if (value is List) {
    return value
        .map<String>((v) => (v['v'] ?? '').toString())
        .where((String s) => s.isNotEmpty)
        .join(', ');
  }
  return value?.toString() ?? '';
}

/// Returns true when the infobox should render with a "show more" toggle
/// because the list is long or any single entry is unusually large.
bool shouldEnableInfoBoxCollapse(List infobox) {
  if (infobox.length > 6) {
    return true;
  }

  for (final item in infobox) {
    final value = item is Map ? item['value'] : null;
    if (value is List && value.length > 4) {
      return true;
    }
    if (summarizeInfoboxValue(value).length > 80) {
      return true;
    }
  }

  return false;
}

/// Returns true when the given infobox entry is missing a key or a value.
bool isInfoboxItemEmpty(dynamic item) {
  if (item is! Map) {
    return true;
  }

  final key = (item['key'] ?? '').toString().trim();
  final value = summarizeInfoboxValue(item['value']).trim();
  return key.isEmpty || value.isEmpty;
}

/// Stable sort priority for site kinds on the bangumi details page:
/// info (0) < onair (1) < resource (2) < anything else (3).
int siteKindPriority(String kind) {
  switch (kind) {
    case 'info':
      return 0;
    case 'onair':
      return 1;
    case 'resource':
      return 2;
    default:
      return 3;
  }
}

/// Formats a `YYYY-MM-DD` (or ISO 8601) date string into a locale-aware
/// year-month label. Returns the input unchanged when it cannot be parsed.
String formatDateToMonth(String dateStr, AppLocalizations l10n) {
  try {
    final date = DateTime.parse(dateStr);
    return l10n.bangumiDetailsYearMonth(date.year, date.month);
  } catch (_) {
    return dateStr;
  }
}

/// Coerces [value] (int, double, or numeric string) into an `int`, or
/// returns `null` when it cannot. Used when reading episode-count fields
/// from the bangumi subject JSON that may arrive as any of these shapes.
int? readIntValue(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

/// Composes a human-readable episode status string such as "全 12 话" or
/// "0话" used in the mobile header. Pure function over the (possibly null)
/// subject data and the optional episode list from the controller.
String getEpisodeStatusText(
  Map<String, dynamic>? data,
  List<BangumiEpisode>? episodes,
  AppLocalizations l10n,
) {
  final total = getTotalEpisodeCount(data, episodes);
  if (total != null && total > 0) {
    return l10n.bangumiDetailsTotalEpisodes(total);
  }
  return l10n.bangumiDetailsZeroEpisodes;
}

/// Resolves the total episode count for [getEpisodeStatusText].
///
/// Tries, in order:
///   1. `data['total_episodes']` (number-like),
///   2. `data['eps']` (number-like),
///   3. `episodes.length`,
///   4. count of Map entries inside `data['episodes']`.
/// Returns `null` when nothing is available.
int? getTotalEpisodeCount(Map<String, dynamic>? data, List<BangumiEpisode>? episodes) {
  final totalFromData = readIntValue(data?['total_episodes']);
  if (totalFromData != null && totalFromData > 0) {
    return totalFromData;
  }

  final epsFromData = readIntValue(data?['eps']);
  if (epsFromData != null && epsFromData > 0) {
    return epsFromData;
  }

  final episodeCount = episodes?.length ?? 0;
  if (episodeCount > 0) {
    return episodeCount;
  }

  final parsedEpisodes = data?['episodes'];
  if (parsedEpisodes is List) {
    final count = parsedEpisodes.whereType<Map>().length;
    if (count > 0) {
      return count;
    }
  }

  return null;
}

/// De-duplicates tag names from the subject's `tags` payload while preserving
/// the order of first occurrence. Falls back to [fallback] when the payload is
/// absent, empty, or has no named entries.
List<String> extractCurrentTags(dynamic rawTags, List<String> fallback) {
  if (rawTags is! List) {
    return fallback;
  }

  final tags = <String>[];
  final seen = <String>{};
  for (final item in rawTags) {
    String value = '';
    if (item is Map) {
      value = item['name']?.toString().trim() ?? '';
    } else {
      value = item?.toString().trim() ?? '';
    }
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.add(key)) {
      tags.add(value);
    }
  }
  return tags.isNotEmpty ? tags : fallback;
}

/// Picks the best available cover URL for display.
///
/// Tries `data['images']['large'|'common'|'medium']` first (matches
/// `_getImageUrl` in the original page), then falls back to [fallback]
/// (typically `widget.anime.coverUrl`).
String? getImageUrl(Map<String, dynamic>? data, String? fallback) {
  if (data != null && data['images'] != null) {
    final images = data['images'];
    return images['large'] ?? images['common'] ?? images['medium'] ?? fallback;
  }
  return fallback;
}

/// Returns the display title: prefers `data['name']`, falling back to
/// [fallback] (typically `widget.anime.title`).
String getDisplayTitle(Map<String, dynamic>? data, String fallback) {
  return data?['name'] ?? fallback;
}

/// Selects the summary text currently shown on the details page.
///
/// When [showOriginal] is true, prefers the original half of a
/// `[简介原文]`-split summary and falls back to the translation. When false,
/// returns only the translation half (or the whole summary when no separator
/// is present).
String? getDisplaySummary(String? summary, {required bool showOriginal}) {
  final parsed = parseBangumiSummary(summary);
  if (showOriginal) {
    return parsed['original'] ?? parsed['translation'];
  }
  return parsed['translation'];
}

/// Returns true when the summary has both a translation half and an original
/// half, so the UI should offer a toggle.
bool hasBothTranslationAndOriginal(String? summary) {
  final parsed = parseBangumiSummary(summary);
  final translation = parsed['translation'];
  final original = parsed['original'];
  return translation != null && original != null;
}
