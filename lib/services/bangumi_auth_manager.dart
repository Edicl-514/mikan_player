import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as rust_bangumi;
import 'package:mikan_player/src/rust/api/config.dart' as rust_config;

/// Owns the Bangumi OAuth token lifecycle: secure persistence, pushing the
/// access token into the Rust `RuntimeConfig` (which owns all Bangumi HTTP),
/// and proactive refresh before expiry.
///
/// This is deliberately separate from [UserManager], which owns the *profile*
/// (nickname / avatar). The split mirrors Bangumi's own model: the token
/// identifies the account, `/v0/me` describes it. On login the flow is:
///
///   1. WebView captures the OAuth `code` (see `BangumiOAuthPage`).
///   2. [completeLogin] exchanges it for tokens (secret stays in Rust),
///      persists them, and pushes the access token into Rust config.
///   3. The caller refreshes [UserManager] via `/v0/me`.
///
/// The redirect URI must match the one registered for the app and used to
/// build the authorization URL byte-for-byte.
class BangumiAuthManager extends ChangeNotifier {
  static final BangumiAuthManager _instance = BangumiAuthManager._internal();
  factory BangumiAuthManager() => _instance;
  BangumiAuthManager._internal();

  /// Fixed loopback redirect. Bangumi rejects `localhost`; it must be
  /// `127.0.0.1`. We never actually bind this port — the in-app WebView
  /// intercepts the navigation to this prefix and extracts the `code`.
  static const String redirectUri = 'http://127.0.0.1:6274/callback';

  static const String _storageKey = 'bangumi_oauth_token';

  /// Refresh when fewer than this many days remain before expiry, matching the
  /// doc's recommended 7-day proactive window.
  static const Duration _refreshWindow = Duration(days: 7);

  FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  int? _userId;
  int _sessionGeneration = 0;
  Future<bool>? _refreshInFlight;
  Future<void> _mutationTail = Future<void>.value();

  bool get isAuthenticated => _accessToken != null;
  int? get userId => _userId;

  /// Creates a high-entropy nonce that binds one OAuth callback to the login
  /// attempt that opened the authorization page.
  static String generateOAuthState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Overrides the secure-storage backend for tests.
  @visibleForTesting
  void debugSetStorage(FlutterSecureStorage storage) {
    _storage = storage;
  }

  /// Clears in-memory token state without touching secure storage.
  @visibleForTesting
  void debugResetForTest() {
    _sessionGeneration++;
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _userId = null;
    _refreshInFlight = null;
    _mutationTail = Future<void>.value();
  }

