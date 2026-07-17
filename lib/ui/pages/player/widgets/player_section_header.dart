import 'package:flutter/material.dart';

/// Shared section header used in player mobile/PC info panels.
class PlayerSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const PlayerSectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ] else ...[
          const Spacer(),
        ],
      ],
    );
  }
}
