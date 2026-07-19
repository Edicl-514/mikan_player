import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  Locale? _locale;
  Locale? get locale => _locale;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Color _seedColor = Colors.teal;
  Color get seedColor => _seedColor;

  bool _useMaterial3Color = true;
  bool get useMaterial3Color => _useMaterial3Color;

  bool _pureBackground = false;
  bool get pureBackground => _pureBackground;

  static const String _localeKey = 'app_locale';
  static const String _themeModeKey = 'theme_mode';
  static const String _seedColorKey = 'seed_color';
  static const String _useMaterial3ColorKey = 'use_material3_color';
  static const String _pureBackgroundKey = 'pure_background';

  /// Restores in-memory defaults without touching SharedPreferences.
  ///
  /// Tests must still call [resetSharedPreferences] (or equivalent) so the
  /// next [init] does not re-read leftover keys from a previous case.
  @visibleForTesting
  void debugResetForTest() {
    _locale = null;
    _themeMode = ThemeMode.system;
    _seedColor = Colors.teal;
    _useMaterial3Color = true;
    _pureBackground = false;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final localeCode = prefs.getString(_localeKey);
    if (localeCode != null) {
      if (localeCode == 'zh') {
        _locale = const Locale('zh');
      } else if (localeCode == 'en') {
        _locale = const Locale('en');
      }
    }

    final themeModeStr = prefs.getString(_themeModeKey);
    if (themeModeStr != null) {
      _themeMode = switch (themeModeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }

    final colorValue = prefs.getInt(_seedColorKey);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }

    final useM3 = prefs.getBool(_useMaterial3ColorKey);
    if (useM3 != null) {
      _useMaterial3Color = useM3;
    }

    final pureBg = prefs.getBool(_pureBackgroundKey);
    if (pureBg != null) {
      _pureBackground = pureBg;
    }
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    if (_seedColor == color) return;
    _seedColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> setUseMaterial3Color(bool value) async {
    if (_useMaterial3Color == value) return;
    _useMaterial3Color = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useMaterial3ColorKey, value);
    notifyListeners();
  }

  Future<void> setPureBackground(bool value) async {
    if (_pureBackground == value) return;
    _pureBackground = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pureBackgroundKey, value);
    notifyListeners();
  }
}