  /// Restore any persisted token on app start, push it into Rust config, and
  /// kick off a background refresh if it is close to expiring. Safe to call
  /// when nothing is stored — it just leaves the manager logged out.
  Future<void> init() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _accessToken = json['access_token'] as String?;
      _refreshToken = json['refresh_token'] as String?;
      final expiresAtMs = json['expires_at_ms'] as int?;
      _expiresAt = expiresAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
      _userId = json['user_id'] as int?;
    } catch (e) {
      debugPrint('Failed to load Bangumi token: $e');
      await logout();
      return;
    }

    if (_accessToken != null) {
      await rust_config.setBangumiAccessToken(
        token: _accessToken!,
        userId: _userId,
      );
      notifyListeners();
      // Best-effort proactive refresh. Authenticated consumers call
      // ensureFreshToken(), which joins this same in-flight operation.
      if (_shouldRefresh) {
        unawaited(
          _refresh().catchError((e) {
            debugPrint('Bangumi token background refresh failed: $e');
            return false;
          }),
        );
      }
    }
  }

  bool get _shouldRefresh {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    final expiresAt = _expiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt.subtract(_refreshWindow));
  }

  bool get _isExpired {
    final expiresAt = _expiresAt;
    return expiresAt != null && !DateTime.now().isBefore(expiresAt);
  }

  /// Build the OAuth authorization URL the login WebView opens. The
  /// `client_id` is fetched from Rust (it is not a secret — it appears here in
  /// plaintext). `redirect_uri` must match [redirectUri] byte-for-byte so the
  /// later token exchange validates.
  Future<String> buildAuthorizeUrl({required String state}) async {
    // Built in Rust so the authorize GET and the later token POST share the
    // exact same OAuth host (`bgm.tv`, not the `bangumi.tv` alias) and the same
    // `redirect_uri` encoding.
    final raw = await rust_bangumi.bangumiOauthAuthorizeUrl(
      redirectUri: redirectUri,
    );
    final uri = Uri.parse(raw);
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'state': state})
        .toString();
  }

  /// Exchange an authorization `code` (captured from the OAuth redirect) for a
  /// token pair, persist it, and push the access token into Rust config.
  ///
  /// Throws on failure; the caller shows the error and stays logged out.
  Future<void> completeLogin(String code) async {
    final generation = ++_sessionGeneration;
    _refreshInFlight = null;
    await _clearSession(generation: generation);
    final token = await rust_bangumi.exchangeBangumiOauthCode(
      code: code,
      redirectUri: redirectUri,
    );
    await _applyToken(token, generation: generation);
  }

  /// Refresh the access token if it is close to expiry. Returns true when a
  /// fresh token is now in place (either it did not need refreshing, or the
  /// refresh succeeded). Callers that are about to make an authenticated
  /// request can `await` this to avoid a mid-session 401.
  Future<bool> ensureFreshToken() async {
    if (_accessToken == null) return false;
    if (!_shouldRefresh) {
      if (_isExpired) {
        await _clearSession(generation: _sessionGeneration);
        return false;
      }
      return true;
    }
    // Do not send an access token after a refresh attempt failed. The token may
    // have been revoked even when its locally stored expiry is still in the
    // future; callers must retry refresh or ask the user to log in again.
    return _refresh();
  }

  Future<bool> _refresh() async {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    final generation = _sessionGeneration;
    final future = _performRefresh(refreshToken, generation);
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefresh(String refreshToken, int generation) async {
    try {
      final token = await rust_bangumi.refreshBangumiOauthToken(
        refreshToken: refreshToken,
        redirectUri: redirectUri,
      );
      if (generation != _sessionGeneration ||
          refreshToken != _refreshToken ||
          _accessToken == null) {
        return false;
      }
      return _applyToken(token, generation: generation);
    } catch (e) {
      debugPrint('Bangumi token refresh failed: $e');
      if (generation == _sessionGeneration && _isExpired) {
        await _clearSession(generation: generation);
      }
      return false;
    }
  }

  Future<bool> _applyToken(
    rust_bangumi.BangumiOAuthToken token, {
    required int generation,
  }) {
    return _serializeMutation(() async {
      if (generation != _sessionGeneration) return false;
      _accessToken = token.accessToken;
      // Bangumi omits refresh_token on some responses; keep the previous one.
      if (token.refreshToken.isNotEmpty) {
        _refreshToken = token.refreshToken;
      }
      final expiresInSeconds = token.expiresIn.toInt();
      _expiresAt = expiresInSeconds > 0
          ? DateTime.now().add(Duration(seconds: expiresInSeconds))
          : null;
      final uid = token.userId.toInt();
      _userId = uid > 0 ? uid : _userId;

      await rust_config.setBangumiAccessToken(
        token: _accessToken!,
        userId: _userId,
      );
      await _persist();
      notifyListeners();
      return true;
    });
  }

  Future<void> _persist() async {
    final json = jsonEncode({
      'access_token': _accessToken,
      'refresh_token': _refreshToken,
      'expires_at_ms': _expiresAt?.millisecondsSinceEpoch,
      'user_id': _userId,
    });
    await _storage.write(key: _storageKey, value: json);
  }

  /// Clear the token everywhere: in-memory, secure storage, and Rust config.
  /// Best-effort drains the sync queue before clearing to avoid losing pending
  /// edits, but logout proceeds even if the drain times out or fails.
  Future<void> logout() async {
    try {
      await drainBangumiSyncQueue().timeout(
        const Duration(seconds: 8),
        onTimeout: () => debugPrint('[logout] sync queue drain timeout'),
      );
    } catch (e) {
      debugPrint('[logout] sync queue drain failed: $e');
    }
    final generation = ++_sessionGeneration;
    _refreshInFlight = null;
    await _clearSession(generation: generation);
  }

  Future<void> _clearSession({required int generation}) {
    return _serializeMutation(() async {
      if (generation != _sessionGeneration) return;
      _accessToken = null;
      _refreshToken = null;
      _expiresAt = null;
      _userId = null;
      await _storage.delete(key: _storageKey);
      await rust_config.clearBangumiAccessToken();
      notifyListeners();
    });
  }

  Future<T> _serializeMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
