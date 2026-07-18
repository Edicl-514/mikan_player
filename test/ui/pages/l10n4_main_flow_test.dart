// L10N-4 smoke tests for main-flow display helpers and history empty state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/index_filter_labels.dart';
import 'package:mikan_player/ui/utils/broadcast_day_tokens.dart';

import '../../support/localized_widget_tester.dart';

void main() {
  group('L10N-4 main flow helpers', () {
    test('broadcast day tokens map DateTime.weekday Mon-Sun', () {
      expect(broadcastDayTokenForWeekday(1), broadcastDayTokenMonday);
      expect(broadcastDayTokenForWeekday(7), broadcastDayTokenSunday);
      expect(broadcastDayTokensWithOther.last, broadcastDayTokenOther);
    });

    test('indexFilterLabel localizes protocol tokens in en/zh', () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final en = lookupAppLocalizations(const Locale('en'));

      expect(indexFilterLabel(zh, indexFilterKeyCategory), '分类');
      expect(indexFilterLabel(en, indexFilterKeyCategory), 'Category');
      expect(indexFilterLabel(zh, '排名'), '排名');
      expect(indexFilterLabel(en, '排名'), 'Rank');
      expect(indexFilterLabel(zh, '3月'), '3月');
      expect(indexFilterLabel(en, '3月'), '3');
      expect(indexFilterLabel(zh, '科幻'), '科幻');
      expect(indexFilterLabel(en, '科幻'), 'Sci-Fi');
      // product lexicon codes stay as-is
      expect(indexFilterLabel(en, 'TV'), 'TV');
    });

    testWidgets('history AppBar title localizes in zh/en', (tester) async {
      await pumpLocalizedWidget(
        tester,
        const HistoryPage(),
        locale: const Locale('zh'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('播放历史'), findsOneWidget);

      await pumpLocalizedWidget(
        tester,
        const HistoryPage(),
        locale: const Locale('en'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('History'), findsOneWidget);
    });
  });
}
