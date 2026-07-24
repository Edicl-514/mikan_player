import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/player/player_ui_mode.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_selector.dart';

void main() {
  group('PlayerUiModeResolver', () {
    test('Windows uses compact mode through 900 px and wide mode above it', () {
      expect(
        PlayerUiModeResolver.resolve(
          width: 720,
          platform: TargetPlatform.windows,
        ),
        PlayerUiMode.desktopCompact,
      );
      expect(
        PlayerUiModeResolver.resolve(
          width: 900,
          platform: TargetPlatform.windows,
        ),
        PlayerUiMode.desktopCompact,
      );
      expect(
        PlayerUiModeResolver.resolve(
          width: 901,
          platform: TargetPlatform.windows,
        ),
        PlayerUiMode.desktopWide,
      );
    });

    test('mobile platforms stay mobile regardless of width', () {
      expect(
        PlayerUiModeResolver.resolve(
          width: 1280,
          platform: TargetPlatform.android,
        ),
        PlayerUiMode.mobile,
      );
      expect(
        PlayerUiModeResolver.resolve(width: 720, platform: TargetPlatform.iOS),
        PlayerUiMode.mobile,
      );
    });

    test('compact mode has desktop input capabilities', () {
      expect(PlayerUiMode.desktopCompact.isDesktop, isTrue);
      expect(PlayerUiMode.desktopCompact.isMobile, isFalse);
      expect(PlayerUiMode.desktopCompact.usesWideLayout, isFalse);
      expect(PlayerUiMode.desktopWide.usesWideLayout, isTrue);
    });
  });

  testWidgets('compact source selector uses desktop copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: PlayerSourceSelector(
            uiMode: PlayerUiMode.desktopCompact,
            isExpanded: false,
            activeSource: 'bt',
            btCount: 2,
            onlineCount: 1,
            currentLabel: 'BT',
            isBtLoading: false,
            hasBtError: false,
            isSampleLoading: false,
            hasSampleError: false,
            onExpand: () {},
            onCollapse: () {},
            onSelectSource: (_) {},
          ),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.playerSourceTitleFound(2, 1, 'BT')), findsOneWidget);
    expect(find.text(l10n.playerSourceTitleFoundMobile), findsNothing);
  });
}
