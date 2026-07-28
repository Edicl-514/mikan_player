// L10N-5 bilingual smoke tests for player widgets.
//
// The plan §4 L10N-5 item 4 requires running the key PlayerPage sub-widgets
// in both zh and en under the smallest mobile width to catch layout regressions
// caused by English text being longer than the original Chinese.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/player/widgets/bt_resource.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comments.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_current_source_actions.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_mobile_layout.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_pc_layout.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_recommendations.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_resource_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_sample_source_panel.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_selector.dart';

Widget _wrap(Widget child, {required Locale locale}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: child),
  );
}

BangumiEpisodeComment _comment({int id = 1, String userName = 'Alice'}) =>
    BangumiEpisodeComment(
      id: id,
      userName: userName,
      userId: 'u$id',
      avatar: '',
      time: '2024-01-01',
      state: 0,
      contentHtml: 'Hello',
      replies: const [],
      reactions: const [],
    );

BangumiEpisode _ep({int id = 1, double sort = 1}) => BangumiEpisode(
  id: id,
  name: 'Episode $id',
  nameCn: '第$id集',
  description: 'desc',
  airdate: '',
  duration: '',
  sort: sort,
);

RankingAnime _item({String title = 'Anime', String id = 'bgm-0'}) =>
    RankingAnime(
      title: title,
      bangumiId: id,
      coverUrl: '',
      info: '',
      score: null,
    );

BtResource _res({String title = 'T', int? episode}) => BtResource(
  title: title,
  magnet: 'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
  size: '1.0GB',
  time: '2024-01-01',
  episode: episode,
);

