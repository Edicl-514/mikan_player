import 'package:flutter/material.dart';

import 'package:mikan_player/ui/pages/player/widgets/bt_resource.dart';
import 'package:mikan_player/ui/pages/player/widgets/bt_resource_tags.dart';

/// BT resource list - player-side display-only widget.
///
/// Extracted from `PlayerPage._buildResourceList`. Renders the BT source
/// status bar, the empty-state search button, and the list of BT resource
/// cards. All data is passed through the constructor; every side effect
/// (copy magnet, start download, play magnet) is forwarded through callbacks.
/// The page retains ownership of `_downloadManager`, `_player`, `_videoError`,
/// loading state, search triggers, and clipboard/snackbar side effects.
class BtResourceList extends StatelessWidget {
  final List<BtResource> resources;
  final bool isExpanded;
  final bool isLoading;
  final bool hasError;
  final String? loadingMagnet;
  final bool isPlayBlocked;
  final VoidCallback onRetrySearch;
  final void Function(BtResource res) onCopyMagnet;
  final void Function(BtResource res) onDownload;
  final void Function(BtResource res) onPlay;

  const BtResourceList({
    super.key,
    required this.resources,
    required this.isExpanded,
    required this.isLoading,
    required this.hasError,
    required this.loadingMagnet,
    required this.isPlayBlocked,
    required this.onRetrySearch,
    required this.onCopyMagnet,
    required this.onDownload,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1E1E2C)
        : theme.colorScheme.surfaceContainer;
    final borderColor = isDark
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);
    final mutedTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final faintTextColor = isDark
        ? Colors.white38
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
    final faintIconColor = isDark
        ? Colors.white24
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    final btCount = resources.length;
    final btStatusBar = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                isLoading
                    ? '正在搜索BT源...'
                    : (btCount > 0
                          ? '已找到 $btCount 个BT源'
                          : (hasError ? 'BT搜索失败' : '尚未开始搜索BT源')),
                style: TextStyle(
                  color: hasError && btCount == 0
                      ? Colors.redAccent
                      : mutedTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (resources.isEmpty) {
      if (isLoading) return const SizedBox.shrink(); // Loader is in tab
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          btStatusBar,
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.search_off, color: faintIconColor, size: 32),
                const SizedBox(height: 8),
                Text(
                  '尚未开始搜索BT源',
                  style: TextStyle(color: faintTextColor, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  '点击下方按钮开始搜索',
                  style: TextStyle(color: faintIconColor, fontSize: 11),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onRetrySearch,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('搜索BT源', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white12
                        : Colors.grey.withValues(alpha: 0.2),
                    foregroundColor: isDark
                        ? Colors.white70
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        btStatusBar,
        ...resources.map(
          (res) => _BtResourceCard(
            resource: res,
            isDark: isDark,
            theme: theme,
            cardColor: cardColor,
            borderColor: borderColor,
            loadingMagnet: loadingMagnet,
            isPlayBlocked: isPlayBlocked,
            onCopyMagnet: () => onCopyMagnet(res),
            onDownload: () => onDownload(res),
            onPlay: () => onPlay(res),
          ),
        ),
      ],
    );
  }
}

class _BtResourceCard extends StatelessWidget {
  final BtResource resource;
  final bool isDark;
  final ThemeData theme;
  final Color cardColor;
  final Color borderColor;
  final String? loadingMagnet;
  final bool isPlayBlocked;
  final VoidCallback onCopyMagnet;
  final VoidCallback onDownload;
  final VoidCallback onPlay;

  const _BtResourceCard({
    required this.resource,
    required this.isDark,
    required this.theme,
    required this.cardColor,
    required this.borderColor,
    required this.loadingMagnet,
    required this.isPlayBlocked,
    required this.onCopyMagnet,
    required this.onDownload,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final title = resource.title;
    final magnet = resource.magnet;
    final size = resource.size;
    final time = resource.time;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          buildBtTagsRow(title),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  size,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: onCopyMagnet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy,
                        size: 12,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '复制',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onDownload,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.download,
                        size: 12,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '下载',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: isPlayBlocked ? null : onPlay,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPlayBlocked
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      if (loadingMagnet == magnet)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      else
                        const Icon(
                          Icons.play_arrow,
                          size: 12,
                          color: Colors.white,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        loadingMagnet == magnet ? '加载中' : '播放',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
