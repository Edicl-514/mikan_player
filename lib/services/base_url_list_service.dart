import 'package:shared_preferences/shared_preferences.dart';

/// Identifies which base-URL list a [BaseUrlListService] call refers to.
enum BaseUrlKind {
  /// bgmlist.com
  bgmlist,

  /// bangumi.tv / bgm.tv / chii.in
  bangumi,

  /// mikanani mirrors
  mikan,
}

/// Manages the selectable base-URL lists for bgmlist / bangumi / mikan.
///
/// Each list is the union of a compiled-in set of [builtinUrls] (which can
/// never be removed) and a user-maintained set of custom URLs persisted in
/// `SharedPreferences`. The currently selected URL is stored separately as a
/// plain string preference (preserving the legacy `bgmlist_url` /
/// `bangumi_url` / `mikan_url` keys).
class BaseUrlListService {
  BaseUrlListService._();

  /// Built-in URLs per kind. These cannot be deleted by the user.
  static const Map<BaseUrlKind, List<String>> builtinUrls = {
    BaseUrlKind.bgmlist: ['https://bgmlist.com'],
    BaseUrlKind.bangumi: [
      'https://bangumi.tv',
      'https://bgm.tv',
      'https://chii.in',
    ],
    BaseUrlKind.mikan: [
      'https://mikanani.kas.pub',
      'https://mikan2.yujiangqaq.com',
      'https://mikan.makura.cc',
      'https://mikanani.me',
    ],
  };

  /// Preference key holding the currently-selected URL for each kind.
  static const Map<BaseUrlKind, String> selectedPrefKey = {
    BaseUrlKind.bgmlist: 'bgmlist_url',
    BaseUrlKind.bangumi: 'bangumi_url',
    BaseUrlKind.mikan: 'mikan_url',
  };

  /// Preference key holding the user's custom (non-builtin) URLs for each kind.
  static const Map<BaseUrlKind, String> customListPrefKey = {
    BaseUrlKind.bgmlist: 'bgmlist_url_custom_list',
    BaseUrlKind.bangumi: 'bangumi_url_custom_list',
    BaseUrlKind.mikan: 'mikan_url_custom_list',
  };

  static List<String> builtinFor(BaseUrlKind kind) =>
      builtinUrls[kind] ?? const <String>[];

  /// Trims and strips trailing slashes so equivalent URLs compare equal.
  static String normalize(String url) {
    var value = url.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static bool isBuiltin(BaseUrlKind kind, String url) {
    final target = normalize(url);
    return builtinFor(kind).any((b) => normalize(b) == target);
  }

  /// Merges builtin + custom URLs, dropping any custom entry that duplicates a
  /// builtin (after normalisation).
  static List<String> mergeUrls(
    BaseUrlKind kind,
    List<String> custom,
  ) {
    final builtin = builtinFor(kind);
    final seen = <String>{};
    final result = <String>[];
    for (final url in [...builtin, ...custom]) {
      final normalized = normalize(url);
      if (normalized.isEmpty) continue;
      if (seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(normalized);
    }
    return result;
  }

  /// Returns the merged list of all selectable URLs (builtin + custom).
  static Future<List<String>> getAllUrls(BaseUrlKind kind) async {
    final custom = await getCustomUrls(kind);
    return mergeUrls(kind, custom);
  }

  /// Returns only the user-added custom URLs.
  static Future<List<String>> getCustomUrls(BaseUrlKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(customListPrefKey[kind]!) ?? const <String>[];
  }

  /// Returns the currently selected URL, defaulting to the first builtin.
  static Future<String> getSelected(BaseUrlKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedPrefKey[kind]!) ??
        builtinFor(kind).first;
  }

  /// Persists the selected URL (normalised).
  static Future<void> setSelected(BaseUrlKind kind, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedPrefKey[kind]!, normalize(url));
  }

  /// Adds [url] to the custom list (if it is not a builtin and not already
  /// present). Returns the resulting merged list of all selectable URLs.
  static Future<List<String>> addCustomUrl(
    BaseUrlKind kind,
    String url,
  ) async {
    final cleaned = normalize(url);
    if (cleaned.isEmpty) return getAllUrls(kind);
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      return getAllUrls(kind);
    }
    if (isBuiltin(kind, cleaned)) {
      return getAllUrls(kind);
    }
    final prefs = await SharedPreferences.getInstance();
    final key = customListPrefKey[kind]!;
    final current = prefs.getStringList(key) ?? <String>[];
    if (current.any((e) => normalize(e) == cleaned)) {
      return mergeUrls(kind, current);
    }
    final updated = [...current, cleaned];
    await prefs.setStringList(key, updated);
    return mergeUrls(kind, updated);
  }

  /// Removes [url] from the custom list. Builtin URLs are never removed.
  /// Returns the resulting merged list of all selectable URLs.
  static Future<List<String>> removeCustomUrl(
    BaseUrlKind kind,
    String url,
  ) async {
    final target = normalize(url);
    if (isBuiltin(kind, target)) {
      return getAllUrls(kind);
    }
    final prefs = await SharedPreferences.getInstance();
    final key = customListPrefKey[kind]!;
    final current = prefs.getStringList(key) ?? <String>[];
    final updated = current.where((e) => normalize(e) != target).toList();
    await prefs.setStringList(key, updated);

    // If the removed URL was the current selection, fall back to the first
    // builtin so the runtime never points at a deleted entry.
    final selected = prefs.getString(selectedPrefKey[kind]!);
    if (selected != null && normalize(selected) == target) {
      await prefs.setString(
        selectedPrefKey[kind]!,
        builtinFor(kind).first,
      );
    }
    return mergeUrls(kind, updated);
  }
}
