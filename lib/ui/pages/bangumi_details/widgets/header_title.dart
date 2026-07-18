import 'package:flutter/material.dart';

/// Title (and optional CN-name subtitle) block used in the wide layout's
/// right panel.
///
/// Stateless presentational widget extracted from `_buildTitleSection` in
/// `bangumi_details_page.dart`.
class BangumiTitleSection extends StatelessWidget {
  final String title;
  final String? cnName;
  final bool centered;
  final bool isDarkBg;

  const BangumiTitleSection({
    super.key,
    required this.title,
    required this.cnName,
    this.centered = false,
    required this.isDarkBg,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkBg
        ? Colors.white
        : Theme.of(context).textTheme.titleLarge?.color;
    final subColor = isDarkBg
        ? Colors.white70
        : Theme.of(context).textTheme.bodyMedium?.color;

    final align = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
          textAlign: textAlign,
        ),
        if (cnName != null && cnName!.isNotEmpty && cnName != title) ...[
          const SizedBox(height: 8),
          Text(
            cnName!,
            style: TextStyle(
              fontSize: 18,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: textAlign,
          ),
        ],
      ],
    );
  }
}
