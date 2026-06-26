import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as rust;

/// In-memory cache + ECH-aware image loader for bangumi-domain URLs.
///
/// `dart:io HttpClient` (used by `Image.network` / `CachedNetworkImage`) does
/// not support ECH, so when ECH is enabled we route bangumi image downloads
/// through the Rust client (`fetchBangumiSubjectImage` + the regular
/// reqwest pool used for other Rust calls). URLs that don't hit bangumi
/// domains are loaded the old way by `CachedNetworkImage`.
class BangumiImageBridge {
  BangumiImageBridge._();

  static final Map<String, Future<Uint8List?>> _inFlight = {};
  static final Map<String, Uint8List> _cache = {};
  static const int _maxEntries = 256;

  static String _cacheKeyFromParts(int subjectId, String imageType) =>
      'subject:$subjectId:$imageType';

  static String _cacheKeyFromUrl(String url) => 'url:${url.trim()}';

  static Future<Uint8List?> fetchCover(int subjectId, String imageType) async {
    if (subjectId <= 0) return null;
    final key = _cacheKeyFromParts(subjectId, imageType);
    final cached = _cache[key];
    if (cached != null) return cached;
    final inflight = _inFlight[key];
    if (inflight != null) return inflight;

    final future = () async {
      try {
        final bytes = await rust.fetchBangumiSubjectImage(
          subjectId: subjectId,
          imageType: imageType,
        );
        if (bytes.isNotEmpty) {
          if (_cache.length >= _maxEntries) {
            _cache.remove(_cache.keys.first);
          }
          _cache[key] = bytes;
        }
        return bytes.isEmpty ? null : bytes;
      } catch (e) {
        debugPrint('BangumiImageBridge fetch failed for $subjectId: $e');
        return null;
      }
    }();
    _inFlight[key] = future;
    final result = await future;
    _inFlight.remove(key);
    return result;
  }

  static Future<Uint8List?> fetchUrl(String url) async {
    if (!isBangumiUrl(url)) return null;
    final normalized = url.trim();
    if (normalized.isEmpty) return null;
    final key = _cacheKeyFromUrl(normalized);
    final cached = _cache[key];
    if (cached != null) return cached;
    final inflight = _inFlight[key];
    if (inflight != null) return inflight;

    final future = () async {
      try {
        final bytes = await rust.fetchBangumiImageUrl(url: normalized);
        if (bytes.isNotEmpty) {
          if (_cache.length >= _maxEntries) {
            _cache.remove(_cache.keys.first);
          }
          _cache[key] = bytes;
        }
        return bytes.isEmpty ? null : bytes;
      } catch (e) {
        debugPrint('BangumiImageBridge fetch failed for $normalized: $e');
        return null;
      }
    }();
    _inFlight[key] = future;
    final result = await future;
    _inFlight.remove(key);
    return result;
  }

  /// Identifies URLs that should be routed through the Rust ECH channel
  /// rather than the system `HttpClient`. Conservative: only the public
  /// bangumi API / mirror hosts are intercepted.
  static bool isBangumiUrl(String url) {
    if (url.isEmpty) return false;
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;
    return host == 'bgm.tv' ||
        host.endsWith('.bgm.tv') ||
        host == 'bangumi.tv' ||
        host.endsWith('.bangumi.tv') ||
        host == 'chii.in' ||
        host.endsWith('.chii.in') ||
        host == 'bangumi.lol' ||
        host.endsWith('.bangumi.lol');
  }

  /// Subject id extracted from a `/v0/subjects/{id}/image` URL, if any.
  /// Returns 0 if the URL doesn't match that shape.
  static int subjectIdFromImageUrl(String url) {
    final match = RegExp(r'/v0/subjects/(\d+)/image').firstMatch(url);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  /// Combined helper: returns bytes if the URL is a bangumi image endpoint we
  /// can route through ECH, otherwise null and the caller should fall back to
  /// `Image.network` / `CachedNetworkImage`.
  static Future<Uint8List?> fetchFromUrl(String url) async {
    if (!isBangumiUrl(url)) return null;
    final subjectId = subjectIdFromImageUrl(url);
    if (subjectId == 0) return fetchUrl(url);
    final typeMatch = RegExp(r'[?&]type=([^&]+)').firstMatch(url);
    final type = typeMatch?.group(1) ?? 'common';
    return fetchCover(subjectId, type);
  }

  static void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
