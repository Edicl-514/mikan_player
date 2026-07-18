import 'package:flutter/material.dart';

/// Section title used in the Bangumi details page header rows.
///
/// Stateless presentational widget extracted from `_buildSectionTitle` in
/// `bangumi_details_page.dart`. The indicator bar picks amber on dark
/// backgrounds and deep purple on light.
class SectionTitle extends StatelessWidget {
  final String title;
  final bool isDarkBg;

  const SectionTitle({
    super.key,
    required this.title,
    required this.isDarkBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: isDarkBg ? Colors.amber : Colors.deepPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkBg ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
