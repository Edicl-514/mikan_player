import 'package:flutter/material.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/src/rust/api/danmaku.dart';

/// 弹幕设置面板
class DanmakuSettingsPanel extends StatefulWidget {
  final DanmakuService danmakuService;
  final VoidCallback? onClose;

  const DanmakuSettingsPanel({
    super.key,
    required this.danmakuService,
    this.onClose,
  });

  @override
  State<DanmakuSettingsPanel> createState() => _DanmakuSettingsPanelState();
}

class _DanmakuSettingsPanelState extends State<DanmakuSettingsPanel>
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2D2D44), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.subtitles, color: Color(0xFFBB86FC)),
                const SizedBox(width: 12),
                const Text(
                  '弹幕设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFBB86FC),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFFBB86FC),
            tabs: const [
              Tab(text: '显示设置'),
              Tab(text: '弹幕源'),
            ],
          ),

          // Tab Content
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDisplaySettings(),
                _buildDanmakuSource(),
              ],
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
          padding: const EdgeInsets.all(16),
          children: [
            // 弹幕开关
            _buildSwitchTile(
              '显示弹幕',
              Icons.visibility,
              settings.enabled,
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(enabled: value),
                );
              },
            ),

            const SizedBox(height: 16),

            // 弹幕类型过滤
            _buildSectionTitle('弹幕类型'),
            _buildSwitchTile(
              '滚动弹幕',
              Icons.arrow_forward,
              settings.showScrolling,
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(showScrolling: value),
                );
              },
            ),
            _buildSwitchTile(
              '顶部弹幕',
              Icons.vertical_align_top,
              settings.showTop,
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(showTop: value),
                );
              },
            ),
            _buildSwitchTile(
              '底部弹幕',
              Icons.vertical_align_bottom,
              settings.showBottom,
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(showBottom: value),
                );
              },
            ),

            const SizedBox(height: 16),

            // 透明度
            _buildSectionTitle('透明度'),
            _buildSlider(
              settings.opacity,
              0.1,
              1.0,
              '${(settings.opacity * 100).toInt()}%',
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(opacity: value),
                );
              },
            ),

            const SizedBox(height: 16),

            // 字体大小
            _buildSectionTitle('字体大小'),
            _buildSlider(
              settings.fontSize,
              14,
              40,
              '${settings.fontSize.toInt()}px',
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(fontSize: value),
                );
              },
            ),

            const SizedBox(height: 16),

            // 弹幕速度
            _buildSectionTitle('弹幕速度'),
            _buildSlider(
              settings.speed,
              4,
              16,
              '${settings.speed.toInt()}秒',
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(speed: value),
                );
              },
            ),

            const SizedBox(height: 16),

            // 显示区域
            _buildSectionTitle('显示区域'),
            _buildSlider(
              settings.displayArea,
              0.25,
              1.0,
              '${(settings.displayArea * 100).toInt()}%',
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(displayArea: value),
                );
              },
            ),

            const SizedBox(height: 16),

            // 同屏数量
            _buildSectionTitle('同屏最大数量'),
            _buildSlider(
              settings.maxCount.toDouble(),
              10,
              100,
              '${settings.maxCount}',
              (value) {
                widget.danmakuService.updateSettings(
                  settings.copyWith(maxCount: value.toInt()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDanmakuSource() {
    return ListenableBuilder(
      listenable: widget.danmakuService,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 状态信息
            _buildStatusCard(),

            const SizedBox(height: 16),

            // 搜索框
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索番剧名称...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2D2D44),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFBB86FC)),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      widget.danmakuService.searchAnime(_searchController.text);
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

            const SizedBox(height: 16),

            // 搜索结果或剧集列表
            if (widget.danmakuService.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
                ),
              )
            else if (widget.danmakuService.error != null)
              _buildErrorCard()
            else if (widget.danmakuService.selectedAnime != null)
              _buildEpisodeList()
            else if (widget.danmakuService.searchResults.isNotEmpty)
              _buildSearchResults(),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard() {
    final service = widget.danmakuService;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (service.danmakuList.isNotEmpty) {
      statusText = '已加载 ${service.danmakuCount} 条弹幕';
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else if (service.isLoading) {
      statusText = '正在加载弹幕...';
      statusIcon = Icons.hourglass_empty;
      statusColor = Colors.orange;
    } else {
      statusText = '未加载弹幕';
      statusIcon = Icons.info_outline;
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (service.selectedAnime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${service.selectedAnime!.animeTitle}${service.selectedEpisode != null ? ' - ${service.selectedEpisode!.episodeTitle}' : ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (service.danmakuList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
              onPressed: () {
                if (service.selectedEpisode != null) {
                  service.selectEpisode(service.selectedEpisode!);
                }
              },
              tooltip: '重新加载',
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.danmakuService.error ?? '未知错误',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('搜索结果 (${widget.danmakuService.searchResults.length})'),
        ...widget.danmakuService.searchResults.map((anime) {
          return _buildAnimeCard(anime);
        }),
      ],
    );
  }

  Widget _buildAnimeCard(DanmakuAnime anime) {
    return Card(
      color: const Color(0xFF2D2D44),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: anime.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  anime.imageUrl!,
                  width: 48,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 64,
                    color: const Color(0xFF3D3D54),
                    child: const Icon(Icons.movie, color: Colors.white38),
                  ),
                ),
              )
            : Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D54),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.movie, color: Colors.white38),
              ),
        title: Text(
          anime.animeTitle,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          anime.typeDescription ?? anime.animeType,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () {
          widget.danmakuService.selectAnime(anime);
        },
      ),
    );
  }

  Widget _buildEpisodeList() {
    final selectedAnime = widget.danmakuService.selectedAnime!;
    final episodes = widget.danmakuService.episodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 返回按钮
        TextButton.icon(
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('返回搜索结果'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFBB86FC),
          ),
          onPressed: () {
            widget.danmakuService.clearDanmaku();
            if (_searchController.text.isNotEmpty) {
              widget.danmakuService.searchAnime(_searchController.text);
            }
          },
        ),

        const SizedBox(height: 8),

        // 当前选中的番剧
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D54),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.movie, color: Color(0xFFBB86FC)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedAnime.animeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionTitle('选择剧集 (${episodes.length})'),

        // 剧集网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2,
          ),
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final episode = episodes[index];
            final isSelected = widget.danmakuService.selectedEpisode == episode;

            return Material(
              color: isSelected
                  ? const Color(0xFFBB86FC)
                  : const Color(0xFF2D2D44),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  widget.danmakuService.selectEpisode(episode);
                },
                child: Center(
                  child: Text(
                    episode.episodeNumber ?? episode.episodeTitle,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Icon(icon, color: Colors.white54, size: 20),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFBB86FC),
        ),
      ),
    );
  }

  Widget _buildSlider(
    double value,
    double min,
    double max,
    String label,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFFBB86FC),
            inactiveColor: const Color(0xFF3D3D54),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// 弹幕开关按钮（用于播放器控制栏）
