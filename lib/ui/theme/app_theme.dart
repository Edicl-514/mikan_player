import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const List<Color> presetColors = [
    Colors.teal,
    Color(0xFF6750A4), // Material purple
    Colors.blue,
    Colors.pink,
    Colors.orange,
    Colors.green,
    Colors.indigo,
    Colors.cyan,
  ];

  static ThemeData light(Color seedColor) => _buildTheme(
    seedColor: seedColor,
    brightness: Brightness.light,
  );

  static ThemeData dark(Color seedColor) => _buildTheme(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  static ThemeData _buildTheme({
    required Color seedColor,
    required Brightness brightness,
  }) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
      fontFamily: _platformFontFamily,
      fontFamilyFallback: _platformFontFamilyFallback,
    );
  }

  static String? get _platformFontFamily {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return 'Segoe UI';
    }
    return null;
  }

  static List<String>? get _platformFontFamilyFallback {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return const ['Microsoft YaHei UI', 'Microsoft YaHei', 'SimHei', 'SimSun'];
    }
    return null;
  }
}
