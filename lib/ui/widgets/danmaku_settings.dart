import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/src/rust/api/danmaku.dart';

/// 移动端底部弹出式弹幕设置面板
class DanmakuSettingsBottomSheet extends StatefulWidget {
  final DanmakuService danmakuService;
  final ScrollController scrollController;

  const DanmakuSettingsBottomSheet({
    super.key,
    required this.danmakuService,
    required this.scrollController,
  });

  @override
  State<DanmakuSettingsBottomSheet> createState() =>
      _DanmakuSettingsBottomSheetState();
}

class _DanmakuSettingsBottomSheetState extends State<DanmakuSettingsBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white10
        : Theme.of(context).colorScheme.outlineVariant;
    final unselectedLabelColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        // Tab 栏
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: unselectedLabelColor,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: l10n.danmakuSettingsDisplayTab),
              Tab(text: l10n.danmakuSettingsSourceTab),
            ],
          ),
        ),
        // 内容区域
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildDisplaySettings(), _buildDanmakuSource()],
          ),
        ),
      ],
    );
  }

  Widget _buildDisplaySettings() {
    return ListenableBuilder(
      listenable: widget.danmakuService,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final settings = widget.danmakuService.settings;
        final dividerColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Theme.of(context).colorScheme.outlineVariant;
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildSwitchTile(
              l10n.danmakuSettingsEnable,
              settings.enabled,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(enabled: value),
              ),
            ),
            Divider(color: dividerColor, height: 1),

            _buildSectionHeader(l10n.danmakuSettingsVisibilitySection),
            _buildSwitchTile(
              l10n.danmakuSettingsScrolling,
              settings.showScrolling,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showScrolling: value),
              ),
            ),
            _buildSwitchTile(
              l10n.danmakuSettingsTop,
              settings.showTop,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showTop: value),
              ),
            ),
            _buildSwitchTile(
              l10n.danmakuSettingsBottom,
              settings.showBottom,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showBottom: value),
              ),
            ),
            Divider(color: dividerColor, height: 1),

            _buildSectionHeader(l10n.danmakuSettingsStyleSection),
            _buildSliderTile(
              l10n.danmakuSettingsOpacity,
              '${(settings.opacity * 100).toInt()}%',
              settings.opacity,
              0.1,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(opacity: value),
              ),
            ),
            _buildSliderTile(
              l10n.fontSize,
              '${settings.fontSize.toInt()}px',
              settings.fontSize,
              14,
              40,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontSize: value),
              ),
            ),
            _buildSliderTile(
              l10n.danmakuSettingsSpeed,
              l10n.danmakuSettingsSpeedValue(settings.speed.toInt()),
              settings.speed,
              4,
              16,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(speed: value),
              ),
            ),
            _buildSliderTile(
              l10n.danmakuSettingsDisplayArea,
              '${(settings.displayArea * 100).toInt()}%',
              settings.displayArea,
              0.25,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(displayArea: value),
              ),
            ),
            _buildSliderTile(
              l10n.danmakuSettingsFontWeight,
              _getFontWeightLabel(l10n, settings.fontWeight),
              settings.fontWeight.toDouble(),
              0,
              8,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontWeight: value.toInt()),
              ),
            ),
            _buildSliderTile(
              l10n.outlineWidth,
              settings.strokeWidth.toStringAsFixed(1),
              settings.strokeWidth,
              0.0,
              5.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(strokeWidth: value),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getFontWeightLabel(AppLocalizations l10n, int weight) {
    switch (weight.clamp(0, 8)) {
      case 0:
        return l10n.danmakuSettingsFontWeightUltraLight;
      case 1:
        return l10n.danmakuSettingsFontWeightExtraLight;
      case 2:
        return l10n.danmakuSettingsFontWeightLight;
      case 3:
        return l10n.danmakuSettingsFontWeightSemiLight;
      case 4:
        return l10n.danmakuSettingsFontWeightRegular;
      case 5:
        return l10n.danmakuSettingsFontWeightSemiBold;
      case 6:
        return l10n.danmakuSettingsFontWeightBold;
      case 7:
        return l10n.danmakuSettingsFontWeightExtraBold;
      case 8:
        return l10n.danmakuSettingsFontWeightBlack;
      default:
        return l10n.danmakuSettingsFontWeightRegular;
    }
  }

  Widget _buildDanmakuSource() {
    return ListenableBuilder(
      listenable: widget.danmakuService,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface;
        final subTextColor = isDark
            ? Colors.white70
            : Theme.of(context).colorScheme.onSurfaceVariant;
        final hintTextColor = isDark
            ? Colors.white38
            : Theme.of(context).colorScheme.outline;
        final fillColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHigh;
        final unselectedEpColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHigh;
        final unselectedEpTextColor = isDark
            ? Colors.white70
            : Theme.of(context).colorScheme.onSurfaceVariant;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchHintText,
                  hintStyle: TextStyle(color: hintTextColor),
                  filled: true,
                  fillColor: fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        widget.danmakuService.searchAnime(
                          _searchController.text,
                        );
                      }
                    },
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    widget.danmakuService.searchAnime(value);
                  }
                },
              ),
            ),
            if (widget.danmakuService.isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (widget.danmakuService.error != null)
              Expanded(
                child: Center(
                  child: Text(
                    widget.danmakuService.error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (widget.danmakuService.danmakuCount > 0) ...[
                      Text(
                        l10n.loadedDanmaku,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLoadedDanmakuInfoCard(context),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.selectedAnime != null) ...[
                      Text(
                        l10n.currentMatch,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSelectedAnimeCard(
                        widget.danmakuService.selectedAnime!,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.searchResults.isNotEmpty) ...[
                      Text(
                        l10n.searchResult,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.danmakuService.searchResults.map(
                        (anime) => _buildAnimeCard(anime),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.episodes.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            l10n.episodeList,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.subtitleTrackCount(
                              widget.danmakuService.episodes.length,
                            ),
                            style: TextStyle(
                              color: hintTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.danmakuService.episodes.map((ep) {
                          final isSelected =
                              widget
                                  .danmakuService
                                  .selectedEpisode
                                  ?.episodeId ==
                              ep.episodeId;
                          return InkWell(
                            onTap: () =>
                                widget.danmakuService.selectEpisode(ep),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 48,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : unselectedEpColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ep.episodeTitle,
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : unselectedEpTextColor,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLoadedDanmakuInfoCard(BuildContext context) {
    final service = widget.danmakuService;
    final count = service.danmakuCount;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    String infoText = '';
    if (service.selectedAnime != null) {
      infoText = service.selectedAnime!.animeTitle;
      if (service.selectedEpisode != null) {
        infoText += ' - ${service.selectedEpisode!.episodeTitle}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.danmakuCount(count),
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (infoText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              infoText,
              style: TextStyle(color: subTextColor, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedAnimeCard(DanmakuAnime anime) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () => widget.danmakuService.selectAnime(anime),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          anime.animeTitle,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimeCard(DanmakuAnime anime) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    return InkWell(
      onTap: () => widget.danmakuService.selectAnime(anime),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              anime.animeTitle,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (anime.typeDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                anime.typeDescription!,
                style: TextStyle(color: subTextColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ),
            SizedBox(
              height: 24,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                activeTrackColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                inactiveThumbColor: isDark
                    ? Colors.grey
                    : Theme.of(context).colorScheme.outline,
                inactiveTrackColor: isDark
                    ? Colors.grey.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String valueText,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final valueTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final thumbColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final inactiveTrackColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: textColor, fontSize: 14)),
              Text(
                valueText,
                style: TextStyle(color: valueTextColor, fontSize: 12),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: inactiveTrackColor,
            thumbColor: thumbColor,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

class VideoSidePanel extends StatefulWidget {
  final DanmakuService danmakuService;
  final VoidCallback? onClose;
  final int initialIndex;

  const VideoSidePanel({
    super.key,
    required this.danmakuService,
    this.onClose,
    this.initialIndex = 0,
  });

  @override
  State<VideoSidePanel> createState() => _VideoSidePanelState();
}

class _VideoSidePanelState extends State<VideoSidePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _displaySettingsScrollController =
      createPlatformScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _displaySettingsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBgColor = isDark
        ? const Color(0xFF13131A).withValues(alpha: 0.95)
        : Theme.of(
            context,
          ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.95);
    final borderColor = isDark
        ? Colors.white10
        : Theme.of(context).colorScheme.outlineVariant;
    final unselectedLabelColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: 320,
      height: double.infinity,
      color: panelBgColor,
      child: Column(
        children: [
          // 顶部 Tab 栏
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: unselectedLabelColor,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      Tab(text: l10n.danmakuSettingsDisplayTab),
                      Tab(text: l10n.danmakuSettingsSourceTab),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 内容区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildDisplaySettings(), _buildDanmakuSource()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplaySettings() {
    return ListenableBuilder(
      listenable: widget.danmakuService,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final settings = widget.danmakuService.settings;
        final dividerColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Theme.of(context).colorScheme.outlineVariant;
        return ListView(
          controller: _displaySettingsScrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildSwitchTile(
              l10n.danmakuSettingsEnable,
              settings.enabled,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(enabled: value),
              ),
            ),
            Divider(color: dividerColor, height: 1),

            _buildSectionHeader(l10n.danmakuSettingsVisibilitySection),
            _buildSwitchTile(
              l10n.danmakuSettingsScrolling,
              settings.showScrolling,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showScrolling: value),
              ),
            ),
            _buildSwitchTile(
              l10n.danmakuSettingsTop,
              settings.showTop,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showTop: value),
              ),
            ),
            _buildSwitchTile(
              l10n.danmakuSettingsBottom,
              settings.showBottom,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showBottom: value),
              ),
            ),
            Divider(color: dividerColor, height: 1),

            _buildSectionHeader(l10n.danmakuSettingsStyleSection),
            _buildSliderTile(
              l10n.danmakuSettingsOpacity,
              '${(settings.opacity * 100).toInt()}%',
              settings.opacity,
              0.1,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(opacity: value),
              ),
            ),
            _buildSliderTile(
              l10n.fontSize,
              '${settings.fontSize.toInt()}px',
              settings.fontSize,
              14,
              40,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontSize: value),
              ),
            ),
            _buildSliderTile(
              l10n.danmakuSettingsSpeed,
              l10n.danmakuSettingsSpeedValue(settings.speed.toInt()),
              settings.speed,
              4,
              16,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(speed: value),
              ),
            ),
            _buildSliderTile(
              l10n.danmakuSettingsDisplayArea,
              '${(settings.displayArea * 100).toInt()}%',
              settings.displayArea,
              0.25,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(displayArea: value),
              ),
            ),
            _buildSliderTile(
              l10n.danmakuSettingsFontWeight,
              _getFontWeightLabel(l10n, settings.fontWeight),
              settings.fontWeight.toDouble(),
              0,
              8,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontWeight: value.toInt()),
              ),
            ),
            _buildSliderTile(
              l10n.outlineWidth,
              settings.strokeWidth.toStringAsFixed(1),
              settings.strokeWidth,
              0.0,
              5.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(strokeWidth: value),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getFontWeightLabel(AppLocalizations l10n, int weight) {
    switch (weight.clamp(0, 8)) {
      case 0:
        return l10n.danmakuSettingsFontWeightUltraLight;
      case 1:
        return l10n.danmakuSettingsFontWeightExtraLight;
      case 2:
        return l10n.danmakuSettingsFontWeightLight;
      case 3:
        return l10n.danmakuSettingsFontWeightSemiLight;
      case 4:
        return l10n.danmakuSettingsFontWeightRegular;
      case 5:
        return l10n.danmakuSettingsFontWeightSemiBold;
      case 6:
        return l10n.danmakuSettingsFontWeightBold;
      case 7:
        return l10n.danmakuSettingsFontWeightExtraBold;
      case 8:
        return l10n.danmakuSettingsFontWeightBlack;
      default:
        return l10n.danmakuSettingsFontWeightRegular;
    }
  }

  Widget _buildDanmakuSource() {
    return ListenableBuilder(
      listenable: widget.danmakuService,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface;
        final subTextColor = isDark
            ? Colors.white70
            : Theme.of(context).colorScheme.onSurfaceVariant;
        final hintTextColor = isDark
            ? Colors.white38
            : Theme.of(context).colorScheme.outline;
        final fillColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHigh;
        final unselectedEpColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHigh;
        final unselectedEpTextColor = isDark
            ? Colors.white70
            : Theme.of(context).colorScheme.onSurfaceVariant;
        final selectedAnimeBgColor = Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.15);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchHintText,
                  hintStyle: TextStyle(color: hintTextColor),
                  filled: true,
                  fillColor: fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        widget.danmakuService.searchAnime(
                          _searchController.text,
                        );
                      }
                    },
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    widget.danmakuService.searchAnime(value);
                  }
                },
              ),
            ),
            if (widget.danmakuService.isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (widget.danmakuService.error != null)
              Expanded(
                child: Center(
                  child: Text(
                    widget.danmakuService.error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (widget.danmakuService.danmakuCount > 0) ...[
                      Text(
                        l10n.loadedDanmaku,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLoadedDanmakuInfoCard(context),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.selectedAnime != null) ...[
                      Text(
                        l10n.currentMatch,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => widget.danmakuService.selectAnime(
                          widget.danmakuService.selectedAnime!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedAnimeBgColor,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.danmakuService.selectedAnime!.animeTitle,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.searchResults.isNotEmpty) ...[
                      Text(
                        l10n.searchResult,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.danmakuService.searchResults.map(
                        (anime) => _buildAnimeCard(anime, false),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.episodes.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            l10n.episodeList,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.subtitleTrackCount(
                              widget.danmakuService.episodes.length,
                            ),
                            style: TextStyle(
                              color: hintTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.danmakuService.episodes.map((ep) {
                          final isSelected =
                              widget
                                  .danmakuService
                                  .selectedEpisode
                                  ?.episodeId ==
                              ep.episodeId;
                          return InkWell(
                            onTap: () =>
                                widget.danmakuService.selectEpisode(ep),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 48,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : unselectedEpColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ep.episodeTitle,
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : unselectedEpTextColor,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ),
            SizedBox(
              height: 24,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                activeTrackColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                inactiveThumbColor: isDark
                    ? Colors.grey
                    : Theme.of(context).colorScheme.outline,
                inactiveTrackColor: isDark
                    ? Colors.grey.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String valueText,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final valueTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final thumbColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final inactiveTrackColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: textColor, fontSize: 13)),
              Text(
                valueText,
                style: TextStyle(color: valueTextColor, fontSize: 12),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: inactiveTrackColor,
            thumbColor: thumbColor,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildLoadedDanmakuInfoCard(BuildContext context) {
    final service = widget.danmakuService;
    final count = service.danmakuCount;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    String infoText = '';
    if (service.selectedAnime != null) {
      infoText = service.selectedAnime!.animeTitle;
      if (service.selectedEpisode != null) {
        infoText += ' - ${service.selectedEpisode!.episodeTitle}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.danmakuCount(count),
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (infoText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              infoText,
              style: TextStyle(color: subTextColor, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimeCard(DanmakuAnime anime, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final unselectedBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    return InkWell(
      onTap: () => widget.danmakuService.selectAnime(anime),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : unselectedBgColor,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              anime.animeTitle,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (anime.typeDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                anime.typeDescription!,
                style: TextStyle(color: subTextColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
