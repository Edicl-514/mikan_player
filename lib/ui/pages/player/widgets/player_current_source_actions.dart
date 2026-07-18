import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';

/// Download / copy-link buttons for the currently playing online source.
class PlayerCurrentSourceActions extends StatelessWidget {
  final bool canAct;
  final bool compact;
  final VoidCallback? onDownload;
  final VoidCallback? onCopyUrl;

  const PlayerCurrentSourceActions({
    super.key,
    required this.canAct,
    this.compact = false,
    this.onDownload,
    this.onCopyUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHigh;
    final border = isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.3);
    final fontSize = compact ? 12.0 : 13.0;
    final iconSize = compact ? 14.0 : 16.0;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    Widget btn({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
    }) {
      return Opacity(
        opacity: canAct ? 1.0 : 0.4,
        child: InkWell(
          onTap: canAct ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(icon: Icons.download, label: l10n.playerDownloadButton, onTap: onDownload),
        const SizedBox(width: 8),
        btn(icon: Icons.link, label: l10n.playerCopyDownloadLinkButton, onTap: onCopyUrl),
      ],
    );
  }
}
