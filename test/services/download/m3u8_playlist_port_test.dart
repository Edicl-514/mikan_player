// Tests for the `M3u8PlaylistPort` seam + the pure `parseM3u8Playlist`
// parser (Phase 3 — m3u8 / HLS playlist-resolution characterization,
// parallel in shape to `http_file_download_port_test.dart`).
//
// The pure parser is exercised with no IO, no Flutter widgets, no platform
// channels, no `HttpClient` — it takes raw playlist text + the playlist's
// own `Uri` and returns `M3u8MasterPlaylist` (variants, sorted by
// `bandwidth` descending) or `M3u8MediaPlaylist` (segments in file order),
// rejecting encrypted media playlists with `UnsupportedError` and empty
// media playlists with `Exception('未找到可下载的HLS分片')`.
//
// The port contract is exercised via a `FakeM3u8PlaylistPort` (defined
// below, also reused by `download_manager_m3u8_test.dart`) that maps
// `Uri` → canned text and records call order / headers / cookies.
//
// The production `IoM3u8PlaylistPort` is intentionally NOT exercised here
// because doing so would require a real network socket; its byte-for-byte
// wire behavior (GET → apply headers/cookies → non-2xx throw →
// `utf8.decoder`).join()) is preserved by reading the prod impl against
// the original inline `_fetchHttpText` and by the manager-side
// characterization tests asserting on the resolved segments via the fake
// port.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/m3u8_playlist_port.dart';

/// Fake [M3u8PlaylistPort] used by both this file and the manager-side
/// characterization tests (`download_manager_m3u8_test.dart`).
///
/// Maps `Uri.toString()` → canned playlist text and records each
/// `fetchText` call's `(url, headers, cookies)` so tests can assert on
/// call order and header/cookie forwarding. A fetch for a URI not present
/// in [texts] throws loudly so an unexpected fetch fails the test rather
/// than silently returning null.
class FakeM3u8PlaylistPort implements M3u8PlaylistPort {
  FakeM3u8PlaylistPort({Map<String, String>? texts}) : _texts = texts ?? {};

  final Map<String, String> _texts;

  /// Insert a canned playlist text keyed by `Uri.toString()`.
  void register(Uri uri, String text) {
    _texts[uri.toString()] = text;
  }

  /// Recorded `(url, headers, cookies)` for each `fetchText` call, in call
  /// order.
  final List<({Uri url, Map<String, String>? headers, String? cookies})> calls =
      [];

  /// Number of `fetchText` calls so far.
  int get callCount => calls.length;

  /// The most recent call's url (or throws if none).
  Uri get lastUrl => calls.last.url;
  Map<String, String>? get lastHeaders => calls.last.headers;
  String? get lastCookies => calls.last.cookies;

