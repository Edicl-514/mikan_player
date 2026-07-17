/// Returns a stable 32-bit FNV-1a hash for download identifiers.
String stableDownloadHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Produces a filesystem-safe, bounded filename stem.
String sanitizeDownloadFileName(String name) {
  final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  final nonEmpty = sanitized.isEmpty ? 'download' : sanitized;
  return nonEmpty.length <= 80 ? nonEmpty : nonEmpty.substring(0, 80);
}

/// Guesses the local video extension from a source URL.
String guessVideoExtension(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.mp4')) return '.mp4';
  if (lower.contains('.mkv')) return '.mkv';
  if (lower.contains('.m3u8')) return '.ts';
  if (lower.contains('.ts')) return '.ts';
  if (lower.contains('.flv')) return '.flv';
  if (lower.contains('.avi')) return '.avi';
  if (lower.contains('.mov')) return '.mov';
  if (lower.contains('.wmv')) return '.wmv';
  return '.mp4';
}

/// Whether the URL path identifies an HLS playlist.
bool isM3u8Url(String url) {
  final uri = Uri.tryParse(url);
  final normalizedPath = uri?.path.toLowerCase() ?? url.toLowerCase();
  return normalizedPath.contains('.m3u8');
}
