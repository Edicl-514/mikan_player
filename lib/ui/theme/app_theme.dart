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

  static ThemeData light({
    required Color seedColor,
    required bool useMaterial3Color,
    required bool pureBackground,
  }) => _buildTheme(
    seedColor: seedColor,
    brightness: Brightness.light,
    useMaterial3Color: useMaterial3Color,
    pureBackground: pureBackground,
  );

  static ThemeData dark({
    required Color seedColor,
    required bool useMaterial3Color,
    required bool pureBackground,
  }) => _buildTheme(
    seedColor: seedColor,
    brightness: Brightness.dark,
    useMaterial3Color: useMaterial3Color,
    pureBackground: pureBackground,
  );

  static ThemeData _buildTheme({
    required Color seedColor,
    required Brightness brightness,
    required bool useMaterial3Color,
    required bool pureBackground,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    ColorScheme finalColorScheme = useMaterial3Color
        ? colorScheme
        : colorScheme.copyWith(primary: seedColor);

    if (pureBackground) {
      final pureBgColor = brightness == Brightness.light
          ? Colors.white
          : Colors.black;
      final pureSurfaceColor = brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF121212);
      finalColorScheme = finalColorScheme.copyWith(
        surface: pureSurfaceColor,
        surfaceContainerLowest: pureBgColor,
        surfaceContainerLow: brightness == Brightness.light
            ? const Color(0xFFF7F7F7)
            : const Color(0xFF1C1C1C),
        surfaceContainer: brightness == Brightness.light
            ? const Color(0xFFF0F0F0)
            : const Color(0xFF242424),
        surfaceContainerHigh: brightness == Brightness.light
            ? const Color(0xFFE8E8E8)
            : const Color(0xFF2C2C2C),
        surfaceContainerHighest: brightness == Brightness.light
            ? const Color(0xFFE0E0E0)
            : const Color(0xFF333333),
      );
    }

    return ThemeData(
      colorScheme: finalColorScheme,
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
      return const [
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'SimHei',
        'SimSun',
      ];
    }
    return null;
  }
}
