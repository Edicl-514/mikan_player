// Phase 1 / R1 unit + widget tests for the pure BT-resource tag helpers
// extracted from `player_page.dart` into
// `lib/ui/pages/player/widgets/bt_resource_tags.dart`.
//
// `parseBtTags` is a pure function — no widget pump needed. `buildBtTag` /
// `buildBtTagsRow` return Widgets and are exercised with `testWidgets`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/ui/pages/player/widgets/bt_resource_tags.dart';

void main() {
  group('parseBtTags resolution', () {
    test('detects 4K and 2160P', () {
      expect(parseBtTags('[X] Foo 4K HEVC')['resolution'], '4K');
      expect(parseBtTags('[X] Foo 2160P HEVC')['resolution'], '4K');
      expect(parseBtTags('[X] Foo 2160 HEVC')['resolution'], '4K');
    });
    test('detects 1080P / 720P / 480P / 360P', () {
      expect(parseBtTags('Foo 1080p')['resolution'], '1080P');
      expect(parseBtTags('Foo 1080')['resolution'], '1080P');
      expect(parseBtTags('Foo 720p')['resolution'], '720P');
      expect(parseBtTags('Foo 480p')['resolution'], '480P');
      expect(parseBtTags('Foo 360p')['resolution'], '360P');
    });
    test('returns null resolution when no marker', () {
      expect(parseBtTags('Foo Bar')['resolution'], isNull);
    });
  });

  group('parseBtTags codec', () {
    test('detects HEVC / H265 / X265', () {
      expect(parseBtTags('Foo HEVC')['codec'], 'HEVC');
      expect(parseBtTags('Foo H.265')['codec'], 'HEVC');
      expect(parseBtTags('Foo H265')['codec'], 'HEVC');
      expect(parseBtTags('Foo x265')['codec'], 'HEVC');
    });
    test('detects AVC / H264 / X264', () {
      expect(parseBtTags('Foo AVC')['codec'], 'AVC');
      expect(parseBtTags('Foo H.264')['codec'], 'AVC');
      expect(parseBtTags('Foo x264')['codec'], 'AVC');
    });
    test('detects AV1', () {
      expect(parseBtTags('Foo AV1')['codec'], 'AV1');
    });
    test('HEVC takes priority over AVC within the same title', () {
      final t = parseBtTags('Foo HEVC H.264');
      expect(t['codec'], 'HEVC');
    });
    test('returns null codec when no marker', () {
      expect(parseBtTags('Foo Bar')['codec'], isNull);
    });
  });

  group('parseBtTags subtitle language', () {
    test('combination 简繁日 wins over single markers', () {
      expect(parseBtTags('简繁日内嵌')['subLang'], '简繁日');
    });
    test('简日 combination', () {
      expect(parseBtTags('简日内封')['subLang'], '简日');
    });
    test('繁日 combination', () {
      expect(parseBtTags('繁日内封')['subLang'], '繁日');
    });
    test('dual 简繁 via 双语 / DUAL', () {
      expect(parseBtTags('双语内嵌')['subLang'], '简繁');
      expect(parseBtTags('DUAL PLAY')['subLang'], '简繁');
    });
    test('简中 via 简体 / CHS / GB', () {
      expect(parseBtTags('简体内嵌')['subLang'], '简中');
      expect(parseBtTags('CHS内嵌')['subLang'], '简中');
      expect(parseBtTags('GB内嵌')['subLang'], '简中');
    });
    test('繁中 via 繁体 / CHT / BIG5', () {
      expect(parseBtTags('繁体内嵌')['subLang'], '繁中');
      expect(parseBtTags('CHT内嵌')['subLang'], '繁中');
      expect(parseBtTags('BIG5内嵌')['subLang'], '繁中');
    });
    test('日语 via 日文 / 日语 / 日本語 (case-sensitive on original title)', () {
      expect(parseBtTags('日文')['subLang'], '日语');
      expect(parseBtTags('日语')['subLang'], '日语');
      expect(parseBtTags('日本語')['subLang'], '日语');
    });
    test('生肉 / RAW only when no other language marker', () {
      expect(parseBtTags('生肉1080p')['subLang'], '生肉');
      expect(parseBtTags('RAW 1080p')['subLang'], '生肉');
      expect(parseBtTags('NOSUB 1080p')['subLang'], '生肉');
      // 简中 takes priority over 生肉
      expect(parseBtTags('简体 生肉')['subLang'], '简中');
    });
    test('returns null subLang when no marker', () {
      expect(parseBtTags('Foo Bar 1080p')['subLang'], isNull);
    });
  });

  group('parseBtTags subtitle type', () {
    test('内封 wins over 内嵌 (soft-sub priority)', () {
      expect(parseBtTags('内封')['subType'], '内封');
      expect(parseBtTags('内嵌')['subType'], '内嵌');
      expect(parseBtTags('内封 内嵌')['subType'], '内封');
    });
    test('HARDSUB / SOFTSUB markers', () {
      expect(parseBtTags('HARDSUB')['subType'], '内嵌');
      expect(parseBtTags('SOFTSUB')['subType'], '内封');
    });
    test('returns null subType when no marker', () {
      expect(parseBtTags('Foo 1080p')['subType'], isNull);
    });
  });

  group('parseBtTags realistic composite title', () {
    test('VCB-Studio style title yields all four tags', () {
      final t = parseBtTags('[VCB-Studio] Foo Bar [01][1080p][HEVC][简日内嵌]');
      expect(t['resolution'], '1080P');
      expect(t['codec'], 'HEVC');
      expect(t['subLang'], '简日');
      expect(t['subType'], '内嵌');
    });
    test('empty title yields all-null tags', () {
      final t = parseBtTags('');
      expect(t['resolution'], isNull);
      expect(t['codec'], isNull);
      expect(t['subLang'], isNull);
      expect(t['subType'], isNull);
    });
  });

  group('buildBtTagsRow widget', () {
    testWidgets('renders the expected tag texts for a known title', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: buildBtTagsRow('[X] Foo 1080p HEVC 简日内嵌')),
        ),
      );
      expect(find.text('1080P'), findsOneWidget);
      expect(find.text('HEVC'), findsOneWidget);
      expect(find.text('简日'), findsOneWidget);
      expect(find.text('内嵌'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when title has no tags', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: buildBtTagsRow('plain text no tags'))),
      );
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('accepts pre-parsed tags via the tags parameter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildBtTagsRow(
              'unused',
              tags: {
                'resolution': '720P',
                'codec': null,
                'subLang': null,
                'subType': null,
              },
            ),
          ),
        ),
      );
      expect(find.text('720P'), findsOneWidget);
      expect(find.text('HEVC'), findsNothing);
    });
  });
}
