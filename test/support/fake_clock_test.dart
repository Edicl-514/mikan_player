// Self-tests for the F-0 controllable clock helper.
//
// The tests focus on the monotonic/non-monotonic contract — a backwards move
// should fail loudly so future time-dependent services surface ordering bugs.

import 'package:flutter_test/flutter_test.dart';

import 'fake_clock.dart';

void main() {
  group('FakeClock', () {
    test('now returns the constructor-initial value', () {
      final base = DateTime.utc(2024, 4, 1, 12);
      final clock = FakeClock(base);
      expect(clock.now(), base);
    });

    test('advanceBy adds a positive duration', () {
      final clock = FakeClock(DateTime.utc(2024, 1, 1));
      clock.advanceBy(const Duration(hours: 3));
      expect(clock.now(), DateTime.utc(2024, 1, 1, 3));
    });

    test('advanceBy with a negative duration throws', () {
      final clock = FakeClock();
      expect(
        () => clock.advanceBy(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('advanceTo moves the clock forward to the target', () {
      final clock = FakeClock(DateTime.utc(2024, 1, 1));
      clock.advanceTo(DateTime.utc(2024, 1, 2));
      expect(clock.now(), DateTime.utc(2024, 1, 2));
    });

    test('advanceTo with an earlier target throws', () {
      final clock = FakeClock(DateTime.utc(2024, 1, 2));
      expect(
        () => clock.advanceTo(DateTime.utc(2024, 1, 1)),
        throwsArgumentError,
      );
    });

    test('reset can move backwards (explicit override of monotonic guard)', () {
      final clock = FakeClock(DateTime.utc(2024, 1, 5));
      clock.reset(DateTime.utc(2024, 1, 1));
      expect(clock.now(), DateTime.utc(2024, 1, 1));
    });

    test('equalsClockTime matcher tolerates UTC vs local offset', () {
      expect(
        DateTime.utc(2024, 6, 1, 0, 0, 0),
        equalsClockTime(DateTime.parse('2024-06-01T08:00:00+08:00')),
      );
    });

    test('equalsClockTime ignores microseconds within a millisecond', () {
      final expected = DateTime.utc(2024, 6, 1, 0, 0, 0, 123, 0);
      final actual = DateTime.utc(2024, 6, 1, 0, 0, 0, 123, 999);
      expect(actual, equalsClockTime(expected));
      expect(
        DateTime.utc(2024, 6, 1, 0, 0, 0, 124),
        isNot(equalsClockTime(expected)),
      );
    });
  });
}
