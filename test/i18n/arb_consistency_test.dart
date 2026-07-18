// L10N-0 ARB consistency guard. The plan §4 / §9 third-party "verifiable"
// criteria for every i18n work package are encoded here so a regression (an
// extra key in only one locale, an accidental placeholder rename, an invalid
// JSON edit) shows up in CI rather than in production.
//
// What this guards (plan §1.2 acceptance + L10N-0 verification):
//   1. both `app_zh.arb` and `app_en.arb` parse as JSON
//   2. the `@@locale` markers identify each file
//   3. every non-metadata key (`@@locale` and `@key` excluded) appears in
//      both files (parity rule in plan §4 item 2 bullet "中英文 key 一致")
//   4. for every shared key, the set of `{placeholder}` names referenced in
//      the message text matches between zh and en
//   5. when an `@key` metadata block declares placeholders explicitly, those
//      declarations agree with the placeholder names actually referenced in
//      the message text in each locale
//   6. every placeholder name respects the project's lowerCamelCase
//      convention — this catches accidental uppercase starts or punctuation.
//
// Generation is intentionally not run here; `gen-l10n` is exercised separately
// from `flutter test` (see plan §9.1).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final zhFile = File('lib/l10n/app_zh.arb');
  final enFile = File('lib/l10n/app_en.arb');

  group('ARB consistency', () {
    late Map<String, Object?> zh;
    late Map<String, Object?> en;

    setUpAll(() {
      // Read raw so encoding-related issues surface as parse errors with a
      // useful stack trace rather than swallowed as an NPE downstream.
      expect(
        zhFile.existsSync(),
        isTrue,
        reason:
            'lib/l10n/app_zh.arb missing — has the ARB template path '
            'changed?',
      );
      expect(
        enFile.existsSync(),
        isTrue,
        reason:
            'lib/l10n/app_en.arb missing — has the second-locale path '
            'changed?',
      );
      zh = jsonDecode(zhFile.readAsStringSync()) as Map<String, Object?>;
      en = jsonDecode(enFile.readAsStringSync()) as Map<String, Object?>;
    });

    test('both files declare their @@locale', () {
      expect(
        zh['@@locale'],
        'zh',
        reason: 'app_zh.arb must declare "@@locale": "zh" for gen-l10n',
      );
      expect(
        en['@@locale'],
        'en',
        reason: 'app_en.arb must declare "@@locale": "en" for gen-l10n',
      );
    });

    test('non-metadata keys are identical between zh and en', () {
      final zhKeys = msgKeys(zh);
      final enKeys = msgKeys(en);

      final missingInEn = zhKeys.difference(enKeys);
      final missingInZh = enKeys.difference(zhKeys);
      final fail = StringBuffer();
      if (missingInEn.isNotEmpty) {
        fail
          ..writeln('Keys present in app_zh.arb but missing in app_en.arb:')
          ..writeln('  ${missingInEn.toList()..sort()}')
          ..writeln();
      }
      if (missingInZh.isNotEmpty) {
        fail
          ..writeln('Keys present in app_en.arb but missing in app_zh.arb:')
          ..writeln('  ${missingInZh.toList()..sort()}')
          ..writeln();
      }
      if (fail.isNotEmpty) {
        // Plan §4 item 2: 中英文 key 一致 is not optional.
        throw TestFailure(fail.toString());
      }
    });

    test('placeholder sets align per shared message key', () {
      final issues = <String, (Set<String>, Set<String>)>{};
      for (final key in msgKeys(zh)) {
        if (!en.containsKey(key)) continue;
        final zhValue = zh[key];
        final enValue = en[key];
        if (zhValue is! String || enValue is! String) continue;

        final zhPlaceholders = placeholderNames(zhValue);
        final enPlaceholders = placeholderNames(enValue);
        if (!_setsEqual(zhPlaceholders, enPlaceholders)) {
          issues[key] = (zhPlaceholders, enPlaceholders);
        }
      }

      if (issues.isNotEmpty) {
        final buf = StringBuffer('Placeholder mismatch per key:\n');
        for (final entry in issues.entries) {
          buf.writeln(
            '  ${entry.key}: zh=${entry.value.$1.toList()..sort()} '
            'en=${entry.value.$2.toList()..sort()}',
          );
        }
        // Plan §4 item 2: 中英文 placeholder 名称和数量必须一致.
        throw TestFailure(buf.toString());
      }
    });

    test('placeholder names respect gen-l10n identifier shape', () {
      final offenders = <String, Set<String>>{};
      for (final locale in <String, Map<String, Object?>>{
        'zh': zh,
        'en': en,
      }.entries) {
        for (final key in msgKeys(locale.value)) {
          final value = locale.value[key];
          if (value is! String) continue;
          final bad = <String>{};
          for (final name in placeholderNames(value)) {
            if (!_placeholderNamePattern.hasMatch(name)) {
              bad.add(name);
            }
          }
          if (bad.isNotEmpty) offenders['${locale.key}:$key'] = bad;
        }
      }

      // This guards the parser too: plural-option labels (`one`, `other`,
      // `=0`) are not placeholders, while nested message placeholders are.
      expect(
        placeholderNames(
          '{count, plural, =0{No entries} other{{count} entries}}',
        ),
        <String>{'count'},
      );
      if (offenders.isNotEmpty) {
        final buf = StringBuffer(
          'Placeholder names must be valid gen-l10n identifiers '
          '(`lowerCamelCase` / `[a-z][A-Za-z0-9_]*`):\n',
        );
        offenders.forEach((key, bad) {
          buf.writeln('  $key: $bad');
        });
        throw TestFailure(buf.toString());
      }
    });

    test('player placeholder messages declare typed metadata', () {
      final issues = <String>[];
      for (final locale in <String, Map<String, Object?>>{
        'zh': zh,
        'en': en,
      }.entries) {
        for (final key in msgKeys(
          locale.value,
        ).where((key) => key.startsWith('player'))) {
          final value = locale.value[key];
          if (value is! String || placeholderNames(value).isEmpty) continue;

          final metadata = locale.value['@$key'];
          if (metadata is! Map<String, Object?>) {
            issues.add('${locale.key}:$key is missing an @key metadata block');
            continue;
          }
          if (metadata['description'] is! String ||
              (metadata['description']! as String).trim().isEmpty) {
            issues.add('${locale.key}:$key metadata needs a description');
          }
          final placeholders = metadata['placeholders'];
          if (placeholders is! Map<String, Object?>) {
            issues.add('${locale.key}:$key metadata needs placeholder types');
            continue;
          }
          for (final name in placeholderNames(value)) {
            final declaration = placeholders[name];
            if (declaration is! Map<String, Object?> ||
                declaration['type'] is! String ||
                (declaration['type']! as String).trim().isEmpty) {
              issues.add('${locale.key}:$key placeholder $name needs a type');
            }
          }
        }
      }

      if (issues.isNotEmpty) {
        throw TestFailure(
          'Player placeholder metadata is incomplete:\n  ${issues.join('\n  ')}',
        );
      }
    });

    test('@key metadata blocks agree with placeholder names in the text', () {
      final issues = <String>[];
      for (final locale in <String, Map<String, Object?>>{
        'zh': zh,
        'en': en,
      }.entries) {
        for (final key in msgKeys(locale.value)) {
          final metadataKey = '@$key';
          if (!locale.value.containsKey(metadataKey)) continue;

          final metadata = locale.value[metadataKey];
          if (metadata is! Map<String, Object?>) {
            issues.add('${locale.key}:$key metadata must be a JSON object');
            continue;
          }

          final declared = <String>{};
          // ARB placeholder metadata can be a list `[{name: ..., ...}]` or a
          // map keyed by placeholder name.
          final placeholdersField = metadata['placeholders'];
          if (placeholdersField is List<Object?>) {
            for (final entry in placeholdersField) {
              if (entry is! Map<String, Object?> || entry['name'] is! String) {
                issues.add(
                  '${locale.key}:$key metadata has an invalid placeholder entry',
                );
                continue;
              }
              declared.add(entry['name']! as String);
            }
          } else if (placeholdersField is Map<String, Object?>) {
            declared.addAll(placeholdersField.keys);
          } else if (placeholdersField != null) {
            issues.add(
              '${locale.key}:$key metadata.placeholders must be a map or list',
            );
          }

          final value = locale.value[key];
          if (value is! String) continue;
          final inText = placeholderNames(value);
          if (!_setsEqual(declared, inText)) {
            issues.add(
              '${locale.key}:$key declared=${declared.toList()..sort()} '
              'inText=${inText.toList()..sort()}',
            );
          }
        }
      }

      if (issues.isNotEmpty) {
        final buf = StringBuffer(
          '@key metadata placeholders disagree with the message text:\n',
        );
        for (final issue in issues) {
          buf.writeln('  $issue');
        }
        // Plan §4 item 2: 新增带 placeholder 的消息补 @key description/type
        // 元数据 — keep the contract testable here so future additions
        // cannot drift.
        throw TestFailure(buf.toString());
      }
    });
  });
}

