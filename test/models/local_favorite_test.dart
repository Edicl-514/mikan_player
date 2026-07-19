// DT-1: pure-Dart composition tests for `models/local_favorite.dart`.
//
// Covers the `create` factory happy-path (which the existing
// `test/widget_test.dart` only exercises for the default `type: 1`),
// the explicit `type` override, and the timestamp contract
// (positive, monotonically non-decreasing, and UTC-stable enough
// to compare across millisecond boundaries).

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/local_favorite.dart';

void main() {
  group('LocalFavorite.create()', () {
    test('fills all required fields with the supplied values', () {
      final favorite = LocalFavorite.create(
        bangumiId: 1,
        title: 'Example',
        coverUrl: 'https://example.com/cover.jpg',
        score: 8.5,
      );

      expect(favorite.bangumiId, 1);
      expect(favorite.title, 'Example');
      expect(favorite.coverUrl, 'https://example.com/cover.jpg');
      expect(favorite.score, 8.5);
      expect(favorite.type, 1, reason: 'default type is Want (1)');
      expect(favorite.id, 0, reason: 'id is left at its default of 0');
      expect(favorite.createdAt, greaterThan(0));
    });

    test('honors a non-default collection type', () {
      // 2: Watched, 3: Watching, 4: Hold, 5: Dropped
      for (final type in [2, 3, 4, 5]) {
        final f = LocalFavorite.create(
          bangumiId: 1,
          title: 'X',
          coverUrl: '',
          score: 0,
          type: type,
        );
        expect(f.type, type);
      }
    });

    test('accepts unicode / emoji in title and cover URL', () {
      final f = LocalFavorite.create(
        bangumiId: 1,
        title: '🎌 日本語 — 中文 ✨',
        coverUrl: 'https://example.com/封面.jpg',
        score: 7.5,
      );
      expect(f.title, '🎌 日本語 — 中文 ✨');
      expect(f.coverUrl, 'https://example.com/封面.jpg');
    });

    test('records a non-zero, non-future createdAt', () {
      // The factory stamps `DateTime.now().millisecondsSinceEpoch` —
      // the value must be a positive integer and not be in the
      // future. A "future" timestamp would suggest a clock skew bug
      // that breaks sort-by-recency in the favorites page.
      final before = DateTime.now().millisecondsSinceEpoch;
      final f = LocalFavorite.create(
        bangumiId: 1,
        title: '',
        coverUrl: '',
        score: 0,
      );
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(f.createdAt, greaterThanOrEqualTo(before));
      expect(f.createdAt, lessThanOrEqualTo(after));
    });

    test('two favorites created back-to-back are timestamp-ordered', () {
      // Drift on extremely fast hardware could in theory make the
      // millisecond counter identical; we require non-decreasing
      // ordering so the favorites list never shows a "newer" entry
      // above an "older" one due to non-monotonic stamps.
      final first = LocalFavorite.create(
        bangumiId: 1,
        title: 'A',
        coverUrl: '',
        score: 0,
      );
      final second = LocalFavorite.create(
        bangumiId: 2,
        title: 'B',
        coverUrl: '',
        score: 0,
      );
      expect(second.createdAt, greaterThanOrEqualTo(first.createdAt));
    });
  });
}
