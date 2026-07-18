import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/section_title.dart';

/// "Loading…" placeholder used when a section's data has not landed yet.
///
/// Stateless presentational widget extracted from `_buildPlaceholderSection`
/// in `bangumi_details_page.dart`.
class PlaceholderSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDarkBg;

  const PlaceholderSection({
    super.key,
    required this.title,
    required this.icon,
    required this.isDarkBg,
  });

  @override
  Widget build(BuildContext context) {
    final boxColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final iconColor = isDarkBg ? Colors.white24 : Colors.grey[400];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title, isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(12),
            border: isDarkBg ? Border.all(color: Colors.white10) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).bangumiDetailsLoadingSection(title),
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).bangumiDetailsComingSoon,
                style: TextStyle(color: iconColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
