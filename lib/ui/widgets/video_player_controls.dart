import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/ui/widgets/danmaku_overlay.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';

/// 自定义视频播放器控件 - 整合弹幕与播放控制
class CustomVideoControls extends StatelessWidget {
  final VideoState state;
  final bool isMobile;
  
  // 弹幕相关
  final DanmakuService danmakuService;
  final double currentVideoTime;
  final bool isVideoPaused;
  final bool showDanmakuSettings;
  final VoidCallback onToggleDanmakuSettings;
  
  // 选集相关
  final List<BangumiEpisode> allEpisodes;
  final BangumiEpisode currentEpisode;
  final Function(BangumiEpisode) onEpisodeSelected;
  
  // 加载状态
  final bool isLoading;

  const CustomVideoControls({
    super.key,
    required this.state,
    required this.isMobile,
    required this.danmakuService,
    required this.currentVideoTime,
    required this.isVideoPaused,
    required this.showDanmakuSettings,
    required this.onToggleDanmakuSettings,
    required this.allEpisodes,
    required this.currentEpisode,
    required this.onEpisodeSelected,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 弹幕渲染层 (最底层)
        Positioned.fill(
          child: IgnorePointer(
            child: DanmakuOverlay(
              currentTime: currentVideoTime,
              danmakuList: danmakuService.danmakuList,
              settings: danmakuService.settings,
              isPaused: isVideoPaused,
              isPlaying: true, // 控制层渲染时通常认为是在尝试播放
            ),
          ),
        ),

        // 2. 加载选集提示或状态
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFBB86FC)),
                    SizedBox(height: 16),
                    Text("正在加载视频流...", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),

        // 3. 原生控制层 (中间层) - 提供基础播放暂停、进度条、全屏切换
        AdaptiveVideoControls(state),

        // 4. 自定义控制层 (顶层) - 弹幕开关、选集按钮等
        _buildOverlayUI(context),

        // 5. 弹幕设置面板
        if (showDanmakuSettings)
          Positioned.fill(
            child: GestureDetector(
              onTap: onToggleDanmakuSettings,
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {}, // 防止点击面板关闭
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 550,
                    ),
                    child: DanmakuSettingsPanel(
                      danmakuService: danmakuService,
                      onClose: onToggleDanmakuSettings,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverlayUI(BuildContext context) {
    return Positioned.fill(
      child: Column(
        children: [
          // 顶部栏
          _buildTopBar(context),
          const Spacer(),
          // 底部栏 (这里可以添加额外的快捷操作)
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16,
          vertical: 8,
        ),
        child: Row(
          children: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            const Spacer(),
            // 选集按钮
            _buildEpisodeButton(context),
            const SizedBox(width: 8),
            // 弹幕控制
            _buildDanmakuControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeButton(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _showEpisodeSelection(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_play, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text(
                "选集",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDanmakuControls(BuildContext context) {
    return ListenableBuilder(
      listenable: danmakuService,
      builder: (context, _) {
        final settings = danmakuService.settings;
        final hasData = danmakuService.danmakuList.isNotEmpty;
        final isLoading = danmakuService.isLoading;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 弹幕数量
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBB86FC).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${danmakuService.danmakuCount}',
                    style: const TextStyle(
                      color: Color(0xFFBB86FC),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFBB86FC),
                  ),
                ),

              if (hasData || isLoading) const SizedBox(width: 4),

              // 弹幕开关
              IconButton(
                icon: Icon(
                  settings.enabled ? Icons.subtitles : Icons.subtitles_off,
                  color: settings.enabled ? const Color(0xFFBB86FC) : Colors.white54,
                  size: 20,
                ),
                tooltip: settings.enabled ? '关闭弹幕' : '开启弹幕',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: hasData ? danmakuService.toggleEnabled : null,
              ),
              // 更多设置
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white54, size: 20),
                tooltip: '弹幕设置',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onToggleDanmakuSettings,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEpisodeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "选集",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: allEpisodes.length,
                  itemBuilder: (context, index) {
                    final ep = allEpisodes[index];
                    final isSelected = ep == currentEpisode;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onEpisodeSelected(ep);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFBB86FC).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFBB86FC)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          ep.sort.toString(),
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFBB86FC) : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
