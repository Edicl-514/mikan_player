import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/config.dart' as rust_config;

abstract interface class BangumiRequestModeBackend {
  Future<void> setMode(String mode);
}

class RustBangumiRequestModeBackend implements BangumiRequestModeBackend {
  const RustBangumiRequestModeBackend();

  @override
  Future<void> setMode(String mode) =>
      rust_config.setBangumiRequestMode(mode: mode);
}

enum BangumiRequestMode {
  legacy('legacy'),
  hybrid('hybrid'),
  modern('modern');

  const BangumiRequestMode(this.value);

  final String value;

  static BangumiRequestMode fromValue(String? value) {
    return BangumiRequestMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => BangumiRequestMode.hybrid,
    );
  }
}

class BangumiRequestModeService {
  BangumiRequestModeService._();

  static const String preferenceKey = 'bangumi_request_mode';
  static final ValueNotifier<BangumiRequestMode> notifier = ValueNotifier(
    BangumiRequestMode.hybrid,
  );
  static BangumiRequestModeBackend _backend =
      const RustBangumiRequestModeBackend();

  static Future<BangumiRequestMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = BangumiRequestMode.fromValue(prefs.getString(preferenceKey));
    if (notifier.value != mode) {
      notifier.value = mode;
    }
    return mode;
  }

  static Future<void> save(BangumiRequestMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, mode.value);
    await _backend.setMode(mode.value);
    if (notifier.value != mode) {
      notifier.value = mode;
    }
  }

  static Future<void> syncToRust() async {
    final mode = await load();
    await _backend.setMode(mode.value);
    if (notifier.value != mode) {
      notifier.value = mode;
    }
  }

  @visibleForTesting
  static void debugBindBackendForTest(BangumiRequestModeBackend backend) {
    _backend = backend;
  }

  @visibleForTesting
  static void debugResetForTest() {
    _backend = const RustBangumiRequestModeBackend();
    notifier.value = BangumiRequestMode.hybrid;
  }
}
