import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_progress_item.dart';

/// View model for one concurrent extraction / captcha / worker row.
class PlayerWebViewTaskRow {
  /// Source name when the worker is busy, otherwise a friendly idle label.
  final String title;

  /// Human-readable stage of this row ("提取中" / "处理验证码" / "准备中"),
  /// rendered as a small chip instead of raw worker/health internals.
  final String statusLabel;

  /// Channel name of the play page being extracted, if the source has one.
  final String? channelName;

  /// Secondary line: play-page host normally, full URL in debug mode.
  final String? subtitle;

  /// Scheduler internals (worker id, health, affinity). Only rendered when the
  /// debug WebView toggle is on.
  final String? debugLine;

  final bool isBusy;

  const PlayerWebViewTaskRow({
    required this.title,
    required this.statusLabel,
    this.channelName,
    this.subtitle,
    this.debugLine,
    this.isBusy = true,
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
  final ScrollController? sourceProgressScrollController;

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
    this.sourceProgressScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                              ? l10n.playerSampleStatusLocalManual
                              : (!autoSearchOnline
                                    ? l10n.playerSampleStatusAutoDisabled
                                    : l10n.playerSampleStatusNotStarted))
                        : l10n.playerSampleStatusCompleted(
                            successfulSources.length,
                            enabledSourceNames.length,
                          );

                    final displayText = isLoadingSample
                        ? statusMessage
                        : (sampleError != null
                              ? l10n.playerSampleStatusFailed
                              : summaryText);

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
              controller: sourceProgressScrollController,
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
                Row(
                  children: [
                    Icon(
                      Icons.travel_explore,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.playerWebViewTaskCount(
                          activeWebViewTaskCount,
                          maxConcurrentWebViews,
                        ),
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (showWebView) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Text(
                      // i18n-ignore: debug WebView worker/stats internals,
                      // not user-facing content
                      '${workerPoolLabel ?? 'legacy'}\n$webviewStatsLabel\n'
                      '${l10n.playerWebViewPerSourceStatus(perSourceStatusLabel)}',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white38
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 8,
                        height: 1.3,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ...activeTaskRows.map(
                  (row) => _ActiveTaskRowWidget(
                    row: row,
                    labelColor: isDark
                        ? Colors.white70
                        : theme.colorScheme.onSurface,
                    mutedColor: isDark
                        ? Colors.white38
                        : theme.colorScheme.outline,
                    showDebugInfo: showWebView,
                  ),
                ),
              ],
            ),
          ),
          _AdvancedOptionsSection(
            showWebView: showWebView,
            onShowWebViewChanged: onShowWebViewChanged,
            useWorkerPool: useWorkerPool,
            onUseWorkerPoolChanged: onUseWorkerPoolChanged,
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
                      l10n.playerWebViewAvailableSources(
                        successfulSources.length,
                      ),
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
                    _playButtonLabel(l10n),
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
                      ? l10n.playerSampleSummaryLocalManual
                      : (!autoSearchOnline
                            ? l10n.playerSampleSummaryAutoDisabled
                            : l10n.playerSampleStatusNotStarted),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  disableAutoSourceSearchForCurrentEpisode
                      ? l10n.playerSampleHintLocalManual
                      : (!autoSearchOnline
                            ? l10n.playerSampleHintAutoDisabled
                            : l10n.playerSampleHintNotStarted),
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
                  label: Text(
                    l10n.searchOnlineSource,
                    style: const TextStyle(fontSize: 12),
                  ),
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

  String _playButtonLabel(AppLocalizations l10n) {
    if (successfulSources.isEmpty) return l10n.playerSamplePlayButtonBase;
    final idx = selectedSourceIndex.clamp(0, successfulSources.length - 1);
    final source = successfulSources[idx];
    if (source.channelName != null) {
      return l10n.playerSamplePlayButtonWithChannel(
        source.sourceName,
        source.channelName!,
      );
    }
    return l10n.playerSamplePlayButtonWithSource(source.sourceName);
  }
}

/// Collapsed-by-default host for developer-facing toggles so the normal
/// search view stays free of debug chrome.
class _AdvancedOptionsSection extends StatefulWidget {
  final bool showWebView;
  final ValueChanged<bool> onShowWebViewChanged;
  final bool useWorkerPool;
  final ValueChanged<bool> onUseWorkerPoolChanged;

  const _AdvancedOptionsSection({
    required this.showWebView,
    required this.onShowWebViewChanged,
    required this.useWorkerPool,
    required this.onUseWorkerPoolChanged,
  });

  @override
  State<_AdvancedOptionsSection> createState() =>
      _AdvancedOptionsSectionState();
}

class _AdvancedOptionsSectionState extends State<_AdvancedOptionsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 14,
                    color: muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.playerWebViewAdvancedOptions,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            _buildToggle(
              value: widget.showWebView,
              onChanged: widget.onShowWebViewChanged,
              label: l10n.playerWebViewShowDebug,
            ),
            _buildToggle(
              value: widget.useWorkerPool,
              onChanged: widget.onUseWorkerPoolChanged,
              label: l10n.playerWebViewWorkerPoolSwitch,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }
}

class _ActiveTaskRowWidget extends StatelessWidget {
  final PlayerWebViewTaskRow row;
  final Color labelColor;
  final Color mutedColor;
  final bool showDebugInfo;

  const _ActiveTaskRowWidget({
    required this.row,
    required this.labelColor,
    required this.mutedColor,
    required this.showDebugInfo,
  });

  String? _visibleSubtitle() {
    final subtitle = row.subtitle;
    if (subtitle == null || subtitle.isEmpty || showDebugInfo) {
      return subtitle;
    }

    final uri = Uri.tryParse(subtitle);
    if (uri == null) return subtitle;
    if (uri.host.isNotEmpty) return uri.host;
    return uri.path.isNotEmpty ? uri.path : subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final subtitle = _visibleSubtitle();

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
                    color: theme.colorScheme.primary,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: row.isBusy
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : mutedColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        row.statusLabel,
                        style: TextStyle(
                          color: row.isBusy
                              ? theme.colorScheme.primary
                              : mutedColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (row.channelName != null && row.channelName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          l10n.playerSampleSourceChannelName(row.channelName!),
                          style: TextStyle(color: mutedColor, fontSize: 9),
                        ),
                      ),
                  ],
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (showDebugInfo &&
                    row.debugLine != null &&
                    row.debugLine!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      row.debugLine!,
                      style: TextStyle(color: mutedColor, fontSize: 8),
                      maxLines: 1,
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
