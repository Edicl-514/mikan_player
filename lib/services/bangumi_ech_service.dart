import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class BangumiEchBackend {
  Future<void> setEnabled(bool enabled);
  Future<int> refresh();
  Future<void> warmup();
  Future<List<String>> setDohEndpoints(List<String> endpoints);
  Future<List<String>> moveDohEndpoint(int from, int to);
  Future<List<String>> resetDohEndpoints();
}

class RustBangumiEchBackend implements BangumiEchBackend {
  const RustBangumiEchBackend();

  @override
  Future<void> setEnabled(bool enabled) =>
      rust.setBangumiUseEch(enabled: enabled);

  @override
  Future<int> refresh() async => (await rust.refreshBangumiEchConfig()).toInt();

  @override
  Future<void> warmup() => rust.warmupBangumiEchConfig();

  @override
  Future<List<String>> setDohEndpoints(List<String> endpoints) =>
      rust.setBangumiDohEndpoints(endpoints: endpoints);

  @override
  Future<List<String>> moveDohEndpoint(int from, int to) =>
      rust.moveBangumiDohEndpoint(from: BigInt.from(from), to: BigInt.from(to));

  @override
  Future<List<String>> resetDohEndpoints() => rust.resetBangumiDohEndpoints();
}

/// Persists the user's ECH (Encrypted Client Hello) preference for bangumi
/// requests and mirrors it to the Rust runtime.
///
/// Independent from the bangumi reverse-proxy toggle. ECH and reverse-proxy
/// can be combined, but the supported product path is:
///   * `useEch=on,  useProxy=off` — preferred default; ECH straight to
///     Cloudflare IPs with the inner SNI HPKE-encrypted.
///   * `useEch=off, useProxy=on`  — fallback when ECHConfig fetching fails.
///   * `useEch=on,  useProxy=on`  — works only when the mirror domain is
///     also fronted by Cloudflare with ECH enabled. Not guaranteed.
///
/// The DoH endpoint list used to fetch Cloudflare's ECHConfig is also
/// persisted here. Users in mainland China can substitute DoH endpoints that
/// are reachable from their network; the Rust side walks the list in order
/// and picks the first one that returns a parseable ECHConfig.
class BangumiEchService {
  BangumiEchService._();

  static const String preferenceKey = 'bangumi_use_ech';
  static const String dohListKey = 'bangumi_doh_endpoints';

