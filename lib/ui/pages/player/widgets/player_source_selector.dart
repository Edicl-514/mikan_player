import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';

/// Collapsed / expanded play-source control bar (BT vs sample tabs).
class PlayerSourceSelector extends StatelessWidget {
  final bool isMobile;
  final bool isExpanded;
  final String activeSource;
  final int btCount;
  final int onlineCount;
  final String currentLabel;
  final bool isBtLoading;
  final bool hasBtError;
  final bool isSampleLoading;
  final bool hasSampleError;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<String> onSelectSource;

  const PlayerSourceSelector({
    super.key,
    required this.isMobile,
    required this.isExpanded,
    required this.activeSource,
    required this.btCount,
    required this.onlineCount,
    required this.currentLabel,
    required this.isBtLoading,
    required this.hasBtError,
    required this.isSampleLoading,
    required this.hasSampleError,
    required this.onExpand,
    required this.onCollapse,
    required this.onSelectSource,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);

    if (!isExpanded) {
      return InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color.fromARGB(255, 20, 20, 25)
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: isMobile
                    ? Row(
                        children: [
                          Text(
                            l10n.playerSourceTitleFoundMobile,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$btCount',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.download_for_offline,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$onlineCount',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.subscriptions,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.playerSourceTitleCurrent(currentLabel),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        l10n.playerSourceTitleFound(
                          btCount,
                          onlineCount,
                          currentLabel,
                        ),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E2C)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SourceTab(
              label: l10n.playerSourceTabBt,
              isSelected: activeSource == 'bt',
              isLoading: isBtLoading,
              hasError: hasBtError,
              count: btCount,
              onTap: () => onSelectSource('bt'),
            ),
          ),
          Container(
            width: 1,
            color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _SourceTab(
              label: l10n.playerSourceTabSubscription,
              isSelected: activeSource == 'sample',
              isLoading: isSampleLoading,
              hasError: hasSampleError,
              count: onlineCount,
              onTap: () => onSelectSource('sample'),
            ),
          ),
          InkWell(
            onTap: onCollapse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: double.infinity,
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_up,
                color: isDark ? Colors.white70 : Colors.grey,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isLoading;
  final bool hasError;
  final int count;
  final VoidCallback onTap;

  const _SourceTab({
    required this.label,
    required this.isSelected,
    required this.isLoading,
    required this.hasError,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurfaceVariant),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isSelected ? theme.colorScheme.primary : Colors.grey,
                ),
              )
            else if (hasError && count == 0)
              Icon(
                Icons.error_outline,
                size: 14,
                color: Colors.redAccent.withValues(alpha: 0.8),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
