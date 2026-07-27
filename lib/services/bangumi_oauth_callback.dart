class BangumiOAuthCallback {
  const BangumiOAuthCallback._();

  /// Returns the authorization code only when the callback has the exact
  /// registered origin/path and the state belongs to the active login attempt.
  static String? extractCode({
    required Uri candidate,
    required String redirectUri,
    required String expectedState,
  }) {
    final expected = Uri.parse(redirectUri);
    if (candidate.scheme.toLowerCase() != expected.scheme.toLowerCase() ||
        candidate.host.toLowerCase() != expected.host.toLowerCase() ||
        candidate.port != expected.port ||
        candidate.path != expected.path ||
        candidate.userInfo != expected.userInfo) {
      return null;
    }
    final state = candidate.queryParameters['state'];
    if (state == null || !_constantTimeEquals(state, expectedState)) {
      return null;
    }
    final code = candidate.queryParameters['code'];
    return code == null || code.isEmpty ? null : code;
  }

  static bool isRedirectTarget({
    required Uri candidate,
    required String redirectUri,
  }) {
    final expected = Uri.parse(redirectUri);
    return candidate.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
        candidate.host.toLowerCase() == expected.host.toLowerCase() &&
        candidate.port == expected.port &&
        candidate.path == expected.path &&
        candidate.userInfo == expected.userInfo;
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}
