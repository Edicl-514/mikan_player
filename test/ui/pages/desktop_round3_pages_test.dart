import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/ui/pages/bangumi_details/layouts/mobile_layout.dart';
import 'package:mikan_player/ui/pages/bangumi_details/layouts/wide_layout.dart';
import 'package:mikan_player/ui/pages/character_detail_page.dart';
import 'package:mikan_player/ui/pages/data_source_config_page.dart';
import 'package:mikan_player/ui/pages/person_detail_page.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_pc_layout.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';

import '../../support/localized_widget_tester.dart';

BangumiEpisode _ep({int id = 1, double sort = 1}) => BangumiEpisode(
  id: id,
  name: 'Episode $id',
  nameCn: '第$id集',
  description: 'desc',
  airdate: '',
  duration: '',
  sort: sort,
);

/// Builds a [PlayerPcLayout] with throwaway props so we only exercise its
/// header chrome. The scroll controllers are disposed by the caller.
Widget _playerPcLayout({
  required bool showInternalChrome,
  required ScrollController main,
  required ScrollController sidebar,
  required ScrollController episodes,
}) {
  return Scaffold(
    body: PlayerPcLayout(
      animeTitle: 'Test Anime',
      currentEpisode: _ep(),
      currentSourceActions: const SizedBox.shrink(),
      videoArea: const ColoredBox(color: Colors.black),
      isDescriptionExpanded: false,
      onToggleDescription: () {},
      playSourceSelector: const SizedBox.shrink(),
      resourceList: const SizedBox.shrink(),
      onairSites: const [],
      commentSortButton: const SizedBox.shrink(),
      comments: const [],
      isLoadingComments: false,
      commentsError: null,
      playableEpisodes: [_ep()],
      episodeScrollController: episodes,
      onEpisodeSelected: (_) {},
      recommendations: const [],
      isLoadingRecommendations: false,
      onRecommendationTap: (_) {},
      mainScrollController: main,
      sidebarScrollController: sidebar,
      showInternalChrome: showInternalChrome,
    ),
  );
}

class _DetailsControllers {
  final wideLeft = ScrollController();
  final wideRight = ScrollController();
  final episodes = ScrollController();
  final characters = ScrollController();
  final relations = ScrollController();
  final sites = ScrollController();

  void dispose() {
    wideLeft.dispose();
    wideRight.dispose();
    episodes.dispose();
    characters.dispose();
    relations.dispose();
    sites.dispose();
  }
}

Widget _bangumiWideLayout(
  _DetailsControllers c, {
  String bangumiId = '1',
  VoidCallback? onLoadMoreComments,
}) => BangumiDetailsWideLayout(
  anime: AnimeInfo(title: 'Test Anime', bangumiId: bangumiId, tags: const []),
  heroTag: null,
  data: const <String, dynamic>{'infobox': <dynamic>[]},
  episodes: const [],
  characters: const [],
  relations: const [],
  comments: const [],
  sites: const [],
  personIdMap: const {},
  isLoadingEpisodes: false,
  isLoadingCharacters: false,
  isLoadingRelations: false,
  isLoadingComments: false,
  isLoadingMoreComments: false,
  hasRequestedComments: true,
  isLocalFavorite: false,
  favoriteType: null,
  isSelectingFavoriteStatus: false,
  isUpdatingFavorite: false,
  isCopied: false,
  showOriginalSummary: false,
  isInfoBoxExpanded: false,
  enableCharacterHero: false,
  wideLeftScrollController: c.wideLeft,
  wideRightScrollController: c.wideRight,
  episodesScrollController: c.episodes,
  charactersScrollController: c.characters,
  relationsScrollController: c.relations,
  sitesScrollController: c.sites,
  onToggleFavorite: () {},
  onFavoriteTypeSelected: (_) {},
  onFavoriteAction: () {},
  onShareTapped: () {},
  onToggleShowOriginal: () {},
  onToggleInfoBoxExpanded: () {},
  onTagTap: (_) {},
  onPersonTap: (_, {personName}) {},
  onCharacterTap: (_, {characterName, heroImageUrl}) {},
  onEpisodeTap: (_) {},
  onRelationTap: (_) {},
  onSiteTap: (_) {},
  onEnsureCommentsLoaded: () {},
  onLoadMoreComments: onLoadMoreComments ?? () {},
);

