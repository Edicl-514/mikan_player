import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/topics_section.dart';

BangumiTopic _topic({
  int id = 1,
  String userName = 'TestUser',
  String avatar = '',
  String title = 'Sample Topic Title',
  String time = '2026-07-29',
  String updatedAt = '2026-07-29 10:00',
  int repliesCount = 8,
}) => BangumiTopic(
  id: id,
  userId: userName,
  userName: userName,
  avatar: avatar,
  title: title,
  time: time,
  updatedAt: updatedAt,
  repliesCount: repliesCount,
);

Widget _buildSectionTitleStub(String text, bool isDarkBg) => Text(
  'SECTION_TITLE:$text',
  style: TextStyle(color: isDarkBg ? Colors.white : Colors.black87),
);

Widget _loadingStub(BuildContext context) => const Text('LOADING_STUB');

void main() {
  group('TopicsSection', () {
    testWidgets(
      'loading state renders loadingPlaceholder; section title omitted',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TopicsSection(
                topics: const [],
                isLoading: true,
                isLoadingMore: false,
                isDarkBg: false,
                sectionTitle: _buildSectionTitleStub('讨论版', false),
                loadingPlaceholder: _loadingStub,
              ),
            ),
          ),
        );

        expect(find.text('LOADING_STUB'), findsOneWidget);
        expect(find.text('SECTION_TITLE:讨论版'), findsNothing);
      },
    );

    testWidgets('empty state renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicsSection(
              topics: const [],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('讨论版', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.text('LOADING_STUB'), findsNothing);
      expect(find.text('SECTION_TITLE:讨论版'), findsNothing);
    });

    testWidgets('populated renders topic titles, replies count, and authors', (
      tester,
    ) async {
      final topics = [
        _topic(id: 1, title: 'Topic 1', userName: 'Alice', repliesCount: 3),
        _topic(id: 2, title: 'Topic 2', userName: 'Bob', repliesCount: 7),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicsSection(
              topics: topics,
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('讨论版', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.text('SECTION_TITLE:讨论版'), findsOneWidget);
      expect(find.text('Topic 1'), findsOneWidget);
      expect(find.text('Topic 2'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('tapping a topic invokes onTopicTap', (tester) async {
      BangumiTopic? tappedTopic;
      final topic = _topic(id: 42, title: 'Tappable Topic');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicsSection(
              topics: [topic],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('讨论版', false),
              loadingPlaceholder: _loadingStub,
              onTopicTap: (t) => tappedTopic = t,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Topic'));
      await tester.pumpAndSettle();

      expect(tappedTopic, equals(topic));
    });

    testWidgets('TopicsSliver renders lazily inside CustomScrollView', (
      tester,
    ) async {
      final topics = List.generate(
        30,
        (index) => _topic(id: index, title: 'Sliver Topic $index'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                TopicsSliver(
                  topics: topics,
                  isLoading: false,
                  isLoadingMore: false,
                  isDarkBg: true,
                  sectionTitle: _buildSectionTitleStub('讨论版', true),
                  loadingPlaceholder: _loadingStub,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Sliver Topic 0'), findsOneWidget);
      expect(find.text('Sliver Topic 29'), findsNothing);
    });
  });
}
