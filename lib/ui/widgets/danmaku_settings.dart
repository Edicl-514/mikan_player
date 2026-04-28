import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
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
    return Column(
      children: [
        // Tab 栏
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFBB86FC),
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: const Color(0xFFBB86FC),
            unselectedLabelColor: Colors.white70,
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
            const Divider(color: Colors.white10, height: 1),

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
            const Divider(color: Colors.white10, height: 1),

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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchHintText,
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Color(0xFFBB86FC),
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
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFBB86FC),
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
                    // 显示当前已加载的弹幕信息
                    if (widget.danmakuService.danmakuCount > 0) ...[
                      Text(
                        l10n.loadedDanmaku,
                        style: TextStyle(
                          color: Colors.white70,
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
                          color: Colors.white70,
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
                          color: Colors.white70,
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
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.subtitleTrackCount(
                              widget.danmakuService.episodes.length,
                            ),
                            style: const TextStyle(
                              color: Colors.white38,
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
                                    ? const Color(0xFFBB86FC)
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ep.episodeTitle,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white70,
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
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedAnimeCard(DanmakuAnime anime) {
    return InkWell(
      onTap: () => widget.danmakuService.selectAnime(anime),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFBB86FC).withValues(alpha: 0.15),
          border: Border.all(color: const Color(0xFFBB86FC), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          anime.animeTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimeCard(DanmakuAnime anime) {
    return InkWell(
      onTap: () => widget.danmakuService.selectAnime(anime),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              anime.animeTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (anime.typeDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                anime.typeDescription!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
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
        style: const TextStyle(
          color: Color(0xFFBB86FC),
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
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            SizedBox(
              height: 24,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: const Color(0xFFBB86FC),
                activeTrackColor: const Color(
                  0xFFBB86FC,
                ).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                valueText,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFBB86FC),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: Colors.white,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 320,
      height: double.infinity,
      color: const Color(0xFF13131A).withValues(alpha: 0.95),
      child: Column(
        children: [
          // 顶部 Tab 栏
          Container(
            height: 48,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFBB86FC),
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: const Color(0xFFBB86FC),
                    unselectedLabelColor: Colors.white70,
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
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildSwitchTile(
              l10n.danmakuSettingsEnable,
              settings.enabled,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(enabled: value),
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

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
            const Divider(color: Colors.white10, height: 1),

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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchHintText,
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Color(0xFFBB86FC),
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
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFBB86FC),
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
                    // 显示当前已加载的弹幕信息
                    if (widget.danmakuService.danmakuCount > 0) ...[
                      Text(
                        l10n.loadedDanmaku,
                        style: TextStyle(
                          color: Colors.white70,
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
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 使用 _buildAnimeCard 但需要确保它可以处理这两种情况，或者我们这里重写逻辑
                      // _buildAnimeCard(widget.danmakuService.selectedAnime!, ),
                      InkWell(
                        onTap: () => widget.danmakuService.selectAnime(
                          widget.danmakuService.selectedAnime!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFBB86FC,
                            ).withValues(alpha: 0.15),
                            border: Border.all(
                              color: const Color(0xFFBB86FC),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.danmakuService.selectedAnime!.animeTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // 假设 DanmakuAnime 没有 seasonTitle，所以这里不显示
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
                          color: Colors.white70,
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
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.subtitleTrackCount(
                              widget.danmakuService.episodes.length,
                            ),
                            style: const TextStyle(
                              color: Colors.white38,
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
                          // selectedEpisode 是 DanmakuEpisode 类型
                          // ep 是 DanmakuEpisode 类型
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
                                    ? const Color(0xFFBB86FC)
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ep.episodeTitle, // 之前看到是 episodeTitle
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white70,
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
        style: const TextStyle(
          color: Color(0xFFBB86FC),
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
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            SizedBox(
              height: 24,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: const Color(0xFFBB86FC),
                activeTrackColor: const Color(
                  0xFFBB86FC,
                ).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                valueText,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFBB86FC),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: Colors.white,
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
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimeCard(DanmakuAnime anime, bool isSelected) {
    return InkWell(
      onTap: () => widget.danmakuService.selectAnime(anime),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFBB86FC).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected ? const Color(0xFFBB86FC) : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              anime.animeTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (anime.typeDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                anime.typeDescription!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
