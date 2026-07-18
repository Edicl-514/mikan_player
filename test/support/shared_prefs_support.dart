// SharedPreferences test helpers.
//
// Most mikan_player services cache values on the SharedPreferences singleton
// (see `SettingsService`, `UserManager`, `BangumiEchService`, ...). The
// singleton survives across tests unless we explicitly swap the mock values
// or call `reload`. Tests should call [resetSharedPreferences] from `setUp`
// (and optionally `tearDown`) so a previous test's writes do not leak in.

import 'package:shared_preferences/shared_preferences.dart';

/// Replaces the in-memory SharedPreferences mock with a fresh empty map (or
/// [initial] when provided) and returns a freshly-loaded instance.
///
/// Always wipes every key — partial resets are a common source of test
/// flakiness. If a test wants to seed values it should pass them in [initial]
/// directly rather than relying on a previous test's leftover state.
///
/// IMPORTANT: any pre-existing `SharedPreferences` instance (e.g. one held by a
/// service that started before this helper ran) keeps its own in-memory cache
/// and will NOT observe the new mock values until it calls `await
/// prefs.reload()`. Tests that need a stale instance to re-read must call
/// [SharedPreferences.reload] on it explicitly — this helper cannot reach into
/// arbitrary references.
Future<SharedPreferences> resetSharedPreferences([
  Map<String, Object> initial = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  // The plugin caches a singleton instance on first `getInstance()`. After
  // `setMockInitialValues` subsequent `getInstance()` calls return a cache
  // backed by the new map, but only after the cached instance has been
  // invalidated. Calling `SharedPreferences.getInstance()` after
  // `setMockInitialValues` is the documented cache invalidation entry point
  // for the freshly-returned instance.
  return SharedPreferences.getInstance();
}

/// Writes the supplied [values] into the live [SharedPreferences] instance,
/// picking the right `setX` method per type.
///
/// Useful when a test needs to amend state mid-case without resetting the
/// whole instance (for example when simulating an upgrade path).
Future<void> seedSharedPreferences(Map<String, Object> values) async {
  final prefs = await SharedPreferences.getInstance();
  for (final entry in values.entries) {
    final value = entry.value;
    if (value is String) {
      await prefs.setString(entry.key, value);
    } else if (value is int) {
      await prefs.setInt(entry.key, value);
    } else if (value is double) {
      await prefs.setDouble(entry.key, value);
    } else if (value is bool) {
      await prefs.setBool(entry.key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(entry.key, value);
    } else {
      throw ArgumentError(
        'Unsupported SharedPreferences value type: ${value.runtimeType}',
      );
    }
  }
}
