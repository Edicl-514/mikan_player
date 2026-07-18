// i18n-scan-ignore-file: BT resource title parser — all literals are
// protocol/source-data matching tokens (resolution / codec / subtitle language
// / subtitle type markers) extracted from user-submitted release titles.
import 'package:flutter/material.dart';

/// Parses release-tag hints (resolution / subtitle language / subtitle type /
/// codec) out of a BT resource title. Pure function; relocates the original
/// `_parseBtTags` from `player_page.dart` verbatim.
Map<String, String?> parseBtTags(String title) {
  final t = title.toUpperCase();

  // Resolution
  String? resolution;
  if (RegExp(r'(?<!\d)4K(?!\d)|2160P?').hasMatch(t)) {
    resolution = '4K';
  } else if (RegExp(r'1080P?').hasMatch(t)) {
    resolution = '1080P';
  } else if (RegExp(r'720P?').hasMatch(t)) {
    resolution = '720P';
  } else if (RegExp(r'480P?').hasMatch(t)) {
    resolution = '480P';
  } else if (RegExp(r'360P?').hasMatch(t)) {
    resolution = '360P';
  }

  // Subtitle language
  // Check for RAW first to avoid false positive matches
  String? subLang;
  final hasRaw = RegExp(r'生肉|RAW(?!\s*[A-Z])|\bNO.?SUB').hasMatch(t);

  // Check for language combinations first (higher priority)
  final hasSimplifiedTraditionalJpn = RegExp(r'简繁日|简繁.*日|简.*繁.*日').hasMatch(t);
  final hasSimplifiedJpn = RegExp(r'简日(?!本)|简.*日(?!本)').hasMatch(t);
  final hasTraditionalJpn = RegExp(r'繁日(?!本)|繁.*日(?!本)').hasMatch(t);

  // Check for individual languages (without dual markers)
  final hasChs = RegExp(r'简体|简中|CHS(?!T)|GB|S_CHS').hasMatch(t);
  final hasCht = RegExp(r'繁体|繁中|CHT|BIG5|T_CHT').hasMatch(t);
  final hasJpn = RegExp(r'日文|日语|日本語').hasMatch(title);
  final hasDual = RegExp(r'简繁|双语|DUAL|CHS.*CHT|CHT.*CHS').hasMatch(t);

  // Priority: combination languages > dual languages > single languages > raw
  if (hasSimplifiedTraditionalJpn) {
    subLang = '简繁日';
  } else if (hasSimplifiedJpn) {
    subLang = '简日';
  } else if (hasTraditionalJpn) {
    subLang = '繁日';
  } else if (hasDual) {
    subLang = '简繁';
  } else if (hasChs && hasCht) {
    subLang = '简繁';
  } else if (hasChs) {
    subLang = '简中';
  } else if (hasCht) {
    subLang = '繁中';
  } else if (hasJpn) {
    subLang = '日语';
  } else if (hasRaw) {
    subLang = '生肉';
  }

  // Subtitle type: embedded-hard (内嵌/外挂) vs embedded-soft (内封)
  String? subType;
  final hasHardSub = RegExp(
    r'内嵌|内挂|硬字幕|HARDSUB|HARD.?SUB|ASS.?SUB|字幕内嵌|内字|内置字幕',
  ).hasMatch(t);
  final hasSoftSub = RegExp(r'内封|软字幕|SOFTSUB|SOFT.?SUB|字幕内封').hasMatch(t);
  // Some groups use 内封字幕 specifically
  final hasSoftSub2 = RegExp(r'内封字幕|内封.*字幕|字幕.*内封').hasMatch(t);

  if (hasSoftSub || hasSoftSub2) {
    subType = '内封';
  } else if (hasHardSub) {
    subType = '内嵌';
  }

  // Codec hints for display
  String? codec;
  if (RegExp(r'HEVC|H\.?265|X265').hasMatch(t)) {
    codec = 'HEVC';
  } else if (RegExp(r'AVC|H\.?264|X264').hasMatch(t)) {
    codec = 'AVC';
  } else if (RegExp(r'AV1').hasMatch(t)) {
    codec = 'AV1';
  }

  return {
    'resolution': resolution,
    'subLang': subLang,
    'subType': subType,
    'codec': codec,
  };
}

/// Renders a single BT tag chip. Relocates the original `_buildBtTag`.
Widget buildBtTag(String label, Color bgColor, Color textColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ),
  );
}

/// Renders the row of BT tag chips for a resource title, deriving the tags
/// via [parseBtTags]. Relocates the original `_buildBtTagsRow`.
Widget buildBtTagsRow(String title, {Map<String, String?>? tags}) {
  final parsed = tags ?? parseBtTags(title);
  final widgets = <Widget>[];

  final resolution = parsed['resolution'];
  if (resolution != null) {
    widgets.add(
      buildBtTag(resolution, const Color(0xFF1A3A5C), const Color(0xFF5BC4FF)),
    );
  }

  final codec = parsed['codec'];
  if (codec != null) {
    widgets.add(
      buildBtTag(codec, const Color(0xFF1A2A1A), const Color(0xFF6BCB77)),
    );
  }

  final subLang = parsed['subLang'];
  if (subLang != null) {
    Color bg, fg;
    switch (subLang) {
      case '生肉':
        bg = const Color(0xFF2A2A1A);
        fg = const Color(0xFFCDC16A);
        break;
      case '简中':
        bg = const Color(0xFF1A2A3A);
        fg = const Color(0xFF64B5F6);
        break;
      case '繁中':
        bg = const Color(0xFF2A1A3A);
        fg = const Color(0xFFCE93D8);
        break;
      case '简繁':
        bg = const Color(0xFF1A1A3A);
        fg = const Color(0xFF90CAF9);
        break;
      case '日语':
        bg = const Color(0xFF3A1A1A);
        fg = const Color(0xFFEF9A9A);
        break;
      default:
        bg = const Color(0xFF2A2A2A);
        fg = Colors.white60;
    }
    widgets.add(buildBtTag(subLang, bg, fg));
  }

  final subType = parsed['subType'];
  if (subType != null) {
    widgets.add(
      buildBtTag(subType, const Color(0xFF2A1A2A), const Color(0xFFFFAB91)),
    );
  }

  if (widgets.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(spacing: 4, runSpacing: 4, children: widgets),
  );
}
