// Tests for path-safety and file-cleanup helpers extracted from
// `lib/services/download_manager.dart`.
//
// Every test that touches the filesystem uses a per-test temp directory
// created with `Directory.systemTemp.createTemp('mikan_dl_cleanup_')` and
// never deletes anything outside that root. Cleanup is performed in
// tearDown so leftover files do not accumulate if a test fails.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/download_file_cleanup.dart';
import 'package:mikan_player/services/download/download_task.dart';

void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('mikan_dl_cleanup_');
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('isPathUnderDownloadDir', () {
    test('returns false when downloadDir is empty', () {
      expect(isPathUnderDownloadDir('/some/path', downloadDir: ''), isFalse);
    });

    test('returns true for the exact download dir path', () {
      final dir = Directory('${tempRoot.path}/dl');
      dir.createSync(recursive: true);
      expect(isPathUnderDownloadDir(dir.path, downloadDir: dir.path), isTrue);
    });

    test('returns true for a child of download dir', () {
      final dir = Directory('${tempRoot.path}/dl');
      final child = Directory('${dir.path}/sub')..createSync(recursive: true);
      final nested = File('${child.path}/file.mkv')..createSync();
      expect(
        isPathUnderDownloadDir(nested.path, downloadDir: dir.path),
        isTrue,
      );
    });

    test(
      'returns false for a similar-prefix sibling (no startWith prefix bug)',
      () {
        final base = Directory('${tempRoot.path}/abc')..createSync();
        final sibling = Directory('${tempRoot.path}/abcd')..createSync();
        final siblingFile = File('${sibling.path}/file.mkv')..createSync();
        expect(
          isPathUnderDownloadDir(siblingFile.path, downloadDir: base.path),
          isFalse,
          reason: 'must not match via plain startsWith on the path string',
        );
      },
    );

    test('returns false for an unrelated path outside the download dir', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      final outside = Directory('${tempRoot.path}/other')..createSync();
      final outsideFile = File('${outside.path}/file.mkv')..createSync();
      expect(
        isPathUnderDownloadDir(outsideFile.path, downloadDir: base.path),
        isFalse,
      );
    });

    test('handles a trailing separator on the download dir', () {
      final dir = Directory('${tempRoot.path}/dl');
      final child = File('${dir.path}/file.mkv')..createSync(recursive: true);
      expect(
        isPathUnderDownloadDir(
          child.path,
          downloadDir: '${dir.path}${Platform.pathSeparator}',
        ),
        isTrue,
      );
    });

    test('POSIX behavior is case-sensitive', () {
      // On POSIX, /tmp/ABC is not the same dir as /tmp/abc.
      if (Platform.isWindows) {
        return;
      }
      final base = Directory('${tempRoot.path}/lower')..createSync();
      final upperFile = File('${base.path.toUpperCase()}/file.mkv')
        ..createSync(recursive: true);
      expect(
        isPathUnderDownloadDir(upperFile.path, downloadDir: base.path),
        isFalse,
      );
    });
  });

  group('isAbsolutePath', () {
    test('recognizes leading slash as absolute', () {
      expect(isAbsolutePath('/foo/bar'), isTrue);
    });

    test('recognizes leading backslash as absolute', () {
      expect(isAbsolutePath(r'\foo\bar'), isTrue);
    });

    test('recognizes Windows drive letter with backslash as absolute', () {
      expect(isAbsolutePath(r'C:\foo\bar'), isTrue);
    });

    test('recognizes Windows drive letter with forward slash as absolute', () {
      expect(isAbsolutePath('C:/foo/bar'), isTrue);
    });

    test('rejects relative paths', () {
      expect(isAbsolutePath('foo/bar'), isFalse);
      expect(isAbsolutePath('./foo'), isFalse);
      expect(isAbsolutePath('../foo'), isFalse);
      expect(isAbsolutePath(''), isFalse);
    });
  });

  group('resolveDownloadChildPath', () {
    test('returns null when downloadDir is empty', () {
      expect(resolveDownloadChildPath('a/b', downloadDir: ''), isNull);
    });

    test('returns null for empty relative path', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      expect(resolveDownloadChildPath('', downloadDir: base.path), isNull);
    });

    test('returns null for absolute relative path', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      expect(
        resolveDownloadChildPath('/etc/passwd', downloadDir: base.path),
        isNull,
      );
      expect(
        resolveDownloadChildPath(r'C:\Windows', downloadDir: base.path),
        isNull,
      );
    });

    test('returns null when any part is `..`', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      expect(
        resolveDownloadChildPath('a/../b', downloadDir: base.path),
        isNull,
      );
    });

    test('returns null when any part is `.`', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      expect(resolveDownloadChildPath('./a/b', downloadDir: base.path), isNull);
    });

    test('returns null when any part contains `:`', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      expect(resolveDownloadChildPath('a/C:b', downloadDir: base.path), isNull);
    });

    test('joins valid parts with the platform separator', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      final result = resolveDownloadChildPath(
        'a/b/file.mkv',
        downloadDir: base.path,
      );
      expect(result, isNotNull);
      final expected =
          '${base.absolute.path}${Platform.pathSeparator}a${Platform.pathSeparator}b${Platform.pathSeparator}file.mkv';
      expect(result, expected);
    });

    test('returns null when normalized path escapes the base', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      // The split already rejects `..`, so the only escape is the
      // final containment check. Build a path manually and call the
      // helper to make sure it still works.
      final escaped =
          '${base.absolute.path}${Platform.pathSeparator}..${Platform.pathSeparator}outside';
      // `..` as a part is rejected before the join, so resolve must be null.
      expect(
        resolveDownloadChildPath('a/../../outside', downloadDir: base.path),
        isNull,
      );
      // Sanity: passing the already-escaped absolute path returns null.
      expect(resolveDownloadChildPath(escaped, downloadDir: base.path), isNull);
    });

    test('accepts both `/` and `\\` as input separators', () {
      final base = Directory('${tempRoot.path}/dl')..createSync();
      final viaSlash = resolveDownloadChildPath(
        'a/b/file.mkv',
        downloadDir: base.path,
      );
      final viaBackslash = resolveDownloadChildPath(
        r'a\b\file.mkv',
        downloadDir: base.path,
      );
      expect(viaSlash, isNotNull);
      expect(viaBackslash, isNotNull);
      expect(viaBackslash, viaSlash);
    });
  });

  group('deleteEmptyParentsUnderDownloadDir', () {
    test('removes nested empty parents up to the root, but not the root', () {
      final root = Directory('${tempRoot.path}/dl')..createSync();
      final a = Directory('${root.path}/a')..createSync();
      final b = Directory('${a.path}/b')..createSync();
      final c = Directory('${b.path}/c')..createSync();
      final file = File('${c.path}/movie.mkv')..createSync();

      file.deleteSync();
      deleteEmptyParentsUnderDownloadDir(file, downloadDir: root.path);

      expect(c.existsSync(), isFalse);
      expect(b.existsSync(), isFalse);
      // The walk deletes every empty directory on the chain from the file's
      // parent up to (but not including) the download root. A direct child of
      // the root that becomes empty is also pruned — this matches the original
      // behavior the helper had while it lived in `download_manager.dart`
      // (callers relied on the empty-folder bubble climbing all the way up).
      expect(a.existsSync(), isFalse);
      // The root itself must never be deleted.
      expect(root.existsSync(), isTrue);
    });

    test('stops at the first non-empty parent', () {
      final root = Directory('${tempRoot.path}/dl')..createSync();
      final a = Directory('${root.path}/a')..createSync();
      final b = Directory('${a.path}/b')..createSync();
      final c = Directory('${b.path}/c')..createSync();
      final file = File('${c.path}/movie.mkv')..createSync();
      // Leave a sibling file in b so b is non-empty.
      final leftover = File('${b.path}/leftover.txt')..createSync();

      file.deleteSync();
      deleteEmptyParentsUnderDownloadDir(file, downloadDir: root.path);

      expect(c.existsSync(), isFalse, reason: 'c was empty, must be deleted');
      expect(b.existsSync(), isTrue, reason: 'b is non-empty, must remain');
      expect(leftover.existsSync(), isTrue);
      expect(a.existsSync(), isTrue);
    });

    test('does not touch directories outside the downloadDir root', () {
      final root = Directory('${tempRoot.path}/dl')..createSync();
      final outside = Directory('${tempRoot.path}/other')..createSync();
      final outsideFile = File('${outside.path}/nested/movie.mkv')
        ..createSync(recursive: true);
      outsideFile.deleteSync();
      expect(outside.existsSync(), isTrue);

      // Calling the cleanup for a file outside the root must be a no-op
      // because the containment check fails on the first iteration.
      deleteEmptyParentsUnderDownloadDir(outsideFile, downloadDir: root.path);
      expect(outside.existsSync(), isTrue);
    });
  });

  group('matchKey', () {
    test('lowercases the input', () {
      expect(matchKey('HelloWorld'), 'helloworld');
    });

    test('strips non-alphanumeric ASCII characters', () {
      expect(matchKey('Hello, World! 123'), 'helloworld123');
    });

    test('preserves CJK characters', () {
      // 進撃の巨人 (Shingeki no Kyojin) — all in the CJK / kana ranges.
      expect(matchKey('進撃の巨人'), '進撃の巨人');
    });

    test('preserves hiragana and katakana', () {
      expect(matchKey('ひらがなカタカナ'), 'ひらがなカタカナ');
    });

    test('strips spaces, dashes, and dots together', () {
      expect(matchKey('[Group] Show - 01.mkv'), 'groupshow01mkv');
    });

    test('is deterministic for equal inputs', () {
      expect(matchKey('Episode 02'), matchKey('Episode 02'));
    });
  });

  group('basename', () {
    test('returns the trailing component for a POSIX path', () {
      expect(basename('/foo/bar/baz.mkv'), 'baz.mkv');
    });

    test('returns the trailing component for a Windows path', () {
      expect(basename(r'C:\foo\bar\baz.mkv'), 'baz.mkv');
    });

    test('returns the input when no separator is present', () {
      expect(basename('baz.mkv'), 'baz.mkv');
    });

    test('handles a single separator', () {
      expect(basename('/foo'), 'foo');
      expect(basename(r'\foo'), 'foo');
    });
  });

  group('isLikelyVideoPath', () {
    test('returns true for common video extensions', () {
      expect(isLikelyVideoPath('x.mkv'), isTrue);
      expect(isLikelyVideoPath('y.mp4'), isTrue);
      expect(isLikelyVideoPath('z.ts'), isTrue);
      expect(isLikelyVideoPath('w.webm'), isTrue);
    });

    test('returns true case-insensitively', () {
      expect(isLikelyVideoPath('UPPER.MKV'), isTrue);
    });

    test('returns false for non-video extensions', () {
      expect(isLikelyVideoPath('a.txt'), isFalse);
    });

    test('returns false when there is no extension', () {
      expect(isLikelyVideoPath('noext'), isFalse);
    });

    test('returns false for dotfiles without a video extension', () {
      expect(isLikelyVideoPath('.gitignore'), isFalse);
    });
  });

  group('findUniqueDownloadedFileCandidate', () {
    DownloadTask buildTask({
      required String name,
      required BigInt totalSize,
      String? downloadDir,
    }) {
      return DownloadTask(
        id: 'task-id',
        name: name,
        magnet: 'magnet:?xt=urn:btih:DEAD',
        startTime: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
        taskType: DownloadTaskType.bt,
        status: DownloadTaskStatus.completed,
        downloaded: totalSize,
        totalSize: totalSize,
        downloadDir: downloadDir,
      );
    }

    void writeFile(Directory dir, String name, int size) {
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      file.createSync(recursive: true);
      file.writeAsBytesSync(List<int>.filled(size, 0));
    }

    test('returns the single file whose size matches totalSize', () {
      final dl = Directory('${tempRoot.path}/dl')..createSync();
      const size = 1234;
      writeFile(dl, 'movie.mkv', size);

      final task = buildTask(
        name: 'movie',
        totalSize: BigInt.from(size),
        downloadDir: dl.path,
      );

      final result = findUniqueDownloadedFileCandidate(
        task,
        downloadDir: dl.path,
      );
      expect(result, isNotNull);
      expect(
        result!.path,
        '${dl.absolute.path}${Platform.pathSeparator}movie.mkv',
      );
    });

    test('returns null when zero files match the size', () {
      final dl = Directory('${tempRoot.path}/dl')..createSync();
      writeFile(dl, 'movie.mkv', 1);
      final task = buildTask(
        name: 'movie',
        totalSize: BigInt.from(9999),
        downloadDir: dl.path,
      );
      expect(
        findUniqueDownloadedFileCandidate(task, downloadDir: dl.path),
        isNull,
      );
    });

    test('disambiguates same-size files using a fuzzy basename match', () {
      final dl = Directory('${tempRoot.path}/dl')..createSync();
      const size = 4096;
      writeFile(dl, 'wrong.mkv', size);
      writeFile(dl, 'show_01.mkv', size);

      final task = buildTask(
        name: 'Show 01',
        totalSize: BigInt.from(size),
        downloadDir: dl.path,
      );

      final result = findUniqueDownloadedFileCandidate(
        task,
        downloadDir: dl.path,
      );
      expect(result, isNotNull);
      expect(
        result!.path,
        '${dl.absolute.path}${Platform.pathSeparator}show_01.mkv',
      );
    });

    test(
      'returns null when two same-size files exist and basename is ambiguous',
      () {
        final dl = Directory('${tempRoot.path}/dl')..createSync();
        const size = 4096;
        writeFile(dl, 'aaa.mkv', size);
        writeFile(dl, 'bbb.mkv', size);

        final task = buildTask(
          name: 'nope',
          totalSize: BigInt.from(size),
          downloadDir: dl.path,
        );

        expect(
          findUniqueDownloadedFileCandidate(task, downloadDir: dl.path),
          isNull,
        );
      },
    );

    test('returns null when totalSize is zero', () {
      final dl = Directory('${tempRoot.path}/dl')..createSync();
      writeFile(dl, 'movie.mkv', 100);
      final task = buildTask(
        name: 'movie',
        totalSize: BigInt.zero,
        downloadDir: dl.path,
      );
      expect(
        findUniqueDownloadedFileCandidate(task, downloadDir: dl.path),
        isNull,
      );
    });

    test('ignores non-video files and .resume sidecars', () {
      final dl = Directory('${tempRoot.path}/dl')..createSync();
      const size = 1024;
      writeFile(dl, 'movie.txt', size);
      writeFile(dl, 'movie.mkv.resume', size);
      writeFile(dl, 'movie.mkv', size);
      final task = buildTask(
        name: 'movie',
        totalSize: BigInt.from(size),
        downloadDir: dl.path,
      );
      final result = findUniqueDownloadedFileCandidate(
        task,
        downloadDir: dl.path,
      );
      expect(result, isNotNull);
      expect(result!.path.endsWith('movie.mkv'), isTrue);
    });
  });
}
