import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/pages/about_page.dart';

void main() {
  testWidgets('workspace link follows browser pointer and keyboard rules', (
    tester,
  ) async {
    final current = <WorkspaceDestination>[];
    final background = <WorkspaceDestination>[];
    final destination = WorkspaceDestination(
      routeId: WorkspaceRouteId.allocate(),
      kind: 'probe',
      title: 'Probe',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceNavigationScope(
          openCurrent: current.add,
          openBackground: background.add,
          child: Material(
            child: Center(
              child: WorkspaceLink(
                destination: destination,
                builder: (context, activate) => InkWell(
                  key: const ValueKey('link'),
                  autofocus: true,
                  onTap: activate,
                  child: const SizedBox(width: 120, height: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final location = tester.getCenter(find.byKey(const ValueKey('link')));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.down(location));
    await tester.sendEventToBinding(mouse.up());
    await tester.pump();
    expect(current, [destination]);
    expect(background, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final ctrlMouse = TestPointer(2, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(ctrlMouse.down(location));
    await tester.sendEventToBinding(ctrlMouse.up());
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(current, [destination]);
    expect(background, [destination]);

    final middleMouse = TestPointer(3, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      middleMouse.down(location, buttons: kMiddleMouseButton),
    );
    await tester.sendEventToBinding(middleMouse.up());
    await tester.pump();
    expect(background, [destination, destination]);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(current, [destination, destination]);
  });

  testWidgets('falls back to Navigator when no workspace is available', (
    tester,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    WorkspaceNavigation.open<void>(
      pageContext,
      WorkspaceDestination(
        routeId: WorkspaceRouteId.allocate(),
        kind: 'about',
        title: 'About',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
  });

  testWidgets('keeps link disposition across asynchronous destination work', (
    tester,
  ) async {
    final background = <WorkspaceDestination>[];
    final destination = WorkspaceDestination(
      routeId: WorkspaceRouteId.allocate(),
      kind: 'async-probe',
      title: 'Async probe',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceNavigationScope(
          openCurrent: (_) {},
          openBackground: background.add,
          child: Builder(
            builder: (pageContext) => Material(
              child: TextButton(
                onPressed: () {},
                child: const Text('Async link'),
              ),
            ),
          ),
        ),
      ),
    );

    final pageContext = tester.element(find.text('Async link'));
    await WorkspaceNavigation.dispatchLink(
      WorkspaceOpenDisposition.backgroundTab,
      () async {
        await Future<void>.value();
        WorkspaceNavigation.open<void>(pageContext, destination);
      },
    );

    expect(background, [destination]);
  });
}
