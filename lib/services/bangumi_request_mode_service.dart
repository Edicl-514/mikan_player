import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/config.dart' as rust_config;

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

  static Future<BangumiRequestMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BangumiRequestMode.fromValue(prefs.getString(preferenceKey));
  }

  static Future<void> save(BangumiRequestMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, mode.value);
    await rust_config.setBangumiRequestMode(mode: mode.value);
  }

  static Future<void> syncToRust() async {
    final mode = await load();
    await rust_config.setBangumiRequestMode(mode: mode.value);
  }
}
