import 'package:flutter/material.dart';

/// Comments sort popup used by the player comments header.
class PlayerCommentSortButton extends StatelessWidget {
  final String sortMode; // 'default' | 'time'
  final ValueChanged<String> onSelected;

  const PlayerCommentSortButton({
    super.key,
    required this.sortMode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return PopupMenuButton<String>(
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      color: isDark
          ? const Color(0xFF1E1E2C)
          : theme.colorScheme.surfaceContainer,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'default',
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                "默认排序",
                style: TextStyle(
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'time',
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                "按时间排序",
                style: TextStyle(
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort,
            color: isDark ? Colors.white54 : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            sortMode == 'default' ? "默认排序" : "按时间排序",
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
