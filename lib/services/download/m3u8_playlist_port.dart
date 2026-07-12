// Injectable m3u8 / HLS playlist-resolution seam (Phase 3 — HLS
// characterization, parallel in shape to `http_file_download_port.dart`).
//
// This file owns exactly two concerns, kept separate so each can be
// characterized independently:
//
// 1. A pure, no-IO playlist parser `parseM3u8Playlist` that, given the
//    playlist text and the playlist's own `Uri` (for `.resolve` of
//    relative lines), decides whether the text is a master playlist
//    (returns the resolved, BANDWIDTH-desc-sorted variant candidates) or
//    a media playlist (returns the resolved segment URIs in file order),
//    and rejects encrypted media playlists with `UnsupportedError`. This
//    is a faithful, byte-for-byte extraction of the parse logic that lived
//    inline in `DownloadManager._resolveHlsSegments`; the recursion, the
//    `depth > 4` throw, and the "highest-BANDWIDTH variant first"
//    selection stay in the manager (the parser is depth-naive and parses
//    exactly ONE playlist text per call).
//
// 2. An injectable fetch port `M3u8PlaylistPort` + prod `IoM3u8PlaylistPort`
//    that fetches playlist text for a `Uri` with optional headers/cookies.
//    The prod impl wraps a fresh `dart:io` `HttpClient` per call and
//    replicates the original inline `_fetchHttpText` wire behavior byte
//    for byte (GET → apply headers/cookies → `request.close()` → non-2xx
//    throws `Exception('HTTP <code>')` → body joined via `utf8.decoder`).
//
// Production behavior is unchanged: `factory DownloadManager()` still
// constructs the singleton with the `IoM3u8PlaylistPort` default, so every
// existing call site keeps working with zero arguments. The per-segment
// download loop in `_downloadM3u8File` keeps its own `HttpClient` and is
// intentionally NOT touched in this checkpoint.

import 'dart:convert';
import 'dart:io';

/// Result of parsing a single m3u8 playlist text via
/// [parseM3u8Playlist].
///
/// Sealed so the manager exhaustively switches on the two cases — master
/// (recurse into the highest-BANDWIDTH variant) vs media (return the
/// segment URIs) — without a nullable union field. Both subtypes are
/// effectively immutable: their list fields are wrapped in
/// `List.unmodifiable` at construction time.
sealed class M3u8Playlist {
  const M3u8Playlist();
}

/// Master playlist result: one or more variant stream candidates already
/// resolved against the playlist's own `Uri`, sorted by `bandwidth`
/// descending (highest first) exactly as the original
/// `_resolveHlsSegments` sorted them before recursing on the first entry.
final class M3u8MasterPlaylist extends M3u8Playlist {
  /// Variant stream candidates `(uri, bandwidth)`, highest bandwidth
  /// first. Resolved against the playlist `Uri`, so callers can `fetch`
  /// and recurse without re-resolving. Never empty: the parser only
  /// returns this subtype when at least one `#EXT-X-STREAM-INF` lines up
  /// with a following non-empty / non-`#` candidate line.
  final List<({Uri uri, int bandwidth})> variants;

  M3u8MasterPlaylist(List<({Uri uri, int bandwidth})> variants)
    : variants = List.unmodifiable(variants);
}

/// Media playlist result: the segment `Uri`s resolved against the
/// playlist's own `Uri`, in file order. Never empty: the parser throws
/// `Exception('未找到可下载的HLS分片')` when a media playlist yields zero
/// segments, mirroring the original inline behavior.
final class M3u8MediaPlaylist extends M3u8Playlist {
  final List<Uri> segments;

  M3u8MediaPlaylist(List<Uri> segments)
    : segments = List.unmodifiable(segments);
}

