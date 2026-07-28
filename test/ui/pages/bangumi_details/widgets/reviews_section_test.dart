import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/reviews_section.dart';

BangumiReview _review({
  int id = 1,
  int entryId = 101,
  String userName = 'TestUser',
  String avatar = '',
  String title = 'Sample Title',
  String summary = 'Sample Summary Content',
  String time = '2026-07-28',
  int repliesCount = 5,
}) => BangumiReview(
  id: id,
  entryId: entryId,
  userId: userName,
  userName: userName,
  avatar: avatar,
  title: title,
  summary: summary,
  time: time,
  repliesCount: repliesCount,
);

Widget _buildSectionTitleStub(String text, bool isDarkBg) => Text(
  'SECTION_TITLE:$text',
  style: TextStyle(color: isDarkBg ? Colors.white : Colors.black87),
);

Widget _loadingStub(BuildContext context) => const Text('LOADING_STUB');

void main() {
  group('ReviewsSection', () {
    testWidgets(
      'loading state renders loadingPlaceholder; section title omitted',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReviewsSection(
                reviews: const [],
                isLoading: true,
                isLoadingMore: false,
                isDarkBg: false,
                sectionTitle: _buildSectionTitleStub('长评', false),
                loadingPlaceholder: _loadingStub,
              ),
            ),
          ),
        );

        expect(find.text('LOADING_STUB'), findsOneWidget);
        expect(find.text('SECTION_TITLE:长评'), findsNothing);
      },
    );

    testWidgets('empty state renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewsSection(
              reviews: const [],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('长评', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.text('LOADING_STUB'), findsNothing);
      expect(find.text('SECTION_TITLE:长评'), findsNothing);
    });

    testWidgets('populated renders all review titles, summaries, and authors', (
      tester,
    ) async {
      final reviews = [
        _review(id: 1, title: 'Review 1', userName: 'Alice'),
        _review(id: 2, title: 'Review 2', userName: 'Bob'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewsSection(
              reviews: reviews,
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('长评', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.text('SECTION_TITLE:长评'), findsOneWidget);
      expect(find.text('Review 1'), findsOneWidget);
      expect(find.text('Review 2'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('tapping a review invokes onReviewTap', (tester) async {
      BangumiReview? tappedReview;
      final review = _review(id: 42, title: 'Tappable Review');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewsSection(
              reviews: [review],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('长评', false),
              loadingPlaceholder: _loadingStub,
              onReviewTap: (r) => tappedReview = r,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Review'));
      await tester.pumpAndSettle();

      expect(tappedReview, equals(review));
    });

    testWidgets('ReviewsSliver renders lazily inside CustomScrollView', (
      tester,
    ) async {
      final reviews = List.generate(
        30,
        (index) => _review(id: index, title: 'Sliver Review $index'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ReviewsSliver(
                  reviews: reviews,
                  isLoading: false,
                  isLoadingMore: false,
                  isDarkBg: true,
                  sectionTitle: _buildSectionTitleStub('长评', true),
                  loadingPlaceholder: _loadingStub,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Sliver Review 0'), findsOneWidget);
      expect(find.text('Sliver Review 29'), findsNothing);
    });
  });
}
