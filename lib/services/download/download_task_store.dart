// Persistence layer for download tasks.
//
// Extracted from `lib/services/download_manager.dart` (Phase 3 revised
// immediate order step 2) so the raw SharedPreferences string read/decode
// and encode/write can be tested in isolation. `DownloadManager` keeps all
// domain logic (validation, status transitions, the resume queue, and the
// cold-start throttle). Only raw encode/decode/string-IO lives here.
//
// Persisted JSON shape and the storage key are FROZEN by the refactor
// plan's Stop Conditions: changing the key would orphan every existing
// user's saved tasks, and changing `DownloadTask`'s JSON keys would break
// on-disk records.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:mikan_player/services/download/download_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key under which the list of [DownloadTask]s is persisted.
///
/// FROZEN by the refactor plan's Stop Conditions: never rename. The literal
/// lives in one place (this file); `DownloadManager` imports and reuses this
/// const so the key is never hardcoded twice.
const String btTasksStorageKey = 'bt_download_tasks_v1';

/// Minimal key-value backing store injected so [DownloadTaskStore] can be
/// tested without [SharedPreferences] / platform channels.
abstract interface class DownloadTaskKeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

/// Production [DownloadTaskKeyValueStore] backed by [SharedPreferences].
///
/// Delegates each call to the shared `SharedPreferences.getInstance()`
/// singleton exactly the way `DownloadManager` did before extraction, so
/// production wiring is unchanged.
class SharedPreferencesDownloadTaskKeyValueStore
    implements DownloadTaskKeyValueStore {
  @override
  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

/// Reads and writes the persisted list of [DownloadTask]s as a JSON string.
///
/// The store performs ONLY raw string IO + JSON encode/decode. It does NO
/// domain logic: no validation, no status transitions, no resume queue.
/// `DownloadManager` keeps all of that and runs it over the list returned by
/// [loadTasks].
///
/// Contract:
/// - [loadTasks] never throws. If the persisted JSON is missing, empty, or
///   undecodable it logs the error (debugPrint) and returns an empty list,
///   matching the manager's pre-extraction swallow behaviour for a corrupt
///   persisted blob.
/// - [saveTasks] never throws. Encode/write errors are logged (debugPrint)
///   and swallowed so a failed persist does not crash the caller, matching
///   the manager's pre-extraction save behaviour.
class DownloadTaskStore {
  DownloadTaskStore({
    required DownloadTaskKeyValueStore prefs,
    String storageKey = btTasksStorageKey,
  }) : _prefs = prefs,
       _storageKey = storageKey;

  final DownloadTaskKeyValueStore _prefs;
  final String _storageKey;

  /// Load all persisted tasks.
  ///
  /// Returns the decoded [DownloadTask] list, or an empty list when the
  /// stored JSON is missing/empty/corrupt. Never throws.
  Future<List<DownloadTask>> loadTasks() async {
    try {
      final jsonStr = await _prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return const [];
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return [
        for (final json in jsonList)
          DownloadTask.fromJson(json as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('[DownloadTaskStore] Error loading tasks: $e');
      return const [];
    }
  }

  /// Persist [tasks] as a JSON array string under the storage key.
  ///
  /// An empty [tasks] is written as the literal string `"[]"` (not absence,
  /// not null) so a subsequent [DownloadTaskKeyValueStore.getString] returns
  /// `"[]"`. Encode/write errors are logged and swallowed so the caller
  /// never crashes on a failed persist.
  Future<void> saveTasks(Iterable<DownloadTask> tasks) async {
    try {
      final jsonList = tasks.map((t) => t.toJson()).toList();
      await _prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[DownloadTaskStore] Error saving tasks: $e');
    }
  }
}
