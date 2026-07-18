// Widget + i18n smoke tests for `SearchSettingsPage` (L10N-1B).
//
// The page is a simple `ListView` of three text fields (search/WebView
// concurrency and WebView launch interval) and two switches. The
// `SharedPreferences`-backed `_loadSettings` runs in `initState` and is
// covered by the test infrastructure in `test/support/shared_prefs_support.dart`.
// `_saveSettings` calls the FRB `setMaxConcurrentSearches`; these tests do
// not tap the save button, since wiring the FRB is out of scope for an
// L10N-* smoke test (per `i18n_workflow.md` §1).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikan_player/ui/pages/search_settings_page.dart';

import '../../../support/localized_widget_tester.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('zh: renders localized section headers and field labels',
      (tester) async {
    await pumpLocalizedWidget(
      tester,
      const SearchSettingsPage(),
      locale: const Locale('zh'),
    );
    // Allow the initState async load to complete.
    await tester.pumpAndSettle();

    expect(find.text('搜索设置'), findsOneWidget);
    expect(find.text('最大并行搜索源数量'), findsOneWidget);
    expect(find.text('WebView Scraper设置 (仅针对Dynamic Webview源)'),
        findsOneWidget);
    expect(find.text('最大WebView并发数量'), findsOneWidget);
    expect(find.text('WebView启动间隔 (毫秒)'), findsOneWidget);
    expect(find.text('自动搜索在线源'), findsOneWidget);
    expect(find.text('播放后取消低优先级源提取'), findsOneWidget);
  });

  testWidgets('en: renders localized section headers and field labels',
      (tester) async {
    await pumpLocalizedWidget(
      tester,
      const SearchSettingsPage(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search settings'), findsOneWidget);
    expect(find.text('Max parallel search sources'), findsOneWidget);
    expect(
      find.text('WebView Scraper settings (Dynamic WebView sources only)'),
      findsOneWidget,
    );
    expect(find.text('Max concurrent WebViews'), findsOneWidget);
    expect(find.text('WebView launch interval (ms)'), findsOneWidget);
    expect(find.text('Auto search online sources'), findsOneWidget);
    expect(find.text('Cancel low-priority source extraction after playback'),
        findsOneWidget);
  });
}
