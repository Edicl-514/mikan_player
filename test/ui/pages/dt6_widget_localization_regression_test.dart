import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/services/settings_service.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/about_page.dart';
import 'package:mikan_player/ui/pages/bangumi_details/layouts/mobile_layout.dart';
import 'package:mikan_player/ui/pages/bangumi_details/layouts/wide_layout.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/pages/theme_settings_page.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';

import '../../support/localized_widget_tester.dart';

const _mobileSize = Size(360, 800);
const _desktopSize = Size(1280, 800);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

PlaybackHistoryItem _historyItem() => PlaybackHistoryItem(
  key: 'dt6-history',
  title: 'Fixture History',
  subTitle: null,
  bangumiId: '1',
  mikanId: null,
  coverUrl: null,
  siteUrl: null,
  broadcastDay: null,
  broadcastTime: null,
  score: null,
  rank: null,
  tags: const [],
  fullJson: null,
  episodeId: 1,
  episodeSort: 1,
  episodeName: 'Episode 1',
  episodeNameCn: '第一集',
  episodesJson: '[]',
  updatedAt: 1,
  lastPositionMs: 0,
);

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

const _anime = AnimeInfo(
  title: 'Fixture Anime With A Deliberately Long Display Title',
  bangumiId: '1',
  tags: [],
);

Map<String, Object> _detailsData() => <String, Object>{
  'name': 'Fixture Anime With A Deliberately Long Display Title',
  'name_cn': '用于布局回归的超长番剧标题',
  'date': '2026-07-19',
  'rating': <String, Object>{'score': 8.5, 'total': 1234, 'rank': 42},
  'collection': <String, Object>{'wish': 100, 'doing': 20, 'dropped': 3},
  'infobox': const <Object>[],
  'tags': const <Object>[],
};

BangumiDetailsMobileLayout _mobileDetails(_DetailsControllers controllers) {
  return BangumiDetailsMobileLayout(
    anime: _anime,
    heroTag: 'dt6-mobile',
    data: _detailsData(),
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
    showOriginalSummary: false,
    isInfoBoxExpanded: false,
    enableCharacterHero: false,
    episodesScrollController: controllers.episodes,
    charactersScrollController: controllers.characters,
    relationsScrollController: controllers.relations,
    sitesScrollController: controllers.sites,
    onToggleFavorite: () {},
    onFavoriteTypeSelected: (_) {},
    onFavoriteAction: () {},
    onToggleShowOriginal: () {},
    onToggleInfoBoxExpanded: () {},
    onTagTap: (_) {},
    onPersonTap: (_) {},
    onCharacterTap: (_, {characterName, heroImageUrl}) {},
    onEpisodeTap: (_) {},
    onRelationTap: (_) {},
    onSiteTap: (_) {},
    onLoadMoreComments: () {},
    onEnsureCommentsLoaded: () {},
  );
}

