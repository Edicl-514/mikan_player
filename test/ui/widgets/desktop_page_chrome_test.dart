import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/pages/about_page.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/settings_page.dart';
import 'package:mikan_player/ui/pages/subscription_debug_page.dart';
import 'package:mikan_player/ui/pages/theme_settings_page.dart';
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

  group('DesktopPageScaffold', () {
    testWidgets('keeps its AppBar when no desktop shell hosts the page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: DesktopPageScaffold(
            title: Text('History'),
            actions: [Icon(Icons.refresh)],
            body: Text('page body'),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(DesktopPageActionRow), findsNothing);
    });

    testWidgets('drops the AppBar and keeps header actions on desktop', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: DesktopPageChromeScope(
            child: DesktopPageScaffold(
              title: Text('History'),
              actions: [Icon(Icons.refresh)],
              body: Text('page body'),
            ),
          ),
        ),
      );

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('History'), findsNothing);
      expect(find.byType(DesktopPageActionRow), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('page body'), findsOneWidget);
    });

    testWidgets('keeps the header bottom slot and body order on desktop', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: DesktopPageChromeScope(
            child: DesktopPageScaffold(
              title: const Text('Favorites'),
              desktopActionRow: const DesktopPageActionRow(
                children: [Icon(Icons.refresh)],
              ),
              appBarBottom: const PreferredSize(
                preferredSize: Size.fromHeight(40),
                child: SizedBox(height: 40, child: Text('tabs')),
              ),
              body: Container(color: const Color(0xff000000)),
            ),
          ),
        ),
      );

      final rowBottom = tester
          .getRect(find.byType(DesktopPageActionRow))
          .bottom;
      final tabsTop = tester.getRect(find.text('tabs')).top;
      final bodyTop = tester.getRect(find.byType(Container)).top;
      expect(tabsTop, greaterThanOrEqualTo(rowBottom));
      expect(bodyTop, greaterThanOrEqualTo(tabsTop));
    });

    testWidgets('page-supplied desktop row wins over AppBar actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: DesktopPageChromeScope(
            child: DesktopPageScaffold(
              actions: [Icon(Icons.refresh)],
              desktopActionRow: DesktopPageActionRow(
                children: [Icon(Icons.cleaning_services)],
              ),
              body: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });
  });

  group('DesktopPageChromeScope', () {
    testWidgets('reports no capability outside a desktop shell', (
      tester,
    ) async {
      late BuildContext probe;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: Builder(
            builder: (context) {
              probe = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(DesktopPageChromeScope.isHosted(probe), isFalse);
      expect(DesktopPageChromeScope.hostsNavigation(probe), isFalse);
      expect(DesktopPageChromeScope.hostsTitle(probe), isFalse);
      expect(DesktopPageChromeScope.hostsPageHeader(probe), isFalse);
      expect(
        DesktopPageMetrics.navigationTopInsetFor(
          probe,
          reserved: kToolbarHeight,
        ),
        kToolbarHeight,
      );
    });

    testWidgets('a nested route can keep its title and drop only Back', (
      tester,
    ) async {
      late BuildContext probe;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: DesktopPageChromeScope(
            child: DesktopPageChromeScope(
              providesTitle: false,
              child: Builder(
                builder: (context) {
                  probe = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(DesktopPageChromeScope.hostsNavigation(probe), isTrue);
      expect(DesktopPageChromeScope.hostsTitle(probe), isFalse);
      expect(DesktopPageChromeScope.hostsPageHeader(probe), isFalse);
      expect(
        DesktopPageMetrics.navigationTopInsetFor(
          probe,
          reserved: kToolbarHeight,
        ),
        DesktopPageMetrics.contentTopInset,
      );
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('drops the page toolbar inset once the shell owns the header', (
      tester,
    ) async {
      late BuildContext probe;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: DesktopPageChromeScope(
            child: Builder(
              builder: (context) {
                probe = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(
        DesktopPageMetrics.navigationTopInsetFor(
          probe,
          reserved: kToolbarHeight + 24,
        ),
        DesktopPageMetrics.contentTopInset,
      );
    });
  });

  group('workspace host integration', () {
    testWidgets('hosted pages see the capability, opted-out hosts do not', (
      tester,
    ) async {
      final controller = WorkspaceTabController();
      final hostController = WorkspaceTabHostController();
      final hosted = <bool>[];

      Widget build({required bool providesPageChrome}) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [const Locale('en'), const Locale('zh')],
        home: WorkspaceTabHost(
          controller: controller,
          hostController: hostController,
          providesPageChrome: providesPageChrome,
          // The scope wraps the page the builder returns, so the capability is
          // read from the page's own context, not the host's.
          destinationBuilder: (context, destination) => Builder(
            builder: (pageContext) {
              hosted.add(DesktopPageChromeScope.hostsPageHeader(pageContext));
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(build(providesPageChrome: true));
      expect(hosted, [isTrue]);

      hosted.clear();
      await tester.pumpWidget(build(providesPageChrome: false));
      await tester.pump();
      expect(hosted, isNot(contains(true)));
      expect(hosted, isNotEmpty);
    });

    testWidgets('renders exactly one back affordance and one title', (
      tester,
    ) async {
      final controller = WorkspaceTabController();
      final hostController = WorkspaceTabHostController();
      final destination = WorkspaceDestination(
        routeId: WorkspaceRouteId.allocate(),
        kind: 'about',
        title: 'About',
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
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
              destinationBuilder: (context, current) => DesktopPageScaffold(
                title: Text(current.title),
                body: const Text('body'),
              ),
            ),
          ),
        ),
      );

      controller.navigate(controller.activeTabId, destination);
      await tester.pumpAndSettle();

      // 'About' appears in the tab strip and the context toolbar, never in a
      // page-owned AppBar.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('About'), findsNWidgets(2));
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('page chrome disappears while the player is fullscreen', (
      tester,
    ) async {
      final controller = WorkspaceTabController();
      final hostController = WorkspaceTabHostController();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: WindowsDesktopFrame(
            contextToolbar: WorkspaceContextToolbar(
              controller: controller,
              hostController: hostController,
            ),
            child: WorkspaceTabHost(
              controller: controller,
              hostController: hostController,
              destinationBuilder: (context, destination) =>
                  const _ToolbarActionPage(
                    title: 'Playing',
                    icon: Icons.download,
                  ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      WindowsDesktopFrameController.instance.setContentFullscreen(true);
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.text('player surface'), findsOneWidget);
    });
  });

  group('mobile tree stays untouched', () {
    // Round 1 removes these pages' AppBars on the desktop branch only. Pinning
    // the current mobile rendering here makes an accidental unconditional
    // removal a test failure rather than a phone-only visual regression.
    testWidgets('pages keep their own AppBar with no shell present', (
      tester,
    ) async {
      for (final page in <Widget>[
        const AboutPage(),
        const HistoryPage(),
        const SettingsPage(),
        const ThemeSettingsPage(),
        const SubscriptionDebugPage(),
      ]) {
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

    // The counterpart for Round 1: when the workspace shell hosts the page, the
    // page-owned AppBar must disappear so the tab strip / context toolbar stays
    // the only place Back and the title come from.
    testWidgets('hosted pages drop their AppBar in the desktop shell', (
      tester,
    ) async {
      for (final page in <Widget>[
        const AboutPage(),
        const HistoryPage(),
        const SettingsPage(),
        const ThemeSettingsPage(),
        const SubscriptionDebugPage(),
      ]) {
        await pumpLocalizedWidget(tester, DesktopPageChromeScope(child: page));
        expect(
          find.byType(AppBar),
          findsNothing,
          reason: '${page.runtimeType} yields its header to the shell',
        );
        expect(
          find.byType(DesktopPageScaffold),
          findsOneWidget,
          reason: '${page.runtimeType} still builds content under the shell',
        );
      }
    });
  });
}

class _ToolbarActionPage extends StatelessWidget {
  const _ToolbarActionPage({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => WorkspaceRouteTitle(
    title: title,
    child: WorkspaceToolbarActions(
      builder: (context) => Icon(icon),
      child: const Center(child: Text('player surface')),
    ),
  );
}
