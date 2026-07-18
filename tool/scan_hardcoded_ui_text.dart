import 'dart:io';

/// Reports string literals that are likely to be user-visible UI text.
///
/// This is intentionally a candidate scanner rather than an automatic fixer.
/// It uses a small lexer so comments are ignored and multiline strings keep
/// correct locations, but it does not build a Dart AST. Review every finding
/// before moving it to ARB: source-data markers, regular expressions, protocol
/// values, and third-party names may legitimately remain hard-coded.
///
/// Usage:
///   dart run tool/scan_hardcoded_ui_text.dart
///   dart run tool/scan_hardcoded_ui_text.dart lib/ui lib/main.dart
///   dart run tool/scan_hardcoded_ui_text.dart --fail-on-findings
///
/// Suppress an intentional literal with a reason on the same or previous line:
///   // i18n-ignore: upstream Bangumi role token
///   const mainRoleToken = '主角';
///
/// Suppress an entire file only when it contains no application UI:
///   // i18n-scan-ignore-file: generated or protocol-only file
void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    stdout.write(_usage);
    return;
  }

  final files = _collectDartFiles(options.paths);
  final findings = <_Finding>[];
  for (final file in files) {
    findings.addAll(_scanFile(file));
  }

  findings.sort((a, b) {
    final pathOrder = a.path.compareTo(b.path);
    if (pathOrder != 0) return pathOrder;
    final lineOrder = a.line.compareTo(b.line);
    if (lineOrder != 0) return lineOrder;
    return a.column.compareTo(b.column);
  });

  final highCount = findings.where((item) => item.confidence == 'high').length;
  final mediumCount = findings.length - highCount;
  final shown = findings.take(options.maxResults).toList(growable: false);

  for (final finding in shown) {
    stdout.writeln(
      '${finding.confidence.toUpperCase().padRight(6)} '
      '${finding.path}:${finding.line}:${finding.column} '
      '[${finding.reason}] "${finding.preview}"',
    );
  }

  if (shown.length < findings.length) {
    stdout.writeln(
      '... ${findings.length - shown.length} more finding(s) omitted; '
      'raise --max-results to show them.',
    );
  }

  stdout.writeln();
  stdout.writeln(
    'Hard-coded UI text candidates: ${findings.length} '
    '(high: $highCount, medium: $mediumCount) in ${files.length} Dart file(s).',
  );
  stdout.writeln(
    'Review candidates manually. Use "// i18n-ignore: <reason>" only for '
    'intentional non-UI literals.',
  );

  if (options.failOnFindings && findings.isNotEmpty) {
    exitCode = 1;
  }
}

const _usage = '''
Find likely hard-coded user-visible strings in Dart UI code.

Usage:
  dart run tool/scan_hardcoded_ui_text.dart [options] [path ...]

Paths default to "lib/ui" and "lib/main.dart".

Options:
  --fail-on-findings   Exit with code 1 when any candidate is found.
  --max-results=N      Limit printed findings (default: 500).
  -h, --help           Show this help.
''';

const _defaultPaths = ['lib/ui', 'lib/main.dart'];

const _ignoredPathParts = <String>[
  '/.dart_tool/',
  '/build/',
  '/lib/gen/',
  '/third_party/',
];

const _ignoredFileSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
];

final _cjkPattern = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');
final _visibleCharacterPattern = RegExp(r'[A-Za-z0-9\u0080-\uffff]');

final _directTextPattern = RegExp(
  r'\b(?:Text|SelectableText)\s*\(\s*(?:const\s+)?$',
);

final _textSpanPattern = RegExp(r'\bTextSpan\s*\([\s\S]{0,400}\btext\s*:\s*$');

final _namedUiArgumentPattern = RegExp(
  r'\b(tooltip|label|hintText|helperText|errorText|semanticLabel|barrierLabel|'
  r'message|title|subtitle|helper|placeholder|emptyText)\s*:\s*$',
);

class _Options {
  const _Options({
    required this.paths,
    required this.failOnFindings,
    required this.maxResults,
    required this.showHelp,
  });

  final List<String> paths;
  final bool failOnFindings;
  final int maxResults;
  final bool showHelp;

