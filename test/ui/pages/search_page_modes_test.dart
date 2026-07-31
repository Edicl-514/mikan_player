import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localized_widget_tester.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BangumiRequestModeService.debugResetForTest();
  });

  tearDown(BangumiRequestModeService.debugResetForTest);

  testWidgets('character and person search modes are available', (
    tester,
  ) async {
    await pumpLocalizedWidget(tester, const SearchPage(autofocus: false));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.text_fields));
    await tester.pumpAndSettle();
    expect(find.text('角色搜索'), findsOneWidget);
    expect(find.text('人物搜索'), findsOneWidget);

    await tester.tap(find.text('角色搜索'));
    await tester.pump();
    expect(find.text('输入角色名进行搜索'), findsWidgets);
    expect(find.byIcon(Icons.sort), findsNothing);
  });
}