/// Pure, no-IO m3u8 playlist parser.
///
/// Given the raw playlist [content] and the [playlistUri] the text was
/// fetched from, decides whether this is a master playlist (returns
/// [M3u8MasterPlaylist] with resolved + BANDWIDTH-desc-sorted variants) or
/// a media playlist (returns [M3u8MediaPlaylist] with resolved segments in
/// file order). Replicates `DownloadManager._resolveHlsSegments`'s parse
/// logic byte for byte:
///
/// - Lines are split on `\n`/`\r\n` via [LineSplitter] and `.trim()`-ed, so
///   leading/trailing whitespace and blank lines are tolerated.
/// - For each `#EXT-X-STREAM-INF` line, `BANDWIDTH=(\d+)` is matched
///   case-insensitively; an unparseable (or missing) value degrades to
///   `0` via `int.tryParse(...) ?? 0`. The first non-empty / non-`#` line
///   after it is the variant URI (resolved against [playlistUri]); the
///   inner scan then `break`s, exactly as the original.
/// - If at least one variant candidate was collected, the list is sorted
///   by `bandwidth` descending and returned as a master playlist — the
///   encryption check is NOT applied to master playlists in this pass
///   (matches original: that check only runs when there are no variants).
/// - Otherwise (no variants), any `#EXT-X-KEY` line whose uppercased form
///   does NOT contain `METHOD=NONE` is treated as an encrypted stream and
///   throws `UnsupportedError('暂不支持下载加密HLS流')`.
/// - Then every non-empty / non-`#` line is collected as a segment
///   (resolved against [playlistUri]); an empty segment list throws
///   `Exception('未找到可下载的HLS分片')`.
///
/// The parser is depth-naive: it parses exactly one playlist text and
/// returns variants-or-segments. The caller (`_resolveHlsSegments`) owns
/// the recursion, the `depth > 4` throw, and the highest-BANDWIDTH
/// selection, so that behavior stays byte-for-byte unchanged.
M3u8Playlist parseM3u8Playlist(String content, Uri playlistUri) {
  final lines = const LineSplitter()
      .convert(content)
      .map((line) => line.trim())
      .toList(growable: false);

  final variantCandidates = <({Uri uri, int bandwidth})>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
    final bandwidthMatch = RegExp(
      r'BANDWIDTH=(\d+)',
      caseSensitive: false,
    ).firstMatch(line);
    final bandwidth = int.tryParse(bandwidthMatch?.group(1) ?? '') ?? 0;

    for (var j = i + 1; j < lines.length; j++) {
      final candidate = lines[j];
      if (candidate.isEmpty || candidate.startsWith('#')) {
        continue;
      }
      variantCandidates.add((
        uri: playlistUri.resolve(candidate),
        bandwidth: bandwidth,
      ));
      break;
    }
  }

  if (variantCandidates.isNotEmpty) {
    variantCandidates.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return M3u8MasterPlaylist(variantCandidates);
  }

  final hasEncryptedKey = lines.any((line) {
    if (!line.startsWith('#EXT-X-KEY')) return false;
    return !line.toUpperCase().contains('METHOD=NONE');
  });
  if (hasEncryptedKey) {
    throw UnsupportedError('暂不支持下载加密HLS流');
  }

  final segments = <Uri>[];
  for (final line in lines) {
    if (line.isEmpty || line.startsWith('#')) continue;
    segments.add(playlistUri.resolve(line));
  }

  if (segments.isEmpty) {
    throw Exception('未找到可下载的HLS分片');
  }
  return M3u8MediaPlaylist(segments);
}

/// Injectable seam for the m3u8 playlist-fetch half of
/// `DownloadManager._resolveHlsSegments`.
///
/// The production manager fetches each playlist's text through the
/// injected port, then delegates the text→decisions parse to the pure
/// [parseM3u8Playlist]. The recursion + `depth > 4` throw + highest-
/// BANDWIDTH selection stay in the manager. Tests inject a fake port that
/// maps `Uri` → canned playlist text so the resolution seam can be
/// characterized with no real `HttpClient` and no real network.
abstract interface class M3u8PlaylistPort {
  /// Fetches the playlist text at [url], applying [headers] and [cookies]
  /// verbatim.
  ///
  /// Throws `Exception('HTTP <statusCode>')` for non-2xx responses,
  /// matching the original inline `_fetchHttpText` behavior. The body is
  /// joined via `utf8.decoder`, exactly as before.
  Future<String> fetchText({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  });
}

/// Production [M3u8PlaylistPort] backed by `dart:io.HttpClient`.
///
/// Replicates the original inline `_fetchHttpText` wiring byte for byte —
/// `client.getUrl(uri)` → header/cookie application → `request.close()`
/// → non-2xx throw → `response.transform(utf8.decoder).join()` — except a
/// fresh `HttpClient` is created and closed per call so the port is a
/// stateless injectable (the original reused the caller's long-lived
/// client; the per-segment download loop in `_downloadM3u8File` still
/// owns its own client). This changes only the connection lifecycle, not
/// the observable playlist-resolution behavior.
class IoM3u8PlaylistPort implements M3u8PlaylistPort {
  @override
  Future<String> fetchText({
    required Uri url,
    Map<String, String>? headers,
    String? cookies,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      _applyHeaders(request, headers, cookies);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      return response.transform(utf8.decoder).join();
    } finally {
      try {
        client.close();
      } catch (_) {}
    }
  }

  static void _applyHeaders(
    HttpClientRequest request,
    Map<String, String>? headers,
    String? cookies,
  ) {
    if (headers != null) {
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }
    if (cookies != null && cookies.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookies);
    }
  }
}
