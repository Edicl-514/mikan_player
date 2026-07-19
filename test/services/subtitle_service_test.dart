import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/ui/widgets/subtitle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SubtitleSettings', () {
    test('copyWith and text style preserve configured appearance', () {
      final settings = const SubtitleSettings().copyWith(
        fontSize: 32,
        fontColor: const Color(0xFF00FF00),
        backgroundColor: const Color(0xFF123456),
        backgroundOpacity: 0.25,
        outlineColor: const Color(0xFFFF0000),
        outlineWidth: 2,
        fontWeight: FontWeight.w700,
      );

      final style = settings.toTextStyle();

      expect(style.fontSize, 32);
      expect(style.color, const Color(0xFF00FF00));
      expect(style.fontWeight, FontWeight.w700);
      expect(style.backgroundColor?.a, closeTo(0.25, 0.001));
      expect(style.shadows, hasLength(4));
      expect(style.shadows!.every((shadow) => shadow.blurRadius == 2), isTrue);
    });

    test('zero outline width omits shadows', () {
      expect(
        const SubtitleSettings(outlineWidth: 0).toTextStyle().shadows,
        isNull,
      );
    });
  });

  group('SubtitleService settings and formatting', () {
    test('loads persisted settings', () async {
      SharedPreferences.setMockInitialValues({
        'subtitle_enabled': false,
        'subtitle_font_size': 36.0,
        'subtitle_font_color': 0xFF112233,
        'subtitle_bg_color': 0xFF445566,
        'subtitle_bg_opacity': 0.7,
        'subtitle_outline_width': 2.5,
        'subtitle_bottom_padding': 80.0,
      });
      final service = SubtitleService();

      await service.debugSettingsLoaded;

      expect(service.settings.enabled, isFalse);
      expect(service.settings.fontSize, 36);
      expect(service.settings.fontColor, const Color(0xFF112233));
      expect(service.settings.backgroundColor, const Color(0xFF445566));
      expect(service.settings.backgroundOpacity, 0.7);
      expect(service.settings.outlineWidth, 2.5);
      expect(service.settings.bottomPadding, 80);
    });

    test('individual setters clamp values and persist them', () async {
      final service = SubtitleService();
      await service.debugSettingsLoaded;

      service.setFontSize(100);
      service.setBackgroundOpacity(-1);
      service.setBottomPadding(500);
      service.setOutlineWidth(9);
      service.setFontColor(const Color(0xFFAABBCC));
      await pumpEventQueue();

      expect(service.settings.fontSize, 64);
      expect(service.settings.backgroundOpacity, 0);
      expect(service.settings.bottomPadding, 200);
      expect(service.settings.outlineWidth, 5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('subtitle_font_size'), 64);
      expect(prefs.getDouble('subtitle_bg_opacity'), 0);
      expect(prefs.getDouble('subtitle_bottom_padding'), 200);
      expect(prefs.getDouble('subtitle_outline_width'), 5);
      expect(prefs.getInt('subtitle_font_color'), 0xFFAABBCC);
    });

    test(
      'track display names cover special, titled, language, and fallback tracks',
      () async {
        final service = SubtitleService();
        await service.debugSettingsLoaded;
        const untitled = SubtitleTrack('3', null, null);
        service.debugSetTracksForTest(
          available: const [
            SubtitleTrack('1', 'Signs', 'eng'),
            SubtitleTrack('2', null, 'jpn'),
            untitled,
          ],
          current: null,
          enabled: true,
        );

        expect(service.getTrackDisplayName(SubtitleTrack.auto()), '自动');
        expect(service.getTrackDisplayName(SubtitleTrack.no()), '关闭');
        expect(
          service.getTrackDisplayName(const SubtitleTrack('1', 'Signs', 'eng')),
          'Signs (英文)',
        );
        expect(
          service.getTrackDisplayName(const SubtitleTrack('2', null, 'jpn')),
          '日文',
        );
        expect(service.getTrackDisplayName(untitled), '字幕 3');
        expect(
          service.getTrackDisplayName(const SubtitleTrack('4', null, 'xx')),
          'XX',
        );
      },
    );

    test(
      'auto track falls back to first actual track and excludes auto/no',
      () async {
        final service = SubtitleService();
        await service.debugSettingsLoaded;
        service.debugSetTracksForTest(
          available: const [
            SubtitleTrack('auto', null, null),
            SubtitleTrack('1', 'First', 'eng'),
            SubtitleTrack('2', 'Second', 'jpn'),
            SubtitleTrack('no', null, null),
          ],
          current: const SubtitleTrack('auto', null, null),
          enabled: true,
        );

        expect(service.actualSubtitleTracks.map((track) => track.id), [
          '1',
          '2',
        ]);
        expect(service.resolvedSelectedTrack?.id, '1');
        expect(service.hasSubtitles, isTrue);
      },
    );

    test('unbind resets all transient track and text state', () async {
      final service = SubtitleService();
      await service.debugSettingsLoaded;
      service.debugSetTracksForTest(
        available: const [SubtitleTrack('1', 'One', 'eng')],
        current: const SubtitleTrack('1', 'One', 'eng'),
        enabled: true,
      );
      service.debugSetSubtitleTextForTest(const ['line']);

      service.unbindPlayer();

      expect(service.availableTracks, isEmpty);
      expect(service.currentTrack, isNull);
      expect(service.currentSubtitleText, ['', '']);
      expect(service.isSubtitleVisible, isFalse);
    });
  });

  group('SubtitleService track selection', () {
    test('auto track resolves to default or first actual track', () {
      final service = SubtitleService();
      // 模拟 media_kit 报告 auto 为当前轨，实际列表有两条。
      service.debugSetTracksForTest(
        available: const [
          SubtitleTrack('auto', null, null),
          SubtitleTrack('1', '简体', 'chi', isDefault: true),
          SubtitleTrack('2', 'English', 'eng'),
          SubtitleTrack('no', null, null),
        ],
        current: const SubtitleTrack('auto', null, null),
        enabled: true,
      );

      expect(service.hasSubtitles, isTrue);
      expect(service.isSubtitleVisible, isTrue);
      expect(service.resolvedSelectedTrack?.id, '1');
      expect(
        service.isTrackSelected(const SubtitleTrack('1', '简体', 'chi')),
        isTrue,
      );
      expect(
        service.isTrackSelected(const SubtitleTrack('2', 'English', 'eng')),
        isFalse,
      );
    });

    test(
      'disabled settings hide selection even if player still on a track',
      () {
        final service = SubtitleService();
        service.debugSetTracksForTest(
          available: const [
            SubtitleTrack('1', '简体', 'chi'),
            SubtitleTrack('2', 'English', 'eng'),
          ],
          current: const SubtitleTrack('1', '简体', 'chi'),
          enabled: false,
        );

        expect(service.isSubtitleVisible, isFalse);
        expect(service.resolvedSelectedTrack, isNull);
        expect(
          service.isTrackSelected(const SubtitleTrack('1', '简体', 'chi')),
          isFalse,
        );
      },
    );
  });

  group('SubtitleOverlay', () {
    testWidgets('rebuilds style when settings change', (tester) async {
      final service = SubtitleService();
      await service.debugSettingsLoaded;
      service.debugSetTracksForTest(
        available: const [SubtitleTrack('1', '简体', 'chi')],
        current: const SubtitleTrack('1', '简体', 'chi'),
        enabled: true,
      );
      service.debugSetSubtitleTextForTest(const ['测试字幕']);
      service.updateSettings(
        const SubtitleSettings(
          enabled: true,
          fontSize: 20,
          fontColor: Colors.white,
          bottomPadding: 40,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SubtitleOverlay(subtitleService: service)),
        ),
      );

      var text = tester.widget<Text>(find.text('测试字幕'));
      expect(text.style?.fontSize, 20);
      expect(text.style?.color?.toARGB32(), Colors.white.toARGB32());

      service.setFontSize(36);
      service.setFontColor(const Color(0xFFFFFF00));
      await tester.pump();

      text = tester.widget<Text>(find.text('测试字幕'));
      expect(text.style?.fontSize, 36);
      expect(text.style?.color?.toARGB32(), const Color(0xFFFFFF00).toARGB32());
    });

    testWidgets('hides text when subtitles disabled', (tester) async {
      final service = SubtitleService();
      await service.debugSettingsLoaded;
      service.debugSetTracksForTest(
        available: const [SubtitleTrack('1', '简体', 'chi')],
        current: const SubtitleTrack('1', '简体', 'chi'),
        enabled: true,
      );
      service.debugSetSubtitleTextForTest(const ['测试字幕']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SubtitleOverlay(subtitleService: service)),
        ),
      );
      expect(find.text('测试字幕'), findsOneWidget);

      service.setEnabled(false);
      await tester.pump();
      expect(find.text('测试字幕'), findsNothing);
    });
  });
}
