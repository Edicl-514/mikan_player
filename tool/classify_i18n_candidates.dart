// L10N-0 candidate classifier. Reads the textual output of
// `tool/scan_hardcoded_ui_text.dart` (or an existing `l10n-audit-v1` JSON
// audit) and labels
// every candidate with `localize` | `keep` | `protocol` plus a machine-readable
// rationale, producing:
//
//   * a JSON file at `--output=<path>` with per-candidate rows, and
//   * a markdown rollup at `--summary=<path>` grouping findings by file for
//     human review during subsequent L10N-1..5 packages.
//
// The classifier is heuristic — it never rewrites sources. Reviews of the
// produced audit file are the actual L10N decision; this tool only seeds the
// first pass so a human can spend their judgment on borderline rows rather
// than on the obvious `localize` ones.
//
// Plan reference: §4 L10N-0 item 1 taxonomy (localize / keep / protocol).

import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    stdout.write(_usage);
    return;
  }

  final findings = _parseInput(_resolveInput(options.inputPath));

  final classified = <_Row>[];
  for (final f in findings) {
    final (label, reason) = _classify(f);
    classified.add(_Row(finding: f, label: label, reason: reason));
  }

  final highRows = classified
      .where((r) => r.finding.confidence == 'HIGH')
      .toList();
  final mediumRows = classified
      .where((r) => r.finding.confidence == 'MEDIUM')
      .toList();

  // Write the JSON audit.
  final json = _toJson(classified);
  File(options.outputPath).writeAsStringSync(jsonEncode(json));

  // Write the markdown summary for human review.
  final summary = _toMarkdown(highRows, mediumRows);
  File(options.summaryPath).writeAsStringSync(summary);

  stdout.writeln(
    'Processed ${classified.length} candidates '
    '(${highRows.length} high, ${mediumRows.length} medium). '
    'Output: ${options.outputPath}',
  );
  stdout.writeln(
    'Summary: ${options.summaryPath} '
    '(audited files: ${_uniqueFiles(classified).length})',
  );
  final byLabel = <String, int>{};
  for (final r in classified) {
    byLabel[r.label] = (byLabel[r.label] ?? 0) + 1;
  }
  stdout.writeln(
    'By label: ${byLabel.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
  );
}

const _usage = '''
L10N-0 candidate classifier.

Usage:
  dart run tool/classify_i18n_candidates.dart --input=<file> --output=<file> --summary=<file>

--input=<path>     Path to scanner stdout (text) or an existing
                   `l10n-audit-v1` JSON audit; defaults to invoking
                   `dart run tool/scan_hardcoded_ui_text.dart --max-results=10000`.
--output=<path>    Destination JSON audit. Defaults to
                   `docs/i18n_classification_baseline.json`.
--summary=<path>   Destination markdown rollup. Defaults to
                   `docs/i18n_classification_baseline.md`.
-h, --help         Show this help.
''';

class _Options {
  _Options({
    required this.inputPath,
    required this.outputPath,
    required this.summaryPath,
    required this.showHelp,
  });

  final String? inputPath;
  final String outputPath;
  final String summaryPath;
  final bool showHelp;

  factory _Options.parse(List<String> args) {
    var inputPath = const String.fromEnvironment('L10N_INPUT');
    var outputPath = 'docs/i18n_classification_baseline.json';
    var summaryPath = 'docs/i18n_classification_baseline.md';
    var showHelp = false;

    for (final arg in args) {
      if (arg == '-h' || arg == '--help') {
        showHelp = true;
      } else if (arg.startsWith('--input=')) {
        inputPath = arg.substring('--input='.length);
      } else if (arg.startsWith('--output=')) {
        outputPath = arg.substring('--output='.length);
      } else if (arg.startsWith('--summary=')) {
        summaryPath = arg.substring('--summary='.length);
      }
    }
    return _Options(
      inputPath: inputPath.isEmpty ? null : inputPath,
      outputPath: outputPath,
      summaryPath: summaryPath,
      showHelp: showHelp,
    );
  }
}

