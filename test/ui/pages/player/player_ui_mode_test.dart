import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('compact and wide resize keeps Player State identity', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);

    await tester.pumpWidget(const MaterialApp(home: _PlayerStateFixture()));
    final compactState = tester.state<_PlayerStateFixtureState>(
      find.byType(_PlayerStateFixture),
    );
    final sessionIdentity = compactState.sessionIdentity;
    expect(find.byKey(const ValueKey(PlayerUiMode.desktopCompact)), findsOne);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    final wideState = tester.state<_PlayerStateFixtureState>(
      find.byType(_PlayerStateFixture),
    );
    expect(wideState, same(compactState));
    expect(wideState.sessionIdentity, same(sessionIdentity));
    expect(find.byKey(const ValueKey(PlayerUiMode.desktopWide)), findsOne);

    tester.view.physicalSize = const Size(800, 800);
    await tester.pump();
    expect(
      tester.state<_PlayerStateFixtureState>(find.byType(_PlayerStateFixture)),
      same(compactState),
    );
    expect(compactState.sessionIdentity, same(sessionIdentity));
    expect(find.byKey(const ValueKey(PlayerUiMode.desktopCompact)), findsOne);

    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Mirrors PlayerPage's ownership boundary without booting MediaKit/WebView.
/// The stable object represents the Player/session fields owned above the
/// responsive branch in PlayerPage.build.
class _PlayerStateFixture extends StatefulWidget {
  const _PlayerStateFixture();

  @override
  State<_PlayerStateFixture> createState() => _PlayerStateFixtureState();
}

class _PlayerStateFixtureState extends State<_PlayerStateFixture> {
  final Object sessionIdentity = Object();

  @override
  Widget build(BuildContext context) {
    final mode = PlayerUiModeResolver.resolve(
      width: MediaQuery.sizeOf(context).width,
    );
    return SizedBox(key: ValueKey(mode));
  }
}
