import 'dart:async';

import 'package:flutter/foundation.dart';

typedef AsyncAction = Future<void> Function();

/// Coalesces rapid changes and runs asynchronous writes in submission order.
class DebouncedAsyncAction {
  DebouncedAsyncAction({
    this.delay = const Duration(milliseconds: 400),
    this.debugLabel = 'async action',
  });

  final Duration delay;
  final String debugLabel;

  Timer? _timer;
  AsyncAction? _pending;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  void schedule(AsyncAction action) {
    if (_disposed) return;
    _pending = action;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final pending = _pending;
      _pending = null;
      _timer = null;
      if (pending != null) _enqueue(pending);
    });
  }

  Future<void> run(AsyncAction action) {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) _enqueue(pending);
    return _enqueue(action);
  }

  /// Flushes the last debounced change while allowing queued writes to finish.
  void dispose() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) _enqueue(pending);
    _disposed = true;
  }

  Future<void> _enqueue(AsyncAction action) {
    final operation = _tail.then<void>((_) => action());
    final guarded = operation.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Failed to run $debugLabel: $error');
      debugPrintStack(stackTrace: stackTrace);
    });
    _tail = guarded;
    return guarded;
  }
}
