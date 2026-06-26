import 'dart:io';

/// Returns the TCP/TLS connect latency in milliseconds for [url].
/// Returns a large sentinel value (999999) on failure so callers can pick
/// the minimum without special-casing errors.
Future<int> tcpPing(String url) async {
  try {
    final uri = Uri.parse(url);
    final port = uri.port != 0
        ? uri.port
        : (uri.scheme == 'https' ? 443 : 80);
    final stopwatch = Stopwatch()..start();
    if (uri.scheme == 'https') {
      final socket = await SecureSocket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 3),
        onBadCertificate: (_) => true,
      );
      stopwatch.stop();
      await socket.close();
    } else {
      final socket = await Socket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 2),
      );
      stopwatch.stop();
      await socket.close();
    }
    return stopwatch.elapsedMilliseconds;
  } catch (_) {
    return 999999;
  }
}

/// Pings each URL in [urls] and returns the one with the lowest latency.
/// Returns `null` when [urls] is empty.
Future<String?> selectFastestUrl(List<String> urls) async {
  if (urls.isEmpty) return null;

  var bestUrl = urls.first;
  var minLatency = 999999;
  for (final url in urls) {
    final latency = await tcpPing(url);
    if (latency < minLatency) {
      minLatency = latency;
      bestUrl = url;
    }
  }
  return bestUrl;
}