  factory _Options.parse(List<String> arguments) {
    final paths = <String>[];
    var failOnFindings = false;
    var maxResults = 500;
    var showHelp = false;

    for (final argument in arguments) {
      if (argument == '--fail-on-findings') {
        failOnFindings = true;
      } else if (argument == '-h' || argument == '--help') {
        showHelp = true;
      } else if (argument.startsWith('--max-results=')) {
        final value = int.tryParse(argument.substring('--max-results='.length));
        if (value == null || value < 1) {
          stderr.writeln('Invalid --max-results value: $argument');
          exitCode = 2;
          return const _Options(
            paths: _defaultPaths,
            failOnFindings: false,
            maxResults: 500,
            showHelp: true,
          );
        }
        maxResults = value;
      } else if (argument.startsWith('-')) {
        stderr.writeln('Unknown option: $argument');
        exitCode = 2;
        return const _Options(
          paths: _defaultPaths,
          failOnFindings: false,
          maxResults: 500,
          showHelp: true,
        );
      } else {
        paths.add(argument);
      }
    }

    return _Options(
      paths: paths.isEmpty ? _defaultPaths : paths,
      failOnFindings: failOnFindings,
      maxResults: maxResults,
      showHelp: showHelp,
    );
  }
}

class _StringLiteral {
  const _StringLiteral({
    required this.start,
    required this.contentStart,
    required this.contentEnd,
    required this.isRaw,
  });

  final int start;
  final int contentStart;
  final int contentEnd;
  final bool isRaw;
}

class _Finding {
  const _Finding({
    required this.path,
    required this.line,
    required this.column,
    required this.confidence,
    required this.reason,
    required this.preview,
  });

  final String path;
  final int line;
  final int column;
  final String confidence;
  final String reason;
  final String preview;
}

List<File> _collectDartFiles(List<String> paths) {
  final files = <File>[];
  final seen = <String>{};

  for (final path in paths) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      stderr.writeln('Path does not exist: $path');
      continue;
    }

    if (type == FileSystemEntityType.file) {
      final file = File(path);
      if (_shouldScan(file.path) && seen.add(file.absolute.path)) {
        files.add(file);
      }
      continue;
    }

    if (type == FileSystemEntityType.directory) {
      for (final entity in Directory(path).listSync(recursive: true)) {
        if (entity is File &&
            _shouldScan(entity.path) &&
            seen.add(entity.absolute.path)) {
          files.add(entity);
        }
      }
    }
  }

  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

bool _shouldScan(String path) {
  final normalized = '/${path.replaceAll('\\', '/').toLowerCase()}';
  if (!normalized.endsWith('.dart')) return false;
  if (_ignoredPathParts.any(normalized.contains)) return false;
  if (_ignoredFileSuffixes.any(normalized.endsWith)) return false;
  return true;
}

List<_Finding> _scanFile(File file) {
  final source = file.readAsStringSync();
  if (source.contains('i18n-scan-ignore-file')) return const [];

  final lineStarts = _lineStarts(source);
  final lines = source.split('\n');
  final findings = <_Finding>[];

  for (final literal in _stringLiterals(source)) {
    final rawContent = source.substring(
      literal.contentStart,
      literal.contentEnd,
    );
    final literalText = _withoutInterpolation(rawContent);
    if (!_visibleCharacterPattern.hasMatch(literalText)) continue;

    final location = _locationForOffset(lineStarts, literal.start);
    if (_isIgnored(lines, location.$1)) continue;

    final contextStart = literal.start > 500 ? literal.start - 500 : 0;
    final context = source.substring(contextStart, literal.start);
    final classification = _classifyLiteral(
      context: context,
      content: rawContent,
      literalText: literalText,
      isRaw: literal.isRaw,
    );
    if (classification == null) continue;

    findings.add(
      _Finding(
        path: _relativePath(file.path),
        line: location.$1,
        column: location.$2,
        confidence: classification.$1,
        reason: classification.$2,
        preview: _preview(rawContent),
      ),
    );
  }

  return findings;
}

