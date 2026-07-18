// Event recorder + pending-result helper for fake services.
//
// L10N/DT tests frequently need a stand-in implementation of a service or a
// repo callback. Stand-ins should:
//   1. record each invocation (name + optional args/result) so the test can
//      assert on the observed call sequence;
//   2. optionally expose [PendingResult] handles so the test can complete or
//      fail an in-flight operation on demand — useful for simulating async
//      latency, cancellations, and timeouts without `Future.delayed`.
//
// These helpers are deliberately tiny and free of test-framework coupling so
// they can be constructed outside an `setUp` block too.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// One recorded invocation. [args] / [result] are deliberately untyped so the
/// recorder can be reused across many fakes — assertions should downcast and
/// validate inside the test body.
class RecordedEvent {
  RecordedEvent(this.name, this.args, this.result, {DateTime? at})
    : at = at ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  final String name;
  final Object? args;
  final Object? result;
  final DateTime at;

  @override
  String toString() => 'RecordedEvent($name, args=$args, result=$result)';
}

/// Append-only ledger of events emitted by a fake service. Tests assert on
/// [records] via [expectInOrder], [expectContainsPredicate] or by reading
/// [records] directly.
class EventRecorder {
  final List<RecordedEvent> _records = <RecordedEvent>[];

  List<RecordedEvent> get records => List.unmodifiable(_records);

  void record(String name, {Object? args, Object? result}) {
    _records.add(RecordedEvent(name, args, result, at: DateTime.now()));
  }

  void clear() => _records.clear();

  /// Asserts the recorder saw events whose [RecordedEvent.name]s match
  /// [names] in order; other events interleaved between the listed ones are
  /// allowed. Use [expectStrictOrder] when interleaving is a bug.
  void expectInOrder(Iterable<String> names) {
    final needle = names.toList(growable: false);
    if (needle.isEmpty) return;
    var index = 0;
    for (final event in _records) {
      if (event.name == needle[index]) index++;
      if (index == needle.length) break;
    }
    if (index != needle.length) {
      throw TestFailure(
        'expected in-order events $needle, but only matched first $index of '
        '${needle.length}. Recorded: ${_records.map((e) => e.name).toList()}',
      );
    }
  }

  /// Asserts the recorder saw exactly the events named in [names] in order.
  void expectStrictOrder(Iterable<String> names) {
    final actual = _records.map((e) => e.name).toList();
    final needle = names.toList(growable: false);
    if (actual.length != needle.length || !_listEquals(actual, needle)) {
      throw TestFailure('expected strict order $needle, got $actual');
    }
  }

  void expectContainsPredicate(bool Function(RecordedEvent) predicate) {
    if (_records.every((e) => !predicate(e))) {
      throw TestFailure(
        'no recorded event satisfied the predicate; '
        'records: ${_records.map((e) => e.name).toList()}',
      );
    }
  }

  void expectNoMoreCalls() {
    if (_records.isNotEmpty) {
      throw TestFailure(
        'expected no further events, got ${_records.map((e) => e.name).toList()}',
      );
    }
  }
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A single-shot completer for fake service methods that should hang until the
/// test explicitly completes them with [complete] / [completeError].
///
/// Wrap any `Future<T>` you intend to gate on in a [PendingResult] and either:
///   - await [future] in production-shaped call sites; or
///   - drive [complete] / [completeError] from the test to release the
///     awaiting side. Both methods are idempotent so double-completion due to
///     a cleanup callback does not raise.
class PendingResult<T> {
  final Completer<T> _completer = Completer<T>.sync();

  Future<T> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void complete(T value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void completeError(Object error, [StackTrace? stack]) {
    if (!_completer.isCompleted) _completer.completeError(error, stack);
  }
}