Future<void> _pumpFor(
  WidgetTester tester,
  Widget widget, {
  required Locale locale,
  Size size = const Size(360, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_wrap(widget, locale: locale));
  await tester.pump();
}

void main() {
  for (final locale in const [Locale('zh'), Locale('en')]) {
    group('player widget L10N-5 bilingual smoke ($locale)', () {
      testWidgets('PlayerComments empty state does not overflow', (
        tester,
      ) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await _pumpFor(
          tester,
          PlayerComments(
            comments: const [],
            isLoading: false,
            error: null,
            scrollController: scrollController,
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerComments populated does not overflow', (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await _pumpFor(
          tester,
          PlayerComments(
            comments: List.generate(
              3,
              (i) => _comment(id: i, userName: 'User $i'),
            ),
            isLoading: false,
            error: null,
            scrollController: scrollController,
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerRecommendations empty/loading does not overflow', (
        tester,
      ) async {
        await _pumpFor(
          tester,
          const PlayerRecommendations(
            recommendations: [],
            isLoading: true,
            isVertical: false,
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);

        await _pumpFor(
          tester,
          const PlayerRecommendations(
            recommendations: [],
            isLoading: false,
            isVertical: false,
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerRecommendations populated does not overflow', (
        tester,
      ) async {
        final items = List.generate(
          3,
          (i) => _item(title: 'Anime $i', id: 'bgm-$i'),
        );
        await _pumpFor(
          tester,
          PlayerRecommendations(
            recommendations: items,
            isLoading: false,
            isVertical: true,
            onItemTap: (_) {},
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerResourceList empty/loading does not overflow', (
        tester,
      ) async {
        await _pumpFor(
          tester,
          BtResourceList(
            resources: const [],
            isExpanded: true,
            isLoading: false,
            hasError: false,
            loadingMagnet: null,
            isPlayBlocked: false,
            onRetrySearch: () {},
            onCopyMagnet: (_) {},
            onDownload: (_) {},
            onPlay: (_) {},
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerResourceList populated does not overflow', (
        tester,
      ) async {
        final resources = List.generate(
          3,
          (i) => _res(title: 'Resource $i', episode: i + 1),
        );
        await _pumpFor(
          tester,
          BtResourceList(
            resources: resources,
            isExpanded: true,
            isLoading: false,
            hasError: false,
            loadingMagnet: null,
            isPlayBlocked: false,
            onRetrySearch: () {},
            onCopyMagnet: (_) {},
            onDownload: (_) {},
            onPlay: (_) {},
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerCurrentSourceActions does not overflow', (
        tester,
      ) async {
        await _pumpFor(
          tester,
          PlayerCurrentSourceActions(
            canAct: true,
            onDownload: () {},
            onCopyUrl: () {},
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerSourceSelector collapsed does not overflow', (
        tester,
      ) async {
        await _pumpFor(
          tester,
          PlayerSourceSelector(
            isMobile: true,
            isExpanded: false,
            activeSource: 'bt',
            btCount: 3,
            onlineCount: 12,
            currentLabel: 'Very long current source name that would clip',
            isBtLoading: false,
            hasBtError: false,
            isSampleLoading: false,
            hasSampleError: false,
            onExpand: () {},
            onCollapse: () {},
            onSelectSource: (_) {},
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerSampleSourcePanel empty state does not overflow', (
        tester,
      ) async {
        final status = ValueNotifier<String>('');
        addTearDown(status.dispose);
        await _pumpFor(
          tester,
          PlayerSampleSourcePanel(
            isLoadingSample: false,
            sampleError: null,
            enabledSourceNames: const [],
            sourceProgressMap: const {},
            successfulSources: const <SearchPlayResult>[],
            selectedSourceIndex: 0,
            sampleVideoUrl: null,
            statusMessageListenable: status,
            disableAutoSourceSearchForCurrentEpisode: false,
            autoSearchOnline: true,
            hasActiveWebViewTasks: false,
            activeWebViewTaskCount: 0,
            maxConcurrentWebViews: 2,
            workerPoolLabel: null,
            webviewStatsLabel: '',
            perSourceStatusLabel: '',
            showWebView: false,
            onShowWebViewChanged: (_) {},
            useWorkerPool: true,
            onUseWorkerPoolChanged: (_) {},
            activeTaskRows: const [],
            onSourceSelected: (_) {},
            onPlaySelected: null,
            onManualSearch: () {},
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerMobileLayout builds without overflow at 360px', (
        tester,
      ) async {
        final tabController = TabController(
          length: 2,
          vsync: const TestVSync(),
        );
        addTearDown(tabController.dispose);
        await _pumpFor(
          tester,
          PlayerMobileLayout(
            videoArea: const ColoredBox(
              color: Colors.black,
              child: Center(child: Text('VIDEO')),
            ),
            tabController: tabController,
            commentsCount: 1234,
            infoTab: const Center(child: Text('INFO')),
            commentsTab: const Center(child: Text('COMMENTS')),
          ),
          locale: locale,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerMobileInfoLayout renders without overflow', (
        tester,
      ) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final episodeScroll = ScrollController();
        addTearDown(episodeScroll.dispose);
        await _pumpFor(
          tester,
          PlayerMobileInfoLayout(
            animeTitle: 'A long anime title that may overflow the header row',
            currentEpisode: _ep(),
            playableEpisodeCount: 24,
            isDescriptionExpanded: false,
            onToggleDescription: () {},
            currentSourceActions: const SizedBox.shrink(),
            episodeStrip: PlayerMobileEpisodeStrip(
              episodes: List.generate(5, (i) => _ep(id: i, sort: i + 1)),
              currentEpisode: _ep(),
              isExpanded: false,
              scrollController: episodeScroll,
              onToggleExpanded: () {},
              onEpisodeSelected: (_) {},
            ),
            playSourceSelector: const Text('SOURCE_SELECTOR'),
            resourceList: const Text('RESOURCE_LIST'),
            onairSites: const [],
            recommendations: List.generate(
              3,
              (i) => _item(title: 'Anime $i', id: 'bgm-$i'),
            ),
            isLoadingRecommendations: false,
            onRecommendationTap: (_) {},
            scrollController: scroll,
          ),
          locale: locale,
          size: const Size(360, 1200),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('PlayerPcLayout renders at a common desktop width', (
        tester,
      ) async {
        final episodeScroll = ScrollController();
        final mainScroll = ScrollController();
        final sidebarScroll = ScrollController();
        addTearDown(episodeScroll.dispose);
        addTearDown(mainScroll.dispose);
        addTearDown(sidebarScroll.dispose);

        await _pumpFor(
          tester,
          PlayerPcLayout(
            animeTitle: 'A long localized anime title for desktop overflow',
            currentEpisode: _ep(),
            currentSourceActions: const SizedBox.shrink(),
            videoArea: const ColoredBox(color: Colors.black),
            isDescriptionExpanded: false,
            onToggleDescription: () {},
            playSourceSelector: const Text('SOURCE_SELECTOR'),
            resourceList: const Text('RESOURCE_LIST'),
            onairSites: const [],
            commentSortButton: const Text('SORT'),
            comments: const [],
            isLoadingComments: false,
            commentsError: null,
            playableEpisodes: List.generate(
              12,
              (i) => _ep(id: i + 1, sort: i + 1),
            ),
            episodeScrollController: episodeScroll,
            onEpisodeSelected: (_) {},
            recommendations: List.generate(
              3,
              (i) => _item(title: 'Anime $i', id: 'desktop-$i'),
            ),
            isLoadingRecommendations: false,
            onRecommendationTap: (_) {},
            mainScrollController: mainScroll,
            sidebarScrollController: sidebarScroll,
          ),
          locale: locale,
          size: const Size(1280, 800),
        );

        expect(tester.view.physicalSize, const Size(1280, 800));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
