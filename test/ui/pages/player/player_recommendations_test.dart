// Phase 2 / Package E focused widget tests for the extracted
// `PlayerRecommendations` widget.
//
// The widget is a pure Flutter widget tree (no network, no WebView, no media
// player). Most test items use an empty `coverUrl`, which keeps their cards on
// the plain colored placeholder path. One focused case supplies a URL to assert
// the cover Hero tag. Tests cover loading, empty, populated vertical, populated
// horizontal, item-tap forwarding, Hero wiring, and the info/score branch of
// the vertical card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_recommendations.dart';

RankingAnime _item({
  String title = '标题',
  String bangumiId = 'bgm-0',
  String coverUrl = '',
  String info = '',
  double? score,
}) {
  return RankingAnime(
    title: title,
    bangumiId: bangumiId,
    coverUrl: coverUrl,
    info: info,
    score: score,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  group('PlayerRecommendations', () {
    testWidgets('loading state shows CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PlayerRecommendations(
            recommendations: [],
            isLoading: true,
            isVertical: false,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.playerRecommendationsEmpty), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('empty state shows localized copy and no spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PlayerRecommendations(
            recommendations: [],
            isLoading: false,
            isVertical: false,
          ),
        ),
      );

      expect(find.text(l10n.playerRecommendationsEmpty), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets(
      'populated vertical renders 3 cards and forwards the tapped item',
      (tester) async {
        final items = [
          _item(title: '标题A', bangumiId: 'bgm-A', info: '2023 / 动画'),
          _item(title: '标题B', bangumiId: 'bgm-B', info: '2022 / 漫画'),
          _item(title: '标题C', bangumiId: 'bgm-C', info: '2021 / 游戏'),
        ];
        final captured = <RankingAnime>[];

        await tester.pumpWidget(
          _wrap(
            PlayerRecommendations(
              recommendations: items,
              isLoading: false,
              isVertical: true,
              onItemTap: captured.add,
            ),
          ),
        );

        // Three item cards render.
        expect(find.byType(InkWell), findsNWidgets(3));
        expect(find.text('标题A'), findsOneWidget);
        expect(find.text('标题B'), findsOneWidget);
        expect(find.text('标题C'), findsOneWidget);
        // Vertical layout does not wrap items in a scroll view.
        expect(find.byType(SingleChildScrollView), findsNothing);

        await tester.tap(find.text('标题B'));
        await tester.pump();

        expect(captured, hasLength(1));
        expect(captured.single.bangumiId, 'bgm-B');
        expect(captured.single.title, '标题B');
      },
    );

    testWidgets(
      'populated horizontal renders 3 cards inside a horizontal scroll',
      (tester) async {
        final items = [
          _item(title: '横标A', bangumiId: 'bgm-A'),
          _item(title: '横标B', bangumiId: 'bgm-B'),
          _item(title: '横标C', bangumiId: 'bgm-C'),
        ];

        await tester.pumpWidget(
          _wrap(
            PlayerRecommendations(
              recommendations: items,
              isLoading: false,
              isVertical: false,
              onItemTap: (_) {},
            ),
          ),
        );

        expect(find.byType(InkWell), findsNWidgets(3));
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        // Each title is a descendant of the horizontal scroll view.
        for (final title in const ['横标A', '横标B', '横标C']) {
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.text(title),
            ),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('cover uses the tag expected by the details page', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerRecommendations(
            recommendations: [
              _item(
                title: 'Hero cover',
                bangumiId: 'bgm-hero',
                coverUrl: 'https://example.com/cover.jpg',
              ),
            ],
            isLoading: false,
            isVertical: false,
            onItemTap: (_) {},
          ),
        ),
      );

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'player_rec_bgm-hero');
    });

    testWidgets('vertical card renders info chip and score when present', (
      tester,
    ) async {
      final items = [
        _item(
          title: '带分数',
          bangumiId: 'bgm-scored',
          info: '2023 / 动画',
          score: 8.5,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          PlayerRecommendations(
            recommendations: items,
            isLoading: false,
            isVertical: true,
            onItemTap: (_) {},
          ),
        ),
      );

      // Info chip shows the part before " / ".
      expect(find.text('2023'), findsOneWidget);
      // Score text renders the double value, plus the star icon.
      expect(find.text('8.5'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('vertical card omits info chip and score when absent', (
      tester,
    ) async {
      final items = [_item(title: '无信息', bangumiId: 'bgm-bare', info: '')];

      await tester.pumpWidget(
        _wrap(
          PlayerRecommendations(
            recommendations: items,
            isLoading: false,
            isVertical: true,
            onItemTap: (_) {},
          ),
        ),
      );

      expect(find.text('无信息'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });
  });
}
