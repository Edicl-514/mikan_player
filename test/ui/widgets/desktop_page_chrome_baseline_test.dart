import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/theme/app_theme.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_strip.dart';

/// Layout baseline for the Windows page shell.
///
/// Round 1–3 remove page `AppBar`s one family at a time, and the failure mode is
/// silent: a page keeps the padding it reserved for its own toolbar and leaves an
/// empty strip above its first item. These are the recorded numbers a migrated
/// page must still produce at the plan's three widths in both themes.
const List<double> _widths = <double>[720, 900, 1280];

const Key _bodyKey = Key('baseline-body');

void main() {
  tearDown(() {
    WorkspacePageChromeRegistry.instance.debugReset();
    WindowsDesktopFrameController.instance.setContentFullscreen(false);
  });

  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'light' : 'dark';
    final theme = brightness == Brightness.light
        ? AppTheme.light(
            seedColor: Colors.blue,
            useMaterial3Color: true,
            pureBackground: false,
          )
        : AppTheme.dark(
            seedColor: Colors.blue,
            useMaterial3Color: true,
            pureBackground: false,
          );

    for (final width in _widths) {
      testWidgets(
        '$themeName @ ${width.toInt()}px: shell owns 82px of chrome',
        (tester) async {
          await _pumpShell(tester, theme: theme, width: width);

          final frameTop = tester.getRect(find.byType(WindowsDesktopFrame)).top;
          final toolbar = tester.getRect(find.byType(WorkspaceContextToolbar));
          final body = tester.getRect(find.byKey(_bodyKey));

          expect(
            toolbar.top - frameTop,
            WindowsDesktopFrame.titleBarHeight,
            reason: 'context toolbar sits directly under the title bar',
          );
          expect(toolbar.height, WorkspaceContextToolbar.height);
          expect(
            body.top - frameTop,
            DesktopPageMetrics.shellChromeHeight,
            reason:
                'page content starts right below the shell, with no gap left '
                'over from a removed AppBar',
          );
          expect(body.width, width);
        },
      );

      testWidgets(
        '$themeName @ ${width.toInt()}px: action row adds only its own height',
        (tester) async {
          await _pumpShell(
            tester,
            theme: theme,
            width: width,
            actionRow: const DesktopPageActionRow(
              children: [Icon(Icons.refresh)],
            ),
          );

          final frameTop = tester.getRect(find.byType(WindowsDesktopFrame)).top;
          final row = tester.getRect(find.byType(DesktopPageActionRow));
          final body = tester.getRect(find.byKey(_bodyKey));

          expect(row.top - frameTop, DesktopPageMetrics.shellChromeHeight);
          expect(row.height, DesktopPageMetrics.actionRowHeight);
          expect(
            body.top - frameTop,
            DesktopPageMetrics.shellChromeHeight +
                DesktopPageMetrics.actionRowHeight,
          );
          expect(row.width, width);
        },
      );
    }

    testWidgets('$themeName: shell chrome tracks the theme surface', (
      tester,
    ) async {
      await _pumpShell(tester, theme: theme, width: 1280);

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(WorkspaceContextToolbar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, theme.colorScheme.surface);
    });
  }
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required ThemeData theme,
  required double width,
  Widget? actionRow,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = WorkspaceTabController(homeTitle: 'Home');
  final hostController = WorkspaceTabHostController();

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en'),
        const Locale('zh'),
      ],
      theme: theme,
      home: WindowsDesktopFrame(
        tabStrip: WorkspaceTabStrip(
          controller: controller,
          hostController: hostController,
        ),
        contextToolbar: WorkspaceContextToolbar(
          controller: controller,
          hostController: hostController,
        ),
        child: WorkspaceTabHost(
          controller: controller,
          hostController: hostController,
          destinationBuilder: (context, destination) => DesktopPageScaffold(
            title: Text(destination.title),
            desktopActionRow: actionRow,
            body: const SizedBox.expand(key: _bodyKey),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
