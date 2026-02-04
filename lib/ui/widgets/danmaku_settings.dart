import 'package:flutter/material.dart';
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
            tabs: const [
              Tab(text: '显示设置'),
              Tab(text: '弹幕源'),
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
        final settings = widget.danmakuService.settings;
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildSwitchTile(
              '显示弹幕',
              settings.enabled,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(enabled: value),
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            _buildSectionHeader('显示类型'),
            _buildSwitchTile(
              '滚动弹幕',
              settings.showScrolling,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showScrolling: value),
              ),
            ),
            _buildSwitchTile(
              '顶部弹幕',
              settings.showTop,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showTop: value),
              ),
            ),
            _buildSwitchTile(
              '底部弹幕',
              settings.showBottom,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showBottom: value),
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            _buildSectionHeader('样式设置'),
            _buildSliderTile(
              '不透明度',
              '${(settings.opacity * 100).toInt()}%',
              settings.opacity,
              0.1,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(opacity: value),
              ),
            ),
            _buildSliderTile(
              '字体大小',
              '${settings.fontSize.toInt()}px',
              settings.fontSize,
              14,
              40,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontSize: value),
              ),
            ),
            _buildSliderTile(
              '弹幕速度',
              '${settings.speed.toInt()}秒',
              settings.speed,
              4,
              16,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(speed: value),
              ),
            ),
            _buildSliderTile(
              '显示区域',
              '${(settings.displayArea * 100).toInt()}%',
              settings.displayArea,
              0.25,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(displayArea: value),
              ),
            ),
            _buildSliderTile(
              '字体字重',
              _getFontWeightLabel(settings.fontWeight),
              settings.fontWeight.toDouble(),
              0,
              8,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontWeight: value.toInt()),
              ),
            ),
            _buildSliderTile(
              '描边宽度',
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

  String _getFontWeightLabel(int weight) {
    const labels = ['极细', '特细', '细', '较细', '正常', '较粗', '粗', '特粗', '极粗'];
    return labels[weight.clamp(0, 8)];
  }

  Widget _buildDanmakuSource() {
    return ListenableBuilder(
      listenable: widget.danmakuService,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜索番剧名称...',
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
                      const Text(
                        '已加载弹幕',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLoadedDanmakuInfoCard(),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.selectedAnime != null) ...[
                      const Text(
                        '当前匹配',
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
                      const Text(
                        '搜索结果',
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
                          const Text(
                            '剧集列表',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '共 ${widget.danmakuService.episodes.length} 集',
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

  Widget _buildLoadedDanmakuInfoCard() {
    final service = widget.danmakuService;
    final count = service.danmakuCount;

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
                '弹幕数量: $count 条',
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
                    tabs: const [
                      Tab(text: '显示设置'),
                      Tab(text: '弹幕源'),
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
        final settings = widget.danmakuService.settings;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildSwitchTile(
              '显示弹幕',
              settings.enabled,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(enabled: value),
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            _buildSectionHeader('显示类型'),
            _buildSwitchTile(
              '滚动弹幕',
              settings.showScrolling,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showScrolling: value),
              ),
            ),
            _buildSwitchTile(
              '顶部弹幕',
              settings.showTop,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showTop: value),
              ),
            ),
            _buildSwitchTile(
              '底部弹幕',
              settings.showBottom,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(showBottom: value),
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            _buildSectionHeader('样式设置'),
            _buildSliderTile(
              '不透明度',
              '${(settings.opacity * 100).toInt()}%',
              settings.opacity,
              0.1,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(opacity: value),
              ),
            ),
            _buildSliderTile(
              '字体大小',
              '${settings.fontSize.toInt()}px',
              settings.fontSize,
              14,
              40,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontSize: value),
              ),
            ),
            _buildSliderTile(
              '弹幕速度',
              '${settings.speed.toInt()}秒',
              settings.speed,
              4,
              16,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(speed: value),
              ),
            ),
            _buildSliderTile(
              '显示区域',
              '${(settings.displayArea * 100).toInt()}%',
              settings.displayArea,
              0.25,
              1.0,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(displayArea: value),
              ),
            ),
            _buildSliderTile(
              '字体字重',
              _getFontWeightLabel(settings.fontWeight),
              settings.fontWeight.toDouble(),
              0,
              8,
              (value) => widget.danmakuService.updateSettings(
                settings.copyWith(fontWeight: value.toInt()),
              ),
            ),
            _buildSliderTile(
              '描边宽度',
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

  String _getFontWeightLabel(int weight) {
    const labels = ['极细', '特细', '细', '较细', '正常', '较粗', '粗', '特粗', '极粗'];
    return labels[weight.clamp(0, 8)];
  }

  Widget _buildDanmakuSource() {
    return ListenableBuilder(
      listenable: widget.danmakuService,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜索番剧名称...',
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
                      const Text(
                        '已加载弹幕',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLoadedDanmakuInfoCard(),
                      const SizedBox(height: 24),
                    ],
                    if (widget.danmakuService.selectedAnime != null) ...[
                      const Text(
                        '当前匹配',
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
                      const Text(
                        '搜索结果',
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
                          const Text(
                            '剧集列表',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '共 ${widget.danmakuService.episodes.length} 集',
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

  Widget _buildLoadedDanmakuInfoCard() {
    final service = widget.danmakuService;
    final count = service.danmakuCount;

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
                '弹幕数量: $count 条',
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
