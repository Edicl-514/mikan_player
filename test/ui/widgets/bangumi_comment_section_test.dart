import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_section.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_tile.dart';

const _comment = BangumiEpisodeComment(
  id: 1,
  userName: 'Alice',
  userId: 'alice',
  avatar: '',
  time: '2026-07-29',
  state: 0,
  contentHtml: 'Hi',
  replies: [],
  reactions: [],
);

Widget _wrap({
  required Widget child,
  bool useSliver = false,
  Brightness brightness = Brightness.light,
}) {
  final inner = useSliver
      ? CustomScrollView(slivers: [child])
      : Material(child: child);
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    theme: ThemeData(brightness: brightness),
    home: inner,
  );
}

void main() {
  group('BangumiCommentSection', () {
    testWidgets('box: loading state shows a spinner', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: BangumiCommentSection(
            isLoading: true,
            failed: false,
            comments: const [],
            isDarkBg: false,
            emptyMessage: 'empty',
            errorMessage: 'error',
            retryLabel: '重试',
            onRetry: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('box: empty state uses the empty message (not the error one)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: BangumiCommentSection(
            isLoading: false,
            failed: false,
            comments: const [],
            isDarkBg: false,
            emptyMessage: '暂无吐槽',
            errorMessage: '吐槽加载失败',
            retryLabel: '重试',
            onRetry: () {},
          ),
        ),
      );
      expect(find.text('暂无吐槽'), findsOneWidget);
      expect(find.text('吐槽加载失败'), findsNothing);
    });

    testWidgets('box: failed state uses the error message and exposes retry', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _wrap(
          child: BangumiCommentSection(
            isLoading: false,
            failed: true,
            comments: const [],
            isDarkBg: false,
            emptyMessage: '暂无吐槽',
            errorMessage: '吐槽加载失败',
            retryLabel: '重试',
            onRetry: () => retries++,
          ),
        ),
      );
      expect(find.text('吐槽加载失败'), findsOneWidget);
      expect(find.text('暂无吐槽'), findsNothing);
      await tester.tap(find.text('重试'));
      expect(retries, 1);
    });

    testWidgets('box: list state renders one tile per comment', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: BangumiCommentSection(
            isLoading: false,
            failed: false,
            comments: const [_comment],
            isDarkBg: false,
            emptyMessage: 'empty',
            errorMessage: 'error',
            retryLabel: '重试',
            onRetry: () {},
          ),
        ),
      );
      expect(find.byType(BangumiCommentTile), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets(
      'sliver: failed state is wrapped as a sliver and still uses the error message',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            useSliver: true,
            child: BangumiCommentSection(
              isLoading: false,
              failed: true,
              comments: const [],
              isDarkBg: true,
              useSliver: true,
              sliverPadding: const EdgeInsets.symmetric(horizontal: 32),
              emptyMessage: 'empty',
              errorMessage: '吐槽加载失败',
              retryLabel: '重试',
              onRetry: () {},
            ),
          ),
        );
        expect(find.text('吐槽加载失败'), findsOneWidget);
        // The sliver variant must be placed inside a CustomScrollView and render
        // its content via SliverToBoxAdapter for the error card.
        expect(find.byType(CustomScrollView), findsOneWidget);
      },
    );

    testWidgets('sliver: list state renders one tile per comment', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          useSliver: true,
          child: BangumiCommentSection(
            isLoading: false,
            failed: false,
            comments: const [_comment],
            isDarkBg: false,
            useSliver: true,
            sliverPadding: const EdgeInsets.symmetric(horizontal: 32),
            emptyMessage: 'empty',
            errorMessage: 'error',
            retryLabel: '重试',
            onRetry: () {},
          ),
        ),
      );
      expect(find.byType(BangumiCommentTile), findsOneWidget);
    });
  });
}
