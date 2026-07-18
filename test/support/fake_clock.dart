// Throws-away controllable clock for tests that take a `now` injection point.
//
// Many services in this app discover the current time via `DateTime.now()`.
// When a behavior depends on time (TTL caches, cooldown windows, playback
// progress timestamps) the production code should accept a
// `DateTime Function() now` parameter and tests should pass a [FakeClock].
//
// For code that schedules [Timer]s or waits on [Future.delayed] prefer
// `package:fake_async` (a transitive dependency of `flutter_test`):
// ```dart
// import 'package:fake_async/fake_async.dart';
// fakeAsync((async) {
//   service.tick();
//   async.elapse(Duration(seconds: 5));
// });
// ```
// Use [FakeClock] only when you need a controllable wall-clock value.

import 'package:flutter_test/flutter_test.dart';

class FakeClock {
  FakeClock([DateTime? initial])
    : _now =
          initial ??
          DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000, isUtc: true);

  DateTime _now;

  /// Current wall-clock value, suitable as a drop-in for `DateTime.now()`.
  DateTime now() => _now;

  /// Advances the clock forward by [duration]. Negative durations throw —
  /// time is monotonic in tests so subtle ordering bugs surface.
  void advanceBy(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError(
        'FakeClock.advanceBy requires a non-negative duration, got $duration',
      );
    }
    _now = _now.add(duration);
  }

  /// Jumps the clock to [target]. Moving backwards throws by contract; use
  /// [reset] when a test genuinely wants to rewind (for example because a
  /// single instance is shared between test cases).
  void advanceTo(DateTime target) {
    if (target.isBefore(_now)) {
      throw ArgumentError('FakeClock cannot move backwards: $_now -> $target');
    }
    _now = target;
  }

  /// Re-points the clock to [target] (or the default epoch) without the
  /// monotonic guard. Intended for `setUp`/`tearDown` reset paths.
  void reset([DateTime? target]) {
    _now =
        target ??
        DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000, isUtc: true);
  }

  /// Convenience for the (surprisingly common) pattern of asserting
  /// "the clock read X after the recorded events".
  @override
  String toString() => 'FakeClock(now: $_now)';
}

/// Matches a [DateTime] against a [FakeClock] ignoring sub-millisecond
/// precision — used by recorder assertions where small rounding differences
/// across platforms should not fail the test.
Matcher equalsClockTime(DateTime expected) => _EqualsClockTime(expected);

class _EqualsClockTime extends Matcher {
  _EqualsClockTime(this._expected);
  final DateTime _expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! DateTime) return false;
    return item.millisecondsSinceEpoch == _expected.millisecondsSinceEpoch;
  }

  @override
  Description describe(Description description) => description
      .add('a DateTime in the same millisecond as ')
      .addDescriptionOf(_expected);
}
