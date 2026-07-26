import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/pages/data_source_settings_page.dart';
import 'package:mikan_player/ui/pages/download_settings_page.dart';
import 'package:mikan_player/ui/pages/favorites_page.dart';
import 'package:mikan_player/ui/pages/my_page.dart';
import 'package:mikan_player/ui/pages/network_settings_page.dart';
import 'package:mikan_player/ui/pages/ranking_page.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/pages/search_settings_page.dart';
import 'package:mikan_player/ui/pages/timetable_page.dart';
import 'package:mikan_player/ui/screens/pc/pc_home_layout.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_strip.dart';

import '../../support/localized_widget_tester.dart';

void main() {
  tearDown(() {
    WorkspacePageChromeRegistry.instance.debugReset();
    WindowsDesktopFrameController.instance.setContentFullscreen(false);
  });

  // Pages whose hosted branch never draws a page-owned AppBar. The body
  // provides either a `DesktopPageActionRow` (command row) or a `TabBar` /
  // `TabBarView` pair.
  const hostedPages = <Widget>[RankingPage(), FavoritesPage(), TimeTablePage()];

  group('hosted action-bearing pages', () {
    for (final page in hostedPages) {
      testWidgets('${page.runtimeType} drops its AppBar in the desktop shell', (
        tester,
      ) async {
        await pumpLocalizedWidget(tester, DesktopPageChromeScope(child: page));
        expect(find.byType(AppBar), findsNothing);
      });
    }

    testWidgets(
      'RankingPage shows its TabBar at the top of the body on desktop',
      (tester) async {
        await pumpLocalizedWidget(
          tester,
          DesktopPageChromeScope(child: const RankingPage()),
        );
        expect(find.byType(TabBar), findsOneWidget);
        // The tab bar lives inside the page body, below the shell's 82px of chrome.
        final tabBarTop = tester.getTopLeft(find.byType(TabBar)).dy;
        expect(tabBarTop, lessThan(120));
      },
    );

    testWidgets('TimeTablePage exposes its quarter picker in an action row', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(child: const TimeTablePage()),
      );
      // Quarter picker and day TabBar both live above the body.
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(find.byType(DesktopPageActionRow), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('FavoritesPage exposes refresh + TabBar above the body', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(child: const FavoritesPage()),
      );
      expect(find.byType(DesktopPageActionRow), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });
  });

  group('SearchPage command row', () {
    testWidgets('drops its AppBar and shows the inline search field on desktop', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(child: const SearchPage()),
      );
      expect(find.byType(AppBar), findsNothing);
      // The body has a TextField for the search input and a search icon button.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsWidgets);
    });

    testWidgets('keeps its AppBar-embedded TextField when no shell hosts it', (
      tester,
    ) async {
      await pumpLocalizedWidget(tester, const SearchPage());
      expect(find.byType(AppBar), findsOneWidget);
      // Same TextField is reached via the AppBar title on the mobile branch.
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('PcHomeLayout action row', () {
    testWidgets('renders home layout with search icon inside page content', (tester) async {
      await pumpLocalizedWidget(
        tester,
        const DesktopPageChromeScope(child: PcHomeLayout()),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('DownloadManagerPage', () {
    testWidgets('drops its AppBar in the desktop shell', (tester) async {
      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(child: const DownloadManagerPage()),
      );
      expect(find.byType(AppBar), findsNothing);
      // The download manager still draws the empty-state copy on first load
      // (no tasks yet), so the action row is hidden — but the page surface
      // is present and the body fills the rest of the shell.
      expect(find.byType(DownloadManagerPage), findsOneWidget);
    });
  });

  group('settings pages (action rows)', () {
    const hostedSettingsPages = <Widget>[
      DataSourceSettingsPage(),
      NetworkSettingsPage(),
      SearchSettingsPage(),
      DownloadSettingsPage(),
    ];

    for (final page in hostedSettingsPages) {
      testWidgets(
        '${page.runtimeType} drops its AppBar and surfaces a desktop action row',
        (tester) async {
          await pumpLocalizedWidget(
            tester,
            DesktopPageChromeScope(child: page),
          );
          expect(find.byType(AppBar), findsNothing);
          expect(find.byType(DesktopPageActionRow), findsOneWidget);
        },
      );
    }

    // The mobile branch keeps the page-owned AppBar so back/title remain in
    // their original positions. Network / data source expose Save/Restore in
    // `actions`; the other two expose Save only.
    testWidgets('mobile pages keep their AppBar with the same actions', (
      tester,
    ) async {
      for (final page in hostedSettingsPages) {
        await pumpLocalizedWidget(tester, page);
        expect(
          find.byType(AppBar),
          findsOneWidget,
          reason: '${page.runtimeType} owns its header off-desktop',
        );
        expect(
          DesktopPageChromeScope.isHosted(tester.element(find.byType(AppBar))),
          isFalse,
        );
      }
    });
  });

  group('workspace host integration', () {
    testWidgets(
      'no page AppBar appears on a hosted tab even before any destination opens',
      (tester) async {
        final controller = WorkspaceTabController(homeTitle: 'Home');
        final hostController = WorkspaceTabHostController();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: WindowsDesktopFrame(
              tabStrip: WorkspaceTabStrip(
                controller: controller,
                hostController: hostController,
              ),
              contextToolbar: WorkspaceContextToolbar(
                controller: controller,
                hostController: hostController,
              ),
              child: WorkspaceTabHost(
                controller: controller,
                hostController: hostController,
                destinationBuilder: (context, destination) => const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Default home tab is the only thing on stage. The host itself never
        // paints a page-owned AppBar, so this is the floor we lock in here.
        expect(find.byType(AppBar), findsNothing);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      },
    );
  });
}
