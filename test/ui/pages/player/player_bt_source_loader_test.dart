// Phase 1.2: unit tests for player_bt_source_loader pure helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/player_bt_source_loader.dart';

void main() {
  group('extractAliasesFromBangumiJson', () {
    test('empty / invalid', () {
      expect(extractAliasesFromBangumiJson(null), isEmpty);
      expect(extractAliasesFromBangumiJson(''), isEmpty);
      expect(extractAliasesFromBangumiJson('not-json'), isEmpty);
      expect(extractAliasesFromBangumiJson('[]'), isEmpty);
    });

    test('parses alias keys and splits multi-value strings', () {
      final json = '''
{
  "infobox": [
    {"key": "别名", "value": "Foo / Bar、Baz"},
    {"key": "中文名", "value": "忽略"},
    {"key": "Alias", "value": [{"v": "Qux"}, "Zap"]},
    {"key": "别称", "value": "  "}
  ]
}
''';
      expect(extractAliasesFromBangumiJson(json), [
        'Foo',
        'Bar',
        'Baz',
        'Qux',
        'Zap',
      ]);
    });
  });

  group('buildSearchNameForSources / captcha keyword', () {
    test('joins unique title/subtitle/aliases', () {
      final name = buildSearchNameForSources(
        title: '  Title  ',
        subTitle: 'Title', // de-dupe case-insensitively? exact lower key
        fullJson:
            '{"infobox":[{"key":"别名","value":"AliasA||x"},{"key":"别名","value":"aliasa"}]}',
      );
      // "AliasA||x" is split by ||? The split regex is [\\/、,，;；·・] — not |
      // So "AliasA||x" stays one candidate unless we also get title.
      expect(name.split('||').first, 'Title');
      expect(name.toLowerCase().contains('aliasa'), isTrue);
    });

    test('captcha keyword is first non-empty segment', () {
      expect(
        buildCaptchaPreflightKeyword(
          title: 'Main',
          subTitle: 'Sub',
          fullJson: null,
        ),
        'Main',
      );
      expect(
        buildCaptchaPreflightKeyword(title: '  ', subTitle: 'OnlySub'),
        'OnlySub',
      );
    });
  });

  group('extractBtHashFromStreamUrl', () {
    test('libtorrent and rqbit forms', () {
      expect(
        extractBtHashFromStreamUrl(
          'http://127.0.0.1:8080/stream/abcdef0123456789/0',
        ),
        'abcdef0123456789',
      );
      expect(
        extractBtHashFromStreamUrl('http://127.0.0.1:8080/streams/ABCDEF/1'),
        'ABCDEF',
      );
      expect(
        extractBtHashFromStreamUrl(
          'http://127.0.0.1:3000/torrents/deadbeef/stream/0',
        ),
        'deadbeef',
      );
      expect(
        extractBtHashFromStreamUrl('http://example.com/video.mp4'),
        isNull,
      );
    });
  });
}