class _Finding {
  const _Finding({
    required this.confidence,
    required this.path,
    required this.line,
    required this.column,
    required this.reason,
    required this.literal,
  });

  final String confidence;
  final String path;
  final int line;
  final int column;
  final String reason;
  final String literal;
}

class _Row {
  const _Row({
    required this.finding,
    required this.label,
    required this.reason,
  });

  final _Finding finding;
  final String label;
  final String reason;
}

RegExp _linePattern = RegExp(
  r'^(HIGH|MEDIUM)\s+([^:]+):(\d+):(\d+)\s+\[([^\]]+)\]\s+"(.*)"$',
);

_Finding? _parseLine(String line) {
  final match = _linePattern.firstMatch(line);
  if (match == null) return null;
  return _Finding(
    confidence: match.group(1)!,
    path: match.group(2)!,
    line: int.parse(match.group(3)!),
    column: int.parse(match.group(4)!),
    reason: match.group(5)!,
    literal: _unescape(match.group(6)!),
  );
}

List<_Finding> _parseInput(String input) {
  if (input.trimLeft().startsWith('{')) {
    return _parseAuditJson(input);
  }

  final findings = <_Finding>[];
  for (final line in input.split('\n')) {
    if (!line.startsWith('HIGH') && !line.startsWith('MEDIUM')) continue;
    final finding = _parseLine(line);
    if (finding == null) {
      throw FormatException('Could not parse scanner finding: $line');
    }
    findings.add(finding);
  }
  return findings;
}

List<_Finding> _parseAuditJson(String input) {
  final decoded = jsonDecode(input);
  if (decoded is! Map<String, Object?> ||
      decoded['schema'] != 'l10n-audit-v1') {
    throw const FormatException(
      'Expected an l10n-audit-v1 JSON object when --input points to JSON.',
    );
  }

  final perFile = decoded['per_file'];
  if (perFile is! List<Object?>) {
    throw const FormatException('l10n-audit-v1 is missing a per_file list.');
  }

  final findings = <_Finding>[];
  for (final file in perFile) {
    if (file is! Map<String, Object?>) {
      throw const FormatException('Each per_file entry must be a JSON object.');
    }
    final path = file['path'];
    final rows = file['rows'];
    if (path is! String || rows is! List<Object?>) {
      throw const FormatException(
        'Each per_file entry needs a string path and a rows list.',
      );
    }
    for (final row in rows) {
      if (row is! Map<String, Object?>) {
        throw const FormatException('Each audit row must be a JSON object.');
      }
      final line = row['line'];
      final column = row['column'];
      final confidence = row['confidence'];
      final reason = row['reason'];
      final literal = row['literal'];
      if (line is! int ||
          column is! int ||
          confidence is! String ||
          reason is! String ||
          literal is! String ||
          (confidence != 'HIGH' && confidence != 'MEDIUM')) {
        throw const FormatException(
          'Audit rows require line, column, confidence, reason, and literal.',
        );
      }
      findings.add(
        _Finding(
          confidence: confidence,
          path: path,
          line: line,
          column: column,
          reason: reason,
          literal: literal,
        ),
      );
    }
  }
  return findings;
}

String _unescape(String raw) {
  // The scanner escapes double quotes with `\\"`. We do not bother with
  // Unicode escapes (the scanner prints Unicode verbatim) so a backslash
  // substitution is enough.
  return raw.replaceAll(r'\"', '"');
}

