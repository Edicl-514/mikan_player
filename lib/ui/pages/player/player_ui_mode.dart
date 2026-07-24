import 'package:flutter/foundation.dart';

/// Presentation mode for the player page.
///
/// Layout density and input platform are intentionally represented by one
/// explicit value so a narrow Windows window cannot opt into touch-only UI.
enum PlayerUiMode { mobile, desktopCompact, desktopWide }

extension PlayerUiModeProperties on PlayerUiMode {
  bool get isMobile => this == PlayerUiMode.mobile;
  bool get isDesktop => !isMobile;
  bool get usesWideLayout => this == PlayerUiMode.desktopWide;
}

class PlayerUiModeResolver {
  const PlayerUiModeResolver._();

  static PlayerUiMode resolve({
    required double width,
    TargetPlatform? platform,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final isDesktopPlatform = switch (target) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
    if (!isDesktopPlatform) return PlayerUiMode.mobile;
    return width > 900 ? PlayerUiMode.desktopWide : PlayerUiMode.desktopCompact;
  }
}
