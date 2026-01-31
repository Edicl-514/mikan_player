import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/ui/widgets/danmaku_overlay.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';

/// 自定义视频播放器控件 - 整合弹幕与播放控制
/// 深度集成 media_kit_video 的 Material 风格控件
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
  
  // 视频标题
  final String? videoTitle;

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
    this.videoTitle,
  });

  @override
  Widget build(BuildContext context) {
    // 移动端 - 非全屏顶部按钮栏
    final mobileNormalTopButtonBar = [
      IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        tooltip: '返回',
      ),
      const Spacer(),
      _buildIntegratedButton(
        icon: Icons.playlist_play,
        label: "选集",
        onPressed: () => _showEpisodeSelection(context),
      ),
      const SizedBox(width: 8),
      ListenableBuilder(
        listenable: danmakuService,
        builder: (context, _) {
          final settings = danmakuService.settings;
          final hasData = danmakuService.danmakuList.isNotEmpty;
          return _buildIntegratedButton(
            icon: settings.enabled ? Icons.subtitles : Icons.subtitles_off,
            label: "弹幕",
            isActive: settings.enabled,
            onPressed: hasData ? danmakuService.toggleEnabled : null,
          );
        },
      ),
      const SizedBox(width: 8),
      _buildIntegratedButton(
        icon: Icons.tune,
        onPressed: onToggleDanmakuSettings,
      ),
    ];

    // 移动端 - 全屏顶部按钮栏（更紧凑，只用图标）
    final mobileFullscreenTopButtonBar = [
      IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        tooltip: '返回',
      ),
      const Spacer(),
      _buildIntegratedButton(
        icon: Icons.playlist_play,
        onPressed: () => _showEpisodeSelection(context),
      ),
      const SizedBox(width: 4),
      ListenableBuilder(
        listenable: danmakuService,
        builder: (context, _) {
          final settings = danmakuService.settings;
          final hasData = danmakuService.danmakuList.isNotEmpty;
          return _buildIntegratedButton(
            icon: settings.enabled ? Icons.subtitles : Icons.subtitles_off,
            isActive: settings.enabled,
            onPressed: hasData ? danmakuService.toggleEnabled : null,
          );
        },
      ),
      const SizedBox(width: 4),
      _buildIntegratedButton(
        icon: Icons.tune,
        onPressed: onToggleDanmakuSettings,
      ),
    ];

    // 桌面端 - 非全屏顶部按钮栏（不显示任何内容）
    final desktopNormalTopButtonBar = <Widget>[];

    // 桌面端 - 全屏顶部按钮栏（显示标题）
    final desktopFullscreenTopButtonBar = [
      if (videoTitle != null) ...[
        const SizedBox(width: 16),
        Text(
          videoTitle!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
      const Spacer(),
    ];

    return MaterialVideoControlsTheme(
      normal: MaterialVideoControlsThemeData(
        topButtonBar: mobileNormalTopButtonBar,
        primaryButtonBar: [
          const Spacer(),
          const MaterialSkipPreviousButton(),
          const MaterialPlayOrPauseButton(iconSize: 48),
          const MaterialSkipNextButton(),
          const Spacer(),
        ],
      ),
      fullscreen: MaterialVideoControlsThemeData(
        topButtonBar: mobileFullscreenTopButtonBar,
        primaryButtonBar: [
          const Spacer(),
          const MaterialSkipPreviousButton(),
          const MaterialPlayOrPauseButton(iconSize: 56),
          const MaterialSkipNextButton(),
          const Spacer(),
        ],
      ),
      child: MaterialDesktopVideoControlsTheme(
        normal: MaterialDesktopVideoControlsThemeData(
          topButtonBar: desktopNormalTopButtonBar,
          bottomButtonBar: [
            const SizedBox(width: 16),
            // 左下角：播放控制
            _buildSkipButton(
              icon: Icons.skip_previous,
              onPressed: () => _onSkipPrevious(),
            ),
            const SizedBox(width: 8),
            const MaterialDesktopPlayOrPauseButton(iconSize: 32),
            const SizedBox(width: 8),
            _buildSkipButton(
              icon: Icons.skip_next,
              onPressed: () => _onSkipNext(),
            ),
            const SizedBox(width: 16),
            const MaterialDesktopVolumeButton(),
            const SizedBox(width: 16),
            // 左下角：时间进度条
            const MaterialDesktopPositionIndicator(),
            const Spacer(),
            // 右下角：功能按钮（不显示选集）
            ListenableBuilder(
              listenable: danmakuService,
              builder: (context, _) {
                final settings = danmakuService.settings;
                final hasData = danmakuService.danmakuList.isNotEmpty;
                return _buildIntegratedButton(
                  icon: settings.enabled ? Icons.comment : Icons.comments_disabled,
                  isActive: settings.enabled,
                  onPressed: hasData ? danmakuService.toggleEnabled : null,
                );
              },
            ),
            const SizedBox(width: 8),
            _buildIntegratedButton(
              icon: Icons.closed_caption_outlined,
              onPressed: null, // 字幕功能待实现
            ),
            const SizedBox(width: 8),
            _buildIntegratedButton(
              icon: Icons.settings,
              onPressed: () => _showSettingsMenu(context),
            ),
            const SizedBox(width: 8),
            const MaterialDesktopFullscreenButton(),
            const SizedBox(width: 16),
          ],
        ),
        fullscreen: MaterialDesktopVideoControlsThemeData(
          topButtonBar: desktopFullscreenTopButtonBar,
          bottomButtonBar: [
            const SizedBox(width: 16),
            // 左下角：播放控制
            _buildSkipButton(
              icon: Icons.skip_previous,
              onPressed: () => _onSkipPrevious(),
            ),
            const SizedBox(width: 8),
            const MaterialDesktopPlayOrPauseButton(iconSize: 32),
            const SizedBox(width: 8),
            _buildSkipButton(
              icon: Icons.skip_next,
              onPressed: () => _onSkipNext(),
            ),
            const SizedBox(width: 16),
            const MaterialDesktopVolumeButton(),
            const SizedBox(width: 16),
            // 左下角：时间进度条
            const MaterialDesktopPositionIndicator(),
            const Spacer(),
            // 右下角：功能按钮
            ListenableBuilder(
              listenable: danmakuService,
              builder: (context, _) {
                final settings = danmakuService.settings;
                final hasData = danmakuService.danmakuList.isNotEmpty;
                return _buildIntegratedButton(
                  icon: settings.enabled ? Icons.comment : Icons.comments_disabled,
                  isActive: settings.enabled,
                  onPressed: hasData ? danmakuService.toggleEnabled : null,
                );
              },
            ),
            const SizedBox(width: 8),
            _buildIntegratedButton(
              icon: Icons.closed_caption_outlined,
              onPressed: null, // 字幕功能待实现
            ),
            const SizedBox(width: 8),
            _buildIntegratedButton(
              icon: Icons.playlist_play,
              onPressed: () => _showEpisodeSelection(context),
            ),
            const SizedBox(width: 8),
            _buildIntegratedButton(
              icon: Icons.settings,
              onPressed: () => _showSettingsMenu(context),
            ),
            const SizedBox(width: 8),
            const MaterialDesktopFullscreenButton(),
            const SizedBox(width: 16),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 弹幕渲染层 (在视频之后，控件之前)
              Positioned.fill(
                child: IgnorePointer(
                  child: DanmakuOverlay(
                    currentTime: currentVideoTime,
                    danmakuList: danmakuService.danmakuList,
                    settings: danmakuService.settings,
                    isPaused: isVideoPaused,
                    isPlaying: true,
                  ),
                ),
              ),

              // 2. 加载选集提示
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
                    ),
                  ),
                ),

              // 3. 原生控制层 (根据主题渲染)
              // 注意：AdaptiveVideoControls 会读取上层 MaterialVideoControlsTheme
              // 如果我们在这里没有显式传参数，它会自己构建一个 UI。
              // 既然我们已经用 Stack 手动包裹了 DanmakuOverlay 和 AdaptiveVideoControls，
              // 就不应该再在外层返回这个 Stack。
              AdaptiveVideoControls(state),

              // 4. 弹幕设置面板 (独立浮层)
              if (showDanmakuSettings)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onToggleDanmakuSettings,
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {},
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
          ),
        ),
      ),
    );
  }

  /// 构建风格统一的工具栏按钮
  Widget _buildIntegratedButton({
    required IconData icon,
    String? label,
    bool isActive = false,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: label ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFFBB86FC) : Colors.white,
                size: 20,
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? const Color(0xFFBB86FC) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建上一集/下一集按钮
  Widget _buildSkipButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      iconSize: 28,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  /// 切换到上一集
  void _onSkipPrevious() {
    final currentIndex = allEpisodes.indexOf(currentEpisode);
    if (currentIndex > 0) {
      onEpisodeSelected(allEpisodes[currentIndex - 1]);
    }
  }

  /// 切换到下一集
  void _onSkipNext() {
    final currentIndex = allEpisodes.indexOf(currentEpisode);
    if (currentIndex < allEpisodes.length - 1) {
      onEpisodeSelected(allEpisodes[currentIndex + 1]);
    }
  }

  void _showSettingsMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '设置',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.tune, color: Color(0xFFBB86FC)),
                title: const Text(
                  '弹幕设置',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onToggleDanmakuSettings();
                },
              ),
              // 可以在这里添加更多设置项
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '关闭',
                style: TextStyle(color: Color(0xFFBB86FC)),
              ),
            ),
          ],
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
                            color: isSelected
                                ? const Color(0xFFBB86FC)
                                : Colors.white70,
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