BangumiDetailsWideLayout _wideDetails(_DetailsControllers controllers) {
  return BangumiDetailsWideLayout(
    anime: _anime,
    heroTag: 'dt6-wide',
    data: _detailsData(),
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
    wideLeftScrollController: controllers.wideLeft,
    wideRightScrollController: controllers.wideRight,
    episodesScrollController: controllers.episodes,
    charactersScrollController: controllers.characters,
    relationsScrollController: controllers.relations,
    sitesScrollController: controllers.sites,
    onToggleFavorite: () {},
    onFavoriteTypeSelected: (_) {},
    onFavoriteAction: () {},
    onShareTapped: () {},
    onToggleShowOriginal: () {},
    onToggleInfoBoxExpanded: () {},
    onTagTap: (_) {},
    onPersonTap: (_) {},
    onCharacterTap: (_, {characterName, heroImageUrl}) {},
    onEpisodeTap: (_) {},
    onRelationTap: (_) {},
    onSiteTap: (_) {},
    onEnsureCommentsLoaded: () {},
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SettingsService().debugResetForTest();
    await SettingsService().init();
  });

  group('DT-6 bilingual responsive pages', () {
    for (final locale in kTestSupportedLocales) {
      testWidgets(
        'AboutPage fits 360px and localizes sections (${locale.languageCode})',
        (tester) async {
          _setViewport(tester, _mobileSize);
          await pumpLocalizedWidget(tester, const AboutPage(), locale: locale);
          final l10n = localizedOf(tester);

          expect(find.text(l10n.aboutTitle), findsOneWidget);
          expect(find.text(l10n.aboutIntro), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text(l10n.aboutDisclaimer),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(l10n.aboutDisclaimer), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('Bangumi mobile layout fits 360px (${locale.languageCode})', (
        tester,
      ) async {
        _setViewport(tester, _mobileSize);
        final controllers = _DetailsControllers();
        addTearDown(controllers.dispose);

        await pumpLocalizedWidget(
          tester,
          _mobileDetails(controllers),
          locale: locale,
        );
        final l10n = localizedOf(tester);

        expect(find.text(l10n.bangumiDetailsTabDetails), findsOneWidget);
        expect(find.text(l10n.bangumiDetailsTabComments), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Bangumi wide layout fits 1280px (${locale.languageCode})', (
        tester,
      ) async {
        _setViewport(tester, _desktopSize);
        final controllers = _DetailsControllers();
        addTearDown(controllers.dispose);

        await pumpLocalizedWidget(
          tester,
          _wideDetails(controllers),
          locale: locale,
        );
        final l10n = localizedOf(tester);

        expect(find.text(l10n.bangumiDetailsNoSummary), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('DT-6 interaction and accessibility', () {
    testWidgets(
      'theme controls persist selections and modal actions localize',
      (tester) async {
        _setViewport(tester, _mobileSize);
        await pumpLocalizedWidget(
          tester,
          const ThemeSettingsPage(),
          locale: const Locale('en'),
        );
        final l10n = localizedOf(tester);

        await tester.tap(find.text(l10n.themeModeSystem));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.themeModeDark).last);
        await tester.pumpAndSettle();
        expect(SettingsService().themeMode, ThemeMode.dark);

        await tester.drag(find.byType(ListView), const Offset(0, -320));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l10n.useMaterial3Color));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.useMaterial3Color));
        await tester.pump();
        expect(SettingsService().useMaterial3Color, isFalse);

        await tester.scrollUntilVisible(
          find.text(l10n.customThemeColor),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(l10n.customThemeColor));
        await tester.pumpAndSettle();
        expect(find.text(l10n.cancel), findsOneWidget);
        expect(find.text(l10n.confirm), findsOneWidget);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('search action exposes localized semantic tooltip text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpLocalizedWidget(
        tester,
        const SearchPage(autofocus: false),
        locale: const Locale('en'),
      );
      final l10n = localizedOf(tester);
      final action = find.byTooltip(l10n.searchHint);

      expect(action, findsOneWidget);
      expect(tester.getSemantics(action).tooltip, l10n.searchHint);
      semantics.dispose();
    });

    testWidgets('history delete exposes localized tooltip and semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpLocalizedWidget(
        tester,
        HistoryPage(loadHistory: () async => [_historyItem()]),
        locale: const Locale('en'),
      );
      await tester.pump();
      final l10n = localizedOf(tester);
      final action = find.byTooltip(l10n.historyDeleteTooltip);

      expect(action, findsOneWidget);
      expect(tester.getSemantics(action).tooltip, l10n.historyDeleteTooltip);
      semantics.dispose();
    });

    testWidgets('danmaku source search icon has a localized tooltip', (
      tester,
    ) async {
      _setViewport(tester, const Size(420, 640));
      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: VideoSidePanel(
            danmakuService: DanmakuService(),
            initialIndex: 1,
          ),
        ),
        locale: const Locale('en'),
      );
      final l10n = localizedOf(tester);

      expect(find.byTooltip(l10n.searchHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
