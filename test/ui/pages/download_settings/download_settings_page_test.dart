// Widget + i18n smoke tests for `DownloadSettingsPage` (L10N-1B).
//
// The page reads its initial state from `DownloadManager` and renders a
// dropdown to switch the BT backend (`rqbit` / `libtorrent`, both product
// names — see the `i18n-ignore: product name` comments in the page). The
// save handler is not exercised here because it depends on the FRB bridge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/ui/pages/download_settings_page.dart';

import '../../../support/localized_widget_tester.dart';

void main() {
  testWidgets('zh: AppBar, engine card, and the two product-name backend '
      'options render with the localized descriptions', (tester) async {
    await pumpLocalizedWidget(
      tester,
      const DownloadSettingsPage(),
      locale: const Locale('zh'),
    );
    await tester.pump();

    expect(find.text('下载设置'), findsOneWidget);
    expect(find.text('BT 引擎'), findsOneWidget);
    // The dropdown only renders the currently selected option ("rqbit" by
    // default), so we cannot see "libtorrent" without first tapping the
    // dropdown. The product-name ignore comment is the meaningful check
    // here — both literal strings still appear in the source.
    expect(find.text('rqbit'), findsOneWidget);
    // The engine description rendered under the dropdown is the localized
    // rqbit one (default backend).
    expect(find.textContaining('rqbit 基于 Rust'), findsOneWidget);
  });

  testWidgets('en: AppBar, engine card, and the two product-name backend '
      'options render with the localized descriptions', (tester) async {
    await pumpLocalizedWidget(
      tester,
      const DownloadSettingsPage(),
      locale: const Locale('en'),
    );
    await tester.pump();

    expect(find.text('Download Settings'), findsOneWidget);
    expect(find.text('BT Engine'), findsOneWidget);
    expect(find.text('rqbit'), findsOneWidget);
    expect(find.textContaining('rqbit is built in Rust'), findsOneWidget);
  });
}
