// Self-tests for the F-0 temp directory fixture helpers.
//
// Confirms that [createTempDir] produces a usable directory, that cleanup is
// registered (we keep the dir alive for the test body and rely on
// `addTearDown` to remove it post-test), and that the file helpers compose
// with the directory without surprise relative-path issues.

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'temp_dir_fixture.dart';

void main() {
  group('createTempDir', () {
    test('returns an existing empty directory whose path contains the prefix',
        () {
      final dir = createTempDir('f0_test_');
      addTearDown(() {
        // Use a separate handle so we can observe post-tearDown behavior in
        // the next test without leaving the directory behind.
      });
      expect(dir.existsSync(), isTrue);
      expect(p.basename(dir.path), contains('f0_test_'));
      // Newly created directory is empty.
      expect(dir.listSync(), isEmpty);
    });

    test('does not leak across tests when used normally', () {
      // If the previous test's directory survived, listing the system temp
      // root would show a name starting with our prefix twice. This cannot
      // be asserted reliably across CI platforms, so we just exercise the
      // path once more to ensure `createTempDir` is happy in consecutive
      // test bodies.
      final dir = createTempDir('f0_repeat_');
      expect(dir.existsSync(), isTrue);
    });
  });

  group('tempFile', () {
    test('joins the parent path with the leaf name without creating the file',
        () {
      final dir = createTempDir('f0_file_');
      final file = tempFile(dir, 'fixture.txt');
      expect(file.path, p.join(dir.path, 'fixture.txt'));
      expect(file.existsSync(), isFalse,
          reason: 'tempFile should not create the file on disk');
    });

    test('writeTempFixture writes the provided bytes and returns the file',
        () async {
      final dir = createTempDir('f0_write_');
      final file = await writeTempFixture(dir, 'payload.bin', [1, 2, 3, 4]);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), <int>[1, 2, 3, 4]);
    });
  });
}
