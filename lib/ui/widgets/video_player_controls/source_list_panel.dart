import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';

// Protocol sentinels compared in settings_panel source subtitle and used as
// the CustomVideoControls default when no label is supplied.
// i18n-ignore: protocol sentinel for unknown source label
const String kPlayerSourceLabelUnknown = '未知';

// Protocol sentinel written by PlayerPlaybackController when nothing is
// playing. Display layer maps it via [displayPlayerSourceLabel].
// i18n-ignore: protocol sentinel for not-playing source label
const String kPlayerSourceLabelNotPlaying = '未播放';

/// Maps internal source-label sentinels to locale-aware display text.
///
/// Real source/channel names pass through unchanged. Sentinels stay as fixed
/// protocol tokens in non-UI layers so comparisons remain stable across locales.
String displayPlayerSourceLabel(AppLocalizations l10n, String label) {
  final trimmed = label.trim();
  if (trimmed == kPlayerSourceLabelUnknown) {
    return l10n.selectedSourceUnknown;
  }
  if (trimmed == kPlayerSourceLabelNotPlaying) {
    return l10n.notPlaying;
  }
  return label;
}

String sourceDisplayLabel(SearchPlayResult source) {
  final channelName = source.channelName;
  if (channelName != null && channelName.isNotEmpty) {
    return '${source.sourceName}($channelName)';
  }
  return source.sourceName;
}

int clampSourceIndex(int index, List<SearchPlayResult> sources) {
  if (sources.isEmpty) return 0;
  return index.clamp(0, sources.length - 1);
}

List<SearchPlayResult> resolveAvailableSourcesSnapshot({
  required List<SearchPlayResult> availableSources,
  ValueListenable<List<SearchPlayResult>>? availableSourcesListenable,
}) {
  return availableSourcesListenable?.value ?? availableSources;
}

String resolveCurrentSourceLabelSnapshot({
  required String currentSourceLabel,
  ValueListenable<String>? currentSourceLabelListenable,
}) {
  return currentSourceLabelListenable?.value ?? currentSourceLabel;
}

int resolveSourceIndexSnapshot({
  required ValueNotifier<int>? sourceIndexNotifier,
  int fallback = 0,
}) {
  return sourceIndexNotifier?.value ?? fallback;
}

int? resolveActiveOnlineSourceIndex(
  List<SearchPlayResult> sources,
  String currentSourceLabel,
) {
  if (sources.isEmpty) {
    return null;
  }

  final currentLabel = currentSourceLabel.trim();
  if (currentLabel.isNotEmpty) {
    final exactMatchIndex = sources.indexWhere(
      (source) => sourceDisplayLabel(source) == currentLabel,
    );
    if (exactMatchIndex >= 0) {
      return exactMatchIndex;
    }

    final sourceNameMatchIndex = sources.indexWhere(
      (source) => source.sourceName == currentLabel,
    );
    if (sourceNameMatchIndex >= 0) {
      return sourceNameMatchIndex;
    }
  }

  return null;
}

class SourceListPanel extends StatefulWidget {
  final List<SearchPlayResult> availableSources;
  final ValueListenable<List<SearchPlayResult>>? availableSourcesListenable;
  final ValueNotifier<int>? sourceIndexNotifier;
  final String currentSourceLabel;
  final ValueListenable<String>? currentSourceLabelListenable;
  final ValueChanged<int> onSourceSelected;
  final ScrollController? scrollController;

  const SourceListPanel({
    super.key,
    required this.availableSources,
    this.availableSourcesListenable,
    this.sourceIndexNotifier,
    required this.currentSourceLabel,
    this.currentSourceLabelListenable,
    required this.onSourceSelected,
    this.scrollController,
  });

  @override
  State<SourceListPanel> createState() => _SourceListPanelState();
}

class _SourceListPanelState extends State<SourceListPanel> {
  late List<SearchPlayResult> _availableSources;
  late String _currentSourceLabel;
  late int _currentSourceIndex;