(String, String)? _classifyLiteral({
  required String context,
  required String content,
  required String literalText,
  required bool isRaw,
}) {
  if (_looksTechnical(content, isRaw: isRaw)) return null;

  if (_directTextPattern.hasMatch(context)) {
    return const ('high', 'Text/SelectableText');
  }
  if (_textSpanPattern.hasMatch(context)) {
    return const ('high', 'TextSpan.text');
  }

  final namedMatch = _namedUiArgumentPattern.firstMatch(context);
  if (namedMatch != null) {
    return ('high', '${namedMatch.group(1)} argument');
  }

  if (_cjkPattern.hasMatch(literalText)) {
    return const ('medium', 'CJK literal in UI source');
  }
  return null;
}

String _withoutInterpolation(String content) {
  return content
      .replaceAll(RegExp(r'\$\{[^{}]*\}'), '')
      .replaceAll(RegExp(r'\$[A-Za-z_]\w*'), '');
}

bool _looksTechnical(String content, {required bool isRaw}) {
  final trimmed = content.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return true;
  }
  if (trimmed.startsWith('assets/') || trimmed.startsWith('package:')) {
    return true;
  }
  if (isRaw &&
      (trimmed.contains(r'\s') ||
          trimmed.contains(r'\d') ||
          trimmed.contains('(?<') ||
          trimmed.contains('.*'))) {
    return true;
  }
  return false;
}

Iterable<_StringLiteral> _stringLiterals(
  String source, [
  int baseOffset = 0,
]) sync* {
  var index = 0;
  while (index < source.length) {
    if (source.startsWith('//', index)) {
      final newline = source.indexOf('\n', index + 2);
      index = newline == -1 ? source.length : newline + 1;
      continue;
    }

    if (source.startsWith('/*', index)) {
      var depth = 1;
      index += 2;
      while (index < source.length && depth > 0) {
        if (source.startsWith('/*', index)) {
          depth++;
          index += 2;
        } else if (source.startsWith('*/', index)) {
          depth--;
          index += 2;
        } else {
          index++;
        }
      }
      continue;
    }

    var isRaw = false;
    var quoteIndex = index;
    final current = source[index];
    if ((current == 'r' || current == 'R') &&
        index + 1 < source.length &&
        (source[index + 1] == "'" || source[index + 1] == '"') &&
        (index == 0 || !_isIdentifierCharacter(source[index - 1]))) {
      isRaw = true;
      quoteIndex = index + 1;
    }

    final quote = source[quoteIndex];
    if (quote != "'" && quote != '"') {
      index++;
      continue;
    }

    final triple =
        quoteIndex + 2 < source.length &&
        source[quoteIndex + 1] == quote &&
        source[quoteIndex + 2] == quote;
    final delimiterLength = triple ? 3 : 1;
    final contentStart = quoteIndex + delimiterLength;
    var cursor = contentStart;
    var terminated = false;

    while (cursor < source.length) {
      if (!isRaw &&
          source[cursor] == r'$' &&
          cursor + 1 < source.length &&
          source[cursor + 1] == '{') {
        final interpolationEnd = _interpolationEnd(source, cursor + 1);
        if (interpolationEnd != null) {
          final expressionStart = cursor + 2;
          yield* _stringLiterals(
            source.substring(expressionStart, interpolationEnd),
            baseOffset + expressionStart,
          );
          cursor = interpolationEnd + 1;
          continue;
        }
      }

      if (triple) {
        if (cursor + 2 < source.length &&
            source[cursor] == quote &&
            source[cursor + 1] == quote &&
            source[cursor + 2] == quote) {
          terminated = true;
          break;
        }
      } else if (source[cursor] == quote) {
        terminated = true;
        break;
      }

      if (!isRaw && source[cursor] == '\\' && cursor + 1 < source.length) {
        cursor += 2;
      } else {
        cursor++;
      }
    }

    if (!terminated) {
      index = contentStart;
      continue;
    }

    yield _StringLiteral(
      start: baseOffset + index,
      contentStart: baseOffset + contentStart,
      contentEnd: baseOffset + cursor,
      isRaw: isRaw,
    );
    index = cursor + delimiterLength;
  }
}

