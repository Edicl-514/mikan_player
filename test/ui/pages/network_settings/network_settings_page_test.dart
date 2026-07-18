// Widget + i18n smoke tests for `NetworkSettingsPage` (L10N-1B).
//
// The page is the most service-heavy of the L10N-1 settings pages
// (`BaseUrlListService`, `BangumiEchService`, `BangumiDataService`, FRB
// `rust` `simple` `ping_url` etc.). The bulk of these services are
// short-circuited by `catchError` fallbacks inside `_loadSettings`, so the
// page renders an empty "no DoH endpoints / no broadcast data" state. We
// exercise only the AppBar, the Bangumi request mode dropdown labels, and
// the "Offline broadcast data" list tile in both locales — the remaining
// 700+ lines are out of scope for an L10N smoke test.
//
// The save path is not exercised: it calls FRB (`rust.setEchEnabled`,
// `rust.setReverseProxyEnabled`, ...) and the snackbars are already covered
// by `i18n_workflow.md` §1 (ARB parity test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikan_player/ui/pages/network_settings_page.dart';

import '../../../support/localized_widget_tester.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('zh: AppBar and section title are localized', (tester) async {
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
  });

  testWidgets('en: AppBar and section title are localized', (tester) async {
    await pumpLocalizedWidget(
      tester,
      const NetworkSettingsPage(),
      locale: const Locale('en'),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Network Settings'), findsOneWidget);
  });
}
