import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_progress_item.dart';

/// View model for one concurrent extraction / captcha / worker row.
class PlayerWebViewTaskRow {
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? affinityLine;
  final bool isBusy;
  final bool highlightAffinity;

  const PlayerWebViewTaskRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.affinityLine,
    this.isBusy = true,
    this.highlightAffinity = false,
  });
}

/// Online / sample source panel (search progress, webview tasks, play list).
class PlayerSampleSourcePanel extends StatelessWidget {
  final bool isLoadingSample;
  final String? sampleError;
  final List<String> enabledSourceNames;
  final Map<String, SourceSearchProgress> sourceProgressMap;
  final List<SearchPlayResult> successfulSources;
  final int selectedSourceIndex;
  final String? sampleVideoUrl;
  final ValueNotifier<String> statusMessageListenable;
  final bool disableAutoSourceSearchForCurrentEpisode;
  final bool autoSearchOnline;
  final bool hasActiveWebViewTasks;
  final int activeWebViewTaskCount;
  final int maxConcurrentWebViews;
  final String? workerPoolLabel;
  final String webviewStatsLabel;
  final String perSourceStatusLabel;
  final bool showWebView;
  final ValueChanged<bool> onShowWebViewChanged;
  final bool useWorkerPool;
  final ValueChanged<bool> onUseWorkerPoolChanged;
  final List<PlayerWebViewTaskRow> activeTaskRows;
  final ValueChanged<int> onSourceSelected;
  final VoidCallback? onPlaySelected;
  final VoidCallback onManualSearch;

  const PlayerSampleSourcePanel({
    super.key,
    required this.isLoadingSample,
    required this.sampleError,
    required this.enabledSourceNames,
    required this.sourceProgressMap,
    required this.successfulSources,
    required this.selectedSourceIndex,
    required this.sampleVideoUrl,
    required this.statusMessageListenable,
    required this.disableAutoSourceSearchForCurrentEpisode,
    required this.autoSearchOnline,
    required this.hasActiveWebViewTasks,
    required this.activeWebViewTaskCount,
    required this.maxConcurrentWebViews,
    required this.workerPoolLabel,
    required this.webviewStatsLabel,
    required this.perSourceStatusLabel,
    required this.showWebView,
    required this.onShowWebViewChanged,
    required this.useWorkerPool,
    required this.onUseWorkerPoolChanged,
    required this.activeTaskRows,
    required this.onSourceSelected,
    required this.onPlaySelected,
    required this.onManualSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;
    final outline = isDark ? Colors.white10 : theme.colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (isLoadingSample) ...[
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
                child: ValueListenableBuilder<String>(
                  valueListenable: statusMessageListenable,
                  builder: (context, statusMessage, _) {
                    final summaryText = enabledSourceNames.isEmpty
                        ? (disableAutoSourceSearchForCurrentEpisode
                              ? '已播放本地资源，在线源搜索待手动触发'
                              : (!autoSearchOnline
                                    ? '在线搜索已关闭，可手动搜索在线源'
                                    : '尚未开始搜索在线源'))
                        : '搜索完成 (${successfulSources.length}/${enabledSourceNames.length} 个可用)';

                    final displayText = isLoadingSample
                        ? statusMessage
                        : (sampleError != null ? '搜索失败' : summaryText);

                    return Text(
                      displayText,
                      style: TextStyle(
                        color: sampleError != null ? Colors.redAccent : muted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (sampleError != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sampleError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (enabledSourceNames.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: enabledSourceNames.length,
              itemBuilder: (context, index) {
                final sourceName = enabledSourceNames[index];
                final progress = sourceProgressMap[sourceName];
                return PlayerSourceProgressItem(
                  sourceName: sourceName,
                  progress: progress,
                );
              },
            ),
          ),
        ],
        if (hasActiveWebViewTasks) ...[
          Divider(color: outline),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black26
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workerPoolLabel == null
                      ? '并发WebView任务 ($activeWebViewTaskCount/$maxConcurrentWebViews)'
                      : '并发WebView任务 ($activeWebViewTaskCount/$maxConcurrentWebViews) · $workerPoolLabel',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    webviewStatsLabel,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 8,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'per-source [p|a|c]: $perSourceStatusLabel',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 8,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                ...activeTaskRows.map(
                  (row) => _ActiveTaskRowWidget(
                    row: row,
                    labelColor: isDark
                        ? Colors.white54
                        : theme.colorScheme.onSurfaceVariant,
                    mutedColor: isDark
                        ? Colors.white24
                        : theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: showWebView,
                    onChanged: (v) => onShowWebViewChanged(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('显示 WebView (调试)', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: useWorkerPool,
                    onChanged: (v) => onUseWorkerPoolChanged(v ?? true),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '统一 Worker 调度 (Round 7)',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
        if (successfulSources.isNotEmpty) ...[
          Divider(color: outline),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '可用源 (${successfulSources.length})',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(successfulSources.length, (index) {
                  final source = successfulSources[index];
                  final isSelected = index == selectedSourceIndex;
                  return GestureDetector(
                    onTap: () => onSourceSelected(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : (isDark
                                  ? Colors.black26
                                  : theme.colorScheme.surfaceContainerHigh),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (isDark
                                      ? Colors.white38
                                      : theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        source.sourceName,
                                        style: TextStyle(
                                          color: isSelected
                                              ? (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                              : (isDark
                                                    ? Colors.white70
                                                    : Colors.grey),
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (source.channelName != null &&
                                        source.channelName!.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFBB86FC,
                                          ).withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: Text(
                                          source.channelName!,
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  source.directVideoUrl ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: sampleVideoUrl != null ? onPlaySelected : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    _playButtonLabel(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(36),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (enabledSourceNames.isEmpty && !isLoadingSample)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  color: isDark
                      ? Colors.white24
                      : Colors.grey.withValues(alpha: 0.5),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  disableAutoSourceSearchForCurrentEpisode
                      ? '已使用本地资源播放'
                      : (!autoSearchOnline ? '在线搜索已关闭' : '尚未开始搜索在线源'),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  disableAutoSourceSearchForCurrentEpisode
                      ? '如需在线源，请点击下方按钮手动搜索'
                      : (!autoSearchOnline ? '点击下方按钮手动搜索在线源' : '点击下方按钮开始搜索'),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onManualSearch,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('搜索在线源', style: TextStyle(fontSize: 12)),
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

  String _playButtonLabel() {
    if (successfulSources.isEmpty) return '播放 - ';
    final idx = selectedSourceIndex.clamp(0, successfulSources.length - 1);
    final source = successfulSources[idx];
    if (source.channelName != null) {
      return '播放 - ${source.sourceName}(${source.channelName})';
    }
    return '播放 - ${source.sourceName}';
  }
}

class _ActiveTaskRowWidget extends StatelessWidget {
  final PlayerWebViewTaskRow row;
  final Color labelColor;
  final Color mutedColor;

  const _ActiveTaskRowWidget({
    required this.row,
    required this.labelColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: row.isBusy
                ? CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF888888),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.title,
                        style: TextStyle(
                          color: row.isBusy ? labelColor : mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if ((row.trailing ?? '').isNotEmpty)
                      Text(
                        row.trailing!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
                if ((row.subtitle ?? '').isNotEmpty)
                  Text(
                    row.subtitle!,
                    style: const TextStyle(color: Colors.grey, fontSize: 8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if ((row.affinityLine ?? '').isNotEmpty)
                  Text(
                    row.affinityLine!,
                    style: TextStyle(
                      color: row.highlightAffinity
                          ? Theme.of(context).colorScheme.primary
                          : mutedColor,
                      fontSize: 8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
