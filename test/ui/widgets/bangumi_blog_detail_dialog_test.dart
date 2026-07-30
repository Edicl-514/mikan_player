import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/bangumi_blog_detail_dialog.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';

const _review = BangumiReview(
  id: 1,
  entryId: 101,
  userId: 'alice',
  userName: 'Alice',
  avatar: '',
  title: 'Review preview',
  summary: 'Summary',
  time: '2026-07-29',
  repliesCount: 1,
);

const _detail = BangumiBlogDetail(
  id: 101,
  title: 'Review detail',
  summary: 'Summary',
  content: 'Full body',
  contentHtml: 'Full body',
  userId: 'alice',
  userName: 'Alice',
  avatar: '',
  time: '2026-07-29',
  repliesCount: 1,
  tags: [],
  reactions: [],
);

const _comment = BangumiEpisodeComment(
  id: 201,
  userName: 'Bob',
  userId: 'bob',
  avatar: '',
  time: '2026-07-29',
  state: 0,
  contentHtml: 'Comment body',
  replies: [],
  reactions: [],
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows the review while comments are still loading', (
    tester,
  ) async {
    final comments = Completer<List<BangumiEpisodeComment>>();

    await tester.pumpWidget(
      _wrap(
        BangumiBlogDetailDialog(
          review: _review,
          fetchDetail: (_) async => _detail,
          fetchComments: (_) => comments.future,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Review detail'), findsOneWidget);
    expect(find.byType(BangumiCommentHtml), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    comments.complete(const [_comment]);
    await tester.pumpAndSettle();
  });

  testWidgets('comments failure does not hide a successfully loaded review', (
    tester,
  ) async {
    var commentsAttempts = 0;

    await tester.pumpWidget(
      _wrap(
        BangumiBlogDetailDialog(
          review: _review,
          fetchDetail: (_) async => _detail,
          fetchComments: (_) async {
            commentsAttempts++;
            if (commentsAttempts == 1) throw Exception('private upstream text');
            return const [_comment];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review detail'), findsOneWidget);
    expect(find.text('长评评论加载失败'), findsOneWidget);
    expect(find.textContaining('private upstream text'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(commentsAttempts, 2);
    expect(find.text('长评评论加载失败'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets(
    'detail failure uses localized copy without exposing raw errors',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          BangumiBlogDetailDialog(
            review: _review,
            fetchDetail: (_) async => throw Exception('private upstream text'),
            fetchComments: (_) async => const [_comment],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('长评正文加载失败'), findsOneWidget);
      expect(find.textContaining('private upstream text'), findsNothing);
    },
  );

  testWidgets('builds comments lazily in a sliver list', (tester) async {
    final comments = List.generate(
      100,
      (index) => BangumiEpisodeComment(
        id: index,
        userName: 'Author $index',
        userId: 'user-$index',
        avatar: '',
        time: '',
        state: 0,
        contentHtml: 'Comment $index',
        replies: const [],
        reactions: const [],
      ),
    );

    await tester.pumpWidget(
      _wrap(
        BangumiBlogDetailDialog(
          review: _review,
          fetchDetail: (_) async => _detail,
          fetchComments: (_) async => comments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Author 0'), findsOneWidget);
    expect(find.text('Author 99'), findsNothing);
  });
}
