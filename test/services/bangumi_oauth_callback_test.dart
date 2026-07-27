import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_oauth_callback.dart';

void main() {
  const redirect = 'http://127.0.0.1:6274/callback';

  group('BangumiOAuthCallback.extractCode', () {
    test('accepts only the exact redirect and matching state', () {
      final code = BangumiOAuthCallback.extractCode(
        candidate: Uri.parse('$redirect?code=abc&state=nonce'),
        redirectUri: redirect,
        expectedState: 'nonce',
      );

      expect(code, 'abc');
    });

    test('rejects a callback with the wrong state', () {
      final code = BangumiOAuthCallback.extractCode(
        candidate: Uri.parse('$redirect?code=abc&state=other'),
        redirectUri: redirect,
        expectedState: 'nonce',
      );

      expect(code, isNull);
    });

    test('rejects prefix, port, host, and path lookalikes', () {
      for (final candidate in [
        'http://127.0.0.1:6274/callback-extra?code=abc&state=nonce',
        'http://127.0.0.1:6275/callback?code=abc&state=nonce',
        'http://localhost:6274/callback?code=abc&state=nonce',
        'http://127.0.0.1:6274/other?code=abc&state=nonce',
      ]) {
        expect(
          BangumiOAuthCallback.extractCode(
            candidate: Uri.parse(candidate),
            redirectUri: redirect,
            expectedState: 'nonce',
          ),
          isNull,
          reason: candidate,
        );
      }
    });

    test('rejects missing and empty authorization codes', () {
      for (final candidate in [
        '$redirect?state=nonce',
        '$redirect?code=&state=nonce',
      ]) {
        expect(
          BangumiOAuthCallback.extractCode(
            candidate: Uri.parse(candidate),
            redirectUri: redirect,
            expectedState: 'nonce',
          ),
          isNull,
        );
      }
    });
  });
}
