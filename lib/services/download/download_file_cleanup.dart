// Path-safety and file-cleanup helpers for the download subsystem.
//
// Extracted verbatim from `lib/services/download_manager.dart` (private
// helpers around the old lines 1170-1349). All functions are pure and
// take their inputs explicitly — no instance state, no globals. This keeps
// the helpers trivially unit-testable.
//
// Persisted JSON keys, public DownloadManager API, and download directory
// resolution semantics are NOT changed by this extraction.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:mikan_player/services/download/download_task.dart';

String _normalizePathForComparison(String path) {
  if (!Platform.isWindows) return path;

  // Windows accepts both separators and compares paths case-insensitively.
  // POSIX treats `\\` as an ordinary filename character, so changing it
  // there could turn a sibling such as `download\\outside` into a child.
  return path.replaceAll('\\', '/').toLowerCase();
}

/// Returns true when [path] (after normalization) is inside [downloadDir].
///
/// The comparison is path-aware: it appends [Platform.pathSeparator] to
/// [downloadDir] so a similar-prefix sibling (e.g. `/tmp/abc` vs `/tmp/abcd`)
/// is correctly rejected. On Windows the comparison is case-insensitive;
/// on POSIX it is case-sensitive.
bool isPathUnderDownloadDir(String path, {required String downloadDir}) {
  if (downloadDir.isEmpty) return false;

  final base = _normalizePathForComparison(
    Directory(downloadDir).absolute.path,
  );
  final target = _normalizePathForComparison(File(path).absolute.path);

  const separator = '/';
  final baseWithSeparator = base.endsWith(separator) ? base : '$base$separator';
  return target == base || target.startsWith(baseWithSeparator);
}

/// Returns true when [path] is platform-recognized as absolute.
///
/// On POSIX a leading `/` is absolute; on Windows we additionally accept
/// `\<path>` and `<drive>:\` / `<drive>:/` forms.
bool isAbsolutePath(String path) {
  if (path.startsWith('/') || path.startsWith(r'\')) return true;
  return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path);
}

/// Join [relativePath] onto [downloadDir] safely.
///
/// Returns null when:
/// - [downloadDir] is empty.
/// - [relativePath] is empty or absolute.
/// - Any path part is `.`, `..`, or contains a `:` (drive / alternate stream).
///
/// Otherwise returns the joined absolute path, but only if the result still
/// resolves under [downloadDir]. This is the last guard against accidental
/// escape via odd input (e.g. embedded `..` introduced after splitting).
String? resolveDownloadChildPath(
  String relativePath, {
  required String downloadDir,
}) {
  if (downloadDir.isEmpty) return null;
  if (relativePath.isEmpty || isAbsolutePath(relativePath)) {
    return null;
  }

  final parts = relativePath
      .split(RegExp(r'[\\/]'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return null;
  if (parts.any((part) => part == '.' || part == '..' || part.contains(':'))) {
    return null;
  }

  var path = Directory(downloadDir).absolute.path;
  for (final part in parts) {
    path = '$path${Platform.pathSeparator}$part';
  }
  return isPathUnderDownloadDir(path, downloadDir: downloadDir) ? path : null;
}

/// True when the extension on [path] looks like a video container we
/// recognize for downloaded file discovery.
bool isLikelyVideoPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  final ext = path.substring(dot + 1).toLowerCase();
  const videoExts = {
    'mkv',
    'mp4',
    'avi',
    'mov',
    'wmv',
    'flv',
    'm4v',
    'ts',
    'webm',
    'mpg',
    'mpeg',
    'm2ts',
    '3gp',
    'vob',
  };
  return videoExts.contains(ext);
}

/// Returns the trailing name component of [path].
///
/// Accepts both POSIX (`/`) and Windows (`\`) separators. If no separator
/// is present, the whole input is returned.
String basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash < 0 ? normalized : normalized.substring(slash + 1);
}

/// Lower-cases [value] and strips any character that is not an ASCII
/// alphanumeric or in the CJK / kana / CJK-extension ranges. The result is
/// used as a fuzzy match key for downloaded file names.
String matchKey(String value) {
  return value.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u9fff]+'),
    '',
  );
}

/// Walk upward from [file]'s parent and delete empty directories as long as
/// they remain inside [downloadDir]. The root itself is never deleted, and
/// the walk stops as soon as a directory is not empty.
void deleteEmptyParentsUnderDownloadDir(
  File file, {
  required String downloadDir,
}) {
  if (downloadDir.isEmpty) return;

  var dir = file.parent;
  final root = _normalizePathForComparison(
    Directory(downloadDir).absolute.path,
  );
  while (isPathUnderDownloadDir(dir.path, downloadDir: downloadDir) &&
      _normalizePathForComparison(dir.absolute.path) != root) {
    try {
      if (!dir.existsSync() || dir.listSync().isNotEmpty) return;
      final parent = dir.parent;
      dir.deleteSync();
      dir = parent;
    } catch (_) {
      return;
    }
  }
}

/// Find a single downloaded video file inside [downloadDir] that matches
/// [task] (size match first, then a fuzzy basename match on [task.name]).
///
/// Returns the unique candidate, or null when there is none or the choice
/// is ambiguous. Logs and swallows scan errors (returns null) so callers do
/// not need their own try/catch.
File? findUniqueDownloadedFileCandidate(
  DownloadTask task, {
  required String downloadDir,
}) {
  if (downloadDir.isEmpty) return null;
  final totalSize = task.totalSize.toInt();
  if (totalSize <= 0) return null;

  final root = Directory(downloadDir);
  if (!root.existsSync()) return null;

  final candidates = <File>[];
  try {
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!isPathUnderDownloadDir(entity.path, downloadDir: downloadDir)) {
        continue;
      }
      if (entity.path.toLowerCase().endsWith('.resume')) continue;
      if (!isLikelyVideoPath(entity.path)) continue;
      if (entity.lengthSync() == totalSize) {
        candidates.add(entity);
      }
    }
  } catch (e) {
    debugPrint('[DownloadFileCleanup] Error scanning downloaded files: $e');
    return null;
  }

  if (candidates.length == 1) return candidates.single;

  final taskKey = matchKey(task.name);
  if (taskKey.isEmpty) return null;
  final named = candidates
      .where((file) => matchKey(basename(file.path)).contains(taskKey))
      .toList(growable: false);
  return named.length == 1 ? named.single : null;
}
