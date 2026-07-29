import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/person_detail_page.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';

void main() {
  final sampleDetails = PersonDetails(
    id: 201,
    name: 'Person B',
    summary: 'A test person',
    img: '',
    career: ['seiyu'],
    personType: 1,
    stat: const CharacterStat(comments: 3, collects: 10),
    infobox: const [],
    locked: false,
  );

  final sampleComments = [
    const BangumiEpisodeComment(
      id: 2,
      userName: 'Bob',
      userId: 'bob456',
      avatar: '',
      time: '2026-07-29',
      state: 0,
      contentHtml: 'Great voice actor!',
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

  group('PersonDetailPage Comments', () {
    testWidgets('renders loaded comments on mobile in light theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: PersonDetailPage(
            personId: 201,
            loadDetails: (_) async => sampleDetails,
            loadSubjects: (_) async => [],
            loadCharacters: (_) async => [],
            loadComments: (_) async => sampleComments,
          ),
          brightness: Brightness.light,
        ),
      );

      await tester.pumpAndSettle();

      final commentsTab = find.widgetWithText(Tab, '人物吐槽');
      expect(commentsTab, findsOneWidget);
      await tester.tap(commentsTab);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bob'), findsOneWidget);
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
            child: PersonDetailPage(
              personId: 201,
              loadDetails: (_) async => sampleDetails,
              loadSubjects: (_) async => [],
              loadCharacters: (_) async => [],
              loadComments: (_) async => sampleComments,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final commentsSegment = find.text('人物吐槽');
        expect(commentsSegment, findsOneWidget);
        await tester.tap(commentsSegment);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Bob'), findsOneWidget);
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
          child: PersonDetailPage(
            personId: 201,
            loadDetails: (_) async => sampleDetails,
            loadSubjects: (_) async => [],
            loadCharacters: (_) async => [],
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

      final commentsTab = find.widgetWithText(Tab, '人物吐槽');
      expect(commentsTab, findsOneWidget);
      await tester.tap(commentsTab);
      await tester.pumpAndSettle();

      final retryButton = find.widgetWithText(ElevatedButton, '重试');
      expect(retryButton, findsOneWidget);
      // The failed state must surface the dedicated error copy, NOT the
      // "no comments yet" placeholder that doubles as the empty-state copy.
      expect(find.text('人物吐槽加载失败'), findsOneWidget);
      expect(find.text('暂无人物吐槽'), findsNothing);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bob'), findsOneWidget);
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
          child: PersonDetailPage(
            personId: 201,
            loadDetails: (_) async => sampleDetails,
            loadSubjects: (_) async => [],
            loadCharacters: (_) async => [],
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
      await tester.tap(find.widgetWithText(Tab, '人物吐槽'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(callCount, 1);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('ignores a stale comment failure after the person changes', (
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
        child: PersonDetailPage(
          personId: id,
          loadDetails: (_) async => sampleDetails,
          loadSubjects: (_) async => [],
          loadCharacters: (_) async => [],
          loadComments: loadComments,
        ),
      );

      await tester.pumpWidget(page(201));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, '人物吐槽'));
      await tester.pump();
      expect(pending, contains(201));

      await tester.pumpWidget(page(202));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, '人物吐槽'));
      await tester.pump();
      expect(pending, contains(202));

      pending[202]!.complete([
        const BangumiEpisodeComment(
          id: 202,
          userName: 'Current person',
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
      expect(find.text('Current person'), findsOneWidget);

      pending[201]!.completeError(Exception('stale failure'));
      await tester.pumpAndSettle();

      expect(find.text('Current person'), findsOneWidget);
      expect(find.text('人物吐槽加载失败'), findsNothing);
    });
  });
}