  void _syncFromWidget() {
    _availableSources = resolveAvailableSourcesSnapshot(
      availableSources: widget.availableSources,
      availableSourcesListenable: widget.availableSourcesListenable,
    );
    _currentSourceLabel = resolveCurrentSourceLabelSnapshot(
      currentSourceLabel: widget.currentSourceLabel,
      currentSourceLabelListenable: widget.currentSourceLabelListenable,
    );
    _currentSourceIndex = clampSourceIndex(
      resolveSourceIndexSnapshot(
        sourceIndexNotifier: widget.sourceIndexNotifier,
      ),
      _availableSources,
    );
  }

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
    widget.sourceIndexNotifier?.addListener(_onSourceIndexChanged);
    widget.availableSourcesListenable?.addListener(_onAvailableSourcesChanged);
    widget.currentSourceLabelListenable?.addListener(
      _onCurrentSourceLabelChanged,
    );
  }

  @override
  void didUpdateWidget(SourceListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourceIndexNotifier != oldWidget.sourceIndexNotifier) {
      oldWidget.sourceIndexNotifier?.removeListener(_onSourceIndexChanged);
      widget.sourceIndexNotifier?.addListener(_onSourceIndexChanged);
      _currentSourceIndex = clampSourceIndex(
        resolveSourceIndexSnapshot(
          sourceIndexNotifier: widget.sourceIndexNotifier,
        ),
        _availableSources,
      );
    }
    if (widget.availableSourcesListenable !=
        oldWidget.availableSourcesListenable) {
      oldWidget.availableSourcesListenable?.removeListener(
        _onAvailableSourcesChanged,
      );
      widget.availableSourcesListenable?.addListener(
        _onAvailableSourcesChanged,
      );
      _availableSources = resolveAvailableSourcesSnapshot(
        availableSources: widget.availableSources,
        availableSourcesListenable: widget.availableSourcesListenable,
      );
      _currentSourceIndex = clampSourceIndex(
        _currentSourceIndex,
        _availableSources,
      );
    }
    if (widget.currentSourceLabelListenable !=
        oldWidget.currentSourceLabelListenable) {
      oldWidget.currentSourceLabelListenable?.removeListener(
        _onCurrentSourceLabelChanged,
      );
      widget.currentSourceLabelListenable?.addListener(
        _onCurrentSourceLabelChanged,
      );
      _currentSourceLabel = resolveCurrentSourceLabelSnapshot(
        currentSourceLabel: widget.currentSourceLabel,
        currentSourceLabelListenable: widget.currentSourceLabelListenable,
      );
    }
    if (!identical(widget.availableSources, oldWidget.availableSources)) {
      _availableSources = resolveAvailableSourcesSnapshot(
        availableSources: widget.availableSources,
        availableSourcesListenable: widget.availableSourcesListenable,
      );
      _currentSourceIndex = clampSourceIndex(
        _currentSourceIndex,
        _availableSources,
      );
    }
    if (widget.currentSourceLabel != oldWidget.currentSourceLabel) {
      _currentSourceLabel = resolveCurrentSourceLabelSnapshot(
        currentSourceLabel: widget.currentSourceLabel,
        currentSourceLabelListenable: widget.currentSourceLabelListenable,
      );
    }
  }

  @override
  void dispose() {
    widget.sourceIndexNotifier?.removeListener(_onSourceIndexChanged);
    widget.availableSourcesListenable?.removeListener(
      _onAvailableSourcesChanged,
    );
    widget.currentSourceLabelListenable?.removeListener(
      _onCurrentSourceLabelChanged,
    );
    super.dispose();
  }

  void _onSourceIndexChanged() {
    setState(() {
      _currentSourceIndex = clampSourceIndex(
        widget.sourceIndexNotifier!.value,
        _availableSources,
      );
    });
  }

  void _onAvailableSourcesChanged() {
    final nextSources =
        widget.availableSourcesListenable?.value ?? widget.availableSources;
    setState(() {
      _availableSources = nextSources;
      _currentSourceIndex = clampSourceIndex(
        _currentSourceIndex,
        _availableSources,
      );
    });
  }

  void _onCurrentSourceLabelChanged() {
    setState(() {
      _currentSourceLabel =
          widget.currentSourceLabelListenable?.value ??
          widget.currentSourceLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white54
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final hintTextColor = isDark
        ? Colors.white38
        : Theme.of(context).colorScheme.outline;
    final unselectedIconColor = isDark
        ? Colors.white54
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final unselectedBgColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final unselectedIconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final emptyIconColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.15);

    if (_availableSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_outlined, size: 64, color: emptyIconColor),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).noAvailablePlaybackSource,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _availableSources.length,
      itemBuilder: (context, index) {
        final source = _availableSources[index];
        final activeOnlineSourceIndex = resolveActiveOnlineSourceIndex(
          _availableSources,
          _currentSourceLabel,
        );
        final isSelected = activeOnlineSourceIndex != null
            ? index == activeOnlineSourceIndex
            : false;

        return InkWell(
          onTap: () {
            setState(() {
              _currentSourceIndex = index;
            });
            widget.onSourceSelected(index);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.15)
                  : unselectedBgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2)
                        : unselectedIconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_circle_outline,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : unselectedIconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              source.sourceName,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : textColor,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (source.channelName != null &&
                              source.channelName!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                source.channelName!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (source.directVideoUrl != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          source.directVideoUrl!,
                          style: TextStyle(color: hintTextColor, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
