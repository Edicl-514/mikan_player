// Header strategies for HTTP / HLS downloads.
//
// Some CDNs require a play-page Referer (anti-hotlink). Others enforce a
// Referer ACL that *rejects* foreign origins (e.g. douyinvod's
// `Ks-Deny-Reason: referer-acl-deny`). media_kit often succeeds with no
// Referer, while a single fixed download policy cannot cover both camps.
//
// Instead of a host denylist, try a short ordered list of distinct header
// sets. On a retryable status (403 / 401 / …) fall through to the next
// strategy; pin the winner onto the task so resume / remaining HLS segments
// reuse it without re-probing.

/// Identity of one header strategy in the download fallback chain.
enum HttpDownloadHeaderStrategyId {
  /// Caller-supplied headers as-is (typically UA + Referer + captured fields).
  base,

  /// Base headers with every Referer key removed.
  withoutReferer,

  /// Base headers with Referer and Origin removed.
  withoutRefererAndOrigin,

  /// Minimal request: only a User-Agent (default if base had none).
  userAgentOnly,
}

/// One concrete header map to try for an HTTP download open.
class HttpDownloadHeaderStrategy {
  const HttpDownloadHeaderStrategy({required this.id, required this.headers});

  final HttpDownloadHeaderStrategyId id;

  /// Header map passed to the download port. Never contains a `Range` key —
  /// the job layer owns resume Range separately.
  final Map<String, String>? headers;
}

/// Default browser UA mirrored from [PlayerPlaybackController.defaultUserAgent]
/// so a `userAgentOnly` strategy still looks like a browser when the base map
/// had no UA at all.
const String kDefaultHttpDownloadUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Builds an ordered, de-duplicated list of header strategies to try.
///
/// Order is intentional:
/// 1. [base] — keeps the historic anti-hotlink Referer that many video hosts
///    require.
/// 2. [withoutReferer] — matches media_kit / "open URL in browser" for CDNs
///    that ACL-deny foreign Referers.
/// 3. [withoutRefererAndOrigin] — some CDNs also reject a foreign Origin.
/// 4. [userAgentOnly] — last-ditch bare request.
List<HttpDownloadHeaderStrategy> buildHttpDownloadHeaderStrategies(
  Map<String, String>? baseHeaders, {
  String defaultUserAgent = kDefaultHttpDownloadUserAgent,
}) {
  final strategies = <HttpDownloadHeaderStrategy>[];
  final seen = <String>{};

  void add(HttpDownloadHeaderStrategyId id, Map<String, String>? headers) {
    final fingerprint = _headerFingerprint(headers);
    if (!seen.add(fingerprint)) return;
    strategies.add(HttpDownloadHeaderStrategy(id: id, headers: headers));
  }

  add(HttpDownloadHeaderStrategyId.base, _copyHeaders(baseHeaders));
  add(
    HttpDownloadHeaderStrategyId.withoutReferer,
    _headersWithoutKeys(baseHeaders, const {'referer'}),
  );
  add(
    HttpDownloadHeaderStrategyId.withoutRefererAndOrigin,
    _headersWithoutKeys(baseHeaders, const {'referer', 'origin'}),
  );

  final ua =
      _findHeaderValue(baseHeaders, 'user-agent') ??
      _findHeaderValue(baseHeaders, 'useragent') ??
      defaultUserAgent;
  add(HttpDownloadHeaderStrategyId.userAgentOnly, {'User-Agent': ua});

  return strategies;
}

/// True when [error] looks like a non-2xx status that is worth retrying under
/// a different header strategy. Connection failures and mid-stream IO errors
/// are not retried here — they are not header-policy problems.
bool isRetryableHttpHeaderStatusError(Object error) {
  final match = RegExp(
    r'HTTP\s+(\d{3})',
    caseSensitive: false,
  ).firstMatch(error.toString());
  if (match == null) return false;
  final code = int.tryParse(match.group(1)!);
  if (code == null) return false;
  // 401/403: auth / referer ACL. 407: proxy auth. 451: legal block sometimes
  // misused as ACL. 5xx is not retried with different headers.
  return code == 401 || code == 403 || code == 407 || code == 451;
}

Map<String, String>? _copyHeaders(Map<String, String>? headers) {
  if (headers == null) return null;
  return Map<String, String>.from(headers);
}

Map<String, String>? _headersWithoutKeys(
  Map<String, String>? headers,
  Set<String> lowerKeysToDrop,
) {
  if (headers == null) return null;
  final result = <String, String>{};
  for (final entry in headers.entries) {
    if (lowerKeysToDrop.contains(entry.key.trim().toLowerCase())) continue;
    result[entry.key] = entry.value;
  }
  return result;
}

String? _findHeaderValue(Map<String, String>? headers, String lowerName) {
  if (headers == null) return null;
  for (final entry in headers.entries) {
    if (entry.key.trim().toLowerCase() != lowerName) continue;
    final value = entry.value.trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

/// Stable fingerprint so two strategies that differ only by key casing /
/// insertion order collapse into one attempt.
String _headerFingerprint(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return '';
  final parts =
      headers.entries
          .map(
            (e) =>
                '${e.key.trim().toLowerCase()}=${e.value.trim().toLowerCase()}',
          )
          .toList(growable: false)
        ..sort();
  return parts.join('\n');
}
