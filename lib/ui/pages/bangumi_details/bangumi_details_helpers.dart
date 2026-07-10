// Pure parsing/sorting helpers extracted from BangumiDetailsPage.
// These are top-level functions so they can be unit tested without a
// Flutter binding or a page instance.

/// Splits a bangumi summary into the user-facing translation and the
/// original Chinese text using the `[简介原文]` separator.
Map<String, String?> parseBangumiSummary(String? summary) {
  if (summary == null || summary.isEmpty) {
    return {'translation': null, 'original': null};
  }

  // Check if summary contains the separator
  final separatorIndex = summary.indexOf('[简介原文]');
  if (separatorIndex == -1) {
    // No separator, treat entire text as translation
    return {'translation': summary, 'original': null};
  }

  // Split into translation and original
  final translation = summary.substring(0, separatorIndex).trim();
  final original = summary.substring(separatorIndex + '[简介原文]'.length).trim();

  return {'translation': translation, 'original': original};
}

/// Flattens an infobox value (string, number, or list of `{v: ...}` maps)
/// into a single human-readable string for preview/collapse heuristics.
String summarizeInfoboxValue(dynamic value) {
  if (value is List) {
    return value
        .map((v) => (v['v'] ?? '').toString())
        .where((s) => s.isNotEmpty)
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
