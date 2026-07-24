import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/widgets/workspace_route_close_scope.dart';

void main() {
  testWidgets('pop waits for asynchronous close preparation', (tester) async {
    final closeCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => WorkspaceRouteCloseScope<void>(
                    prepareToClose: () => closeCompleter.future,
                    child: Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('close route'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open route'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('close route'));
    await tester.pump();

    expect(find.text('close route'), findsOneWidget);

    closeCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('close route'), findsNothing);
    expect(find.text('open route'), findsOneWidget);
  });
}
