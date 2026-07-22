// Phase 4 / Package D focused widget tests for the extracted
// `CommentsSection` widget.
//
// No network, no WebView, no media player — all data passed via constructor.
// Test instances use empty `avatar`/`contentHtml`/`content` to avoid real
// `CachedNetworkImage` network decode (the avatar fallback `Icons.person`
// path is exercised) and `HtmlWidget` HTML decode (PROVEN safe by
// `test/ui/pages/player/widgets/player_comments_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/comments_section.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';

BangumiComment _comment({
  String userName = '',
  int? rate,
  String content = '',
  String contentHtml = '',
  String time = '',
  String avatar = '',
}) => BangumiComment(
  userName: userName,
  rate: rate,
  content: content,
  contentHtml: contentHtml,
  time: time,
  avatar: avatar,
);

Widget _buildSectionTitleStub(String text, bool isDarkBg) => Text(
  'SECTION_TITLE:$text',
  style: TextStyle(color: isDarkBg ? Colors.white : Colors.black87),
);

Widget _loadingStub(BuildContext context) => const Text('LOADING_STUB');

void main() {
  group('CommentsSection', () {
    testWidgets(
      'loading state renders loadingPlaceholder; section title omitted',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CommentsSection(
                comments: const [],
                isLoading: true,
                isLoadingMore: false,
                isDarkBg: false,
                sectionTitle: _buildSectionTitleStub('评论', false),
                loadingPlaceholder: _loadingStub,
              ),
            ),
          ),
        );

        expect(find.text('LOADING_STUB'), findsOneWidget);
        expect(find.text('SECTION_TITLE:评论'), findsNothing);
      },
    );

    testWidgets('empty state renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: const [],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.text('LOADING_STUB'), findsNothing);
      expect(find.text('SECTION_TITLE:评论'), findsNothing);
    });

    testWidgets('populated renders all comments and the section title once', (
      tester,
    ) async {
      final comments = [
        _comment(userName: 'Alice', time: '1月1日'),
        _comment(userName: 'Bob', time: '1月2日'),
        _comment(userName: 'Charlie', time: '1月3日'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: comments,
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.text('SECTION_TITLE:评论'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('1月1日'), findsOneWidget);
      expect(find.text('1月2日'), findsOneWidget);
      expect(find.text('1月3日'), findsOneWidget);
    });

    testWidgets('scrolling near the bottom invokes onLoadMore', (tester) async {
      var loadMoreCalls = 0;
      final comments = List.generate(
        30,
        (index) => _comment(userName: 'User $index', time: '1月1日'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: comments,
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
              onLoadMore: () => loadMoreCalls++,
            ),
          ),
        ),
      );

      await tester.fling(find.byType(ListView), const Offset(0, -5000), 5000);
      await tester.pumpAndSettle();

      expect(loadMoreCalls, greaterThan(0));
    });

    testWidgets('sliver variant only builds viewport-visible comments', (
      tester,
    ) async {
      final comments = List.generate(
        50,
        (index) => _comment(userName: 'Sliver User $index', time: '1月1日'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                CommentsSliver(
                  comments: comments,
                  isLoading: false,
                  isLoadingMore: false,
                  isDarkBg: false,
                  sectionTitle: _buildSectionTitleStub('评论', false),
                  loadingPlaceholder: _loadingStub,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Sliver User 0'), findsOneWidget);
      expect(find.text('Sliver User 49'), findsNothing);
    });

    testWidgets(
      'rate renders exactly (rate/2) filled stars and the rest border',
      (tester) async {
        // rate: 8 -> (8/2).round() = 4 filled Icons.star and 1 Icons.star_border
        // out of the 5 generated icons. A single-card test has no other
        // Icons.star/star_border anywhere, so plain counts are unambiguous.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CommentsSection(
                comments: [_comment(userName: 'Rater', time: '1月1日', rate: 8)],
                isLoading: false,
                isLoadingMore: false,
                isDarkBg: false,
                sectionTitle: _buildSectionTitleStub('评论', false),
                loadingPlaceholder: _loadingStub,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsNWidgets(4));
        expect(find.byIcon(Icons.star_border), findsOneWidget);
      },
    );

    testWidgets('rate null produces zero star icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: [_comment(userName: 'NoRate', time: '1月1日')],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('isLoadingMore true renders trailing spinner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: [_comment(userName: 'Alice', time: '1月1日')],
              isLoading: false,
              isLoadingMore: true,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('isLoadingMore false omits trailing spinner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: [_comment(userName: 'Alice', time: '1月1日')],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('isDarkBg true renders without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: [_comment(userName: 'Dark', time: '1月1日')],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: true,
              sectionTitle: _buildSectionTitleStub('评论', true),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      expect(find.text('SECTION_TITLE:评论'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('HtmlWidget path renders without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: [
                _comment(
                  userName: 'Html',
                  time: '1月1日',
                  content: 'hello',
                  contentHtml: '<p>hello</p>',
                ),
              ],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      // Smoke: HtmlWidget wired correctly; no throw. Do not assert on
      // HtmlWidget internals.
      expect(find.text('Html'), findsOneWidget);
    });

    testWidgets('text_mask span renders BangumiCommentHtml', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsSection(
              comments: [
                _comment(
                  userName: 'Masker',
                  time: '1月1日',
                  contentHtml: '<span class="text_mask">剧透剧透</span>',
                ),
              ],
              isLoading: false,
              isLoadingMore: false,
              isDarkBg: false,
              sectionTitle: _buildSectionTitleStub('评论', false),
              loadingPlaceholder: _loadingStub,
            ),
          ),
        ),
      );

      // Masks soft-wrap as TextSpans via BangumiCommentHtml (not a block widget).
      expect(find.byType(BangumiCommentHtml), findsOneWidget);
      expect(find.text('Masker'), findsOneWidget);
    });
  });
}
