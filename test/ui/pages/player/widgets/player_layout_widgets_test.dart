// Phase 1.7+ independent layout/widget smoke tests.
//
// These cover the UI files that were converted from `_PlayerPageState`
// extensions into real StatelessWidgets with explicit props. They do not
// boot MediaKit / WebView / Rust, so they can run in pure flutter_test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_mobile_layout.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_sample_source_panel.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_selector.dart';

Widget _wrap(Widget child, {Size size = const Size(400, 800)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

BangumiEpisode _ep({int id = 1, double sort = 1}) => BangumiEpisode(
  id: id,
  name: 'Episode $id',
  nameCn: '第$id集',
  description: 'desc',
  airdate: '',
  duration: '',
  sort: sort,
);

void main() {
  testWidgets('PlayerSourceSelector collapsed shows counts and expands', (
    tester,
  ) async {
    var expanded = false;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return PlayerSourceSelector(
              isMobile: true,
              isExpanded: expanded,
              activeSource: 'bt',
              btCount: 3,
              onlineCount: 2,
              currentLabel: 'BT',
              isBtLoading: false,
              hasBtError: false,
              isSampleLoading: false,
              hasSampleError: false,
              onExpand: () => setState(() => expanded = true),
              onCollapse: () => setState(() => expanded = false),
              onSelectSource: (_) {},
            );
          },
        ),
      ),
    );

    expect(find.textContaining('已找到'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(PlayerSourceSelector));
    await tester.pump();
    expect(find.text('BT'), findsOneWidget);
    expect(find.text('订阅源'), findsOneWidget);
  });

  testWidgets('PlayerSampleSourcePanel empty state offers manual search', (
    tester,
  ) async {
    var searched = false;
    final status = ValueNotifier<String>('');
    addTearDown(status.dispose);

    await tester.pumpWidget(
      _wrap(
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
          onManualSearch: () => searched = true,
        ),
      ),
    );

    expect(find.text('尚未开始搜索在线源'), findsWidgets);
    await tester.tap(find.text('搜索在线源'));
    await tester.pump();
    expect(searched, isTrue);
  });

  testWidgets('PlayerMobileLayout builds video + tabs without overflow', (
    tester,
  ) async {
    final tabController = TabController(length: 2, vsync: const TestVSync());
    addTearDown(tabController.dispose);

    await tester.pumpWidget(
      _wrap(
        PlayerMobileLayout(
          videoArea: const ColoredBox(
            color: Colors.black,
            child: Center(child: Text('VIDEO')),
          ),
          tabController: tabController,
          commentsCount: 0,
          infoTab: const Center(child: Text('INFO')),
          commentsTab: const Center(child: Text('COMMENTS')),
        ),
        size: const Size(390, 844),
      ),
    );

    expect(find.text('VIDEO'), findsOneWidget);
    expect(find.text('简介 & 推荐'), findsOneWidget);
    expect(find.text('评论 (0)'), findsOneWidget);
    expect(find.text('INFO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlayerMobileInfoLayout renders title and sources section', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final episodeScroll = ScrollController();
    addTearDown(episodeScroll.dispose);

    await tester.pumpWidget(
      _wrap(
        PlayerMobileInfoLayout(
          animeTitle: 'Test Anime',
          currentEpisode: _ep(),
          playableEpisodeCount: 1,
          isDescriptionExpanded: false,
          onToggleDescription: () {},
          currentSourceActions: const SizedBox.shrink(),
          episodeStrip: PlayerMobileEpisodeStrip(
            episodes: [_ep()],
            currentEpisode: _ep(),
            isExpanded: false,
            scrollController: episodeScroll,
            onToggleExpanded: () {},
            onEpisodeSelected: (_) {},
          ),
          playSourceSelector: const Text('SOURCE_SELECTOR'),
          resourceList: const Text('RESOURCE_LIST'),
          onairSites: const [],
          recommendations: const [],
          isLoadingRecommendations: false,
          onRecommendationTap: (_) {},
          scrollController: scroll,
        ),
      ),
    );

    expect(find.text('Test Anime'), findsOneWidget);
    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('SOURCE_SELECTOR'), findsOneWidget);
    expect(find.text('RESOURCE_LIST'), findsOneWidget);
    expect(find.text('播放源'), findsOneWidget);
    expect(find.text('相关推荐'), findsOneWidget);
  });
}