  @override
  Future<String> fetchText({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async {
    calls.add((url: url, headers: headers, cookies: cookies));
    final text = _texts[url.toString()];
    if (text == null) {
      throw Exception('FakeM3u8PlaylistPort: no canned text for $url');
    }
    return text;
  }
}

void main() {
  group('parseM3u8Playlist — master playlist', () {
    test('extracts variants, resolves relative URIs, sorts BANDWIDTH desc', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720
720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080
1080p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360
360p.m3u8
''';
      final playlistUri = Uri.parse('https://hls.example.com/master.m3u8');
      final result = parseM3u8Playlist(content, playlistUri);

      expect(result, isA<M3u8MasterPlaylist>());
      final master = result as M3u8MasterPlaylist;
      expect(master.variants.length, 3);
      // Sorted by bandwidth descending.
      expect(master.variants.map((v) => v.bandwidth).toList(), [
        3_000_000,
        1_000_000,
        500_000,
      ]);
      // Relative URIs resolved against the playlist's own URI.
      expect(
        master.variants[0].uri,
        Uri.parse('https://hls.example.com/1080p.m3u8'),
      );
      expect(
        master.variants[1].uri,
        Uri.parse('https://hls.example.com/720p.m3u8'),
      );
      expect(
        master.variants[2].uri,
        Uri.parse('https://hls.example.com/360p.m3u8'),
      );
    });

    test('resolves an absolute http:// variant URI verbatim', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000
http://other.example.com/stream.m3u8
''';
      final playlistUri = Uri.parse('https://hls.example.com/master.m3u8');
      final result =
          parseM3u8Playlist(content, playlistUri) as M3u8MasterPlaylist;
      expect(result.variants.length, 1);
      expect(
        result.variants.single.uri,
        Uri.parse('http://other.example.com/stream.m3u8'),
      );
      expect(result.variants.single.bandwidth, 2_000_000);
    });

    test('resolves a relative URI against a trailing-slash directory URI', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000
720p.m3u8
''';
      final playlistUri = Uri.parse('https://hls.example.com/dir/');
      final result =
          parseM3u8Playlist(content, playlistUri) as M3u8MasterPlaylist;
      expect(
        result.variants.single.uri,
        Uri.parse('https://hls.example.com/dir/720p.m3u8'),
      );
    });

    test(
      'keeps the bandwidth-desc sort invariant across equal-bandwidth ties',
      () {
        // Note: Dart's `List.sort` is not guaranteed stable, so the relative
        // order of equal-bandwidth variants is not contractually pinned.
        // This test asserts the deterministic invariant (bandwidth
        // sequence is sorted desc) plus the full set of resolved URIs,
        // which is what the original inline sort also guaranteed.
        const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
a.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000
b.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000
c.m3u8
''';
        final playlistUri = Uri.parse('https://hls.example.com/master.m3u8');
        final result =
            parseM3u8Playlist(content, playlistUri) as M3u8MasterPlaylist;
        expect(result.variants.length, 3);
        expect(result.variants.map((v) => v.bandwidth).toList(), [
          2000,
          2000,
          1000,
        ]);
        expect(result.variants.map((v) => v.uri.toString()).toSet(), {
          'https://hls.example.com/a.m3u8',
          'https://hls.example.com/b.m3u8',
          'https://hls.example.com/c.m3u8',
        });
      },
    );

    test('returns variants, NOT segments, for a master playlist', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000
720p.m3u8
''';
      final result = parseM3u8Playlist(
        content,
        Uri.parse('https://hls.example.com/m.m3u8'),
      );
      expect(result, isA<M3u8MasterPlaylist>());
      expect(result is M3u8MediaPlaylist, isFalse);
    });

    test('does NOT run the encryption check on a master playlist', () {
      // Byte-for-byte nuance: the original inline `_resolveHlsSegments`
      // only checks `#EXT-X-KEY` AFTER the `if (variantCandidates
      // isNotEmpty)` branch returns. A master playlist carrying an
      // encrypted-key line therefore returns its variants instead of
      // throwing — the encryption check only runs on media playlists
      // (no variants).
      const content = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="https://hls.example.com/key.bin"
#EXT-X-STREAM-INF:BANDWIDTH=1000000
720p.m3u8
''';
      final result = parseM3u8Playlist(
        content,
        Uri.parse('https://hls.example.com/master.m3u8'),
      );
      expect(result, isA<M3u8MasterPlaylist>());
      expect(
        (result as M3u8MasterPlaylist).variants.single.bandwidth,
        1_000_000,
      );
    });

    test('falls back to bandwidth 0 when BANDWIDTH= is missing entirely', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:RESOLUTION=1280x720
720p.m3u8
''';
      final result =
          parseM3u8Playlist(
                content,
                Uri.parse('https://hls.example.com/master.m3u8'),
              )
              as M3u8MasterPlaylist;
      expect(result.variants.length, 1);
      expect(result.variants.single.bandwidth, 0);
      expect(
        result.variants.single.uri,
        Uri.parse('https://hls.example.com/720p.m3u8'),
      );
    });

    test(
      'does not treat AVERAGE-BANDWIDTH as BANDWIDTH (attribute boundary)',
      () {
        // `BANDWIDTH=(\d+)` used to match the suffix of AVERAGE-BANDWIDTH.
        // The fixed parser requires a whole attribute token.
        const content = '''
#EXTM3U
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=3000000,RESOLUTION=1920x1080
1080p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000,AVERAGE-BANDWIDTH=900000
720p.m3u8
''';
        final result =
            parseM3u8Playlist(
                  content,
                  Uri.parse('https://hls.example.com/master.m3u8'),
                )
                as M3u8MasterPlaylist;
        expect(result.variants.length, 2);
        expect(result.variants.map((v) => v.bandwidth).toList(), [
          1_000_000,
          0,
        ]);
        expect(
          result.variants[0].uri,
          Uri.parse('https://hls.example.com/720p.m3u8'),
        );
      },
    );

    test(
      'rejects #EXT-X-STREAM-INF prefix collisions without colon delimiter',
      () {
        // `#EXT-X-STREAM-INF-EXTRA` must not be treated as STREAM-INF.
        const content = '''
#EXTM3U
#EXT-X-STREAM-INF-EXTRA:BANDWIDTH=999
not-a-variant
#EXTINF:10.0,
seg1.ts
''';
        final result =
            parseM3u8Playlist(
                  content,
                  Uri.parse('https://hls.example.com/media.m3u8'),
                )
                as M3u8MediaPlaylist;
        expect(result.segments, [
          Uri.parse('https://hls.example.com/not-a-variant'),
          Uri.parse('https://hls.example.com/seg1.ts'),
        ]);
      },
    );

    test('falls back to bandwidth 0 when BANDWIDTH= value is non-numeric', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=abc
720p.m3u8
''';
      final result =
          parseM3u8Playlist(
                content,
                Uri.parse('https://hls.example.com/master.m3u8'),
              )
              as M3u8MasterPlaylist;
      expect(result.variants.single.bandwidth, 0);
    });

