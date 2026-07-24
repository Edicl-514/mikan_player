import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_lifecycle.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_strip.dart';

void main() {
  tearDown(() => WorkspaceLifecycleRegistry.instance.debugReset());

  testWidgets(
    'keeps tab state alive while switching and closes asynchronously',
    (tester) async {
      final controller = WorkspaceTabController();
      final hostController = WorkspaceTabHostController();
      final disposed = <String>[];
      final closeCompleter = Completer<void>();
      final id = controller.activeTabId;

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceTabHost(
            controller: controller,
            hostController: hostController,
            destinationBuilder: (context, destination) => _Probe(
              label: destination.title,
              onDispose: () => disposed.add(destination.title),
            ),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'first tab');

      final secondId = controller.create();
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '',
      );
      await tester.enterText(find.byType(TextField), 'second tab');
      controller.activate(id);
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'first tab',
      );
      expect(disposed, isEmpty);

      final fake = PlayerSessionHandle(
        sessionId: const PlayerSessionId('tab-session'),
        isPlaying: () => false,
        isBusy: () => false,
        pause: () {},
        resume: () {},
        prepareToClose: () => closeCompleter.future,
      );
      WorkspaceLifecycleRegistry.instance.register(fake, tabId: id);
      final closeFuture = hostController.closeTab(id);
      await tester.pump();
      expect(controller.tabById(id)!.isClosing, isTrue);
      expect(controller.tabById(secondId), isNotNull);
      expect(disposed, isEmpty);

      closeCompleter.complete();
      await closeFuture;
      await tester.pump();
      expect(controller.tabById(id), isNull);
      expect(controller.tabs, hasLength(1));
      expect(disposed, contains('Home'));
    },
  );

  testWidgets('handles workspace keyboard shortcuts', (tester) async {
    final controller = WorkspaceTabController();
    final hostController = WorkspaceTabHostController();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceTabHost(
          controller: controller,
          hostController: hostController,
          destinationBuilder: (context, destination) => const SizedBox(),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.tabs, hasLength(2));

    final active = controller.activeTabId;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.activeTabId, isNot(active));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(controller.tabs, hasLength(1));
  });

  testWidgets('middle mouse closes a tab without activating it', (
    tester,
  ) async {
    final controller = WorkspaceTabController();
    final hostController = WorkspaceTabHostController();
    final first = controller.activeTabId;
    final second = controller.create();
    controller.updateMetadata(second, title: 'Second');

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(
              height: 40,
              child: WorkspaceTabStrip(
                controller: controller,
                hostController: hostController,
              ),
            ),
            Expanded(
              child: WorkspaceTabHost(
                controller: controller,
                hostController: hostController,
                destinationBuilder: (context, destination) => const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final location = tester.getCenter(find.text('Home'));
    await tester.sendEventToBinding(
      pointer.down(location, buttons: kMiddleMouseButton),
    );
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(controller.tabById(first), isNull);
    expect(controller.activeTabId, second);
  });

  testWidgets('ctrl click opens a destination as an inactive tab root', (
    tester,
  ) async {
    final controller = WorkspaceTabController();
    final hostController = WorkspaceTabHostController();
    final originalTab = controller.activeTabId;
    final destination = WorkspaceDestination(
      routeId: WorkspaceRouteId.allocate(),
      kind: 'target',
      title: 'Target',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceTabHost(
          controller: controller,
          hostController: hostController,
          destinationBuilder: (context, current) {
            if (current.kind != WorkspaceDestination.homeKind) {
              return Text(current.title);
            }
            return Material(
              child: Center(
                child: WorkspaceLink(
                  destination: destination,
                  builder: (context, activate) => InkWell(
                    key: const ValueKey('workspace-link'),
                    onTap: activate,
                    child: const SizedBox(width: 120, height: 48),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final pointer = TestPointer(9, PointerDeviceKind.mouse);
    final location = tester.getCenter(
      find.byKey(const ValueKey('workspace-link')),
    );
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(pointer.up());
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.tabs, hasLength(2));
    expect(controller.activeTabId, originalTab);
    expect(controller.tabs.last.destinations, [destination]);
    expect(controller.tabs.last.canGoBack, isFalse);
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.label, required this.onDispose});

  final String label;
  final VoidCallback onDispose;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    child: Column(
      children: [
        Text(widget.label),
        const SizedBox(width: 240, child: TextField()),
      ],
    ),
  );
}
