import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/config.dart' as rust_config;
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

class BangumiReverseProxyService {
  BangumiReverseProxyService._();

  static const String preferenceKey = 'bangumi_use_reverse_proxy';

  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getBool(preferenceKey);
    // Default to `false`: the user has to opt-in. This preserves the previous
    // behaviour for everyone who was happily using the canonical bangumi.tv /
    // bgm.tv hosts.
    final value = raw ?? false;
    if (notifier.value != value) {
      notifier.value = value;
    }
    BangumiUrlRewriter.setEnabled(value);
    return value;
  }

  static Future<void> save(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey, enabled);
    await rust_config.setBangumiReverseProxy(enabled: enabled);
    if (notifier.value != enabled) {
      notifier.value = enabled;
    }
    BangumiUrlRewriter.setEnabled(enabled);
  }

  static Future<void> syncToRust() async {
    final value = await load();
    await rust_config.setBangumiReverseProxy(enabled: value);
    BangumiUrlRewriter.setEnabled(value);
  }
}