    test(
      'scans past empty / # lines after #EXT-X-STREAM-INF to the candidate',
      () {
        // The inner scan `continue`s on empty and `#`-prefixed lines until it
        // finds the first real candidate, then `break`s — exactly as the
        // original inline loop did.
        const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000

#EXT-X-VERSION:3
720p.m3u8
''';
        final result =
            parseM3u8Playlist(
                  content,
                  Uri.parse('https://hls.example.com/master.m3u8'),
                )
                as M3u8MasterPlaylist;
        expect(result.variants.length, 1);
        expect(result.variants.single.bandwidth, 1000);
        expect(
          result.variants.single.uri,
          Uri.parse('https://hls.example.com/720p.m3u8'),
        );
      },
    );

    test('#EXT-X-STREAM-INF with no following candidate is NOT added; the '
        'playlist falls through to the media path', () {
      // A master tag at the end with only `#`-lines after it yields no
      // candidate, so variantCandidates stays empty and the parser falls
      // through to the encryption + segment-extraction path. With no
      // segments either, it throws `未找到可下载的HLS分片`.
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
#EXT-X-ENDLIST
''';
      expect(
        () => parseM3u8Playlist(
          content,
          Uri.parse('https://hls.example.com/master.m3u8'),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains('未找到可下载的HLS分片'),
          ),
        ),
      );
    });
  });

  group('parseM3u8Playlist — media playlist', () {
    test('extracts segments in file order, resolves relative URIs', () {
      const content = '''
#EXTM3U
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
#EXTINF:10.0,
seg3.ts
#EXT-X-ENDLIST
''';
      final result = parseM3u8Playlist(
        content,
        Uri.parse('https://hls.example.com/media.m3u8'),
      );
      expect(result, isA<M3u8MediaPlaylist>());
      final media = result as M3u8MediaPlaylist;
      expect(media.segments, [
        Uri.parse('https://hls.example.com/seg1.ts'),
        Uri.parse('https://hls.example.com/seg2.ts'),
        Uri.parse('https://hls.example.com/seg3.ts'),
      ]);
    });

    test('resolves segment URIs against a trailing-slash directory URI', () {
      const content = '''
#EXTM3U
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
''';
      final result =
          parseM3u8Playlist(content, Uri.parse('https://hls.example.com/dir/'))
              as M3u8MediaPlaylist;
      expect(result.segments, [
        Uri.parse('https://hls.example.com/dir/seg1.ts'),
        Uri.parse('https://hls.example.com/dir/seg2.ts'),
      ]);
    });

    test(
      'tolerates leading/trailing whitespace and blank / # comment lines',
      () {
        // Mirrors the original `.trim()` on every line: a segment line with
        // surrounding whitespace resolves to the trimmed URI; blank lines
        // and `#`-only comment lines are skipped.
        const content = '''
  #EXTM3U  

#EXTINF:5.0,
   seg1.ts   
# a bare comment line, not a tag (still skipped as `#`)
#EXTINF:5.0,
seg2.ts
#EXT-X-ENDLIST
''';
        final result =
            parseM3u8Playlist(
                  content,
                  Uri.parse('https://hls.example.com/media.m3u8'),
                )
                as M3u8MediaPlaylist;
        expect(result.segments, [
          Uri.parse('https://hls.example.com/seg1.ts'),
          Uri.parse('https://hls.example.com/seg2.ts'),
        ]);
      },
    );

    test('only # comment lines and no segments throws 未找到可下载的HLS分片', () {
      const content = '''
#EXTM3U
#EXT-X-TARGETDURATION:10
#EXT-X-ENDLIST
''';
      expect(
        () => parseM3u8Playlist(
          content,
          Uri.parse('https://hls.example.com/media.m3u8'),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains('未找到可下载的HLS分片'),
          ),
        ),
      );
    });
  });

  group('parseM3u8Playlist — encryption', () {
    test('#EXT-X-KEY:METHOD=AES-128 throws 暂不支持下载加密HLS流', () {
      const content = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="https://hls.example.com/key.bin",IV=0x1234
#EXTINF:10.0,
seg1.ts
''';
      expect(
        () => parseM3u8Playlist(
          content,
          Uri.parse('https://hls.example.com/media.m3u8'),
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.toString(),
            'toString',
            contains('暂不支持下载加密HLS流'),
          ),
        ),
      );
    });

    test('#EXT-X-KEY:METHOD=EXAMPLE throws 暂不支持下载加密HLS流', () {
      const content = '''
#EXTM3U
#EXT-X-KEY:METHOD=EXAMPLE
#EXTINF:10.0,
seg1.ts
''';
      expect(
        () => parseM3u8Playlist(
          content,
          Uri.parse('https://hls.example.com/media.m3u8'),
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.toString(),
            'toString',
            contains('暂不支持下载加密HLS流'),
          ),
        ),
      );
    });

    test('#EXT-X-KEY:METHOD=NONE is NOT treated as encrypted', () {
      // `METHOD=NONE` (the clear-key sentinel) must not trip the
      // encrypted-key gate; segments are returned as usual.
      const content = '''
#EXTM3U
#EXT-X-KEY:METHOD=NONE
#EXTINF:10.0,
seg1.ts
#EXTINF:10.0,
seg2.ts
''';
      final result =
          parseM3u8Playlist(
                content,
                Uri.parse('https://hls.example.com/media.m3u8'),
              )
              as M3u8MediaPlaylist;
      expect(result.segments, [
        Uri.parse('https://hls.example.com/seg1.ts'),
        Uri.parse('https://hls.example.com/seg2.ts'),
      ]);
    });

    test(
      'METHOD=NONE as substring of another method still counts as encrypted',
      () {
        // Old check used `contains('METHOD=NONE')` and would false-negative
        // on values like `METHOD=NONE-BUT-ENCRYPTED`. Attribute parse only
        // accepts the exact METHOD token value `NONE`.
        const content = '''
#EXTM3U
#EXT-X-KEY:METHOD=NONE-BUT-ENCRYPTED,URI="https://hls.example.com/key.bin"
#EXTINF:10.0,
seg1.ts
''';
        expect(
          () => parseM3u8Playlist(
            content,
            Uri.parse('https://hls.example.com/media.m3u8'),
          ),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.toString(),
              'toString',
              contains('暂不支持下载加密HLS流'),
            ),
          ),
        );
      },
    );

    test('#EXT-X-KEY without METHOD attribute is treated as encrypted', () {
      const content = '''
#EXTM3U
#EXT-X-KEY:URI="https://hls.example.com/key.bin"
#EXTINF:10.0,
seg1.ts
''';
      expect(
        () => parseM3u8Playlist(
          content,
          Uri.parse('https://hls.example.com/media.m3u8'),
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.toString(),
            'toString',
            contains('暂不支持下载加密HLS流'),
          ),
        ),
      );
    });

    test('rejects #EXT-X-KEY prefix collisions without colon delimiter', () {
      const content = '''
#EXTM3U
#EXT-X-KEY-EXTRA:METHOD=AES-128
#EXTINF:10.0,
seg1.ts
''';
      final result =
          parseM3u8Playlist(
                content,
                Uri.parse('https://hls.example.com/media.m3u8'),
              )
              as M3u8MediaPlaylist;
      expect(result.segments, [Uri.parse('https://hls.example.com/seg1.ts')]);
    });
  });

  group('FakeM3u8PlaylistPort', () {
    test(
      'fetchText captures url, headers, and cookies verbatim in order',
      () async {
        final port = FakeM3u8PlaylistPort();
        port.register(Uri.parse('https://hls.example.com/a.m3u8'), '#EXTM3U\n');
        port.register(Uri.parse('https://hls.example.com/b.m3u8'), '#EXTM3U\n');

        expect(port.callCount, 0);
        expect(port.calls, isEmpty);

        await port.fetchText(
          url: Uri.parse('https://hls.example.com/a.m3u8'),
          headers: {'Range': 'bytes=0-', 'User-Agent': 'mikan-test/1'},
          cookies: 'session=abcde',
        );
        await port.fetchText(
          url: Uri.parse('https://hls.example.com/b.m3u8'),
          headers: null,
          cookies: null,
        );

        expect(port.callCount, 2);
        expect(port.calls[0].url, Uri.parse('https://hls.example.com/a.m3u8'));
        expect(port.calls[0].headers, {
          'Range': 'bytes=0-',
          'User-Agent': 'mikan-test/1',
        });
        expect(port.calls[0].cookies, 'session=abcde');
        expect(port.calls[1].url, Uri.parse('https://hls.example.com/b.m3u8'));
        expect(port.calls[1].headers, isNull);
        expect(port.calls[1].cookies, isNull);

        expect(port.lastUrl, Uri.parse('https://hls.example.com/b.m3u8'));
      },
    );

    test('fetchText returns the registered text for a known URI', () async {
      final port = FakeM3u8PlaylistPort();
      const text = '#EXTM3U\n#EXTINF:1,\nseg.ts\n';
      port.register(Uri.parse('https://hls.example.com/media.m3u8'), text);
      final got = await port.fetchText(
        url: Uri.parse('https://hls.example.com/media.m3u8'),
      );
      expect(got, text);
    });

    test('fetchText throws loudly for an unregistered URI', () {
      final port = FakeM3u8PlaylistPort();
      expect(
        () => port.fetchText(url: Uri.parse('https://hls.example.com/x.m3u8')),
        throwsA(isA<Exception>()),
      );
      expect(port.callCount, 1);
    });

    test('M3u8PlaylistPort interface exposes a single fetchText method with '
        'url (required) + headers/cookies (optional)', () {
      // Static contract check: the port is an `abstract interface class`
      // whose only method is `fetchText`. A trivial anonymous impl with
      // the exact signature compiles, proving the contract shape.
      final M3u8PlaylistPort port = _ContractPort();
      expect(port, isA<M3u8PlaylistPort>());
    });
  });
}

/// Anonymous impl proving the port contract shape (see the contract test).
class _ContractPort implements M3u8PlaylistPort {
  @override
  Future<String> fetchText({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async => '';
}
