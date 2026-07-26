import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/utils/debounced_async_action.dart';

void main() {
  test('coalesces rapid submissions to the latest action', () async {
    final values = <int>[];
    final action = DebouncedAsyncAction(
      delay: const Duration(milliseconds: 10),
    );

    action.schedule(() async => values.add(1));
    action.schedule(() async => values.add(2));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(values, [2]);
    action.dispose();
  });

  test('serializes immediate actions', () async {
    final values = <String>[];
    final firstMayFinish = Completer<void>();
    final action = DebouncedAsyncAction();

    final first = action.run(() async {
      values.add('first-start');
      await firstMayFinish.future;
      values.add('first-end');
    });
    final second = action.run(() async => values.add('second'));

    await Future<void>.delayed(Duration.zero);
    expect(values, ['first-start']);
    firstMayFinish.complete();
    await Future.wait([first, second]);

    expect(values, ['first-start', 'first-end', 'second']);
    action.dispose();
  });

  test('immediate action flushes a pending debounced action first', () async {
    final values = <String>[];
    final action = DebouncedAsyncAction(delay: const Duration(seconds: 1));

    action.schedule(() async => values.add('pending'));
    await action.run(() async => values.add('immediate'));

    expect(values, ['pending', 'immediate']);
    action.dispose();
  });

  test('flushes the last pending action on dispose', () async {
    final completed = Completer<void>();
    final action = DebouncedAsyncAction(delay: const Duration(seconds: 1));

    action.schedule(() async => completed.complete());
    action.dispose();

    await completed.future.timeout(const Duration(seconds: 1));
  });
}
