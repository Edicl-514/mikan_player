import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_strip.dart';

WorkspaceDestination _destination(String kind, String title) =>
    WorkspaceDestination(
      routeId: WorkspaceRouteId.allocate(),
      kind: kind,
      title: title,
    );

void main() {
  tearDown(() => WorkspacePageChromeRegistry.instance.debugReset());

  group('WorkspacePageChromeRegistry', () {
    test('titles are a stack that falls back as routes retract', () {
      final registry = WorkspacePageChromeRegistry.instance;
      const tab = WorkspaceTabId('tab-1');
      final outer = Object();
      final inner = Object();

      expect(registry.titleFor(tab), isNull);
      registry.publishTitle(tab, outer, 'Player - EP 1');
      expect(registry.titleFor(tab), 'Player - EP 1');

      registry.publishTitle(tab, inner, 'Source settings');
      expect(registry.titleFor(tab), 'Source settings');

      registry.retractTitle(tab, inner);
      expect(registry.titleFor(tab), 'Player - EP 1');

      registry.publishTitle(tab, outer, 'Player - EP 2');
      expect(registry.titleFor(tab), 'Player - EP 2');

      registry.retractTitle(tab, outer);
      expect(registry.titleFor(tab), isNull);
    });

    test('entries are scoped per tab and cleared with the tab', () {
      final registry = WorkspacePageChromeRegistry.instance;
      const tabA = WorkspaceTabId('tab-a');
      const tabB = WorkspaceTabId('tab-b');
      final owner = Object();

      registry.publishTitle(tabA, owner, 'A');
      registry.publishToolbarActions(
        tabA,
        owner,
        (context) => const SizedBox(),
      );
      registry.publishTitle(tabB, owner, 'B');

      expect(registry.titleFor(tabA), 'A');
      expect(registry.titleFor(tabB), 'B');
      expect(registry.toolbarActionsFor(tabA), hasLength(1));
      expect(registry.toolbarActionsFor(tabB), isEmpty);

      registry.clearTab(tabA);
      expect(registry.titleFor(tabA), isNull);
      expect(registry.toolbarActionsFor(tabA), isEmpty);
      expect(registry.titleFor(tabB), 'B');
    });

    test('republishing from the same owner replaces rather than stacks', () {
      final registry = WorkspacePageChromeRegistry.instance;
      const tab = WorkspaceTabId('tab-1');
      final owner = Object();

      registry.publishToolbarActions(
        tab,
        owner,
        (context) => const Icon(Icons.download),
      );
      registry.publishToolbarActions(
        tab,
        owner,
        (context) => const Icon(Icons.copy),
      );

      expect(registry.toolbarActionsFor(tab), hasLength(1));
    });

    test('notifies only on real changes', () {
      final registry = WorkspacePageChromeRegistry.instance;
      const tab = WorkspaceTabId('tab-1');
      final owner = Object();
      var notifications = 0;
      void listener() => notifications += 1;
      registry.addListener(listener);
      addTearDown(() => registry.removeListener(listener));

      registry.publishTitle(tab, owner, 'Same');
      expect(notifications, 1);
      registry.publishTitle(tab, owner, 'Same');
      expect(notifications, 1);
      registry.retractTitle(tab, Object());
      expect(notifications, 1);
      registry.retractTitle(tab, owner);
      expect(notifications, 2);
    });
  });

  group('title source of truth', () {
    testWidgets('destination title drives the tab, published titles refine it', (
      tester,
    ) async {
      final controller = WorkspaceTabController(homeTitle: 'Home');
      final hostController = WorkspaceTabHostController();
      final player = _destination('player', 'Some Anime');

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
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
            destinationBuilder: (context, destination) =>
                destination.kind == 'player'
                ? const WorkspaceRouteTitle(
                    title: 'Some Anime - EP 3',
                    child: SizedBox(),
                  )
                : const SizedBox(),
          ),
        ),
      );
      final tabId = controller.activeTabId;
      expect(controller.activeTab.title, 'Home');

      controller.navigate(tabId, player);
      await tester.pumpAndSettle();
      expect(controller.activeTab.title, 'Some Anime - EP 3');

      // A route below the current one stays mounted, but its refinement must
      // not leak into the destination above it.
      controller.navigate(tabId, _destination('about', 'About'));
      await tester.pumpAndSettle();
      expect(controller.activeTab.title, 'About');

      expect(controller.back(tabId), isTrue);
      await tester.pumpAndSettle();
      expect(controller.activeTab.title, 'Some Anime - EP 3');

      // Back leaves the player route; the tab returns to the destination title.
      expect(controller.back(tabId), isTrue);
      await tester.pumpAndSettle();
      expect(controller.activeTab.title, 'Home');

      // Forward rebuilds the route from the destination, and the rebuilt page
      // republishes its refinement.
      expect(controller.forward(tabId), isTrue);
      await tester.pumpAndSettle();
      expect(controller.activeTab.title, 'Some Anime - EP 3');
    });

    testWidgets('a title published after an async open still lands', (
      tester,
    ) async {
      final controller = WorkspaceTabController(homeTitle: 'Home');
      final hostController = WorkspaceTabHostController();
      final resolved = ValueNotifier<String?>(null);
      addTearDown(resolved.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
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
            destinationBuilder: (context, destination) =>
                ValueListenableBuilder<String?>(
                  valueListenable: resolved,
                  builder: (context, value, _) => value == null
                      ? const SizedBox()
                      : WorkspaceRouteTitle(
                          title: value,
                          child: const SizedBox(),
                        ),
                ),
          ),
        ),
      );
      final tabId = controller.activeTabId;
      controller.navigate(tabId, _destination('character', '#4711'));
      await tester.pumpAndSettle();
      expect(controller.activeTab.title, '#4711');

      resolved.value = 'Rem';
      await tester.pumpAndSettle();
      expect(controller.activeTab.title, 'Rem');
    });

    testWidgets('closing a tab drops what its routes published', (
      tester,
    ) async {
      final controller = WorkspaceTabController(homeTitle: 'Home');
      final hostController = WorkspaceTabHostController();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
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
            destinationBuilder: (context, destination) => WorkspaceRouteTitle(
              title: '${destination.title} +',
              child: const SizedBox(),
            ),
          ),
        ),
      );
      final first = controller.activeTabId;
      controller.create();
      await tester.pumpAndSettle();
      expect(WorkspacePageChromeRegistry.instance.titleFor(first), 'Home +');

      await hostController.closeTab(first);
      await tester.pumpAndSettle();
      expect(WorkspacePageChromeRegistry.instance.titleFor(first), isNull);
    });
  });

  group('context toolbar action slot', () {
    testWidgets('shows only the active tab actions and drops them on unmount', (
      tester,
    ) async {
      final controller = WorkspaceTabController(homeTitle: 'Home');
      final hostController = WorkspaceTabHostController();
      var pressed = 0;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: Column(
            children: [
              WorkspaceContextToolbar(
                controller: controller,
                hostController: hostController,
              ),
              Expanded(
                child: WorkspaceTabHost(
                  controller: controller,
                  hostController: hostController,
                  destinationBuilder: (context, destination) =>
                      destination.kind == 'player'
                      ? WorkspaceToolbarActions(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => pressed += 1,
                          ),
                          child: const SizedBox(),
                        )
                      : const SizedBox(),
                ),
              ),
            ],
          ),
        ),
      );
      final playerTab = controller.activeTabId;
      expect(find.byIcon(Icons.download), findsNothing);

      controller.navigate(playerTab, _destination('player', 'Playing'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsOneWidget);

      await tester.tap(find.byIcon(Icons.download));
      expect(pressed, 1);

      // A second tab has published nothing, so the slot is empty there.
      final other = controller.create();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsNothing);

      controller.activate(playerTab);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsOneWidget);

      // A destination above the player keeps the player route mounted, but
      // only the visible route may contribute toolbar actions.
      controller.navigate(playerTab, _destination('about', 'About'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsNothing);

      expect(controller.back(playerTab), isTrue);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsOneWidget);

      // Leaving the route retracts the actions.
      expect(controller.back(playerTab), isTrue);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsNothing);
      expect(controller.tabById(other), isNotNull);
    });

    testWidgets('actions never displace Back, Forward or the title', (
      tester,
    ) async {
      final controller = WorkspaceTabController(homeTitle: 'Home');
      final hostController = WorkspaceTabHostController();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('en'), const Locale('zh')],
          home: Column(
            children: [
              SizedBox(
                width: 720,
                child: WorkspaceContextToolbar(
                  controller: controller,
                  hostController: hostController,
                ),
              ),
              Expanded(
                child: WorkspaceTabHost(
                  controller: controller,
                  hostController: hostController,
                  destinationBuilder: (context, destination) =>
                      WorkspaceToolbarActions(
                        builder: (context) => const Icon(Icons.download),
                        child: const SizedBox(),
                      ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      final title = tester.getRect(find.text('Home'));
      final action = tester.getRect(find.byIcon(Icons.download));
      expect(title.right, lessThanOrEqualTo(action.left));
      expect(
        tester.getSize(find.byType(WorkspaceContextToolbar)).height,
        WorkspaceContextToolbar.height,
      );
    });
  });
}
