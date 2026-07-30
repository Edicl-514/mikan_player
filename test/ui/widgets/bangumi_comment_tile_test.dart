import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_tile.dart';

const _unexpectedDeepReply = BangumiEpisodeComment(
  id: 3,
  userName: 'Unexpected',
  userId: 'unexpected',
  avatar: '',
  time: '',
  state: 0,
  contentHtml: 'must not render',
  replies: [],
  reactions: [],
);

const _nestedReply = BangumiEpisodeComment(
  id: 2,
  userName: 'Carol',
  userId: 'carol',
  avatar: '',
  time: '2026-07-29',
  state: 0,
  contentHtml: 'nested',
  replies: [_unexpectedDeepReply],
  reactions: [],
);

const _topReply = BangumiEpisodeComment(
  id: 1,
  userName: 'Bob',
  userId: 'bob',
  avatar: '',
  time: '2026-07-29',
  state: 0,
  contentHtml: 'reply body',
  replies: [_nestedReply],
  reactions: [],
);

Widget _wrap({required Widget child, bool isDark = false}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: ThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('BangumiCommentTile', () {
    testWidgets('renders author, time and content for a top-level comment', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(child: BangumiCommentTile(comment: _topReply, isDarkBg: false)),
      );
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Unexpected'), findsNothing);
      expect(find.text('must not render'), findsNothing);
      // Top-level and nested replies each go through BangumiCommentBody.
      expect(find.byType(BangumiCommentBody), findsNWidgets(2));
    });

    testWidgets('cascades the floor label onto nested replies', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: BangumiCommentTile(
            comment: _topReply,
            isDarkBg: false,
            floorLabel: '#2',
          ),
        ),
      );
      // Top tile carries the floor label verbatim.
      expect(find.text('#2'), findsOneWidget);
      // Nested reply gets the cascading '#2-1' label.
      expect(find.text('#2-1'), findsOneWidget);
    });

    testWidgets('omits the floor label entirely when no label is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(child: BangumiCommentTile(comment: _topReply, isDarkBg: false)),
      );
      // No '#'-prefixed floor labels at all when the parent has none, and the
      // nested reply stays unlabelled too (the cascading helper returns null).
      expect(find.textContaining(RegExp(r'^#')), findsNothing);
    });

    testWidgets(
      'respects comment state and hides content for deleted comments',
      (tester) async {
        const hidden = BangumiEpisodeComment(
          id: 99,
          userName: 'Ghost',
          userId: 'ghost',
          avatar: '',
          time: '',
          state: 6,
          contentHtml: 'should not be visible',
          replies: [],
          reactions: [],
        );

        await tester.pumpWidget(
          _wrap(child: BangumiCommentTile(comment: hidden, isDarkBg: false)),
        );
        expect(find.text('Ghost'), findsOneWidget);
        expect(find.text('should not be visible'), findsNothing);
      },
    );
  });
}
