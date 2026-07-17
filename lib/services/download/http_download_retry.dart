// Transient failure detection + backoff for HTTP / HLS download retries.
//
// Used by [DownloadManager] for automatic in-process retries after network
// blips. Permanent failures (4xx after header strategies, missing local path,
// unsupported encryption, …) must not be retried here.

/// Maximum automatic retries after a transient HTTP/HLS failure within one
/// download run. Manual retry via [DownloadManager.resumeTask] is unlimited.
const int kHttpDownloadMaxAutoRetries = 3;

/// Backoff delays between automatic retries (index = attempt that just failed).
const List<Duration> kHttpDownloadAutoRetryDelays = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10),
];

/// True when [error] looks like a temporary network / transport failure that
/// may succeed on a later attempt without changing the URL or headers.
///
/// Permanent application outcomes (HTTP 4xx after strategy fallback, missing
/// video URL, unsupported HLS encryption, parse errors) return false.
bool isTransientHttpDownloadError(Object error) {
  final text = error.toString().toLowerCase();

  // Explicit non-2xx from our ports: only retry 408 / 425 / 429 / 5xx.
  final statusMatch = RegExp(
    r'http\s+(\d{3})',
    caseSensitive: false,
  ).firstMatch(text);
  if (statusMatch != null) {
    final code = int.tryParse(statusMatch.group(1)!);
    if (code == null) return false;
    if (code == 408 || code == 425 || code == 429) return true;
    if (code >= 500 && code <= 599) return true;
    return false;
  }

  // dart:io / common transport wording.
  const markers = <String>[
    'socketexception',
    'handshakeexception',
    'tlsexception',
    'clientexception',
    'connection closed',
    'connection reset',
    'connection refused',
    'connection abort',
    'broken pipe',
    'network is unreachable',
    'software caused connection abort',
    'timed out',
    'timeout',
    'failed host lookup',
    'no address associated',
    'connection terminated',
    'http connection closed',
    'stream closed',
    'connection reset by peer',
  ];
  for (final marker in markers) {
    if (text.contains(marker)) return true;
  }
  return false;
}

/// Delay to wait after auto-retry attempt [failedAttempt] (0-based).
Duration httpDownloadAutoRetryDelay(int failedAttempt) {
  if (failedAttempt < 0) return kHttpDownloadAutoRetryDelays.first;
  if (failedAttempt >= kHttpDownloadAutoRetryDelays.length) {
    return kHttpDownloadAutoRetryDelays.last;
  }
  return kHttpDownloadAutoRetryDelays[failedAttempt];
}
