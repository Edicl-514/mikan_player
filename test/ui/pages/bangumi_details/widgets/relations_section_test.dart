// Phase 4 / Package D focused widget tests for the extracted
// `RelationsSection` widget.
//
// No network, no WebView, no media player — all data passed via constructor.
// Test instances use empty `image` to avoid real `CachedNetworkImage` network
// decode; the fallback `Icons.movie_outlined` path is exercised instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/relations_section.dart';

BangumiRelatedSubject _relation({
  int id = 1,
  String name = '',
  String nameCn = '',
  String relation = 'TV',
  String image = '',
}) => BangumiRelatedSubject(
  id: id,
  name: name,
  nameCn: nameCn,
  relation: relation,
  image: image,
);

Widget _buildSectionTitleStub(String text, bool isDarkBg) => Text(
  'SECTION_TITLE:$text',
  style: TextStyle(color: isDarkBg ? Colors.white : Colors.black87),
);

Widget _loadingStub(BuildContext context) => const Text('LOADING_STUB');

void main() {
  group('RelationsSection', () {
    testWidgets('loading state renders loadingPlaceholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationsSection(
              relations: const [],
              isLoading: true,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('关联', false),
              loadingPlaceholder: _loadingStub,
              scrollController: ScrollController(),
              onItemTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('LOADING_STUB'), findsOneWidget);
    });

    testWidgets('empty state renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationsSection(
              relations: const [],
              isLoading: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('关联', false),
              loadingPlaceholder: _loadingStub,
              scrollController: ScrollController(),
              onItemTap: (_) {},
            ),
          ),
        ),
      );

      // The section title is STILL rendered by the widget (it's part of the
      // Column before the empty scroll row). The widget builds the title
      // unconditionally when not loading and not isEmpty — wait, actually
      // when relations is empty the widget returns SizedBox.shrink BEFORE
      // the Column, so the title ALSO disappears. This matches the original
      // page behavior: the outer `if (_relations != null && _relations!.isNotEmpty)`
      // check already skips the entire section when empty. So asserting
      // the title is NOT present is correct when relations is empty.
      expect(find.text('LOADING_STUB'), findsNothing);
      expect(find.text('SECTION_TITLE:关联'), findsNothing);
    });

    testWidgets('populated state renders relation cards', (tester) async {
      final relations = [
        _relation(id: 1, nameCn: 'Relation One', relation: 'TV'),
        _relation(id: 2, nameCn: 'Relation Two', relation: 'OVA'),
        _relation(id: 3, nameCn: 'Relation Three', relation: 'Movie'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationsSection(
              relations: relations,
              isLoading: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('关联', false),
              loadingPlaceholder: _loadingStub,
              scrollController: ScrollController(),
              onItemTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('SECTION_TITLE:关联'), findsOneWidget);
      expect(find.text('Relation One'), findsOneWidget);
      expect(find.text('Relation Two'), findsOneWidget);
      expect(find.text('Relation Three'), findsOneWidget);
      expect(find.text('TV'), findsOneWidget);
      expect(find.text('OVA'), findsOneWidget);
      expect(find.text('Movie'), findsOneWidget);
    });

    testWidgets('tap invokes onItemTap with the right relation', (
      tester,
    ) async {
      final relations = [
        _relation(id: 1, nameCn: 'Tap Me', relation: 'TV'),
        _relation(id: 2, nameCn: 'Do Not Tap', relation: 'OVA'),
      ];
      BangumiRelatedSubject? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationsSection(
              relations: relations,
              isLoading: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('关联', false),
              loadingPlaceholder: _loadingStub,
              scrollController: ScrollController(),
              onItemTap: (rel) => captured = rel,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.id, 1);
      expect(captured!.nameCn, 'Tap Me');
    });

    testWidgets('isDarkBg true renders without exception', (tester) async {
      final relations = [_relation(id: 1, nameCn: 'Dark', relation: 'TV')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationsSection(
              relations: relations,
              isLoading: false,
              isDarkBg: true,
              sectionTitle: _buildSectionTitleStub('关联', true),
              loadingPlaceholder: _loadingStub,
              scrollController: ScrollController(),
              onItemTap: (_) {},
            ),
          ),
        ),
      );

      // The section title should render in its dark-bg style
      expect(find.text('SECTION_TITLE:关联'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });
  });
}
