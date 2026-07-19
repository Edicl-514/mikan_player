// DT-1: pure-Dart composition tests for `models/bangumi_user_collection.dart`.
//
// Covers:
//   * Full happy-path JSON deserialization with every field populated.
//   * Defensive defaults for missing fields and unexpected types.
//   * BangumiUserCollectionSubject images get passed through the
//     `BangumiUrlRewriter.rewrite` pipeline (we exercise the static
//     public surface — no caching enabled in these tests so the input
//     is returned unchanged, and we confirm that contract).
//   * `tags` and other `dynamic` fields are preserved verbatim (the
//     model does not validate them — only hands them to UI code that
//     must deal with whatever the API sends).

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

void main() {
  // Make sure the cached reverse-proxy flag is `null` (the default
  // for an unconfigured session). Several of these tests assert that
  // rewrite() returns the input unchanged — that contract only holds
  // when the cache is null or false. Other test files may toggle it.
  setUp(() {
    BangumiUrlRewriter.setEnabled(false);
  });

  group('BangumiUserCollection.fromJson()', () {
    test('parses a fully-populated payload', () {
      final json = <String, dynamic>{
        'updated_at': '2024-08-15T10:30:00Z',
        'comment': 'favourite this season',
        'tags': <String>['奇幻', '冒险'],
        'subject': <String, dynamic>{
          'id': 42,
          'name': 'Original Name',
          'name_cn': '显示名称',
          'short_summary': 'A short summary',
          'score': 8.7,
          'images': <String, dynamic>{
            'small': 'https://lain.bgm.tv/img/small',
            'grid': 'https://lain.bgm.tv/img/grid',
            'large': 'https://lain.bgm.tv/img/large',
            'medium': 'https://lain.bgm.tv/img/medium',
            'common': 'https://lain.bgm.tv/img/common',
          },
          'eps': 12,
          'collection_total': 12345,
        },
        'subject_id': 42,
        'type': 3,
        'rate': 8,
        'private': true,
      };

      final c = BangumiUserCollection.fromJson(json);

      expect(c.date, '2024-08-15T10:30:00Z');
      expect(c.comment, 'favourite this season');
      expect(c.tags, ['奇幻', '冒险']);
      expect(c.subjectId, 42);
      expect(c.type, 3);
      expect(c.rate, 8);
      expect(c.private, isTrue);

      expect(c.subject.id, 42);
      expect(c.subject.name, 'Original Name');
      expect(c.subject.nameCn, '显示名称');
      expect(c.subject.shortSummary, 'A short summary');
      expect(c.subject.score, 8.7);
      expect(c.subject.eps, 12);
      expect(c.subject.collectionTotal, 12345);

      // With caching disabled, rewrite() is a no-op; the input URLs
      // round-trip as-is.
      expect(c.subject.images.small, 'https://lain.bgm.tv/img/small');
      expect(c.subject.images.grid, 'https://lain.bgm.tv/img/grid');
      expect(c.subject.images.large, 'https://lain.bgm.tv/img/large');
      expect(c.subject.images.medium, 'https://lain.bgm.tv/img/medium');
      expect(c.subject.images.common, 'https://lain.bgm.tv/img/common');
    });

    test('falls back to safe defaults for missing top-level fields', () {
      final c = BangumiUserCollection.fromJson(<String, dynamic>{
        'subject': <String, dynamic>{
          'id': 1,
          'name': 'X',
          'name_cn': '',
          'short_summary': '',
          'score': 0,
          'images': <String, dynamic>{
            'small': '',
            'grid': '',
            'large': '',
            'medium': '',
            'common': '',
          },
          'eps': 0,
          'collection_total': 0,
        },
      });

      expect(c.date, '');
      expect(c.comment, '');
      expect(c.tags, isEmpty);
      expect(c.subjectId, 0);
      expect(c.type, 0);
      expect(c.rate, 0);
      expect(c.private, isFalse);
    });

    test('null score coerces to 0.0', () {
      // The model calls `(json['score'] ?? 0).toDouble()`; a numeric
      // (or null) value must end up as a double, never as an int.
      final c = BangumiUserCollection.fromJson(<String, dynamic>{
        'subject': <String, dynamic>{
          'id': 1,
          'name': 'X',
          'name_cn': '',
          'short_summary': '',
          'score': null,
          'images': <String, dynamic>{
            'small': '',
            'grid': '',
            'large': '',
            'medium': '',
            'common': '',
          },
          'eps': 0,
          'collection_total': 0,
        },
      });
      expect(c.subject.score, 0.0);
      expect(c.subject.score, isA<double>());
    });

    test('preserves arbitrary tag payloads (mixed types and shapes)', () {
      // The model exposes `tags: List<dynamic>` and never re-shapes
      // the API value. UI callers must accept whatever Bangumi sends,
      // so verify the contract: pass-through, no copy, no filter.
      final rawTags = <dynamic>[
        'string-tag',
        {'name': 'object-tag'},
        42,
        null,
      ];
      final c = BangumiUserCollection.fromJson(<String, dynamic>{
        'tags': rawTags,
        'subject': <String, dynamic>{
          'id': 1,
          'name': 'X',
          'name_cn': '',
          'short_summary': '',
          'score': 0,
          'images': <String, dynamic>{
            'small': '',
            'grid': '',
            'large': '',
            'medium': '',
            'common': '',
          },
          'eps': 0,
          'collection_total': 0,
        },
      });
      // Identity-preserving — UI code can match by reference.
      expect(identical(c.tags, rawTags), isTrue);
    });

    test('null tags fall back to an empty list', () {
      final c = BangumiUserCollection.fromJson(<String, dynamic>{
        'tags': null,
        'subject': <String, dynamic>{
          'id': 1,
          'name': 'X',
          'name_cn': '',
          'short_summary': '',
          'score': 0,
          'images': <String, dynamic>{
            'small': '',
            'grid': '',
            'large': '',
            'medium': '',
            'common': '',
          },
          'eps': 0,
          'collection_total': 0,
        },
      });
      expect(c.tags, isEmpty);
    });

    test('accepts unicode / emoji in name and comment', () {
      final c = BangumiUserCollection.fromJson(<String, dynamic>{
        'comment': '🎉 番剧真好看 — ностальгия ✨',
        'subject': <String, dynamic>{
          'id': 1,
          'name': '日本語タイトル',
          'name_cn': '中文标题',
          'short_summary': '概要…',
          'score': 7.5,
          'images': <String, dynamic>{
            'small': '',
            'grid': '',
            'large': '',
            'medium': '',
            'common': '',
          },
          'eps': 24,
          'collection_total': 99999,
        },
      });
      expect(c.comment, '🎉 番剧真好看 — ностальгия ✨');
      expect(c.subject.name, '日本語タイトル');
      expect(c.subject.nameCn, '中文标题');
    });

    test('private defaults to false when missing', () {
      final c = BangumiUserCollection.fromJson(<String, dynamic>{
        'subject': <String, dynamic>{
          'id': 1,
          'name': 'X',
          'name_cn': '',
          'short_summary': '',
          'score': 0,
          'images': <String, dynamic>{
            'small': '',
            'grid': '',
            'large': '',
            'medium': '',
            'common': '',
          },
          'eps': 0,
          'collection_total': 0,
        },
      });
      expect(c.private, isFalse);
    });
  });
}
