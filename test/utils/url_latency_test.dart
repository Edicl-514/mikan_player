// DT-1: pure-Dart composition tests for `utils/url_latency.dart`.
//
// The real `tcpPing` opens a TCP/TLS connection. We avoid any real
// network I/O in this test file by using `LocalHttpServer` from the
// F-0 test support (which binds 127.0.0.1) for the happy path and
// by exercising `selectFastestUrl`'s sentinel-based error fallback
// with URLs that point at reserved ports that immediately refuse
// connections.
//
// Coverage:
//   * `selectFastestUrl(null) => null` (empty input short-circuit).
//   * `selectFastestUrl` on a single URL returns that URL.
//   * Two locally-served URLs: the function returns *some* URL in
//     the input list (we don't assert which — the goal is just
//     that it completes without throwing and yields a value from
//     the candidate set).
//   * `tcpPing` returns the failure sentinel (999999) for an
//     unresolvable host.
//   * `tcpPing` returns the failure sentinel for an invalid URL
//     string that fails Uri.parse.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/utils/url_latency.dart';

import '../support/local_http_server.dart';

void main() {
  group('selectFastestUrl()', () {
    test('returns null for an empty list (no I/O)', () async {
      expect(await selectFastestUrl(<String>[]), isNull);
    });

    test('returns the only URL in a single-element list', () async {
      // We use an unrouted IP so the ping fails fast and falls
      // through to the sentinel. The function must still report
      // *that* URL as the "fastest" because it is the only
      // candidate.
      const candidate = 'http://127.0.0.1:1/';
      final result = await selectFastestUrl(<String>[candidate]);
      expect(result, candidate);
    });

    test('picks one of the input URLs from a locally-served pair', () async {
      // Spin up two local servers; even on a hot loop, both
      // connect latencies are near-instant. We assert only that the
      // returned value belongs to the candidate set and is non-null.
      final a = await LocalHttpServer.start();
      final b = await LocalHttpServer.start();
      addTearDown(a.close);
      addTearDown(b.close);

      final candidates = <String>[a.baseUri.toString(), b.baseUri.toString()];
      final result = await selectFastestUrl(candidates);

      expect(result, isNotNull);
      expect(candidates, contains(result));
    });

    test('falls back to the first URL when every ping fails', () async {
      // Both malformed URLs return the 999999 sentinel, and the min-tracking
      // loop must still yield the first candidate — the implementation initializes
      // `bestUrl` to `urls.first` and the `<` check means it only
      // swaps on a strictly smaller value, so the first URL
      // survives a uniform failure.
      const candidates = <String>['not-a-real-url', 'also-not-a-real-url'];
      final result = await selectFastestUrl(candidates);
      expect(result, candidates.first);
    });
  });

  group('tcpPing()', () {
    test('returns the failure sentinel for an unresolvable host', () async {
      // Port 1 on loopback is reserved / unbindable. The function
      // catches the underlying SocketException and returns 999999.
      // Note: 999999 is the documented sentinel; a test of this
      // shape protects against accidental re-mapping.
      expect(await tcpPing('http://127.0.0.1:1/'), 999999);
    });

    test('returns the failure sentinel for a malformed URL', () async {
      // A URL that does not parse cleanly must also be caught by
      // the blanket `catch (_)` and return 999999.
      expect(await tcpPing('not-a-real-url'), 999999);
    });

    test('returns a non-negative integer for a locally-served URL', () async {
      final server = await LocalHttpServer.start();
      addTearDown(server.close);
      final latency = await tcpPing(server.baseUri.toString());
      expect(latency, isA<int>());
      expect(latency, greaterThanOrEqualTo(0));
    });
  });
}
