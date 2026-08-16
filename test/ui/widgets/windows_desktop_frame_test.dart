import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_strip.dart';

void main() {
  tearDown(() {
    WindowsDesktopFrameController.instance.setContentFullscreen(false);
  });

  testWidgets('renders stable chrome with tab and context toolbar slots', (
    tester,
  ) async {
    var newTabCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en'),
          const Locale('zh'),
        ],
        home: WindowsDesktopFrame(
          tabStrip: const SizedBox(key: Key('tab-strip')),
          contextToolbar: const SizedBox(
            key: Key('context-toolbar'),
            height: 48,
          ),
          onNewTab: () => newTabCount += 1,
          child: const Center(child: Text('workspace body')),
        ),
      ),
    );

    expect(find.byKey(const Key('tab-strip')), findsOneWidget);
    expect(find.byKey(const Key('context-toolbar')), findsOneWidget);
    expect(find.byIcon(Icons.minimize), findsNothing);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));

    expect(newTabCount, 1);
    expect(find.text('workspace body'), findsOneWidget);
  });

  testWidgets('hides all desktop chrome while player content is fullscreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en'),
          const Locale('zh'),
        ],
        home: WindowsDesktopFrame(
          child: Center(child: Text('fullscreen player')),
        ),
      ),
    );

    WindowsDesktopFrameController.instance.setContentFullscreen(true);
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.text('fullscreen player'), findsOneWidget);
  });

  testWidgets('provides an overlay for title bar interactions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en'),
          const Locale('zh'),
        ],
        builder: (context, child) => WindowsDesktopFrame(
          onNewTab: () {},
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SizedBox(),
      ),
    );

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(tester.getCenter(find.byIcon(Icons.add)));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text('New tab'), findsOneWidget);
  });

  testWidgets('places new-tab button directly after the tab strip', (
    tester,
  ) async {
    final controller = WorkspaceTabController();
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
        supportedLocales: [
          const Locale('en'),
          const Locale('zh'),
        ],
        home: WindowsDesktopFrame(
          tabStrip: WorkspaceTabStrip(
            controller: controller,
            hostController: hostController,
          ),
          onNewTab: controller.create,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final tabRect = tester.getRect(
      find.byKey(ValueKey(controller.activeTabId)),
    );
    final newTabRect = tester.getRect(find.byIcon(Icons.add));

    // The button's 18px icon is centered in the 46px title-bar button.
    expect(newTabRect.left, tabRect.right + 14);
  });

  testWidgets('reorders tabs from a mouse drag without a long press', (
    tester,
  ) async {
    final controller = WorkspaceTabController();
    final hostController = WorkspaceTabHostController();
    final firstId = controller.activeTabId;
    final secondId = controller.create(activate: false);
    final thirdId = controller.create(activate: false);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en'),
          const Locale('zh'),
        ],
        builder: (context, child) => WindowsDesktopFrame(
          tabStrip: WorkspaceTabStrip(
            controller: controller,
            hostController: hostController,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SizedBox.expand(),
      ),
    );

    final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final firstTab = find.byKey(ValueKey(firstId));
    controller.activate(thirdId);
    await tester.pump();
    await tester.tap(firstTab);
    await tester.pump();
    expect(controller.activeTabId, firstId);

    final initialFirstTabLeft = tester.getRect(firstTab).left;
    await drag.addPointer(location: tester.getCenter(firstTab));
    await drag.moveTo(tester.getCenter(firstTab));
    await drag.down(tester.getCenter(firstTab));
    await tester.pump();
    await drag.moveBy(const Offset(16, 0));
    await tester.pump();
    await drag.moveTo(tester.getCenter(find.byKey(ValueKey(thirdId))));
    await tester.pump();
    expect(controller.tabs.map((tab) => tab.id), [firstId, secondId, thirdId]);
    expect(tester.getRect(firstTab).left, greaterThan(initialFirstTabLeft));
    await drag.up();
    await tester.pumpAndSettle();

    expect(controller.tabs.map((tab) => tab.id), [secondId, thirdId, firstId]);
    expect(tester.takeException(), isNull);
  });
}
