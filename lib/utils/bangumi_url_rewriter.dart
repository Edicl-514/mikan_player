import 'package:mikan_player/src/rust/api/config.dart' as rust_config;

/// Helpers for translating the hard-coded bangumi host strings used elsewhere in
/// the Dart codebase (e.g. share-link copy buttons, comment smile fallbacks)
/// to whichever host the user has currently selected.
///
/// When the user opts into the reverse-proxy (`bangumi_use_reverse_proxy` =
/// true) the canonical hosts (`bangumi.tv`, `bgm.tv`, `chii.in`, `api.bgm.tv`,
/// `lain.bgm.tv`, `next.bgm.tv`, `fast.bgm.tv`, `doujin.bgm.tv`) get rewritten
/// to the mirror hosts (`bangumi.lol`, `api.bangumi.lol`, etc.). Otherwise the
/// inputs are returned unchanged.
class BangumiUrlRewriter {
  BangumiUrlRewriter._();

  static const Map<String, String> _realToMirror = {
    'bangumi.tv': 'bangumi.lol',
    'bgm.tv': 'bangumi.lol',
    'chii.in': 'bangumi.lol',
    'api.bgm.tv': 'api.bangumi.lol',
    'next.bgm.tv': 'next.bangumi.lol',
    'lain.bgm.tv': 'lain.bangumi.lol',
    'fast.bgm.tv': 'fast.bangumi.lol',
    'doujin.bgm.tv': 'doujin.bangumi.lol',
  };

  static const Map<String, String> _mirrorToReal = {
    'bangumi.lol': 'bangumi.tv',
    'api.bangumi.lol': 'api.bgm.tv',
    'next.bangumi.lol': 'next.bgm.tv',
    'lain.bangumi.lol': 'lain.bgm.tv',
    'fast.bangumi.lol': 'fast.bgm.tv',
    'doujin.bangumi.lol': 'doujin.bgm.tv',
  };

  static const Map<String, String> _canonicalHosts = {
    ..._mirrorToReal,
    'bgm.tv': 'bangumi.tv',
    'chii.in': 'bangumi.tv',
  };

  /// Returns the bangumi host currently selected for the given role (the
  /// canonical real form when proxying is disabled, the mirror host when
  /// enabled).
  static Future<String> hostFor(String role) async {
    final enabled = await rust_config.getBangumiReverseProxy();
    if (!enabled) {
      switch (role) {
        case 'main':
          return 'bangumi.tv';
        case 'api':
          return 'api.bgm.tv';
        case 'next':
          return 'next.bgm.tv';
        case 'lain':
          return 'lain.bgm.tv';
        default:
          return 'bangumi.tv';
      }
    }
    switch (role) {
      case 'main':
        return 'bangumi.lol';
      case 'api':
        return 'api.bangumi.lol';
      case 'next':
        return 'next.bangumi.lol';
      case 'lain':
        return 'lain.bangumi.lol';
      default:
        return 'bangumi.lol';
    }
  }

  /// Rewrite a known bangumi host (or full URL) to its mirror equivalent when
  /// the user has opted into reverse-proxy mode.
  static String rewrite(String input) {
    if (input.isEmpty) return input;
    final enabled = _cachedEnabled;
    if (enabled != true) {
      // When the cached flag is null/false we don't rewrite. This avoids
      // blocking hot paths on async reads.
      return input;
    }

    return _replaceKnownHost(input, _realToMirror);
  }

  /// Normalize a URL to always use the canonical (real) bangumi hosts,
  /// regardless of whether reverse-proxy mode is currently enabled.
  /// This produces a stable cache key that survives proxy toggling.
  static String canonicalize(String input) {
    if (input.isEmpty) return input;

    return _replaceKnownHost(input, _canonicalHosts);
  }

  /// Replaces only the parsed URL host, leaving path/query/fragment text
  /// untouched. Parsing the authority also prevents a known host used as a
  /// prefix of an unrelated host (for example `bangumi.tv.example.com`) from
  /// being rewritten.
  static String _replaceKnownHost(
    String input,
    Map<String, String> replacements,
  ) {
    final normalized = input.startsWith('//') ? 'https:$input' : input;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return normalized;
    }

    final replacement = replacements[uri.host.toLowerCase()];
    if (replacement == null) return normalized;
    return uri.replace(host: replacement).toString();
  }

  // The reverse-proxy toggle rarely changes during a session, so caching the
  // most recent value lets us avoid an FFI round-trip on every image render.
  // Set via [BangumiUrlRewriter.setEnabled].
  static bool? _cachedEnabled;

  /// Update the cached reverse-proxy flag. Call this whenever the user toggles
  /// the setting.
  static void setEnabled(bool enabled) {
    _cachedEnabled = enabled;
  }

  /// Read the latest cached reverse-proxy flag.
  static bool? get enabled => _cachedEnabled;
}
