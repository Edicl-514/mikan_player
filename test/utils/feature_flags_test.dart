import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/utils/feature_flags.dart';

void main() {
  test('subscription debug mode follows the compile-time environment', () {
    const expected = bool.fromEnvironment(
      'ENABLE_SUBSCRIPTION_DEBUG',
      defaultValue: false,
    );
    expect(enableSubscriptionDebug, expected);
  });
}
