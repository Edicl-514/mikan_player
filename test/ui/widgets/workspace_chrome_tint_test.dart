import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_route_observer.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';
import 'package:mikan_player/ui/widgets/workspace_chrome_tint.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_strip.dart';

void main() {
  const chromeKey = ValueKey('workspace_chrome_background');

  tearDown(() {
    WorkspacePageChromeRegistry.instance.debugReset();
    WorkspaceChromeTintPublisher.debugResetForTest();
    WindowsDesktopFrameController.instance.setContentFullscreen(false);
  });

  Color chromeColor(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(find.byKey(chromeKey));
    return (container.decoration! as BoxDecoration).color!;
  }

  Color surfaceColor(WidgetTester tester) =>
      Theme.of(tester.element(find.byKey(chromeKey))).colorScheme.surface;

  test('tint barrier blocks and then restores the lower tint', () {
    final controller = WorkspaceTabController();
    final tintOwner = Object();
    final barrierOwner = Object();
    const tint = Color(0xFF7A1A2B);

    WorkspacePageChromeRegistry.instance.publishTint(
      controller.activeTabId,
      tintOwner,
      tint,
    );
    WorkspacePageChromeRegistry.instance.publishTintBarrier(
      controller.activeTabId,
      barrierOwner,
    );
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      isNull,
    );

    WorkspacePageChromeRegistry.instance.retractTint(
      controller.activeTabId,
      barrierOwner,
    );
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      tint,
    );
  });

  testWidgets('title bar animates to a published tint and back', (
    tester,
  ) async {
    final controller = WorkspaceTabController();
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
          controller: controller,
          child: const SizedBox.expand(),
        ),
      ),
    );

    // Default: the theme surface.
    expect(chromeColor(tester), surfaceColor(tester));

    const tint = Color(0xFF7A1A2B);
    final owner = Object();
    WorkspacePageChromeRegistry.instance.publishTint(
      controller.activeTabId,
      owner,
      tint,
    );
    await tester.pumpAndSettle();
    expect(chromeColor(tester), tint);

    WorkspacePageChromeRegistry.instance.retractTint(
      controller.activeTabId,
      owner,
    );
    await tester.pumpAndSettle();
    expect(chromeColor(tester), surfaceColor(tester));
  });

  testWidgets('title bar follows the active tab tint when switching tabs', (
    tester,
  ) async {
    final controller = WorkspaceTabController();
    final secondId = controller.create(activate: false);
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
          controller: controller,
          child: const SizedBox.expand(),
        ),
      ),
    );

    const red = Color(0xFF7A1A2B);
    const blue = Color(0xFF1A3B7A);
    WorkspacePageChromeRegistry.instance.publishTint(
      controller.activeTabId,
      Object(),
      red,
    );
    WorkspacePageChromeRegistry.instance.publishTint(secondId, Object(), blue);
    await tester.pumpAndSettle();
    expect(chromeColor(tester), red);

    controller.activate(secondId);
    await tester.pumpAndSettle();
    expect(chromeColor(tester), blue);
  });

  testWidgets('publisher publishes the chrome tint for the current tab', (
    tester,
  ) async {
    WorkspaceChromeTintPublisher.debugChromeOverride = (url) =>
        const Color(0xFF7A1A2B);
    final controller = WorkspaceTabController();

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
        navigatorObservers: [workspaceRouteObserver],
        home: WorkspaceTabScope(
          tabId: controller.activeTabId,
          controller: controller,
          child: const WorkspaceChromeTintPublisher(
            imageUrl: 'https://example.com/cover.jpg',
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      const Color(0xFF7A1A2B),
    );
  });

  testWidgets('publisher retracts its tint when disposed', (tester) async {
    WorkspaceChromeTintPublisher.debugChromeOverride = (url) =>
        const Color(0xFF7A1A2B);
    final controller = WorkspaceTabController();

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
        navigatorObservers: [workspaceRouteObserver],
        home: WorkspaceTabScope(
          tabId: controller.activeTabId,
          controller: controller,
          child: const WorkspaceChromeTintPublisher(
            imageUrl: 'https://example.com/cover.jpg',
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      isNull,
    );
  });

  testWidgets('publisher retracts its old tint when the image URL changes', (
    tester,
  ) async {
    WorkspaceChromeTintPublisher.debugChromeOverride = (url) =>
        const Color(0xFF7A1A2B);
    final controller = WorkspaceTabController();

    Widget buildPublisher(String? imageUrl) {
      return MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [const Locale('en'), const Locale('zh')],
        navigatorObservers: [workspaceRouteObserver],
        home: WorkspaceTabScope(
          tabId: controller.activeTabId,
          controller: controller,
          child: WorkspaceChromeTintPublisher(
            imageUrl: imageUrl,
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildPublisher('https://example.com/cover.jpg'));
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      const Color(0xFF7A1A2B),
    );

    await tester.pumpWidget(buildPublisher(null));
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      isNull,
    );
  });

  testWidgets('context toolbar rides the tint background', (tester) async {
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
          controller: controller,
          contextToolbar: WorkspaceContextToolbar(
            controller: controller,
            hostController: hostController,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    const tint = Color(0xFF7A1A2B);
    WorkspacePageChromeRegistry.instance.publishTint(
      controller.activeTabId,
      Object(),
      tint,
    );
    await tester.pumpAndSettle();

    final toolbarMaterial = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(WorkspaceContextToolbar),
            matching: find.byType(Material),
          ),
        )
        .first;
    expect(toolbarMaterial.color, tint);
  });

  testWidgets('covering route without a tint blocks the one underneath', (
    tester,
  ) async {
    WorkspaceChromeTintPublisher.debugChromeOverride = (url) =>
        const Color(0xFF7A1A2B);
    final controller = WorkspaceTabController();
    final navigatorKey = GlobalKey<NavigatorState>();

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
        home: WorkspaceTabScope(
          tabId: controller.activeTabId,
          controller: controller,
          child: _TintNavigator(
            navigatorKey: navigatorKey,
            firstChild: const WorkspaceChromeTintPublisher(
              imageUrl: 'https://example.com/underneath.jpg',
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      const Color(0xFF7A1A2B),
    );

    // A route that never publishes a tint must use the shell surface rather
    // than leaking the color from the page underneath it.
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkspaceRouteTintBoundary(
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      isNull,
    );

    // Popping restores the same tint.
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      const Color(0xFF7A1A2B),
    );
  });

  testWidgets('covering route inherits only while extraction is pending', (
    tester,
  ) async {
    const underneath = Color(0xFF7A1A2B);
    final coveringExtraction = Completer<Color?>();
    WorkspaceChromeTintPublisher.debugChromeOverride = (url) =>
        url.contains('underneath') ? underneath : coveringExtraction.future;
    final controller = WorkspaceTabController();
    final navigatorKey = GlobalKey<NavigatorState>();

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
        home: WorkspaceTabScope(
          tabId: controller.activeTabId,
          controller: controller,
          child: _TintNavigator(
            navigatorKey: navigatorKey,
            firstChild: const WorkspaceChromeTintPublisher(
              imageUrl: 'https://example.com/underneath.jpg',
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkspaceRouteTintBoundary(
          child: WorkspaceChromeTintPublisher(
            imageUrl: 'https://example.com/cover.jpg',
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      underneath,
    );

    coveringExtraction.complete(null);
    await tester.pumpAndSettle();
    expect(
      WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
      isNull,
    );
  });

  testWidgets(
    'covering route tint replaces the one underneath once published',
    (tester) async {
      const underneath = Color(0xFF7A1A2B);
      const covering = Color(0xFF1A3B7A);
      WorkspaceChromeTintPublisher.debugChromeOverride = (url) =>
          url.contains('underneath') ? underneath : covering;
      final controller = WorkspaceTabController();
      final navigatorKey = GlobalKey<NavigatorState>();

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
          home: WorkspaceTabScope(
            tabId: controller.activeTabId,
            controller: controller,
            child: _TintNavigator(
              navigatorKey: navigatorKey,
              firstChild: const WorkspaceChromeTintPublisher(
                imageUrl: 'https://example.com/underneath.jpg',
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
        underneath,
      );

      // Cover it with a route that publishes its own tint: that one wins while
      // on top, and popping restores the tint underneath.
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const WorkspaceRouteTintBoundary(
            child: WorkspaceChromeTintPublisher(
              imageUrl: 'https://example.com/cover.jpg',
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
        covering,
      );
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId),
        underneath,
      );
    },
  );
}

/// A [Navigator] owning the two test routes so both stay inside the enclosing
/// [WorkspaceTabScope]; pushed routes otherwise build outside the scope and
/// publish to no tab.
class _TintNavigator extends StatelessWidget {
  const _TintNavigator({required this.navigatorKey, required this.firstChild});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget firstChild;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: [workspaceRouteObserver],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => WorkspaceRouteTintBoundary(child: firstChild),
      ),
    );
  }
}