void main() {
  tearDown(() {
    WorkspacePageChromeRegistry.instance.debugReset();
    WindowsDesktopFrameController.instance.setContentFullscreen(false);
  });

  group('CharacterDetailPage error branch', () {
    Widget page() => CharacterDetailPage(
      characterId: 1,
      loadDetails: (_) async => throw StateError('boom'),
      loadSubjects: (_) async => throw StateError('boom'),
    );

    testWidgets('drops its transparent AppBar when hosted', (tester) async {
      await pumpLocalizedWidget(tester, DesktopPageChromeScope(child: page()));
      await tester.pump();
      // Error copy is shown, and no page-owned AppBar remains.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('keeps its transparent AppBar when not hosted', (tester) async {
      await pumpLocalizedWidget(tester, page());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('PersonDetailPage error branch', () {
    Widget page() => PersonDetailPage(
      personId: 1,
      loadDetails: (_) async => throw StateError('boom'),
      loadSubjects: (_) async => throw StateError('boom'),
    );

    testWidgets('drops its transparent AppBar when hosted', (tester) async {
      await pumpLocalizedWidget(tester, DesktopPageChromeScope(child: page()));
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('keeps its transparent AppBar when not hosted', (tester) async {
      await pumpLocalizedWidget(tester, page());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('BangumiDetailsWideLayout chrome', () {
    late _DetailsControllers controllers;

    setUp(() => controllers = _DetailsControllers());
    tearDown(() => controllers.dispose());

    testWidgets('hosted layout drops transparent AppBar and old inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(child: _bangumiWideLayout(controllers)),
      );

      expect(find.byType(AppBar), findsNothing);
      expect(tester.getTopLeft(find.text('Test Anime')).dy, lessThan(56));
    });

    testWidgets('non-hosted layout keeps transparent AppBar', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpLocalizedWidget(tester, _bangumiWideLayout(controllers));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('resets the selected tab when the anime changes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpLocalizedWidget(tester, _bangumiWideLayout(controllers));
      tester
          .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .onSelectionChanged!({2});
      await tester.pump();
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {2},
      );

      await pumpLocalizedWidget(
        tester,
        _bangumiWideLayout(controllers, bangumiId: '2'),
      );
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {0},
      );
    });

    testWidgets('loads more comments only from the comments tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var loadMoreCalls = 0;

      await pumpLocalizedWidget(
        tester,
        _bangumiWideLayout(
          controllers,
          onLoadMoreComments: () => loadMoreCalls++,
        ),
      );
      controllers.wideRight.jumpTo(
        controllers.wideRight.position.maxScrollExtent,
      );
      await tester.pump();
      expect(loadMoreCalls, 0);

      tester
          .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .onSelectionChanged!({1});
      await tester.pump();
      controllers.wideRight.jumpTo(0);
      await tester.pump();
      controllers.wideRight.jumpTo(
        controllers.wideRight.position.maxScrollExtent,
      );
      await tester.pump();
      expect(loadMoreCalls, greaterThan(0));
    });
  });

  group('DataSourceConfigPage', () {
    testWidgets('hosted editor moves Save into a desktop action row', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        const DesktopPageChromeScope(child: DataSourceConfigPage()),
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(DesktopPageActionRow), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('non-hosted editor keeps its AppBar', (tester) async {
      await pumpLocalizedWidget(tester, const DataSourceConfigPage());
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });
  });

  group('PlayerPcLayout header chrome', () {
    late ScrollController main;
    late ScrollController sidebar;
    late ScrollController episodes;

    setUp(() {
      main = ScrollController();
      sidebar = ScrollController();
      episodes = ScrollController();
    });

    tearDown(() {
      main.dispose();
      sidebar.dispose();
      episodes.dispose();
    });

    // The wide layout needs a desktop-sized surface (Expanded main column plus
    // a fixed 380px sidebar), so size the test view instead of relying on the
    // 800x600 default.
    Future<void> pumpWide(
      WidgetTester tester, {
      required bool showInternalChrome,
    }) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpLocalizedWidget(
        tester,
        _playerPcLayout(
          showInternalChrome: showInternalChrome,
          main: main,
          sidebar: sidebar,
          episodes: episodes,
        ),
      );
    }

    testWidgets('hosted layout drops the internal back button + anime title', (
      tester,
    ) async {
      await pumpWide(tester, showInternalChrome: false);
      // Back arrow and duplicate anime title are gone; the episode label
      // remains as the in-content heading.
      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
      expect(find.text('Test Anime'), findsNothing);
      expect(find.textContaining('EP 1'), findsOneWidget);
    });

    testWidgets('non-hosted layout keeps back button + anime title', (
      tester,
    ) async {
      await pumpWide(tester, showInternalChrome: true);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.text('Test Anime'), findsOneWidget);
      expect(find.textContaining('EP 1'), findsOneWidget);
    });
  });

  group('BangumiDetailsMobileLayout SliverAppBar leading', () {
    Widget layout() {
      final episodes = ScrollController();
      final characters = ScrollController();
      final relations = ScrollController();
      final sites = ScrollController();
      addTearDown(episodes.dispose);
      addTearDown(characters.dispose);
      addTearDown(relations.dispose);
      addTearDown(sites.dispose);
      return BangumiDetailsMobileLayout(
        anime: const AnimeInfo(title: 'Test Anime', bangumiId: '1', tags: []),
        heroTag: null,
        data: null,
        episodes: null,
        characters: null,
        relations: null,
        comments: null,
        sites: null,
        personIdMap: const {},
        isLoadingEpisodes: false,
        isLoadingCharacters: false,
        isLoadingRelations: false,
        isLoadingComments: false,
        isLoadingMoreComments: false,
        hasRequestedComments: false,
        isLocalFavorite: false,
        favoriteType: null,
        isSelectingFavoriteStatus: false,
        isUpdatingFavorite: false,
        showOriginalSummary: false,
        isInfoBoxExpanded: false,
        enableCharacterHero: false,
        episodesScrollController: episodes,
        charactersScrollController: characters,
        relationsScrollController: relations,
        sitesScrollController: sites,
        onToggleFavorite: () {},
        onFavoriteTypeSelected: (_) {},
        onFavoriteAction: () {},
        onToggleShowOriginal: () {},
        onToggleInfoBoxExpanded: () {},
        onTagTap: (_) {},
        onPersonTap: (_, {personName}) {},
        onCharacterTap: (_, {characterName, heroImageUrl}) {},
        onEpisodeTap: (_) {},
        onRelationTap: (_) {},
        onSiteTap: (_) {},
        onLoadMoreComments: () {},
        onEnsureCommentsLoaded: () {},
      );
    }

    testWidgets('suppresses the implicit back arrow when hosted', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(child: layout()),
      );
      await tester.pump();
      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
    });

    testWidgets('keeps the implicit back arrow when not hosted', (
      tester,
    ) async {
      await pumpLocalizedWidget(tester, layout());
      await tester.pump();
      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.automaticallyImplyLeading, isTrue);
    });
  });
}