/// Returns the set of message keys in an ARB JSON map by skipping the
/// metadata entries (`@@locale` and `@<message>` description blocks).
Set<String> msgKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).cast<String>().toSet();
}

/// Extracts placeholder names from ICU message arguments.
///
/// Plural/select option labels such as `one`, `other`, and `=0` are not
/// placeholders. Nested placeholders in their message bodies are collected.
/// Embedded Dart interpolation `${name}` is intentionally ignored — it should
/// never appear in ARB values.
Set<String> placeholderNames(String text) {
  final names = <String>{};
  _collectIcuMessagePlaceholders(text, names);
  return names;
}

void _collectIcuMessagePlaceholders(String message, Set<String> names) {
  var index = 0;
  while (index < message.length) {
    if (message[index] == r'$' &&
        index + 1 < message.length &&
        message[index + 1] == '{') {
      index += 2;
      continue;
    }
    if (message[index] != '{') {
      index++;
      continue;
    }
    final next = _parseIcuArgument(message, index, names);
    index = next ?? index + 1;
  }
}

int? _parseIcuArgument(String message, int open, Set<String> names) {
  final close = _matchingBrace(message, open);
  if (close == null) return null;

  var cursor = open + 1;
  final nameEnd = _nextDelimiter(message, cursor, close);
  if (nameEnd == null) return null;
  final name = message.substring(cursor, nameEnd).trim();
  if (name.isEmpty) return null;
  names.add(name);
  if (message[nameEnd] == '}') return close + 1;

  cursor = nameEnd + 1;
  while (cursor < close && _isWhitespace(message[cursor])) {
    cursor++;
  }
  final typeEnd = _nextDelimiter(message, cursor, close);
  if (typeEnd == null) return close + 1;
  final type = message.substring(cursor, typeEnd).trim();
  if (message[typeEnd] == '}') return close + 1;

  final style = message.substring(typeEnd + 1, close);
  if (type == 'plural' || type == 'select' || type == 'selectordinal') {
    _collectIcuOptionPlaceholders(style, names);
  } else {
    _collectIcuMessagePlaceholders(style, names);
  }
  return close + 1;
}