// Heuristic classification. The order matters: earlier matches win — protocol
// signals are checked first since some brand terms also appear in URL/JSON
// contexts (which would otherwise be misfiled as `keep`).
(String, String) _classify(_Finding f) {
  final literal = f.literal;

  // Rule 0: SCANNER already filters `_looksTechnical` — if a candidate
  // survives that filter it is *most likely* UI text. We retain only a small
  // patch-up for the few cases that survive the rough technical filter but
  // are still protocol-ish (e.g. Bangumi role tokens, local role tags).
  //
  // --- protocol -----------------------------------------------------------------
  final protocolHit = _protocolPatterns.firstWhere(
    (rule) => rule.$1.hasMatch(literal),
    orElse: () => (RegExp(''), ''),
  );
  if (protocolHit.$2.isNotEmpty) {
    return ('protocol', protocolHit.$2);
  }

  // --- keep -------------------------------------------------------------------
  final keepHit = _keepPatterns.firstWhere(
    (rule) => rule.$1.hasMatch(literal),
    orElse: () => (RegExp(''), ''),
  );
  if (keepHit.$2.isNotEmpty) {
    return ('keep', keepHit.$2);
  }

  // --- localize ----------------------------------------------------------------
  // Default for high-confidence UI candidates. Medium candidates need a file
  // hint; controller/helper files commonly hold protocol-ish tokens even if
  // they happen to be CJK labels readable to humans.
  if (f.confidence == 'HIGH') {
    return ('localize', 'high-confidence UI surface (scanner ${f.reason})');
  }

  // Medium heuristic: protocol/keep patterns above already filtered the
  // clear non-UI tokens (role tags, brand names, acronyms). Everything else
  // with CJK characters is most likely a user-facing string — including
  // format strings like `${year}年` and `全 $n 话` which belong in ARB or
  // an ICU formatter, not in the protocol bucket. The line-level review in
  // L10N-1..5 is the place to apply `i18n-ignore` if a specific medium
  // candidate turns out to be a source-data marker after all.
  return (
    'localize',
    'medium CJK literal in UI source — likely user-facing; confirm by reading '
        'the line and apply `i18n-ignore: <reason>` if not.',
  );
}

// Protocol patterns: literals that match a token used for matching /
// comparison / parsing rather than for display.
final List<(RegExp, String)> _protocolPatterns = <(RegExp, String)>[
  (
    RegExp(r'^主角$'),
    'Bangumi character role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^配角$'),
    'Bangumi character role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^客串$'),
    'Bangumi character role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^原作$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^导演$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^系列构成$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^动画制作$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^音乐$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^脚本$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^作画监督$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^分镜$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^演出$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^制片人$'),
    'Bangumi staff role token — used for matching, do not localize',
  ),
  (
    RegExp(r'^\[.*原文\]$'),
    'Bangumi-style summary marker square-brackets — these survive as visual decoration only when displayed',
  ),
  (
    RegExp(r'^[A-Z]{2,6}$'),
    'All-caps acronym (e.g. EP/CV/BT) — industry-domain term, not UI prose',
  ),
  (
    RegExp(r'\s\((?:简繁|日语|国语|粤语|英配|中配|台配|港配)\)$'),
    'audio-track tag used for matching by resource parsers — should be the protocol token-postfix rather than UI',
  ),
];

// Keep patterns: brand/site names, common abbreviations, low-sensitivity
// labels that should not enter ARB. These rules fire ONLY when the literal
// is exactly the brand/term — literals that merely *contain* a brand word
// (e.g. "Bangumi 请求方式") still need translation and stay `localize`.
final List<(RegExp, String)> _keepPatterns = <(RegExp, String)>[
  (RegExp(r'^Mikan$'), 'product/brand name'),
  (RegExp(r'^Mikan Player$'), 'product/brand name'),
  (RegExp(r'^Bangumi$'), 'third-party brand name'),
  (RegExp(r'^bgm\.tv$'), 'host brand'),
  (RegExp(r'^DMHY$'), 'source-site brand'),
  (RegExp(r'^mikanani'), 'source-site brand inside protocol literal'),
  (
    RegExp(r'^episod(e|es)\b'),
    'EP-style English episode label — product lexicon',
  ),
  (RegExp(r'^EP\s'), 'EP-style English episode label — product lexicon'),
  (RegExp(r'^H\.264$'), 'codec string'),
  (RegExp(r'^H\.265$'), 'codec string'),
  (RegExp(r'^1080p$'), 'video stream resolution string'),
  (RegExp(r'^720p$'), 'video stream resolution string'),
  (RegExp(r'^4K$'), 'resolution string'),
  (RegExp(r'^10bit$'), 'bit-depth codec string'),
];

