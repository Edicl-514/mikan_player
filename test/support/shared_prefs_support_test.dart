// Self-tests for the F-0 SharedPreferences support helpers.
//
// The goal is to lock in the contract: prior values are cleared, the new
// instance reflects the supplied [initial] map, and the type-dispatching
// [seedSharedPreferences] rejects unsupported types rather than silently
// no-op.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_prefs_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resetSharedPreferences', () {
    test('clears prior values returned by the fresh instance', () async {
      // Seed leftover state as a previous test would have.
      SharedPreferences.setMockInitialValues({'stale_key': 'stale_value'});
      final stale = await SharedPreferences.getInstance();
      expect(stale.getString('stale_key'), 'stale_value');

      final fresh = await resetSharedPreferences();
      // Fresh instance reflects the cleared store immediately.
      expect(fresh.getString('stale_key'), isNull);

      // Prior `stale` instance caches values into its own map; asking it to
      // reload pivots the cache to the new mock store. This is the contract
      // the helper documents via the docstring on `resetSharedPreferences`.
      await stale.reload();
      expect(stale.getString('stale_key'), isNull);
    });

    test('honors the [initial] argument for typed preseeding', () async {
      final prefs = await resetSharedPreferences(<String, Object>{
        'a_string': 'value',
        'an_int': 5,
        'a_double': 1.25,
        'a_bool': true,
        'a_list': <String>['x', 'y'],
      });

      expect(prefs.getString('a_string'), 'value');
      expect(prefs.getInt('an_int'), 5);
      expect(prefs.getDouble('a_double'), 1.25);
      expect(prefs.getBool('a_bool'), isTrue);
      expect(prefs.getStringList('a_list'), <String>['x', 'y']);
    });
  });

  group('seedSharedPreferences', () {
    test('appends values onto an existing instance', () async {
      await resetSharedPreferences();
      await seedSharedPreferences(<String, Object>{
        'one': '1',
        'two': 2,
        'three': 3.0,
        'four': true,
        'five': <String>['list'],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('one'), '1');
      expect(prefs.getInt('two'), 2);
      expect(prefs.getDouble('three'), 3.0);
      expect(prefs.getBool('four'), isTrue);
      expect(prefs.getStringList('five'), <String>['list']);
    });

    test('rejects unsupported value types with a clear ArgumentError',
        () async {
      await resetSharedPreferences();
      expect(
        () => seedSharedPreferences(<String, Object>{'bad': <int>[1, 2]}),
        throwsArgumentError,
      );
    });
  });
}
