// Phase 1.7 smoke tests for extracted player UI section widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comment_sort_button.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_current_source_actions.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_onair_sites_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_pc_episode_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_section_header.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_progress_item.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: Scaffold(body: child),
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  testWidgets('PlayerSectionHeader shows title', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerSectionHeader('播放源')));
    expect(find.text('播放源'), findsOneWidget);
  });

  testWidgets('PlayerCommentSortButton shows mode label and fires onSelected', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _wrap(
        PlayerCommentSortButton(
          sortMode: 'default',
          onSelected: (v) => selected = v,
        ),
      ),
    );
    expect(find.text(l10n.playerSortDefault), findsOneWidget);
    await tester.tap(find.byType(PlayerCommentSortButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.playerSortByTime).last);
    await tester.pumpAndSettle();
    expect(selected, 'time');
  });

  testWidgets('PlayerCurrentSourceActions disables when canAct=false', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        PlayerCurrentSourceActions(
          canAct: false,
          onDownload: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.text(l10n.playerDownloadButton));
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('PlayerSourceProgressItem maps failed step', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PlayerSourceProgressItem(
          sourceName: 'srcA',
          progress: SourceSearchProgress(
            sourceName: 'srcA',
            step: SearchStep.failed,
            error: 'boom',
            playPageUrl: null,
            videoRegex: null,
            directVideoUrl: null,
            cookies: null,
            headers: null,
            enableNestedUrl: false,
          ),
        ),
      ),
    );
    expect(find.text('srcA'), findsOneWidget);
    expect(find.text(l10n.playerSearchProgressStepFailed), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('PlayerOnairSitesList renders titles', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PlayerOnairSitesList(
          sites: [
            BangumiDataSiteEntry(
              site: 'bilibili',
              title: '哔哩哔哩',
              url: 'https://example.com',
              kind: 'onair',
            ),
          ],
        ),
      ),
    );
    expect(find.text('哔哩哔哩'), findsOneWidget);
  });

  testWidgets('PlayerPcEpisodeList selects episode', (tester) async {
    final eps = [
      const BangumiEpisode(
        id: 1,
        name: 'EP1',
        nameCn: '第一集',
        description: '',
        airdate: '2024-01-01',
        duration: '',
        sort: 1,
      ),
      const BangumiEpisode(
        id: 2,
        name: 'EP2',
        nameCn: '第二集',
        description: '',
        airdate: '2024-01-08',
        duration: '',
        sort: 2,
      ),
    ];
    BangumiEpisode? picked;
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          height: 400,
          child: PlayerPcEpisodeList(
            episodes: eps,
            currentEpisode: eps.first,
            scrollController: ScrollController(),
            onEpisodeSelected: (e) => picked = e,
          ),
        ),
      ),
    );
    expect(find.text('第一集'), findsOneWidget);
    await tester.tap(find.text('第二集'));
    await tester.pump();
    expect(picked?.id, 2);
  });

  testWidgets('PlayerPcEpisodeList scrolls when content overflows', (
    tester,
  ) async {
    final eps = List.generate(
      20,
      (i) => BangumiEpisode(
        id: i + 1,
        name: 'EP${i + 1}',
        nameCn: '第${i + 1}集',
        description: '',
        airdate: '',
        duration: '',
        sort: (i + 1).toDouble(),
      ),
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        SizedBox(
          height: 200,
          child: PlayerPcEpisodeList(
            episodes: eps,
            currentEpisode: eps.first,
            scrollController: controller,
            onEpisodeSelected: (_) {},
          ),
        ),
      ),
    );

    expect(controller.hasClients, isTrue);
    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(find.text('第1集'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(find.text('第1集'), findsNothing);
  });
}
