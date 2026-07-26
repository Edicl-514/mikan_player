// Widget + i18n smoke tests for `NetworkSettingsPage` (L10N-1B).
//
// The page is the most service-heavy of the L10N-1 settings pages
// (`BaseUrlListService`, `BangumiEchService`, `BangumiDataService`, FRB
// `rust` `simple` `ping_url` etc.). The bulk of these services are
// short-circuited by `catchError` fallbacks inside `_loadSettings`, so the
// page renders an empty "no DoH endpoints / no broadcast data" state. These
// tests cover the AppBar plus every L10N-1 string added to the request-mode
// dropdown and offline broadcast-data tile in both locales.
//
// The save path is not exercised: it calls FRB (`rust.setEchEnabled`,
// `rust.setReverseProxyEnabled`, ...) and the snackbars are already covered
// by `i18n_workflow.md` §1 (ARB parity test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikan_player/src/rust/api/crawler.dart'
    show BangumiDataCacheStatus;
import 'package:mikan_player/ui/pages/network_settings_page.dart';

import '../../../support/localized_widget_tester.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('zh: request mode and offline broadcast data are localized', (
    tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      const NetworkSettingsPage(),
      locale: const Locale('zh'),
    );
    // Wait for the SharedPreferences / FRB future chain to finish. The page
    // starts in `_isLoading = true` and shows a `CircularProgressIndicator`
    // until `_loadSettings` resolves. The service calls are all guarded by
    // `catchError` so a missing FRB bridge turns into empty defaults and
    // the page eventually renders the body. We settle aggressively.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('网络设置'), findsOneWidget);
    expect(find.text('Bangumi 请求方式'), findsWidgets);

    await tester.tap(find.text('混合（推荐）').first);
    await tester.pumpAndSettle();
    expect(find.text('旧版'), findsOneWidget);
    expect(find.text('混合（推荐）'), findsWidgets);
    expect(find.text('新版'), findsOneWidget);
    // Dismiss the menu without changing the selection. Selecting an item now
    // triggers auto-save, which calls the uninitialized FRB bridge; this test
    // only checks that the options are localized (per the file header).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('离线放送数据'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(find.text('离线放送数据'), findsOneWidget);
    final l10n = localizedOf(tester);
    expect(bangumiDataStatusSubtitle(null, l10n), '加载中…');
    expect(
      bangumiDataStatusSubtitle(
        BangumiDataCacheStatus(
          cached: true,
          fileSize: BigInt.from(1024 * 1024),
          version: '1',
          lastFailedSecs: BigInt.from(30),
        ),
        l10n,
      ),
      '已缓存 1.0 MB · v1 · 1分钟前同步失败',
    );
  });

  testWidgets('en: request mode and offline broadcast data are localized', (
    tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      const NetworkSettingsPage(),
      locale: const Locale('en'),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Network Settings'), findsOneWidget);
    expect(find.text('Bangumi request mode'), findsWidgets);

    await tester.tap(find.text('Hybrid (recommended)').first);
    await tester.pumpAndSettle();
    expect(find.text('Legacy'), findsOneWidget);
    expect(find.text('Hybrid (recommended)'), findsWidgets);
    expect(find.text('Modern'), findsOneWidget);
    // Dismiss the menu without changing the selection. Selecting an item now
    // triggers auto-save, which calls the uninitialized FRB bridge; this test
    // only checks that the options are localized (per the file header).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Offline broadcast data'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(find.text('Offline broadcast data'), findsOneWidget);
    final l10n = localizedOf(tester);
    expect(bangumiDataStatusSubtitle(null, l10n), 'Loading…');
    expect(
      bangumiDataStatusSubtitle(
        BangumiDataCacheStatus(
          cached: true,
          fileSize: BigInt.from(1024 * 1024),
          version: '1',
          lastFailedSecs: BigInt.from(30),
        ),
        l10n,
      ),
      'Cached 1.0 MB · v1 · Last sync failed 1 min ago',
    );
  });
}
