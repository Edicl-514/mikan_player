import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';

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
      const MaterialApp(
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
}
