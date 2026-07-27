import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/bangumi_account_mode.dart';
import 'package:mikan_player/models/user.dart';
import 'package:mikan_player/services/bangumi_auth_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as rust;
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserManager extends ChangeNotifier {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  User? _user;
  BangumiAccountMode? _accountMode;
  User? get user => _user;
  bool get isLoggedIn => _user != null;
  BangumiAccountMode? get accountMode => _accountMode;
  bool get isSyncMode =>
      _user != null && _accountMode == BangumiAccountMode.sync;

  static const String _userKey = 'bangumi_user';
  static const String _accountModeKey = 'bangumi_account_mode';

  /// When true, [init] restores the cached user but skips the background
  /// network refresh via [login]. Tests that only exercise persistence must
  /// set this so they stay offline.
  @visibleForTesting
  bool debugSkipAutoRefresh = false;

  /// Clears in-memory user state. Does not touch SharedPreferences.
  @visibleForTesting
  void debugResetForTest() {
    _user = null;
    _accountMode = null;
    debugSkipAutoRefresh = false;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        _user = User.fromJson(jsonDecode(userJson));
        _accountMode = BangumiAccountMode.fromStorage(
          prefs.getString(_accountModeKey),
        );
        // Existing installs predate the mode key. An OAuth token means the
        // account came from the new authenticated flow; otherwise preserve the
        // original public-profile behavior.
        _accountMode ??= BangumiAuthManager().isAuthenticated
            ? BangumiAccountMode.sync
            : BangumiAccountMode.public;
        await prefs.setString(_accountModeKey, _accountMode!.storageValue);
        notifyListeners();
        // Auto update in background (goes through the ECH-capable Rust client).
        // Prefer the authenticated /v0/me endpoint when an OAuth token was
        // restored; fall back to the public username lookup otherwise.
        if (!debugSkipAutoRefresh) {
          final refresh = isSyncMode
              ? (BangumiAuthManager().isAuthenticated
                    ? refreshFromMe()
                    : Future<void>.value())
              : _refreshPublicProfile(_user!.username);
          refresh.catchError((e) {
            debugPrint('Failed to auto-update user: $e');
          });
        }
      } catch (e) {
        debugPrint('Failed to load user: $e');
        await logout();
      }
    }
  }

  Future<void> login(String username) async {
    await loginPublic(username);
  }

  Future<void> loginPublic(String username) async {
    final info = await rust.fetchBangumiUserInfo(username: username);
    await _applyUserInfo(info, mode: BangumiAccountMode.public);
  }

  Future<void> _refreshPublicProfile(String username) async {
    final info = await rust.fetchBangumiUserInfo(username: username);
    await _applyUserInfo(info);
  }

  /// Refresh the cached profile from the authenticated `/v0/me` endpoint.
  ///
  /// Requires a valid OAuth access token to already be in Rust config (set by
  /// [BangumiAuthManager]); call this right after a successful OAuth login and
  /// on startup when a token was restored. Unlike [login] it does not depend on
  /// a username, so a rename never breaks it.
  Future<void> refreshFromMe() async {
    if (!await BangumiAuthManager().ensureFreshToken()) {
      throw StateError('Bangumi login expired');
    }
    final info = await rust.fetchBangumiMe();
    await _applyUserInfo(info, mode: BangumiAccountMode.sync);
  }

  Future<void> _applyUserInfo(
    rust.BangumiUserInfo info, {
    BangumiAccountMode? mode,
  }) async {
    final host = await BangumiUrlRewriter.hostFor('api');
    String? rewrite(String? url) {
      if (url == null) return null;
      return BangumiUrlRewriter.rewrite(url).replaceFirst('api.bgm.tv', host);
    }

    _user = User(
      id: info.id,
      username: info.username,
      nickname: info.nickname,
      sign: info.sign,
      url: rewrite(info.url),
      avatar: UserAvatar(
        large: rewrite(info.avatarLarge) ?? '',
        medium: rewrite(info.avatarMedium) ?? '',
        small: rewrite(info.avatarSmall) ?? '',
      ),
    );
    if (mode != null) _accountMode = mode;
    await _saveUser();
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _accountMode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_accountModeKey);
    notifyListeners();
  }

  Future<void> _saveUser() async {
    if (_user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
      if (_accountMode != null) {
        await prefs.setString(_accountModeKey, _accountMode!.storageValue);
      }
    }
  }
}
