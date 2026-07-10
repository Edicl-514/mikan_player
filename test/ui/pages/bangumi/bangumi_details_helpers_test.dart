import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_helpers.dart';

void main() {
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
}
