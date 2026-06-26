import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/user.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as rust;
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserManager extends ChangeNotifier {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  User? _user;
  User? get user => _user;
  bool get isLoggedIn => _user != null;

  static const String _userKey = 'bangumi_user';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        _user = User.fromJson(jsonDecode(userJson));
        notifyListeners();
        // Auto update in background (goes through the ECH-capable Rust client)
        login(_user!.username).catchError((e) {
          debugPrint('Failed to auto-update user: $e');
        });
      } catch (e) {
        debugPrint('Failed to load user: $e');
        await logout();
      }
    }
  }

  Future<void> login(String username) async {
    final info = await rust.fetchBangumiUserInfo(username: username);
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
    await _saveUser();
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<void> _saveUser() async {
    if (_user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    }
  }
}
