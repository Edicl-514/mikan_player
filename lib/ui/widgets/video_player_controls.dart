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
      Builder(
        builder: (ctx) => _buildIntegratedButton(
          icon: Icons.tune,
          onPressed: () => _showMobileSettingsMenu(ctx, isFullscreen: false),
        ),
      ),
    ];

    // 移动端 - 全屏顶部按钮栏
    final mobileFullscreenTopButtonBar = [
      IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        tooltip: '返回',
      ),
      if (videoTitle != null) ...[
        const SizedBox(width: 8),
        Text(
          videoTitle!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
      const Spacer(),
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
      Builder(
        builder: (ctx) => _buildIntegratedButton(
          icon: Icons.tune,
          onPressed: () => _showMobileSettingsMenu(ctx, isFullscreen: true),
        ),
      ),
    ];

    // 移动端 - 非全屏底部按钮栏
    final mobileNormalBottomButtonBar = [
      Expanded(
        child: SizedBox(
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MaterialSeekBar(),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const MaterialPlayOrPauseButton(),
                        const SizedBox(width: 8),
                        const MaterialPositionIndicator(),
                        const Spacer(),
                        const MaterialFullscreenButton(),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    // 移动端 - 全屏底部按钮栏
    final mobileFullscreenBottomButtonBar = [
      Expanded(
        child: SizedBox(
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MaterialSeekBar(),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 16),
                        _buildSkipButton(
                          icon: Icons.skip_previous,
                          onPressed: () => _onSkipPrevious(),
                        ),
                        const SizedBox(width: 8),
                        const MaterialPlayOrPauseButton(),
                        const SizedBox(width: 8),
                        _buildSkipButton(
                          icon: Icons.skip_next,
                          onPressed: () => _onSkipNext(),
                        ),
                        const SizedBox(width: 8),
                        const MaterialPositionIndicator(),
                        const Spacer(),
                        Builder(
                          builder: (ctx) => _buildIntegratedButton(
                            icon: Icons.playlist_play,
                            label: "选集",
                            onPressed: () => _showEpisodeSidePanel(ctx),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const MaterialFullscreenButton(),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        bottomButtonBar: mobileNormalBottomButtonBar,
        primaryButtonBar: [], // 移除中间按钮
        displaySeekBar: false,
      ),
      fullscreen: MaterialVideoControlsThemeData(
        topButtonBar: mobileFullscreenTopButtonBar,
        bottomButtonBar: mobileFullscreenBottomButtonBar,
        primaryButtonBar: [], // 移除中间按钮
        displaySeekBar: false,
      ),
      child: MaterialDesktopVideoControlsTheme(
        normal: MaterialDesktopVideoControlsThemeData(
          topButtonBar: desktopNormalTopButtonBar,
          bottomButtonBar: [
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
            const MaterialDesktopVolumeButton(),
            const SizedBox(width: 8),
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
                  icon: settings.enabled
                      ? Icons.comment
                      : Icons.comments_disabled,
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
            const SizedBox(width: 8),
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
                  icon: settings.enabled
                      ? Icons.comment
                      : Icons.comments_disabled,
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
                  child: StreamBuilder<bool>(
                    stream: state.widget.controller.player.stream.playing,
                    builder: (context, playingSnapshot) {
                      final isPlaying =
                          playingSnapshot.data ??
                          state.widget.controller.player.state.playing;
                      return StreamBuilder<Duration>(
                        stream: state.widget.controller.player.stream.position,
                        builder: (context, posSnapshot) {
                          final position =
                              posSnapshot.data ??
                              state.widget.controller.player.state.position;
                          final currentSeconds =
                              position.inMilliseconds / 1000.0;
                          return DanmakuOverlay(
                            currentTime: currentSeconds,
                            danmakuList: danmakuService.danmakuList,
                            settings: danmakuService.settings,
                            isPaused: !isPlaying,
                            isPlaying: true,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // 2. 加载选集提示
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFBB86FC),
                      ),
                    ),
                  ),
                ),

              // 3. 原生控制层 (根据主题渲染)
              // 注意：AdaptiveVideoControls 会读取上层 MaterialVideoControlsTheme
              // 如果我们在这里没有显式传参数，它会自己构建一个 UI。
              // 既然我们已经用 Stack 手动包裹了 DanmakuOverlay 和 AdaptiveVideoControls，
              // 就不应该再在外层返回这个 Stack。
              AdaptiveVideoControls(state),

              // 4. 右侧设置面板 (类似 Bilibili 风格)
              if (showDanmakuSettings) ...[
                // 背景点击关闭
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onToggleDanmakuSettings,
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // 侧边栏
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {}, // 阻止点击穿透关闭面板
                    child: VideoSidePanel(
                      danmakuService: danmakuService,
                      onClose: onToggleDanmakuSettings,
                    ),
                  ),
                ),
              ],
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

  /// 移动端设置菜单
  void _showMobileSettingsMenu(BuildContext context, {required bool isFullscreen}) {
    if (isFullscreen) {
      // 全屏时使用从右侧滑入的侧边栏
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭设置',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A24),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // 标题栏
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              '显示设置',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      // 设置内容
                      Expanded(
                        child: DanmakuSettingsBottomSheet(
                          danmakuService: danmakuService,
                          scrollController: ScrollController(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      );
    } else {
      // 非全屏时从底部弹出
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A24),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // 拖动指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        '显示设置',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                // 设置内容
                Expanded(
                  child: DanmakuSettingsBottomSheet(
                    danmakuService: danmakuService,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showSettingsMenu(BuildContext context) {
    // 根据是否全屏选择不同的显示方式
    final isFullscreen = state.widget.controller.player.state.width != null &&
        MediaQuery.of(context).orientation == Orientation.landscape;
    
    if (isMobile && !isFullscreen) {
      // 移动端非全屏：从底部弹出
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF13131A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // 拖动指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 设置面板内容
                Expanded(
                  child: DanmakuSettingsBottomSheet(
                    danmakuService: danmakuService,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // 全屏或桌面端：使用侧边栏
      onToggleDanmakuSettings();
    }
  }

  /// 全屏时从右侧滑入的选集面板
  void _showEpisodeSidePanel(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭选集',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A24),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            '选集',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '共${allEpisodes.length}集',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // 选集列表
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.2,
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
                            borderRadius: BorderRadius.circular(8),
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
                                      : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                ep.sort.toString(),
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFBB86FC)
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
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
