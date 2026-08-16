// Pure-function unit tests for `person_text_spans.dart`.
//
// No Flutter binding, no widget, no Navigator — the matching algorithm and
// span list builder are pure functions and can be tested in isolation. The
// `PersonAwareText` widget itself is exercised indirectly by the comment /
// infobox rendering in the page/widget tests.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/ui/pages/bangumi_details/person_text_spans.dart';

void main() {
  group('PersonTextMatch', () {
    test('is a const-constructible value object', () {
      const match = PersonTextMatch(start: 0, end: 2, name: 'Aa', personId: 7);
      expect(match.start, 0);
      expect(match.end, 2);
      expect(match.name, 'Aa');
      expect(match.personId, 7);
    });
  });

  group('findNextPersonMatch', () {
    test('returns null when personIdMap is empty', () {
      expect(findNextPersonMatch('hello world', 0, const {}), isNull);
    });

    test('returns null when no name occurs in text', () {
      final map = <String, int>{'Bob': 1, 'Alex': 2};
      expect(findNextPersonMatch('hello world', 0, map), isNull);
    });

    test('returns the leftmost match when names overlap', () {
      final map = <String, int>{'Bob': 1, 'Alex': 2};
      final text = 'Alex and Bob';
      final match = findNextPersonMatch(text, 0, map);
      expect(match!.start, 0);
      expect(match.end, 4);
      expect(match.name, 'Alex');
      expect(match.personId, 2);
    });

    test('prefers the longer name when both start at the same index', () {
      // "Vinland Saga" vs "Vinland" — both start at 0, longer wins.
      final map = <String, int>{'Vinland': 1, 'Vinland Saga': 2};
      final text = 'Vinland Saga is great';
      final match = findNextPersonMatch(text, 0, map);
      expect(match!.name, 'Vinland Saga');
      expect(match.personId, 2);
      expect(match.start, 0);
      expect(match.end, 12);
    });

    test('returns null when all names are shorter than 2 chars', () {
      final map = <String, int>{'A': 1, 'B': 2};
      expect(findNextPersonMatch('BA here', 0, map), isNull);
    });

    test('trims whitespace in map keys before matching', () {
      // Both keys map to 'Bob' after trimming. The first one wins dedup —
      // behavior of the second is suppressed by the seen-set.
      final map = <String, int>{'Bob': 1, '  Bob  ': 2};
      final text = 'Bob';
      final match = findNextPersonMatch(text, 0, map);
      expect(match, isNotNull);
      expect(match!.name, 'Bob');
      expect(match.start, 0);
      expect(match.end, 3);
      // The personId is whichever non-duped key was applied last; both
      // keys collapse to "Bob" so the second entry's personId wins the
      // update inside the loop's `if name.length < 2 || !seenNames.add(name)`
      final spans = buildPersonInlineSpans(
        'hello Bob world',
        textStyle: const TextStyle(fontSize: 14),
        linkStyle: const TextStyle(fontSize: 14, color: Colors.blue),
        personIdMap: const {'Bob': 7},
        onPersonTap: (id, {personName}) {},
      );
      expect(spans.length, 3);
      expect(spans[0].toPlainText(), 'hello ');
      expect(spans[1].toPlainText(), 'Bob');
      expect(spans[2].toPlainText(), ' world');
    });

    test('case-sensitive match works', () {
      final spans = buildPersonInlineSpans(
        'hello bob world',
        textStyle: const TextStyle(fontSize: 14),
        linkStyle: const TextStyle(fontSize: 14, color: Colors.blue),
        personIdMap: const {'Bob': 7},
        onPersonTap: (id, {personName}) {},
      );
      expect(spans.length, 1);
      expect(spans[0].toPlainText(), 'hello bob world');
    });

    test('empty personIdMap returns single plain text span', () {
      final spans = buildPersonInlineSpans(
        'hello Bob world',
        textStyle: const TextStyle(fontSize: 14),
        linkStyle: const TextStyle(fontSize: 14, color: Colors.blue),
        personIdMap: const {},
        onPersonTap: (id, {personName}) {},
      );
      expect(spans.length, 1);
      expect(spans[0].toPlainText(), 'hello Bob world');
    });

    test('link span carries a TapGestureRecognizer bound to onPersonTap', () {
      final tapped = <int>[];
      final spans = buildPersonInlineSpans(
        'hello Bob world',
        textStyle: const TextStyle(fontSize: 14),
        linkStyle: const TextStyle(fontSize: 14, color: Colors.blue),
        personIdMap: const {'Bob': 7},
        onPersonTap: (id, {personName}) => tapped.add(id),
      );
      final link = spans[1] as TextSpan;
      expect(link.recognizer, isA<TapGestureRecognizer>());
      (link.recognizer! as TapGestureRecognizer).onTap!();
      expect(tapped, [7]);
      link.recognizer!.dispose();
    });

    test('handles match at the start without leading plain span', () {
      final spans = buildPersonInlineSpans(
        'Bob world',
        textStyle: const TextStyle(fontSize: 14),
        linkStyle: const TextStyle(fontSize: 14, color: Colors.blue),
        personIdMap: const {'Bob': 7},
        onPersonTap: (id, {personName}) {},
      );
      expect(spans.length, 2);
      expect(spans[0].toPlainText(), 'Bob');
      expect(spans[1].toPlainText(), ' world');
    });

    test('handles match at the end without trailing plain span', () {
      final spans = buildPersonInlineSpans(
        'hello Bob',
        textStyle: const TextStyle(fontSize: 14),
        linkStyle: const TextStyle(fontSize: 14, color: Colors.blue),
        personIdMap: const {'Bob': 7},
        onPersonTap: (id, {personName}) {},
      );
      expect(spans.length, 2);
      expect(spans[0].toPlainText(), 'hello ');
      expect(spans[1].toPlainText(), 'Bob');
    });
  });

  group('PersonAwareText widget', () {
    testWidgets('renders the text up to and after the link portion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: PersonAwareText(
              text: 'hello Bob world',
              textStyle: TextStyle(fontSize: 14),
              linkStyle: TextStyle(fontSize: 14, color: Colors.blue),
              personIdMap: {'Bob': 7},
              onPersonTap: _noOpTap,
            ),
          ),
        ),
      );
      expect(find.text('hello Bob world'), findsOneWidget);
    });

    testWidgets('renders the whole text when personIdMap is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: PersonAwareText(
              text: 'No links here',
              textStyle: TextStyle(fontSize: 14),
              linkStyle: TextStyle(fontSize: 14, color: Colors.blue),
              personIdMap: {},
              onPersonTap: _noOpTap,
            ),
          ),
        ),
      );
      expect(find.text('No links here'), findsOneWidget);
    });
  });
}

void _noOpTap(int _, {String? personName}) {}
