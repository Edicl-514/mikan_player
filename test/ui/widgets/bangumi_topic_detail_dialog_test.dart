import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/bangumi_reaction_badge.dart';
import 'package:mikan_player/ui/widgets/bangumi_topic_detail_dialog.dart';

const _topic = BangumiTopic(
  id: 24339,
  userId: 'moyis',
  userName: 'Uaoko',
  avatar: '',
  title: 'Topic preview',
  time: '2026-07-29',
  updatedAt: '2026-07-29 10:00',
  repliesCount: 24,
);

const _reaction = BangumiCommentReaction(
  name: 'bgm38',
  imageUrl: 'https://lain.bgm.tv/img/smiles/tv/15.gif',
  count: 3,
  reacted: true,
);

const _reply = BangumiEpisodeComment(
  id: 3002,
  userName: 'Bob',
  userId: 'bob',
  avatar: '',
  time: '2026-07-29',
  state: 0,
  contentHtml: 'Floor two body',
  replies: [],
  reactions: [_reaction],
);

BangumiTopicDetail _detail({
  int contentState = 0,
  String contentHtml = 'Opening post body',
  List<BangumiCommentReaction> reactions = const [_reaction],
  List<BangumiEpisodeComment> replies = const [_reply],
}) => BangumiTopicDetail(
  id: 24339,
  title: 'Topic detail',
  userId: 'moyis',
  userName: 'Uaoko',
  avatar: '',
  time: '2026-07-29',
  updatedAt: '2026-07-29 10:00',
  repliesCount: 24,
  content: contentHtml,
  contentHtml: contentHtml,
  contentState: contentState,
  reactions: reactions,
  replies: replies,
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
  testWidgets('renders the opening post, its reactions, and floor replies', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        BangumiTopicDetailDialog(
          topic: _topic,
          fetchDetail: (_) async => _detail(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Topic detail'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    // Opening post is floor #1, the first reply is #2.
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    // One badge for the opening post, one for the reply.
    expect(find.byType(BangumiReactionBadge), findsNWidgets(2));
  });

  testWidgets('a deleted opening post is not rendered as normal content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        BangumiTopicDetailDialog(
          topic: _topic,
          fetchDetail: (_) async => _detail(
            contentState: 6,
            contentHtml: 'should not be shown',
            replies: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该评论不可见'), findsOneWidget);
    expect(find.byType(BangumiCommentHtml), findsNothing);
    // Reactions belong to content that is no longer viewable.
    expect(find.byType(BangumiReactionBadge), findsNothing);
  });

  testWidgets('a folded opening post stays collapsed until asked for', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        BangumiTopicDetailDialog(
          topic: _topic,
          fetchDetail: (_) async => _detail(
            contentState: 8,
            contentHtml: 'folded body',
            replies: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该评论已折叠'), findsOneWidget);
    expect(find.byType(BangumiCommentHtml), findsNothing);

    await tester.tap(find.text('展开'));
    await tester.pumpAndSettle();

    expect(find.byType(BangumiCommentHtml), findsOneWidget);
  });

  testWidgets('load failure shows localized copy and retries', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      _wrap(
        BangumiTopicDetailDialog(
          topic: _topic,
          fetchDetail: (_) async {
            attempts++;
            if (attempts == 1) throw Exception('private upstream text');
            return _detail();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('讨论帖内容加载失败'), findsOneWidget);
    expect(find.textContaining('private upstream text'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('讨论帖内容加载失败'), findsNothing);
    expect(find.text('Topic detail'), findsOneWidget);
  });
}
