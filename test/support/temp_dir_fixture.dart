// Temporary directory fixtures.
//
// Tests that touch file-system-touching services (cache, download records,
// bangumi_data_store, image cache, ...) should write into a unique temp
// directory registered via [addTearDown] so the OS eventually reclaims the
// space and the user's `AppData` directory stays pristine even when a test
// crashes mid-way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Creates a unique empty directory under [Directory.systemTemp] and registers
/// a recursive delete on [addTearDown]. The directory is returned immediately
/// so synchronous code paths can write into it inside `setUp`.
///
/// Cleanup failures are swallowed — leftover temp files in the system temp
/// root are reclaimed by the OS and should not mask the real test failure.
///
/// [prefix] is forwarded to `Directory.systemTemp.createTempSync(prefix)` and
/// should identify the work package producing the directory (for example
/// `'mikan_dt2_'` for the `DT-2` persistence tests).
Directory createTempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup; do not turn infrastructure noise into a test
      // failure.
    }
  });
  return dir;
}

/// Returns a [File] located at `{parent.path}/{name}` without creating it.
///
/// Tests that want to write a fixture should follow this with
/// `file.writeAsBytesSync(...)` / `writeAsStringSync(...)`.
File tempFile(Directory parent, String name) => File(p.join(parent.path, name));

/// Writes [contents] to `{parent}/{name}` and returns the populated [File].
///
/// Convenience for fixture-driven tests (e.g. config JSON, offline HTML) so
/// each writer does not reinvent its own write-then-return dance.
Future<File> writeTempFixture(
  Directory parent,
  String name,
  List<int> contents,
) async {
  final file = tempFile(parent, name);
  await file.writeAsBytes(contents, flush: true);
  return file;
}
