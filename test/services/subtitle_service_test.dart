import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/ui/widgets/subtitle_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('disabled settings hide selection even if player still on a track', () {
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
    });
  });

  group('SubtitleOverlay', () {
    testWidgets('rebuilds style when settings change', (tester) async {
      final service = SubtitleService();
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
