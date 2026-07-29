import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/character_detail_page.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';

void main() {
  final sampleDetails = CharacterDetails(
    id: 101,
    name: 'Character A',
    summary: 'A test character',
    gender: 'female',
    stat: const CharacterStat(comments: 2, collects: 5),
    infobox: const [],
  );

  final sampleComments = [
    const BangumiEpisodeComment(
      id: 1,
      userName: 'Alice',
      userId: 'alice123',
      avatar: '',
      time: '2026-07-29',
      state: 0,
      contentHtml: 'Nice character!',
      replies: [],
      reactions: [],
    ),
  ];

  Widget buildTestApp({
    required Widget child,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: brightness),
      home: Material(child: child),
    );
  }

  group('CharacterDetailPage Comments', () {
    testWidgets('renders loaded comments on mobile in light theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: CharacterDetailPage(
            characterId: 101,
            loadDetails: (_) async => sampleDetails,
            loadSubjects: (_) async => [],
            loadComments: (_) async => sampleComments,
          ),
          brightness: Brightness.light,
        ),
      );

      await tester.pumpAndSettle();

      final commentsTab = find.widgetWithText(Tab, '角色吐槽');
      expect(commentsTab, findsOneWidget);
      await tester.tap(commentsTab);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(BangumiCommentBody), findsOneWidget);
    });

    testWidgets(
      'renders comments on desktop layout with fixed dark background',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestApp(
            child: CharacterDetailPage(
              characterId: 101,
              loadDetails: (_) async => sampleDetails,
              loadSubjects: (_) async => [],
              loadComments: (_) async => sampleComments,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final commentsSegment = find.text('角色吐槽');
        expect(commentsSegment, findsOneWidget);
        await tester.tap(commentsSegment);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Alice'), findsOneWidget);
        expect(find.byType(BangumiCommentBody), findsOneWidget);
      },
    );

    testWidgets('shows retry button when loadComments fails on mobile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int callCount = 0;
      await tester.pumpWidget(
        buildTestApp(
          child: CharacterDetailPage(
            characterId: 101,
            loadDetails: (_) async => sampleDetails,
            loadSubjects: (_) async => [],
            loadComments: (_) async {
              callCount++;
              if (callCount == 1) {
                throw Exception('Network error');
              }
              return sampleComments;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final commentsTab = find.widgetWithText(Tab, '角色吐槽');
      expect(commentsTab, findsOneWidget);
      await tester.tap(commentsTab);
      await tester.pumpAndSettle();

      final retryButton = find.widgetWithText(ElevatedButton, '重试');
      expect(retryButton, findsOneWidget);
      // The failed state must surface the dedicated error copy, NOT the
      // "no comments yet" placeholder that doubles as the empty-state copy.
      expect(find.text('角色吐槽加载失败'), findsOneWidget);
      expect(find.text('暂无角色吐槽'), findsNothing);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(BangumiCommentBody), findsOneWidget);
    });

    testWidgets('does not request comments until the comments tab is opened', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int callCount = 0;
      await tester.pumpWidget(
        buildTestApp(
          child: CharacterDetailPage(
            characterId: 101,
            loadDetails: (_) async => sampleDetails,
            loadSubjects: (_) async => [],
            loadComments: (_) async {
              callCount++;
              return sampleComments;
            },
          ),
        ),
      );

      // Let the page itself and the details/subjects load finish without
      // touching the comments tab.
      await tester.pumpAndSettle();
      expect(callCount, 0);

      // Only after the user explicitly opens the comments tab does the page
      // kick off the fetch; this avoids a wasted request for users who never
      // look at the comments.
      await tester.tap(find.widgetWithText(Tab, '角色吐槽'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(callCount, 1);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('ignores a stale comment result after the character changes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pending = <int, Completer<List<BangumiEpisodeComment>>>{};
      Future<List<BangumiEpisodeComment>> loadComments(int id) =>
          (pending[id] ??= Completer<List<BangumiEpisodeComment>>()).future;

      Widget page(int id) => buildTestApp(
        child: CharacterDetailPage(
          characterId: id,
          loadDetails: (_) async => sampleDetails,
          loadSubjects: (_) async => [],
          loadComments: loadComments,
        ),
      );

      await tester.pumpWidget(page(101));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, '角色吐槽'));
      await tester.pump();
      expect(pending, contains(101));

      await tester.pumpWidget(page(102));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, '角色吐槽'));
      await tester.pump();
      expect(pending, contains(102));

      pending[102]!.complete([
        const BangumiEpisodeComment(
          id: 102,
          userName: 'Current character',
          userId: 'current',
          avatar: '',
          time: '',
          state: 0,
          contentHtml: 'current comment',
          replies: [],
          reactions: [],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Current character'), findsOneWidget);

      pending[101]!.complete([
        const BangumiEpisodeComment(
          id: 101,
          userName: 'Stale character',
          userId: 'stale',
          avatar: '',
          time: '',
          state: 0,
          contentHtml: 'stale comment',
          replies: [],
          reactions: [],
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Current character'), findsOneWidget);
      expect(find.text('Stale character'), findsNothing);
    });
  });
}
