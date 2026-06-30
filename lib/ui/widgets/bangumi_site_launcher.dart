import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches a bangumi-data site URL in the device's default browser.
///
/// Rejects anything that is not an `http(s)` URL as a defense-in-depth
/// measure: the bangumi-data payload is community-maintained and could
/// in theory contain `javascript:` or other schemes that should never
/// be auto-launched from a tap on a static icon.
///
/// Logs failures via [debugPrint] so we can diagnose the rare case
/// where the platform refuses to hand off the URL (e.g. no browser
/// installed).
Future<void> launchBangumiSiteUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (!uri.hasScheme || !uri.scheme.startsWith('http')) {
      debugPrint('Refusing to launch non-HTTP URL: $url');
      return;
    }
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      debugPrint('launchUrl returned false for $url');
    }
  } catch (e) {
    debugPrint('Failed to launch $url: $e');
  }
}