class DanmakuToggleButton extends StatelessWidget {
  final DanmakuService danmakuService;
  final VoidCallback? onSettingsPressed;

  const DanmakuToggleButton({
    super.key,
    required this.danmakuService,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: danmakuService,
      builder: (context, _) {
        final enabled = danmakuService.settings.enabled;
        final hasData = danmakuService.danmakuList.isNotEmpty;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 弹幕开关
            IconButton(
              icon: Icon(
                enabled ? Icons.subtitles : Icons.subtitles_off,
                color: hasData
                    ? (enabled ? const Color(0xFFBB86FC) : Colors.white54)
                    : Colors.white30,
              ),
              tooltip: enabled ? '关闭弹幕' : '开启弹幕',
              onPressed: hasData ? danmakuService.toggleEnabled : null,
            ),

            // 设置按钮
            if (onSettingsPressed != null)
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white54),
                tooltip: '弹幕设置',
                onPressed: onSettingsPressed,
              ),
          ],
        );
      },
    );
  }
}

/// 弹幕信息徽章
class DanmakuBadge extends StatelessWidget {
  final DanmakuService danmakuService;

  const DanmakuBadge({
    super.key,
    required this.danmakuService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: danmakuService,
      builder: (context, _) {
        if (danmakuService.isLoading) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '加载中',
                  style: TextStyle(color: Colors.orange, fontSize: 11),
                ),
              ],
            ),
          );
        }

        final count = danmakuService.danmakuCount;
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFBB86FC).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '弹幕 $count',
            style: const TextStyle(
              color: Color(0xFFBB86FC),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}