int? _interpolationEnd(String source, int openBrace) {
  var depth = 1;
  var cursor = openBrace + 1;

  while (cursor < source.length) {
    if (source.startsWith('//', cursor)) {
      final newline = source.indexOf('\n', cursor + 2);
      cursor = newline == -1 ? source.length : newline + 1;
      continue;
    }
    if (source.startsWith('/*', cursor)) {
      var commentDepth = 1;
      cursor += 2;
      while (cursor < source.length && commentDepth > 0) {
        if (source.startsWith('/*', cursor)) {
          commentDepth++;
          cursor += 2;
        } else if (source.startsWith('*/', cursor)) {
          commentDepth--;
          cursor += 2;
        } else {
          cursor++;
        }
      }
      continue;
    }

    final stringEnd = _stringLiteralEnd(source, cursor);
    if (stringEnd != null) {
      cursor = stringEnd;
      continue;
    }

    if (source[cursor] == '{') {
      depth++;
    } else if (source[cursor] == '}') {
      depth--;
      if (depth == 0) return cursor;
    }
    cursor++;
  }

  return null;
}

int? _stringLiteralEnd(String source, int index) {
  var isRaw = false;
  var quoteIndex = index;
  if ((source[index] == 'r' || source[index] == 'R') &&
      index + 1 < source.length &&
      (source[index + 1] == "'" || source[index + 1] == '"') &&
      (index == 0 || !_isIdentifierCharacter(source[index - 1]))) {
    isRaw = true;
    quoteIndex = index + 1;
  }

  final quote = source[quoteIndex];
  if (quote != "'" && quote != '"') return null;

  final triple =
      quoteIndex + 2 < source.length &&
      source[quoteIndex + 1] == quote &&
      source[quoteIndex + 2] == quote;
  final delimiterLength = triple ? 3 : 1;
  var cursor = quoteIndex + delimiterLength;
  while (cursor < source.length) {
    if (triple) {
      if (cursor + 2 < source.length &&
          source[cursor] == quote &&
          source[cursor + 1] == quote &&
          source[cursor + 2] == quote) {
        return cursor + delimiterLength;
      }
    } else if (source[cursor] == quote) {
      return cursor + delimiterLength;
    }

    if (!isRaw && source[cursor] == '\\' && cursor + 1 < source.length) {
      cursor += 2;
    } else {
      cursor++;
    }
  }
  return null;
}

bool _isIdentifierCharacter(String character) {
  final codeUnit = character.codeUnitAt(0);
  return (codeUnit >= 48 && codeUnit <= 57) ||
      (codeUnit >= 65 && codeUnit <= 90) ||
      (codeUnit >= 97 && codeUnit <= 122) ||
      character == '_' ||
      character == r'$';
}

List<int> _lineStarts(String source) {
  final starts = <int>[0];
  for (var index = 0; index < source.length; index++) {
    if (source.codeUnitAt(index) == 10) starts.add(index + 1);
  }
  return starts;
}

(int, int) _locationForOffset(List<int> lineStarts, int offset) {
  var low = 0;
  var high = lineStarts.length - 1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    if (lineStarts[middle] <= offset) {
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }
  final lineIndex = high < 0 ? 0 : high;
  return (lineIndex + 1, offset - lineStarts[lineIndex] + 1);
}

bool _isIgnored(List<String> lines, int oneBasedLine) {
  final index = oneBasedLine - 1;
  if (index >= 0 &&
      index < lines.length &&
      lines[index].contains('i18n-ignore')) {
    return true;
  }
  return index > 0 && lines[index - 1].contains('i18n-ignore');
}

String _relativePath(String path) {
  final absolutePath = File(path).absolute.path;
  final root = Directory.current.absolute.path;
  if (absolutePath.toLowerCase().startsWith(root.toLowerCase())) {
    var relative = absolutePath.substring(root.length);
    while (relative.startsWith('\\') || relative.startsWith('/')) {
      relative = relative.substring(1);
    }
    return relative.replaceAll('\\', '/');
  }
  return path.replaceAll('\\', '/');
}

String _preview(String content) {
  final singleLine = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  final escaped = singleLine.replaceAll('"', r'\"');
  if (escaped.length <= 100) return escaped;
  return '${escaped.substring(0, 97)}...';
}
