import 'dart:convert';

/// Structured failure detail for an authenticated Bangumi operation.
///
/// Rust serializes this as `bangumi_api_error:{json}` in the error text (see
/// `rust/src/api/bangumi/user.rs`). Parsing that one well-known envelope is the
/// contract; callers must never scrape upstream prose to classify a failure.
class BangumiApiError implements Exception {
  const BangumiApiError({
    required this.operation,
    required this.status,
    this.upstreamCode,
    this.retryAfterSeconds,
    this.message = '',
  });

  final String operation;
  final int status;
  final String? upstreamCode;
  final int? retryAfterSeconds;
  final String message;

  static const String _prefix = 'bangumi_api_error:';

  /// Extracts the structured error from an arbitrary thrown object, or returns
  /// `null` when it is not one of ours (network failure, cancellation, …).
  static BangumiApiError? tryParse(Object? error) {
    if (error is BangumiApiError) return error;
    if (error == null) return null;
    final text = error.toString();
    final start = text.indexOf(_prefix);
    if (start < 0) return null;
    final payload = text.substring(start + _prefix.length).trim();
    // The message is embedded in a larger anyhow chain, so take the outermost
    // balanced JSON object rather than assuming it runs to end-of-string.
    final json = _firstJsonObject(payload);
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      final status = decoded['status'];
      return BangumiApiError(
        operation: decoded['operation']?.toString() ?? '',
        status: status is num ? status.toInt() : 0,
        upstreamCode: decoded['upstream_code']?.toString(),
        retryAfterSeconds: switch (decoded['retry_after_seconds']) {
          final num value => value.toInt(),
          _ => null,
        },
        message: decoded['message']?.toString() ?? '',
      );
    } on FormatException {
      return null;
    }
  }

  static String? _firstJsonObject(String source) {
    if (!source.startsWith('{')) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return source.substring(0, i + 1);
      }
    }
    return null;
  }

  /// The access token was rejected. Worth one refresh-and-retry.
  bool get isUnauthorized => status == 401;

  /// The collection does not exist on Bangumi. For a metadata PATCH this is a
  /// useful concurrency guard, not something to paper over by re-creating it.
  bool get isNotFound => status == 404;

  bool get isRateLimited => status == 429;

  /// Server-side faults are worth retrying; 4xx (other than the cases above)
  /// will fail again with the same payload.
  bool get isRetryable => isRateLimited || status >= 500;

  @override
  String toString() =>
      'BangumiApiError($operation, status: $status'
      '${upstreamCode == null ? '' : ', code: $upstreamCode'})';
}
