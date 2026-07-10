// Magnet URI helpers — tracker injection and info-hash extraction.
//
// Pure Dart, no Flutter dependencies, no I/O. Safe to unit-test.

/// High-quality public trackers to inject into magnet links.
///
/// Kept intentionally short: every extra tracker has to be announced to on
/// startup, which delays the first peer connection when many are slow or dead.
/// Users get the rest through DHT + PEX + the magnet's own trackers.
const List<String> kInjectedMagnetTrackers = [
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.demonii.com:1337/announce',
  'udp://exodus.desync.com:6969/announce',
  'udp://tracker.openbittorrent.com:6969/announce',
  'udp://opentracker.i2p.rocks:6969/announce',
  // Anime-friendly (kept minimal; many bangumi-specific trackers are unreliable)
  'udp://tracker.doko.moe:6969/announce',
];

/// Inject [kInjectedMagnetTrackers] into a magnet URI, skipping duplicates
/// (matched by the `&tr=<url>` substring that was already appended).
String injectMagnetTrackers(String magnet) {
  var result = magnet;
  for (final tracker in kInjectedMagnetTrackers) {
    final trParam = '&tr=$tracker';
    if (!result.contains(trParam)) {
      result = '$result$trParam';
    }
  }
  return result;
}

/// Extract info hash from magnet link.
///
/// Recognizes the modern BitTorrent v2 multihash (`btmh:1220<sha256>`),
/// SHA-1 hex (`btih:<64 hex>`), base32 (`btih:<32 base32 chars>`),
/// and the legacy 40-char hex form when not followed by another hex char.
String? extractInfoHashFromMagnet(String magnet) {
  final btmh = RegExp(r'btmh:1220([a-fA-F0-9]{64})');
  final hex64 = RegExp(r'btih:([a-fA-F0-9]{64})');
  final base32 = RegExp(r'btih:([A-Za-z2-7]{32})');
  final hex40 = RegExp(r'btih:([a-fA-F0-9]{40})(?![a-fA-F0-9])');

  for (final regex in [btmh, hex64, base32, hex40]) {
    final match = regex.firstMatch(magnet);
    if (match != null) {
      return match.group(1)!.toLowerCase();
    }
  }
  return null;
}

/// Extract info hash from a torrent stream URL of the form
/// `.../torrents/<hash>/...`.
///
/// Returns the hash in lowercase or `null` if no match.
String? extractInfoHashFromStreamUrl(String url) {
  final regex = RegExp(r'/torrents/([a-fA-F0-9]+)/');
  final match = regex.firstMatch(url);
  return match?.group(1)?.toLowerCase();
}
