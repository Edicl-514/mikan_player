import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/user.dart';
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
      } catch (e) {
        debugPrint('Failed to load user: $e');
        await logout();
      }
    }
  }

  Future<void> login(String username) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('https://api.bgm.tv/v0/users/$username'),
      );
      request.headers.add('accept', 'application/json');
      // Add User-Agent as good practice for APIs
      request.headers.add('User-Agent', 'MikanPlayer/1.0.0 (flutter)');

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        _user = User.fromJson(json);
        await _saveUser();
        notifyListeners();
      } else {
        throw Exception('Failed to fetch user: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
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