  /// Compiled-in default DoH endpoints, mirroring `DEFAULT_DOH_ENDPOINTS`
  /// in `rust/src/api/ech.rs`. Shown in the settings UI when the user has not
  /// configured a custom list. Keep in sync with the Rust constant.
  static const List<String> defaultDohEndpoints = <String>[
    'https://doh.090227.xyz/SB-query',
    'https://dns.alidns.com/resolve',
    'https://doh.pub/resolve',
  ];

  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(true);
  static final ValueNotifier<List<String>> dohNotifier =
      ValueNotifier<List<String>>(const []);
  static BangumiEchBackend _backend = const RustBangumiEchBackend();

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getBool(preferenceKey);
    // Default to `true` so mainland-China users immediately benefit from
    // SNI cloaking; users in unrestricted regions can disable it in settings.
    final value = raw ?? true;
    if (notifier.value != value) {
      notifier.value = value;
    }
    await _backend.setEnabled(value);
    await _syncDohList(prefs);
    return value;
  }

  static Future<void> save(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey, enabled);
    await _backend.setEnabled(enabled);
    if (notifier.value != enabled) {
      notifier.value = enabled;
    }
  }

  /// Force-refresh the cached ECHConfig (e.g. from the settings UI).
  /// Returns the byte length of the new ECHConfigList, or 0 on failure.
  static Future<int> refresh() async {
    return _backend.refresh();
  }

  /// Warm the ECHConfig cache if ECH is enabled and the cache is empty.
  /// Safe to call from app startup.
  static Future<void> warmup() async {
    await _backend.warmup();
  }

  static Future<void> syncToRust() async {
    await load();
  }

  /// Read the persisted DoH list and push it to the Rust runtime.
  static Future<List<String>> _syncDohList(SharedPreferences prefs) async {
    final stored = prefs.getStringList(dohListKey);
    final list = stored ?? const <String>[];
    final result = await _backend.setDohEndpoints(list);
    if (listEquals(result, dohNotifier.value) == false) {
      dohNotifier.value = List<String>.unmodifiable(result);
    }
    return result;
  }

  /// Public read: returns the user-configured DoH list. Empty list means
  /// "use the compiled-in defaults on the Rust side".
  static Future<List<String>> getDohEndpoints() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(dohListKey) ?? const <String>[];
    return stored;
  }

  /// Add `endpoint` to the end of the user DoH list. Persists to
  /// SharedPreferences and syncs to Rust. Returns the updated list.
  static Future<List<String>> addDohEndpoint(String endpoint) async {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return getDohEndpoints();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(dohListKey) ?? <String>[];
    if (current.any((e) => _normalize(e) == _normalize(trimmed))) {
      return current;
    }
    final updated = [...current, trimmed];
    await prefs.setStringList(dohListKey, updated);
    return _syncDohList(prefs);
  }

  /// Remove `endpoint` from the user DoH list. Persists and syncs.
  /// Returns the updated list.
  static Future<List<String>> removeDohEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(dohListKey) ?? <String>[];
    final updated = current
        .where((e) => _normalize(e) != _normalize(endpoint))
        .toList();
    await prefs.setStringList(dohListKey, updated);
    return _syncDohList(prefs);
  }

  /// Move the entry at `from` to position `to` in the user DoH list.
  /// Persists and syncs. Returns the updated list.
  static Future<List<String>> moveDohEndpoint(int from, int to) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(
      prefs.getStringList(dohListKey) ?? <String>[],
    );
    if (current.isEmpty || from < 0 || from >= current.length) {
      return current;
    }
    final clampedTo = to.clamp(0, current.length - 1);
    if (from == clampedTo) {
      return current;
    }
    final item = current.removeAt(from);
    current.insert(clampedTo, item);
    await prefs.setStringList(dohListKey, current);
    final result = await _backend.moveDohEndpoint(from, clampedTo);
    if (listEquals(result, dohNotifier.value) == false) {
      dohNotifier.value = List<String>.unmodifiable(result);
    }
    return result;
  }

  /// Reset the user DoH list back to empty (= use compiled-in defaults).
  /// Persists and syncs. Returns the resulting list (which will be empty).
  static Future<List<String>> resetDohEndpoints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(dohListKey);
    final result = await _backend.resetDohEndpoints();
    if (listEquals(result, dohNotifier.value) == false) {
      dohNotifier.value = List<String>.unmodifiable(result);
    }
    return result;
  }

  /// Replace the entire user DoH list. Useful for paste-in or restore.
  static Future<List<String>> setDohEndpoints(List<String> endpoints) async {
    final cleaned = endpoints
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(dohListKey, cleaned);
    return _syncDohList(prefs);
  }

  /// Test a single DoH endpoint by attempting to fetch the ECHConfig from it.
  /// Returns the byte length of the ECHConfig returned on success, or 0 on
  /// failure. Failure does NOT mutate the user DoH list.
  static Future<int> testDohEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getStringList(dohListKey) ?? <String>[];
    try {
      // Temporarily push just this single endpoint to Rust, refresh, capture
      // the byte length, then restore the previous list.
      await prefs.setStringList(dohListKey, [endpoint.trim()]);
      await _syncDohList(prefs);
      return await _backend.refresh();
    } catch (_) {
      return 0;
    } finally {
      // This is a temporary probe: never leak the tested endpoint into the
      // user's persisted list or the Rust runtime, even when refresh throws.
      await prefs.setStringList(dohListKey, previous);
      await _syncDohList(prefs);
    }
  }

  /// Encode the user DoH list as a JSON string for the export UI.
  static String exportDohEndpointsJson(List<String> endpoints) {
    return jsonEncode(endpoints);
  }

  /// Decode a JSON-encoded DoH list. Returns null on parse failure.
  static List<String>? importDohEndpointsJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  static String _normalize(String s) {
    var value = s.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  @visibleForTesting
  static void debugBindBackendForTest(BangumiEchBackend backend) {
    _backend = backend;
  }

  @visibleForTesting
  static void debugResetForTest() {
    _backend = const RustBangumiEchBackend();
    notifier.value = true;
    dohNotifier.value = const [];
  }
}
