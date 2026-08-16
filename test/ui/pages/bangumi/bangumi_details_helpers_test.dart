import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_helpers.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));
  group('parseBangumiSummary', () {
    test('null summary returns both fields as null', () {
      final parsed = parseBangumiSummary(null);
      expect(parsed['translation'], isNull);
      expect(parsed['original'], isNull);
    });

    test('empty summary returns both fields as null', () {
      final parsed = parseBangumiSummary('');
      expect(parsed['translation'], isNull);
      expect(parsed['original'], isNull);
    });

    test('summary without separator puts everything in translation', () {
      final parsed = parseBangumiSummary('just a translation');
      expect(parsed['translation'], 'just a translation');
      expect(parsed['original'], isNull);
    });

    test('summary with separator splits translation and original', () {
      final parsed = parseBangumiSummary('translated[简介原文]原文中文字');
      expect(parsed['translation'], 'translated');
      expect(parsed['original'], '原文中文字');
    });

    test('separator at the start yields empty translation', () {
      final parsed = parseBangumiSummary('[简介原文]原文中文字');
      expect(parsed['translation'], '');
      expect(parsed['original'], '原文中文字');
    });

    test('separator at the end yields empty original', () {
      final parsed = parseBangumiSummary('translated[简介原文]');
      expect(parsed['translation'], 'translated');
      expect(parsed['original'], '');
    });

    test('trims whitespace around both halves', () {
      final parsed = parseBangumiSummary('  translated  [简介原文]  原文中文字  ');
      expect(parsed['translation'], 'translated');
      expect(parsed['original'], '原文中文字');
    });
  });

  group('summarizeInfoboxValue', () {
    test('string value is returned via toString', () {
      expect(summarizeInfoboxValue('hello'), 'hello');
    });

    test('integer value is rendered as its string form', () {
      expect(summarizeInfoboxValue(5), '5');
    });

    test('null value renders as empty string', () {
      expect(summarizeInfoboxValue(null), '');
    });

    test('list of v-maps joins their v fields with comma-space', () {
      final value = [
        {'v': 'a'},
        {'v': 'b'},
      ];
      expect(summarizeInfoboxValue(value), 'a, b');
    });

    test('list filters out entries whose v is empty', () {
      final value = [
        {'v': 'a'},
        {'v': ''},
        {'v': 'b'},
      ];
      expect(summarizeInfoboxValue(value), 'a, b');
    });

    test('empty list renders as empty string', () {
      expect(summarizeInfoboxValue(<dynamic>[]), '');
    });

    test('non-list map renders as its toString', () {
      expect(summarizeInfoboxValue({'k': 'v'}), "{k: v}");
    });

    test(
      'regression: JSON-decoded List<dynamic> with mixed-empty v values does not throw',
      () {
        // Reproduces the field shape that arrived from the bangumi JSON
        // payload: the infobox `value` slot is a `List<dynamic>` whose
        // elements are `Map<String, dynamic>`, with at least one entry
        // whose `v` field is an empty string. Before the fix this raised
        // `type '(dynamic) => dynamic' is not a subtype of type
        // '(dynamic) => bool' of 'test'` from the `.where` step.
        final decoded =
            jsonDecode('''
          [
            {"v": "Alice"},
            {"v": ""},
            {"v": "Bob"}
          ]
          ''')
                as List<dynamic>;

        expect(summarizeInfoboxValue(decoded), 'Alice, Bob');
      },
    );
  });

  group('shouldEnableInfoBoxCollapse', () {
    test('empty list does not enable collapse', () {
      expect(shouldEnableInfoBoxCollapse(<dynamic>[]), isFalse);
    });

    test('exactly 6 items does not enable collapse', () {
      final items = List.generate(6, (_) => {'key': 'k', 'value': 'v'});
      expect(shouldEnableInfoBoxCollapse(items), isFalse);
    });

    test('7 items enables collapse', () {
      final items = List.generate(7, (_) => {'key': 'k', 'value': 'v'});
      expect(shouldEnableInfoBoxCollapse(items), isTrue);
    });

    test('list-valued entry with more than 4 elements enables collapse', () {
      final items = [
        {
          'key': 'k',
          'value': List.generate(5, (i) => {'v': 'x$i'}),
        },
      ];
      expect(shouldEnableInfoBoxCollapse(items), isTrue);
    });

    test(
      'list-valued entry with exactly 4 elements does not enable collapse',
      () {
        final items = [
          {
            'key': 'k',
            'value': List.generate(4, (i) => {'v': 'x$i'}),
          },
        ];
        expect(shouldEnableInfoBoxCollapse(items), isFalse);
      },
    );

    test('value whose summary exceeds 80 chars enables collapse', () {
      final long = 'x' * 81;
      final items = [
        {'key': 'k', 'value': long},
      ];
      expect(shouldEnableInfoBoxCollapse(items), isTrue);
    });

    test('short values stay collapsed-disabled', () {
      final items = [
        {'key': 'a', 'value': 'short'},
        {'key': 'b', 'value': 'also short'},
      ];
      expect(shouldEnableInfoBoxCollapse(items), isFalse);
    });
  });

  group('isInfoboxItemEmpty', () {
    test('empty key and value is empty', () {
      expect(isInfoboxItemEmpty({'key': '', 'value': ''}), isTrue);
    });

    test('non-map item is empty', () {
      expect(isInfoboxItemEmpty('not a map'), isTrue);
      expect(isInfoboxItemEmpty(null), isTrue);
    });

    test('key and value both present is not empty', () {
      expect(isInfoboxItemEmpty({'key': 'a', 'value': 'b'}), isFalse);
    });

    test('whitespace-only key is empty', () {
      expect(isInfoboxItemEmpty({'key': '   ', 'value': 'b'}), isTrue);
    });

    test('whitespace-only value is empty', () {
      expect(isInfoboxItemEmpty({'key': 'a', 'value': '   '}), isTrue);
    });
  });

  group('siteKindPriority', () {
    test('info < onair < resource < default', () {
      expect(siteKindPriority('info'), lessThan(siteKindPriority('onair')));
      expect(siteKindPriority('onair'), lessThan(siteKindPriority('resource')));
      expect(siteKindPriority('resource'), lessThan(siteKindPriority('other')));
    });

    test('exact priority values', () {
      expect(siteKindPriority('info'), 0);
      expect(siteKindPriority('onair'), 1);
      expect(siteKindPriority('resource'), 2);
      expect(siteKindPriority('something-else'), 3);
      expect(siteKindPriority(''), 3);
    });
  });

  group('formatDateToMonth', () {
    test('parses YYYY-MM-DD with locale-aware formatting', () {
      expect(formatDateToMonth('2026-01-15', zh), '2026年 1月');
      expect(formatDateToMonth('2024-12-31', zh), '2024年 12月');
      expect(formatDateToMonth('2026-01-15', en), '1/2026');
    });

    test('returns input unchanged for unparseable strings', () {
      expect(formatDateToMonth('not a date', zh), 'not a date');
    });

    test('empty string returns empty', () {
      expect(formatDateToMonth('', zh), '');
    });
  });

  group('readIntValue', () {
    test('int passes through', () {
      expect(readIntValue(12), 12);
    });

    test('double is truncated to int', () {
      expect(readIntValue(12.9), 12);
      expect(readIntValue(12.0), 12);
    });

    test('numeric string is parsed', () {
      expect(readIntValue('42'), 42);
    });

    test('non-numeric string returns null', () {
      expect(readIntValue('abc'), isNull);
    });

    test('null returns null', () {
      expect(readIntValue(null), isNull);
    });
  });

  group('getTotalEpisodeCount', () {
    test('prefers total_episodes when positive', () {
      expect(getTotalEpisodeCount({'total_episodes': 24}, null), 24);
    });

    test('ignores zero total_episodes, falls back to eps', () {
      expect(getTotalEpisodeCount({'total_episodes': 0, 'eps': 12}, null), 12);
    });

    test('falls back to episodes list length when data has none', () {
      const episodes = <BangumiEpisode>[
        BangumiEpisode(
          id: 1,
          sort: 1,
          name: '',
          nameCn: '',
          description: '',
          airdate: '',
          duration: '',
        ),
        BangumiEpisode(
          id: 2,
          sort: 2,
          name: '',
          nameCn: '',
          description: '',
          airdate: '',
          duration: '',
        ),
      ];
      expect(getTotalEpisodeCount({}, episodes), 2);
    });

    test('falls back to episodes Map list when no episodes list supplied', () {
      final data = {
        'episodes': [
          {'id': 1, 'sort': 1},
          {'id': 2, 'sort': 2},
        ],
      };
      expect(getTotalEpisodeCount(data, null), 2);
    });

    test('returns null when everything is empty', () {
      expect(getTotalEpisodeCount({}, null), isNull);
      expect(getTotalEpisodeCount(null, null), isNull);
    });
  });

  group('getEpisodeStatusText', () {
    test('returns localized total when count is positive', () {
      expect(getEpisodeStatusText({'total_episodes': 12}, null, zh), '全 12 话');
      expect(
        getEpisodeStatusText({'total_episodes': 12}, null, en),
        '12 episodes',
      );
    });

    test('returns localized zero status when nothing is available', () {
      expect(getEpisodeStatusText({}, null, zh), '0话');
      expect(getEpisodeStatusText({}, null, en), '0 episodes');
    });
  });

  group('extractCurrentTags', () {
    test('returns fallback when rawTags is not a list', () {
      expect(extractCurrentTags(null, ['fallback']), ['fallback']);
      expect(extractCurrentTags('not a list', ['fallback']), ['fallback']);
    });

    test('preserves order of first occurrence, dedupes by lowercase', () {
      final rawTags = [
        {'name': 'Action'},
        {'name': 'comedy'},
        {'name': 'action'},
        {'name': 'Drama'},
      ];
      expect(extractCurrentTags(rawTags, const []), [
        'Action',
        'comedy',
        'Drama',
      ]);
    });

    test('skips entries with empty or whitespace-only names', () {
      final rawTags = [
        {'name': ''},
        {'name': '  '},
        {'name': 'Action'},
      ];
      expect(extractCurrentTags(rawTags, const []), ['Action']);
    });

    test('returns fallback when all entries are empty', () {
      final rawTags = [
        {'name': ''},
      ];
      expect(extractCurrentTags(rawTags, ['fallback']), ['fallback']);
    });

    test('handles raw string entries (not just Maps)', () {
      final rawTags = <dynamic>['Action', 'comedy', 'action'];
      // Strings are also deduped by lowercase key.
      expect(extractCurrentTags(rawTags, const []), ['Action', 'comedy']);
    });
  });

  group('getImageUrl', () {
    test('prefers data["images"]["large"]', () {
      expect(
        getImageUrl({
          'images': {'large': 'L', 'common': 'C', 'medium': 'M'},
        }, 'fallback'),
        'L',
      );
    });

    test('falls back through common -> medium -> fallback', () {
      expect(
        getImageUrl({
          'images': {'medium': 'M'},
        }, 'fallback'),
        'M',
      );
      expect(getImageUrl({'images': {}}, 'fallback'), 'fallback');
    });

    test('null data uses fallback', () {
      expect(getImageUrl(null, 'fallback'), 'fallback');
    });
  });

  group('getDisplayTitle', () {
    test('prefers data["name"]', () {
      expect(getDisplayTitle({'name': 'realname'}, 'fallback'), 'realname');
    });

    test('falls back when data is null or name missing', () {
      expect(getDisplayTitle(null, 'fallback'), 'fallback');
      expect(getDisplayTitle({}, 'fallback'), 'fallback');
    });
  });

  group('getDisplaySummary / hasBothTranslationAndOriginal', () {
    test('prefers translation when showOriginal is false', () {
      expect(
        getDisplaySummary('translated[简介原文]original', showOriginal: false),
        'translated',
      );
    });

    test('prefers original when showOriginal is true', () {
      expect(
        getDisplaySummary('translated[简介原文]original', showOriginal: true),
        'original',
      );
    });

    test('falls back to translation when original half is missing', () {
      expect(
        getDisplaySummary('only translation', showOriginal: true),
        'only translation',
      );
    });

    test('hasBoth is true only when both halves exist', () {
      expect(hasBothTranslationAndOriginal('translated[简介原文]original'), isTrue);
      expect(hasBothTranslationAndOriginal('only translation'), isFalse);
      expect(hasBothTranslationAndOriginal(null), isFalse);
    });
  });
}
