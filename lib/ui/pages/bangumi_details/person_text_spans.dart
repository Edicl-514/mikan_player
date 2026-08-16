// Person-aware text helpers extracted from BangumiDetailsPage.
//
// The infobox and character CV names both link matched substrings to a
// `personId` for navigation to PersonDetailPage. This file owns the
// leftmost-longest matcher and a small `PersonAwareText` widget so the
// searcher can be unit tested without a Flutter binding or page instance.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Immutable record describing one matched person-name substring in a piece
/// of text. The match defines a half-open range `[start, end)` together with
/// the matched `name` and the associated `personId` that should be opened
/// when the substring is tapped.
class PersonTextMatch {
  final int start;
  final int end;
  final String name;
  final int personId;

  const PersonTextMatch({
    required this.start,
    required this.end,
    required this.name,
    required this.personId,
  });
}

/// Finds the next [PersonTextMatch] in [text] starting at [startIndex].
///
/// Implements a leftmost-longest scan over [personIdMap]: the match with the
/// smallest `start` wins; ties are broken by the longer name. Pure function —
/// has no Flutter/page dependency, so it can be unit tested in isolation.
PersonTextMatch? findNextPersonMatch(
  String text,
  int startIndex,
  Map<String, int> personIdMap,
) {
  PersonTextMatch? bestMatch;
  final seenNames = <String>{};

  for (final entry in personIdMap.entries) {
    final name = entry.key.trim();
    if (name.length < 2 || !seenNames.add(name)) continue;

    final matchIndex = text.indexOf(name, startIndex);
    if (matchIndex == -1) continue;

    final candidate = PersonTextMatch(
      start: matchIndex,
      end: matchIndex + name.length,
      name: name,
      personId: entry.value,
    );

    if (bestMatch == null ||
        candidate.start < bestMatch.start ||
        (candidate.start == bestMatch.start &&
            candidate.name.length > bestMatch.name.length)) {
      bestMatch = candidate;
    }
  }

  return bestMatch;
}

/// Builds the inline span list for [text], splitting unmatched fragments into
/// plain [TextSpan]s and matched names into tappable [TextSpan]s wired to
/// [onPersonTap] via a fresh [TapGestureRecognizer].
///
/// Each tap recognizer is owned by the returned span list — the surrounding
/// [Text.rich] takes ownership once rendered. Callers should not retain the
/// returned list across rebuilds; rebuild from a fresh call instead.
List<InlineSpan> buildPersonInlineSpans(
  String text, {
  required TextStyle textStyle,
  required TextStyle linkStyle,
  required Map<String, int> personIdMap,
  required void Function(int personId, {String? personName}) onPersonTap,
}) {
  if (text.isEmpty || personIdMap.isEmpty) {
    return [TextSpan(text: text, style: textStyle)];
  }

  final spans = <InlineSpan>[];
  var cursor = 0;

  while (cursor < text.length) {
    final match = findNextPersonMatch(text, cursor, personIdMap);
    if (match == null) {
      spans.add(TextSpan(text: text.substring(cursor), style: textStyle));
      break;
    }

    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: textStyle),
      );
    }

    spans.add(
      TextSpan(
        text: match.name,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => onPersonTap(match.personId, personName: match.name),
      ),
    );
    cursor = match.end;
  }

  return spans;
}

/// Renders [text] with any embedded person-name substrings turned into
/// tappable links that call [onPersonTap] with the matched `personId`.
///
/// Stateless convenience widget around [buildPersonInlineSpans]. Use it
/// whenever a label may contain a known person name (e.g. infobox values
/// and character CV names).
class PersonAwareText extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final TextStyle linkStyle;
  final Map<String, int> personIdMap;
  final void Function(int personId, {String? personName}) onPersonTap;

  const PersonAwareText({
    super.key,
    required this.text,
    required this.textStyle,
    required this.linkStyle,
    required this.personIdMap,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: textStyle,
        children: buildPersonInlineSpans(
          text,
          textStyle: textStyle,
          linkStyle: linkStyle,
          personIdMap: personIdMap,
          onPersonTap: onPersonTap,
        ),
      ),
    );
  }
}
