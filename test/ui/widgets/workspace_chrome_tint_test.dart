import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('title bar animates to a published tint and back', (
    tester,
  ) async {
    final controller = WorkspaceTabController();
    await tester.pumpWidget(
      MaterialApp(
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
}
