import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';

/// 设置面板组件 - 支持一级菜单导航
class SettingsPanel extends StatefulWidget {
  final bool isFullscreen;
  final DanmakuService danmakuService;
  final SubtitleService subtitleService;
  final List<SearchPlayResult> availableSources;
  final ValueListenable<List<SearchPlayResult>>? availableSourcesListenable;
  final ValueNotifier<int>? sourceIndexNotifier;
  final String currentSourceLabel;
  final ValueListenable<String>? currentSourceLabelListenable;
  final Function(int) onSourceSelected;
  final bool isAutoPlayNextEnabled;
  final VoidCallback onToggleAutoPlayNext;
  final double playbackSpeed;
  final ValueChanged<double> onPlaybackSpeedChanged;
  final ScrollController? scrollController;

  const SettingsPanel({
    super.key,
    required this.isFullscreen,
    required this.danmakuService,
    required this.subtitleService,
    required this.availableSources,
    this.availableSourcesListenable,
    this.sourceIndexNotifier,
    required this.currentSourceLabel,
    this.currentSourceLabelListenable,
    required this.onSourceSelected,
    required this.isAutoPlayNextEnabled,
    required this.onToggleAutoPlayNext,
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
    this.scrollController,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  // 0: 主菜单, 1: 弹幕设置, 2: 字幕设置, 3: 播放源, 4: 播放速度
  int _currentPage = 0;
  late int _currentSourceIndex;
  late double _currentPlaybackSpeed;
  late List<SearchPlayResult> _availableSources;
  late String _currentSourceLabel;

  static const List<double> _playbackSpeedPresets = <double>[
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.5,
    3.0,
  ];

  @override
  void initState() {
    super.initState();
    _availableSources = widget.availableSources;
    _currentSourceLabel = widget.currentSourceLabel;
    _currentSourceIndex = widget.sourceIndexNotifier?.value ?? 0;
    _currentPlaybackSpeed = widget.playbackSpeed.clamp(0.25, 3.0).toDouble();
    widget.sourceIndexNotifier?.addListener(_onSourceIndexChanged);
    widget.availableSourcesListenable?.addListener(_onAvailableSourcesChanged);
    widget.currentSourceLabelListenable?.addListener(
      _onCurrentSourceLabelChanged,
    );
  }

  @override
  void didUpdateWidget(SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourceIndexNotifier != oldWidget.sourceIndexNotifier) {
      oldWidget.sourceIndexNotifier?.removeListener(_onSourceIndexChanged);
      widget.sourceIndexNotifier?.addListener(_onSourceIndexChanged);
      _currentSourceIndex = widget.sourceIndexNotifier?.value ?? 0;
    }
    if (widget.availableSourcesListenable !=
        oldWidget.availableSourcesListenable) {
      oldWidget.availableSourcesListenable?.removeListener(
        _onAvailableSourcesChanged,
      );
      widget.availableSourcesListenable?.addListener(
        _onAvailableSourcesChanged,
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
    }
    if (!identical(widget.availableSources, oldWidget.availableSources)) {
      _availableSources = widget.availableSources;
      _currentSourceIndex = _clampSourceIndex(
        _currentSourceIndex,
        _availableSources,
      );
    }
    if (widget.currentSourceLabel != oldWidget.currentSourceLabel) {
      _currentSourceLabel = widget.currentSourceLabel;
    }
    if ((widget.playbackSpeed - oldWidget.playbackSpeed).abs() > 0.001) {
      _currentPlaybackSpeed = widget.playbackSpeed.clamp(0.25, 3.0).toDouble();
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
      _currentSourceIndex = _clampSourceIndex(
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
      _currentSourceIndex = _clampSourceIndex(
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

  int _clampSourceIndex(int index, List<SearchPlayResult> sources) {
    if (sources.isEmpty) return 0;
    return index.clamp(0, sources.length - 1);
  }

  String _sourceDisplayLabel(SearchPlayResult source) {
    final channelName = source.channelName;
    if (channelName != null && channelName.isNotEmpty) {
      return '${source.sourceName}($channelName)';
    }
    return source.sourceName;
  }

  int? _resolveActiveOnlineSourceIndex() {
    if (_availableSources.isEmpty) {
      return null;
    }

    final currentLabel = _currentSourceLabel.trim();
    if (currentLabel.isNotEmpty) {
      final exactMatchIndex = _availableSources.indexWhere(
        (source) => _sourceDisplayLabel(source) == currentLabel,
      );
      if (exactMatchIndex >= 0) {
        return exactMatchIndex;
      }

      final sourceNameMatchIndex = _availableSources.indexWhere(
        (source) => source.sourceName == currentLabel,
      );
      if (sourceNameMatchIndex >= 0) {
        return sourceNameMatchIndex;
      }
    }

    return null;
  }

  String _buildSourceMenuSubtitle() {
    final activeOnlineSourceIndex = _resolveActiveOnlineSourceIndex();
    if (activeOnlineSourceIndex != null) {
      return '${_sourceDisplayLabel(_availableSources[activeOnlineSourceIndex])} (${_availableSources.length}个可用)';
    }

    final currentLabel = _currentSourceLabel.trim();
    if (currentLabel.isNotEmpty &&
        currentLabel != '未知' &&
        currentLabel != '未播放') {
      return _availableSources.isEmpty
          ? '当前：$currentLabel'
          : '当前：$currentLabel (${_availableSources.length}个在线源可切换)';
    }

    if (_availableSources.isNotEmpty) {
      final fallbackIndex = _clampSourceIndex(
        _currentSourceIndex,
        _availableSources,
      );
      return '${_sourceDisplayLabel(_availableSources[fallbackIndex])} (${_availableSources.length}个可用)';
    }

    return '暂无可用源';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBgColor = isDark
        ? const Color(0xFF1A1A24)
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final dragIndicatorColor = isDark ? Colors.white30 : Colors.black26;
    final dividerColor = isDark
        ? Colors.white12
        : Theme.of(context).colorScheme.outlineVariant;

    return Container(
      width: widget.isFullscreen ? 320 : double.infinity,
      height: widget.isFullscreen ? double.infinity : null,
      decoration: BoxDecoration(
        color: panelBgColor,
        borderRadius: widget.isFullscreen
            ? const BorderRadius.horizontal(left: Radius.circular(16))
            : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        left: false,
        right: widget.isFullscreen,
        bottom: !widget.isFullscreen,
        child: Column(
          children: [
            // 非全屏时显示拖动指示器
            if (!widget.isFullscreen)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: dragIndicatorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // 标题栏
            _buildHeader(),
            Divider(color: dividerColor, height: 1),
            // 内容区域
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final iconColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    String title;
    switch (_currentPage) {
      case 1:
        title = '弹幕设置';
        break;
      case 2:
        title = '字幕设置';
        break;
      case 3:
        title = '播放源';
        break;
      case 4:
        title = '播放速度';
        break;
      default:
        title = '设置';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (_currentPage != 0)
            IconButton(
              onPressed: () => setState(() => _currentPage = 0),
              icon: Icon(Icons.arrow_back, color: iconColor, size: 20),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentPage) {
      case 1:
        return DanmakuSettingsBottomSheet(
          danmakuService: widget.danmakuService,
          scrollController:
              widget.scrollController ?? createPlatformScrollController(),
        );
      case 2:
        return _buildSubtitleSettings();
      case 3:
        return _buildSourceList();
      case 4:
        return _buildPlaybackSpeedSettings();
      default:
        return _buildMainMenu();
    }
  }

  Widget _buildMainMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 获取字幕状态描述
    String subtitleStatus;
    if (widget.subtitleService.hasSubtitles) {
      if (widget.subtitleService.isSubtitleVisible) {
        final currentTrack = widget.subtitleService.currentTrack;
        subtitleStatus = currentTrack != null
            ? widget.subtitleService.getTrackDisplayName(currentTrack)
            : '已开启';
      } else {
        subtitleStatus = '已关闭';
      }
    } else {
      subtitleStatus = '暂无字幕';
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildMenuItem(
          icon: Icons.comment_outlined,
          title: '弹幕设置',
          subtitle: widget.danmakuService.settings.enabled ? '已开启' : '已关闭',
          onTap: () => setState(() => _currentPage = 1),
        ),
        _buildMenuItem(
          icon: Icons.subtitles_outlined,
          title: '字幕设置',
          subtitle: subtitleStatus,
          onTap: () => setState(() => _currentPage = 2),
        ),
        _buildMenuItem(
          icon: Icons.speed,
          title: '播放速度',
          subtitle: _formatPlaybackSpeed(
            _currentPlaybackSpeed,
            includeNormalTag: true,
          ),
          onTap: () => setState(() => _currentPage = 4),
        ),
        _buildMenuItem(
          icon: Icons.video_library_outlined,
          title: '播放源',
          subtitle: _buildSourceMenuSubtitle(),
          onTap: () => setState(() => _currentPage = 3),
        ),
        const SizedBox(height: 16),
        Divider(
          color: isDark
              ? Colors.white12
              : Theme.of(context).colorScheme.outlineVariant,
          height: 1,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSwitchRow(
            title: '自动连播',
            value: widget.isAutoPlayNextEnabled,
            onChanged: (v) => widget.onToggleAutoPlayNext(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackSpeedSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final hintColor = isDark
        ? Colors.white38
        : Theme.of(context).colorScheme.outline;

    final speed = _currentPlaybackSpeed.clamp(0.25, 3.0).toDouble();
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: [
        _buildSliderRow(
          title: '播放速度',
          value: speed,
          min: 0.25,
          max: 3.0,
          divisions: 55,
          displayValue: _formatPlaybackSpeed(speed, includeNormalTag: true),
          onChanged: _updatePlaybackSpeed,
        ),
        const SizedBox(height: 16),
        Text(
          '常用倍速',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: _playbackSpeedPresets.map((preset) {
            final isSelected = (speed - preset).abs() < 0.001;
            return _buildTrackItem(
              title: _formatPlaybackSpeed(preset),
              subtitle: (preset - 1.0).abs() < 0.001 ? '正常速度' : '',
              isSelected: isSelected,
              onTap: () => _updatePlaybackSpeed(preset),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          '提示：播放速度会同时影响视频与弹幕的时间同步。',
          style: TextStyle(color: hintColor, fontSize: 12),
        ),
      ],
    );
  }

  void _updatePlaybackSpeed(double value) {
    final stepped = ((value * 20).round() / 20.0).clamp(0.25, 3.0).toDouble();
    if ((stepped - _currentPlaybackSpeed).abs() < 0.001) return;
    setState(() {
      _currentPlaybackSpeed = stepped;
    });
    widget.onPlaybackSpeedChanged(stepped);
  }

  String _formatPlaybackSpeed(double value, {bool includeNormalTag = false}) {
    final speed = value.clamp(0.25, 3.0).toDouble();
    final scaled = (speed * 100).round();
    final text = scaled % 10 == 0
        ? speed.toStringAsFixed(1)
        : speed.toStringAsFixed(2);
    final label = '${text}x';
    if (includeNormalTag && (speed - 1.0).abs() < 0.001) {
      return '$label (正常)';
    }
    return label;
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final iconColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final subTextColor = isDark
        ? Colors.white54
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final chevronColor = isDark
        ? Colors.white38
        : Theme.of(context).colorScheme.outline;
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleSettings() {
    return ListenableBuilder(
      listenable: widget.subtitleService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dividerColor = isDark
            ? Colors.white12
            : Theme.of(context).colorScheme.outlineVariant;
        final sectionLabelColor = isDark
            ? Colors.white70
            : Theme.of(context).colorScheme.onSurfaceVariant;
        final hintColor = isDark
            ? Colors.white38
            : Theme.of(context).colorScheme.outline;
        final emptyIconColor = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.15);
        final previewBgColor = isDark ? Colors.black : Colors.white;

        final service = widget.subtitleService;
        final settings = service.settings;
        final hasSubtitles = service.hasSubtitles;
        final actualTracks = service.actualSubtitleTracks;

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          children: [
            // 字幕开关
            _buildSwitchRow(
              title: '显示字幕',
              value: settings.enabled,
              onChanged: hasSubtitles ? (v) => service.setEnabled(v) : null,
            ),

            const SizedBox(height: 16),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 16),

            // 字幕轨道选择
            Text(
              '字幕轨道',
              style: TextStyle(
                color: sectionLabelColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            if (!hasSubtitles)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.subtitles_off_outlined,
                      size: 48,
                      color: emptyIconColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '当前视频没有内嵌字幕',
                      style: TextStyle(color: hintColor, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...actualTracks.map((track) {
                final isSelected = service.currentTrack?.id == track.id;
                return _buildTrackItem(
                  title: service.getTrackDisplayName(track),
                  subtitle: track.language ?? '',
                  isSelected: isSelected,
                  onTap: () => service.selectTrack(track),
                );
              }),

            // 关闭字幕选项
            if (hasSubtitles)
              _buildTrackItem(
                title: '关闭字幕',
                subtitle: '',
                isSelected: !service.isSubtitleVisible,
                onTap: () => service.disableSubtitle(),
              ),

            const SizedBox(height: 16),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 16),

            // 字幕样式设置
            Text(
              '字幕样式',
              style: TextStyle(
                color: sectionLabelColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // 字体大小滑块
            _buildSliderRow(
              title: '字体大小',
              value: settings.fontSize,
              min: 12,
              max: 48,
              divisions: 18,
              displayValue: '${settings.fontSize.round()}',
              onChanged: (v) => service.setFontSize(v),
            ),

            const SizedBox(height: 12),

            // 背景透明度滑块
            _buildSliderRow(
              title: '背景透明度',
              value: settings.backgroundOpacity,
              min: 0,
              max: 1,
              divisions: 10,
              displayValue: '${(settings.backgroundOpacity * 100).round()}%',
              onChanged: (v) => service.setBackgroundOpacity(v),
            ),

            const SizedBox(height: 12),

            // 底部边距滑块
            _buildSliderRow(
              title: '底部边距',
              value: settings.bottomPadding,
              min: 0,
              max: 150,
              divisions: 15,
              displayValue: '${settings.bottomPadding.round()}',
              onChanged: (v) => service.setBottomPadding(v),
            ),

            const SizedBox(height: 12),

            // 描边宽度滑块
            _buildSliderRow(
              title: '描边宽度',
              value: settings.outlineWidth,
              min: 0,
              max: 4,
              divisions: 8,
              displayValue: settings.outlineWidth.toStringAsFixed(1),
              onChanged: (v) => service.setOutlineWidth(v),
            ),

            const SizedBox(height: 16),

            // 字体颜色选择
            Builder(
              builder: (context) {
                final sectionLabelColor =
                    Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Theme.of(context).colorScheme.onSurfaceVariant;
                return Text(
                  '字体颜色',
                  style: TextStyle(
                    color: sectionLabelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SubtitleColorPresets.fontColors.map((color) {
                final isSelected =
                    settings.fontColor.toARGB32() == color.toARGB32();
                return _buildColorOption(
                  color: color,
                  isSelected: isSelected,
                  onTap: () => service.setFontColor(color),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // 预览
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: previewBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('字幕预览效果', style: settings.toTextStyle()),
              ),
            ),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final inactiveTrackColor = isDark
        ? Colors.white24
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: textColor, fontSize: 14)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Theme.of(context).colorScheme.primary,
          inactiveTrackColor: inactiveTrackColor,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final inactiveTrackColor = isDark
        ? Colors.white24
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: textColor, fontSize: 14)),
            Text(
              displayValue,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: inactiveTrackColor,
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackItem({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final unselectedBgColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final unselectedBorderColor = isDark
        ? Colors.transparent
        : Colors.transparent;
    final subTextColor = isDark
        ? Colors.white38
        : Theme.of(context).colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : unselectedBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : unselectedBorderColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : textColor,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(color: subTextColor, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBorderColor = isDark ? Colors.white24 : Colors.black26;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : unselectedBorderColor,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildSourceList() {
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
              '暂无可用播放源',
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
        final activeOnlineSourceIndex = _resolveActiveOnlineSourceIndex();
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