int? _nextDelimiter(String text, int start, int end) {
  for (var index = start; index <= end; index++) {
    final char = text[index];
    if (char == ',' || char == '}') return index;
  }
  return null;
}

void _collectIcuOptionPlaceholders(String style, Set<String> names) {
  var index = 0;
  while (index < style.length) {
    while (index < style.length && _isWhitespace(style[index])) {
      index++;
    }
    if (style.startsWith('offset:', index)) {
      index += 'offset:'.length;
      while (index < style.length && !_isWhitespace(style[index])) {
        index++;
      }
      continue;
    }

    while (index < style.length &&
        !_isWhitespace(style[index]) &&
        style[index] != '{') {
      index++;
    }
    while (index < style.length && _isWhitespace(style[index])) {
      index++;
    }
    if (index >= style.length || style[index] != '{') {
      index++;
      continue;
    }
    final close = _matchingBrace(style, index);
    if (close == null) return;
    _collectIcuMessagePlaceholders(style.substring(index + 1, close), names);
    index = close + 1;
  }
}

int? _matchingBrace(String text, int open) {
  var depth = 0;
  for (var index = open; index < text.length; index++) {
    if (text[index] == '{') depth++;
    if (text[index] == '}') {
      depth--;
      if (depth == 0) return index;
    }
  }
  return null;
}

bool _isWhitespace(String char) => char == ' ' || char == '\n' || char == '\t';

bool _setsEqual(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

// The project convention is lowerCamelCase placeholder names (e.g.
// `streamUrl`). A typo like `{stream url}`, `{stream-url}`, or `{StreamUrl}`
// must trip the consistency guard before gen-l10n is run.
final RegExp _placeholderNamePattern = RegExp(r'^[a-z][A-Za-z0-9_]*$');
