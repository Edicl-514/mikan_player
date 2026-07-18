import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';

/// Single source search progress row in the sample-source panel.
class PlayerSourceProgressItem extends StatelessWidget {
  final String sourceName;
  final SourceSearchProgress? progress;

  const PlayerSourceProgressItem({
    super.key,
    required this.sourceName,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pendingColor = isDark
        ? Colors.white24
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final idleTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final activeTextColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    IconData icon;
    Color iconColor;
    String statusText;
    String? errorText;

    if (progress == null) {
      icon = Icons.hourglass_empty;
      iconColor = pendingColor;
      statusText = l10n.playerSearchProgressStepPending;
    } else {
      switch (progress!.step) {
        case SearchStep.pending:
          icon = Icons.hourglass_empty;
          iconColor = pendingColor;
          statusText = l10n.playerSearchProgressStepPending;
          break;
        case SearchStep.searching:
          icon = Icons.search;
          iconColor = theme.colorScheme.primary;
          statusText = l10n.playerSearchProgressStepSearching;
          break;
        case SearchStep.fetchingDetail:
          icon = Icons.article_outlined;
          iconColor = theme.colorScheme.primary;
          statusText = l10n.playerSearchProgressStepDetail;
          break;
        case SearchStep.fetchingEpisodes:
          icon = Icons.list_alt;
          iconColor = theme.colorScheme.primary;
          statusText = l10n.playerSearchProgressStepEpisodes;
          break;
        case SearchStep.extractingVideo:
          icon = Icons.video_library;
          iconColor = theme.colorScheme.primary;
          statusText = l10n.playerSearchProgressStepExtracting;
          break;
        case SearchStep.success:
          icon = Icons.check_circle;
          iconColor = Colors.green;
          statusText = progress!.directVideoUrl != null
              ? l10n.playerSearchProgressStepSuccess
              : l10n.playerSearchProgressStepFoundPlayPage;
          break;
        case SearchStep.failed:
          icon = Icons.error_outline;
          iconColor = Colors.redAccent;
          statusText = l10n.playerSearchProgressStepFailed;
          errorText = progress!.error;
          break;
      }
    }

    final isActive =
        progress != null &&
        progress!.step != SearchStep.pending &&
        progress!.step != SearchStep.success &&
        progress!.step != SearchStep.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (isActive)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: iconColor,
              ),
            )
          else
            Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sourceName,
                        style: TextStyle(
                          color: isActive ? activeTextColor : idleTextColor,
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(color: iconColor, fontSize: 10),
                    ),
                  ],
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
