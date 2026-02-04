import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class for managing app directories
/// Ensures unified data storage across debug/release builds on Windows
class AppDirectories {
  /// Get unified app data directory for all build modes (debug/release/profile)
  /// This prevents data separation between different build modes on Windows
  static Future<Directory> getUnifiedAppDataDirectory() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      // On Windows, use LOCALAPPDATA/mikan_player to avoid debug/release separation
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        final unifiedDir = Directory('$localAppData\\mikan_player');
        if (!await unifiedDir.exists()) {
          await unifiedDir.create(recursive: true);
        }
        return unifiedDir;
      }
    }
    // Fallback to default path_provider behavior on other platforms
    return await getApplicationSupportDirectory();
  }
}
