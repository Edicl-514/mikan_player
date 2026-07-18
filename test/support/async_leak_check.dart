// Resource leak checker for `async` tear-down paths.
//
// Many bugs in this app are caused by `StreamSubscription`s, `Timer`s, or
// [Future]-gated side effects surviving a test case and racing with the next
// one ("setState after dispose", double-completion, late callback). The
// checker is a small ledger: tests register every disposable created during
// the case and call [verify] from `tearDown`. Any handle still alive at that
// point becomes a [TestFailure] rather than silently leaking into the next
// test.
//
// Prefer `addTearDown` for trivial cleanup; reach for this helper only when
// the test volunteers a list of handles whose lifetime is not contiguous
// with the test body itself (for example subscriptions returned from
// `StreamController.broadcast`).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Tracks disposables across a single test case.
class AsyncLeakCheck {
  final List<DisposableHandle> _handles = <DisposableHandle>[];

  /// Registers a [StreamSubscription] for cleanup/validation.
  void registerStreamSubscription<T>(
    StreamSubscription<T> subscription, {
    String label = 'StreamSubscription',
  }) {
    _handles.add(_StreamSubscriptionHandle<T>(subscription, label));
  }

  /// Registers a [Timer] for cleanup/validation.
  void registerTimer(Timer timer, {String label = 'Timer'}) {
    _handles.add(_TimerHandle(timer, label));
  }

  /// Registers a generic `void Function()` teardown as a disposable.
  void registerDisposer(void Function() disposer, {String label = 'disposer'}) {
    _handles.add(_CallbackHandle(disposer, label));
  }

  /// Returns handles that have NOT been disposed so far.
  List<DisposableHandle> get pending =>
      _handles.where((h) => !h.isDisposed).toList(growable: false);

  /// Number of handles still alive. 0 means everyone called dispose/onCancel.
  int get pendingCount => pending.length;

  /// Calls every pending handle's dispose routine. Swallows exceptions so a
  /// single misbehaving disposer cannot mask other leaks; the per-handle error
  /// is recorded in [disposeErrors] for inspection.
  final List<Object> disposeErrors = <Object>[];

  Future<void> disposeAll() async {
    for (final handle in _handles) {
      if (handle.isDisposed) continue;
      try {
        await handle.dispose();
      } catch (e) {
        disposeErrors.add(e);
      }
    }
  }

  /// Throws a [TestFailure] naming every handle still alive. [message], when
  /// provided, becomes the leading fragment of the failure text — the handle
  /// labels are always appended so the localized failure shows which
  /// subscription/timer actually leaked.
  void verify({String? message}) {
    final alive = pending;
    if (alive.isEmpty) return;
    final names = alive.map((h) => h.label).join(', ');
    final fallback = 'Leaked resources still alive at end of test';
    throw TestFailure('${message ?? fallback}: $names');
  }
}

/// Opaque handle to a resource tracked by [AsyncLeakCheck]. Subclasses are
/// private and registered only via the typed [AsyncLeakCheck.register*]
/// helpers — external code must not construct handles itself.
abstract class DisposableHandle {
  const DisposableHandle({required this.label});

  final String label;

  bool get isDisposed;

  Future<void> dispose();
}
class _StreamSubscriptionHandle<T> implements DisposableHandle {
  _StreamSubscriptionHandle(this._subscription, this.label);

  @override
  final String label;
  final StreamSubscription<T> _subscription;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription.cancel();
  }
}

class _TimerHandle implements DisposableHandle {
  _TimerHandle(this._timer, this.label);

  @override
  final String label;
  final Timer _timer;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer.cancel();
  }
}

class _CallbackHandle implements DisposableHandle {
  _CallbackHandle(this._callback, this.label);

  @override
  final String label;
  final void Function() _callback;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _callback();
  }
}
