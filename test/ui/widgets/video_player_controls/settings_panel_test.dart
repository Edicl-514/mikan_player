// L10N-2: SettingsPanel main menu / subtitle empty state smoke tests.
//
// Avoids media_kit / danmaku service network: DanmakuService and SubtitleService
// are constructed with their default in-memory settings. Assertions cover only
// the localized menu surface in zh and en.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/settings_panel.dart';

import '../../../support/localized_widget_tester.dart';

Future<void> _pumpSettings(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
  List<SearchPlayResult> sources = const <SearchPlayResult>[],
  String currentSourceLabel = '',
}) async {
  await pumpLocalizedWidget(
    tester,
    Scaffold(
      body: SizedBox(
        width: 360,
        height: 640,
        child: SettingsPanel(
          isFullscreen: false,
          danmakuService: DanmakuService(),
          subtitleService: SubtitleService(),
          availableSources: sources,
          currentSourceLabel: currentSourceLabel,
          onSourceSelected: (_) {},
          isAutoPlayNextEnabled: true,
          onToggleAutoPlayNext: () {},
          playbackSpeed: 1.0,
          onPlaybackSpeedChanged: (_) {},
        ),
      ),
    ),
    locale: locale,
  );
  await tester.pump();
}

void main() {
  group('SettingsPanel i18n (L10N-2)', () {
    testWidgets('zh main menu shows localized section titles', (tester) async {
      await _pumpSettings(tester, locale: const Locale('zh'));
      final l10n = localizedOf(tester);

      expect(find.text(l10n.settingsTitle), findsWidgets);
      expect(find.text(l10n.danmakuSettingsTitle), findsOneWidget);
      expect(find.text(l10n.subtitleSettingsTitle), findsOneWidget);
      expect(find.text(l10n.playbackSpeed), findsOneWidget);
      expect(find.text(l10n.playSourceTitle), findsOneWidget);
      expect(find.text(l10n.autoPlayNext), findsOneWidget);
      // Danmaku defaults to enabled; subtitles have no tracks until media loads.
      expect(find.text(l10n.statusEnabled), findsOneWidget);
      expect(find.text(l10n.noSubtitlesAvailable), findsOneWidget);
    });

    testWidgets('en main menu shows localized section titles', (tester) async {
      await _pumpSettings(tester, locale: const Locale('en'));
      final l10n = localizedOf(tester);

      expect(find.text(l10n.danmakuSettingsTitle), findsOneWidget);
      expect(find.text(l10n.subtitleSettingsTitle), findsOneWidget);
      expect(find.text(l10n.playbackSpeed), findsOneWidget);
      expect(find.text(l10n.playSourceTitle), findsOneWidget);
      expect(find.text(l10n.autoPlayNext), findsOneWidget);
      // Chinese leftovers must not remain on the main menu surface.
      expect(find.text('弹幕设置'), findsNothing);
      expect(find.text('字幕设置'), findsNothing);
      expect(find.text('自动连播'), findsNothing);
    });

    testWidgets('tapping subtitle settings shows empty embedded-track copy', (
      tester,
    ) async {
      await _pumpSettings(tester, locale: const Locale('zh'));
      final l10n = localizedOf(tester);

      await tester.tap(find.text(l10n.subtitleSettingsTitle));
      await tester.pumpAndSettle();

            expect(find.text(l10n.showSubtitles), findsOneWidget);
      expect(find.text(l10n.subtitleTracks), findsOneWidget);
      expect(find.text(l10n.noEmbeddedSubtitles), findsOneWidget);
      expect(find.text(l10n.subtitleStyle), findsOneWidget);
      // Preview text sits further down the ListView; ensure it is reachable.
      await tester.scrollUntilVisible(
        find.text(l10n.subtitlePreview),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.subtitlePreview), findsOneWidget);
    });

    testWidgets('source menu subtitle uses short empty copy', (tester) async {
      await _pumpSettings(tester, locale: const Locale('zh'));
      final l10n = localizedOf(tester);
      expect(find.text(l10n.noAvailableSourcesShort), findsOneWidget);
    });
  });
}
