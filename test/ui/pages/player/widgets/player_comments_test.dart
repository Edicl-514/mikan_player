// Phase 2 / Package E2 focused widget tests for the extracted
// `PlayerComments` widget.
//
// No network, no WebView, no media — all test instances use empty
// contentHtml/avatar to avoid real network fetches and HTML decode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comments.dart';

BangumiEpisodeComment _comment({
  int id = 1,
  String userName = '',
  String userId = '',
  String avatar = '',
  String time = '',
  String contentHtml = '',
  List<BangumiEpisodeComment> replies = const [],
}) => BangumiEpisodeComment(
  id: id,
  userName: userName,
  userId: userId,
  avatar: avatar,
  time: time,
  contentHtml: contentHtml,
  replies: replies,
);

void main() {
  group('PlayerComments', () {
    testWidgets('loading state shows CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: const [],
              isLoading: true,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error state shows error text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: const [],
              isLoading: false,
              error: 'network timeout',
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.text('加载失败: network timeout'), findsOneWidget);
    });

    testWidgets('empty state shows "暂无评论"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: const [],
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.text('暂无评论'), findsOneWidget);
    });

    testWidgets('populated renders comment items with user names', (
      tester,
    ) async {
      final comments = [
        _comment(id: 1, userName: 'Alice', time: '1月1日', contentHtml: ''),
        _comment(id: 2, userName: 'Bob', time: '1月2日', contentHtml: ''),
        _comment(id: 3, userName: 'Charlie', time: '1月3日', contentHtml: ''),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: comments,
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.text('全部评论'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('1月1日'), findsOneWidget);
      expect(find.text('1月2日'), findsOneWidget);
      expect(find.text('1月3日'), findsOneWidget);
    });

    testWidgets('sortButton is rendered when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: [_comment(id: 1, userName: 'Test', contentHtml: '')],
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
              sortButton: const Text('SORT_BTN'),
            ),
          ),
        ),
      );

      expect(find.text('SORT_BTN'), findsOneWidget);
    });
  });
}
