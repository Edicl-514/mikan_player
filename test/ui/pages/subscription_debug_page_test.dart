import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/subscription_debug_page.dart';


import '../../support/localized_widget_tester.dart';

void main() {
  testWidgets('SubscriptionDebugPage renders cleanly without build-phase errors', (
    tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      const SubscriptionDebugPage(),
    );

    expect(find.byType(SubscriptionDebugPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
