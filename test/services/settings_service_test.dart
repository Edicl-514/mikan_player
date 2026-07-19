// DT-2A: SettingsService persistence + notification contract.
//
// Covers defaults, legacy key loading, unknown values falling back safely,
// setters notifying once, and concurrent writes settling on last-write-wins.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shared_prefs_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late int notifyCount;
  late VoidCallback listener;

  setUp(() async {
    await resetSharedPreferences();
    settings = SettingsService()..debugResetForTest();
    notifyCount = 0;
    listener = () => notifyCount++;
    settings.addListener(listener);
  });

  tearDown(() {
    settings
      ..removeListener(listener)
      ..debugResetForTest();
  });

  group('defaults before init', () {
    test('expose system theme, teal seed, M3 on, pure bg off, null locale', () {
      expect(settings.locale, isNull);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.seedColor.toARGB32(), Colors.teal.toARGB32());
      expect(settings.useMaterial3Color, isTrue);
      expect(settings.pureBackground, isFalse);
    });
  });

  group('init loads persisted values', () {
    test('reads known locale / theme / color / flags', () async {
      await resetSharedPreferences(<String, Object>{
        'app_locale': 'en',
        'theme_mode': 'dark',
        'seed_color': Colors.purple.toARGB32(),
        'use_material3_color': false,
        'pure_background': true,
      });
      settings.debugResetForTest();

      await settings.init();

      expect(settings.locale, const Locale('en'));
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.seedColor.toARGB32(), Colors.purple.toARGB32());
      expect(settings.useMaterial3Color, isFalse);
      expect(settings.pureBackground, isTrue);
    });

    test('unknown theme_mode falls back to system', () async {
      await resetSharedPreferences(<String, Object>{'theme_mode': 'sepia'});
      settings.debugResetForTest();
      await settings.init();
      expect(settings.themeMode, ThemeMode.system);
    });

    test('unknown locale code is ignored (stays null)', () async {
      await resetSharedPreferences(<String, Object>{'app_locale': 'fr'});
      settings.debugResetForTest();
      await settings.init();
      expect(settings.locale, isNull);
    });

    test('missing keys keep compiled defaults', () async {
      await resetSharedPreferences();
      settings.debugResetForTest();
      await settings.init();
      expect(settings.locale, isNull);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.seedColor.toARGB32(), Colors.teal.toARGB32());
      expect(settings.useMaterial3Color, isTrue);
      expect(settings.pureBackground, isFalse);
    });
  });

  group('setters', () {
    test('setLocale persists languageCode and notifies once', () async {
      await settings.setLocale(const Locale('zh'));
      expect(settings.locale, const Locale('zh'));
      expect(notifyCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'zh');
    });

    test('setLocale(null) removes the preference key', () async {
      await settings.setLocale(const Locale('en'));
      notifyCount = 0;
      await settings.setLocale(null);
      expect(settings.locale, isNull);
      expect(notifyCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('app_locale'), isFalse);
    });

    test('identical setLocale is a no-op', () async {
      await settings.setLocale(const Locale('en'));
      notifyCount = 0;
      await settings.setLocale(const Locale('en'));
      expect(notifyCount, 0);
    });

    test('setThemeMode writes mode.name and notifies', () async {
      await settings.setThemeMode(ThemeMode.light);
      expect(settings.themeMode, ThemeMode.light);
      expect(notifyCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('identical setThemeMode is a no-op', () async {
      await settings.setThemeMode(ThemeMode.dark);
      notifyCount = 0;
      await settings.setThemeMode(ThemeMode.dark);
      expect(notifyCount, 0);
    });

    test('setSeedColor persists ARGB32 and notifies', () async {
      const color = Color(0xFF112233);
      await settings.setSeedColor(color);
      expect(settings.seedColor.toARGB32(), color.toARGB32());
      expect(notifyCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('seed_color'), color.toARGB32());
    });

    test('setUseMaterial3Color / setPureBackground round-trip', () async {
      await settings.setUseMaterial3Color(false);
      await settings.setPureBackground(true);
      expect(settings.useMaterial3Color, isFalse);
      expect(settings.pureBackground, isTrue);
      expect(notifyCount, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_material3_color'), isFalse);
      expect(prefs.getBool('pure_background'), isTrue);
    });
  });

  group('concurrency', () {
    test('overlapping setThemeMode settles on the last write', () async {
      await Future.wait(<Future<void>>[
        settings.setThemeMode(ThemeMode.light),
        settings.setThemeMode(ThemeMode.dark),
        settings.setThemeMode(ThemeMode.system),
      ]);
      expect(settings.themeMode, ThemeMode.system);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'system');
    });
  });

  group('re-init after external seed', () {
    test('init reloads values written outside the service', () async {
      await settings.setLocale(const Locale('zh'));
      // Simulate another process / old version writing prefs directly.
      await seedSharedPreferences(<String, Object>{'app_locale': 'en'});
      // Service keeps its in-memory value until re-init.
      expect(settings.locale, const Locale('zh'));

      settings.debugResetForTest();
      await settings.init();
      expect(settings.locale, const Locale('en'));
    });
  });
}
