import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_helpers.dart';
import 'package:mikan_player/ui/pages/bangumi_details/person_text_spans.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/section_title.dart';

/// Story summary section with optional translation/original toggle.
///
/// Stateless presentational widget extracted from `_buildSummarySection` in
/// `bangumi_details_page.dart`. The host owns the `showOriginal` flag and
/// provides `hasBothTranslationAndOriginal` to enable the toggle.
class BangumiSummarySection extends StatelessWidget {
  final String summary;
  final bool showOriginal;
  final bool hasBothTranslationAndOriginal;
  final VoidCallback? onToggle;
  final bool isDarkBg;

  const BangumiSummarySection({
    super.key,
    required this.summary,
    required this.showOriginal,
    required this.hasBothTranslationAndOriginal,
    required this.onToggle,
    required this.isDarkBg,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkBg
        ? Colors.white70
        : Theme.of(context).textTheme.bodyMedium?.color;
    final hintColor = isDarkBg ? Colors.white38 : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: AppLocalizations.of(context).bangumiDetailsStory,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: TextStyle(fontSize: 15, height: 1.6, color: textColor),
                textAlign: TextAlign.justify,
              ),
              if (hasBothTranslationAndOriginal) ...[
                const SizedBox(height: 8),
                Text(
                  showOriginal ? "点击显示翻译" : "点击显示原文",
                  style: TextStyle(fontSize: 12, color: hintColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Wide-layout tags section: pill chips that navigate to TagBrowsePage via
/// [onTagTap]. Extracted from `_buildTagsSection`.
class BangumiTagsSection extends StatelessWidget {
  final dynamic tags;
  final bool isDarkBg;
  final void Function(String tagName) onTagTap;

  const BangumiTagsSection({
    super.key,
    required this.tags,
    required this.isDarkBg,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tags == null || tags is! List || (tags as List).isEmpty) {
      return const SizedBox.shrink();
    }
    final tagList = tags as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: AppLocalizations.of(context).bangumiDetailsTags,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tagList.map<Widget>((tag) {
            final name = (tag['name'] ?? '') as String;
            return GestureDetector(
              onTap: name.isNotEmpty ? () => onTagTap(name) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDarkBg ? Colors.white10 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    color: isDarkBg ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Mobile-layout tags subsection: compact Wrap with counts (top 15 only).
/// Extracted from `_buildMobileTags`.
class BangumiMobileTags extends StatelessWidget {
  final dynamic tags;
  final bool isDarkBg;
  final void Function(String tagName) onTagTap;

  const BangumiMobileTags({
    super.key,
    required this.tags,
    required this.isDarkBg,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tags == null || tags is! List) {
      return const SizedBox.shrink();
    }
    final tagList = tags as List;

    final borderColor = isDarkBg ? Colors.white24 : Colors.grey[300]!;
    final textColor = isDarkBg ? Colors.white70 : Colors.black87;
    final countColor = isDarkBg ? Colors.white38 : Colors.grey;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tagList.take(15).map<Widget>((tag) {
        final name = tag['name'];
        final count = tag['count'];
        return GestureDetector(
          onTap: name != null ? () => onTagTap(name as String) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$name ",
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                  if (count != null)
                    TextSpan(
                      text: "$count",
                      style: TextStyle(fontSize: 10, color: countColor),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Infobox list with optional collapse/expand control.
///
/// Stateless presentational widget extracted from `_buildInfoBoxList` in
/// `bangumi_details_page.dart`. The host owns the `isExpanded` flag and
/// `onToggleExpanded` callback.
class BangumiInfoBoxList extends StatelessWidget {
  final List infobox;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final bool isDarkBg;
  final Map<String, int> personIdMap;
  final void Function(int personId) onPersonTap;

  const BangumiInfoBoxList({
    super.key,
    required this.infobox,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.isDarkBg,
    required this.personIdMap,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    if (infobox.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final keyColor = isDarkBg ? Colors.white54 : Colors.grey;
    final bgColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.withValues(alpha: 0.1);
    final canCollapse = shouldEnableInfoBoxCollapse(infobox);
    final visibleItems =
        isExpanded || !canCollapse ? infobox : infobox.take(6).toList();
    final hiddenCount = infobox.length - visibleItems.length;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Information",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (canCollapse)
                  TextButton(
                    onPressed: onToggleExpanded,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: Text(isExpanded ? "收起" : "展开"),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in visibleItems)
                    _BangumiInfoBoxItem(
                      item: item,
                      isExpanded: isExpanded || !canCollapse,
                      textColor: textColor,
                      keyColor: keyColor,
                      isDarkBg: isDarkBg,
                      personIdMap: personIdMap,
                      onPersonTap: onPersonTap,
                    ),
                  if (!isExpanded && canCollapse && hiddenCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "还有 $hiddenCount 项，点击展开查看完整信息",
                        style: TextStyle(color: keyColor, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a single infobox row, delegating the (possibly multi-line) expanded
/// value to [BangumiExpandedInfoBoxValue].
class _BangumiInfoBoxItem extends StatelessWidget {
  final dynamic item;
  final bool isExpanded;
  final Color textColor;
  final Color keyColor;
  final bool isDarkBg;
  final Map<String, int> personIdMap;
  final void Function(int personId) onPersonTap;

  const _BangumiInfoBoxItem({
    required this.item,
    required this.isExpanded,
    required this.textColor,
    required this.keyColor,
    required this.isDarkBg,
    required this.personIdMap,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final key = (item['key'] ?? '').toString();
    final value = item['value'];
    final valueStyle = TextStyle(color: textColor, fontSize: 12);
    final linkColor = isDarkBg ? Colors.cyanAccent : Colors.blue.shade800;
    final linkStyle = TextStyle(
      color: linkColor,
      fontSize: 12,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              key,
              style: TextStyle(
                color: keyColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isExpanded
                ? BangumiExpandedInfoBoxValue(
                    value: value,
                    valueStyle: valueStyle,
                    linkStyle: linkStyle,
                    personIdMap: personIdMap,
                    onPersonTap: onPersonTap,
                  )
                : Text(
                    summarizeInfoboxValue(value),
                    style: valueStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Renders the expanded form of an infobox value. For list values the items
/// are joined with `", "` and each element is rendered with [PersonAwareText]
/// so person names become tappable links. String/number values are rendered
/// the same way.
class BangumiExpandedInfoBoxValue extends StatelessWidget {
  final dynamic value;
  final TextStyle valueStyle;
  final TextStyle linkStyle;
  final Map<String, int> personIdMap;
  final void Function(int personId) onPersonTap;

  const BangumiExpandedInfoBoxValue({
    super.key,
    required this.value,
    required this.valueStyle,
    required this.linkStyle,
    required this.personIdMap,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    if (value is List) {
      final names = value
          .map((v) => (v['v'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();

      if (names.isEmpty) {
        return const SizedBox.shrink();
      }

      return Wrap(
        spacing: 0,
        runSpacing: 4,
        children: [
          for (int i = 0; i < names.length; i++) ...[
            PersonAwareText(
              text: names[i],
              textStyle: valueStyle,
              linkStyle: linkStyle,
              personIdMap: personIdMap,
              onPersonTap: onPersonTap,
            ),
            if (i < names.length - 1) Text(', ', style: valueStyle),
          ],
        ],
      );
    }

    return PersonAwareText(
      text: value?.toString() ?? '',
      textStyle: valueStyle,
      linkStyle: linkStyle,
      personIdMap: personIdMap,
      onPersonTap: onPersonTap,
    );
  }
}