Map<String, Object?> _toJson(List<_Row> rows) {
  final byFile = <String, List<_Row>>{};
  for (final row in rows) {
    byFile.putIfAbsent(row.finding.path, () => <_Row>[]).add(row);
  }
  final perFile = <Map<String, Object?>>[];
  final paths = byFile.keys.toList()..sort();
  for (final path in paths) {
    final rowsForFile = byFile[path]!;
    perFile.add(<String, Object?>{
      'path': path,
      'total': rowsForFile.length,
      'high': rowsForFile.where((r) => r.finding.confidence == 'HIGH').length,
      'medium': rowsForFile
          .where((r) => r.finding.confidence == 'MEDIUM')
          .length,
      'rows': rowsForFile
          .map(
            (r) => <String, Object?>{
              'line': r.finding.line,
              'column': r.finding.column,
              'confidence': r.finding.confidence,
              'reason': r.finding.reason,
              'literal': r.finding.literal,
              'label': r.label,
              'rationale': r.reason,
            },
          )
          .toList(growable: false),
    });
  }
  final byLabel = <String, int>{};
  for (final r in rows) {
    byLabel[r.label] = (byLabel[r.label] ?? 0) + 1;
  }
  return <String, Object?>{
    'schema': 'l10n-audit-v1',
    'generated_for': 'L10N-0',
    'by_label': byLabel,
    'per_file': perFile,
  };
}

String _toMarkdown(List<_Row> high, List<_Row> medium) {
  final byFile = <String, List<_Row>>{};
  for (final row in [...high, ...medium]) {
    byFile.putIfAbsent(row.finding.path, () => <_Row>[]).add(row);
  }
  final buf = StringBuffer();
  buf
    ..writeln('# L10N-0 candidate classifier roll-up')
    ..writeln()
    ..writeln(
      '> Heuristic first-pass audit created from the scanner baseline. Treat '
      'every label as a *suggestion*, not a final verdict — L10N-1..5 packages '
      'revisit borderline rows when actually touching the file.',
    )
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('- Total candidates: ${high.length + medium.length}')
    ..writeln('- High: ${high.length}')
    ..writeln('- Medium: ${medium.length}')
    ..writeln()
    ..writeln('## Per-file audit')
    ..writeln();
  final paths = byFile.keys.toList()..sort();
  for (var index = 0; index < paths.length; index++) {
    final path = paths[index];
    final rows = byFile[path]!;
    buf
      ..writeln('### `$path`')
      ..writeln()
      ..writeln('| Line | Confidence | Reason | Literal | Label | Rationale |')
      ..writeln('|---:|---|---|---|---|---|');
    for (final row in rows) {
      final literal = _mdEscape(row.finding.literal).replaceAll('\n', ' ');
      final rationale = _mdEscape(row.reason);
      buf.writeln(
        '| ${row.finding.line}:${row.finding.column} '
        '| ${row.finding.confidence} '
        '| ${row.finding.reason} '
        '| `$literal` '
        '| `${row.label}` '
        '| $rationale |',
      );
    }
    if (index != paths.length - 1) {
      buf.writeln();
    }
  }
  return buf.toString();
}

String _mdEscape(String text) =>
    text.replaceAll(r'|', r'\|').replaceAll('`', r'\`');

Set<String> _uniqueFiles(List<_Row> rows) =>
    rows.map((r) => r.finding.path).toSet();

String _resolveInput(String? inputPath) {
  if (inputPath == null) {
    // Invoke the scanner and capture stdout. The scanner is in the same repo
    // so we know its interface.
    final result = io.Process.runSync('dart', const <String>[
      'run',
      'tool/scan_hardcoded_ui_text.dart',
      '--max-results=10000',
    ], runInShell: true);
    if (result.exitCode != 0) {
      throw ProcessException(
        'dart',
        const <String>[
          'run',
          'tool/scan_hardcoded_ui_text.dart',
          '--max-results=10000',
        ],
        result.stderr is String ? result.stderr as String : '$result.stderr',
        result.exitCode,
      );
    }
    if (result.stdout is! String) {
      throw StateError(
        'Scanner stdout was not text: ${result.stdout.runtimeType}',
      );
    }
    return result.stdout as String;
  }
  return File(inputPath).readAsStringSync();
}
