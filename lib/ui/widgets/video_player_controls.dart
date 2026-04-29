import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/ui/widgets/danmaku_overlay.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';

import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// 自定义视频播放器控件 - 整合弹幕与播放控制
/// 深度集成 media_kit_video 的 Material 风格控件
class CustomVideoControls extends StatelessWidget {
  final VideoState state;
  final bool isMobile;

  // 弹幕相关
  final DanmakuService danmakuService;
  final ValueListenable<double> currentVideoTimeListenable;
  final ValueListenable<bool> isVideoPausedListenable;
  final ValueListenable<bool> showDanmakuSettingsListenable;
  final VoidCallback onToggleDanmakuSettings;

  // 字幕相关
  final SubtitleService subtitleService;

  // 选集相关
  final List<BangumiEpisode> allEpisodes;
  final BangumiEpisode currentEpisode;
  final Function(BangumiEpisode) onEpisodeSelected;

  // 播放源相关
  final List<SearchPlayResult> availableSources;
  final ValueNotifier<int>? sourceIndexNotifier;
  final Function(int) onSourceSelected;
  final String currentSourceLabel;

  // 播放设置
  final bool isAutoPlayNextEnabled;
  final VoidCallback onToggleAutoPlayNext;
  final double playbackSpeed;
  final ValueChanged<double> onPlaybackSpeedChanged;

  // 加载状态
  final bool isLoading;

  // 移动端锁屏状态
  final ValueNotifier<bool> mobilePlayerLockNotifier;

  // 视频标题
  final String? videoTitle;

  // 下载当前在线源
  final VoidCallback? onDownloadCurrentSource;

  const CustomVideoControls({
    super.key,
    required this.state,
    required this.isMobile,
    required this.danmakuService,
    required this.currentVideoTimeListenable,
    required this.isVideoPausedListenable,
    required this.showDanmakuSettingsListenable,
    required this.onToggleDanmakuSettings,
    required this.subtitleService,
    required this.allEpisodes,
    required this.currentEpisode,
    required this.onEpisodeSelected,
    required this.availableSources,
    this.sourceIndexNotifier,
    required this.onSourceSelected,
    this.currentSourceLabel = '未知',
    this.isLoading = false,
    required this.mobilePlayerLockNotifier,
    this.videoTitle,
    this.onDownloadCurrentSource,
    required this.isAutoPlayNextEnabled,
    required this.onToggleAutoPlayNext,
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 计算当前集数索引，用于控制按钮显示
    final currentIndex = allEpisodes.indexOf(currentEpisode);
    final isFirstEpisode = currentIndex <= 0;
    final isLastEpisode = currentIndex >= allEpisodes.length - 1;

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
      if (onDownloadCurrentSource != null)
        Builder(
          builder: (ctx) => _buildIntegratedButton(
            icon: Icons.download,
            onPressed: onDownloadCurrentSource!,
          ),
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
      if (onDownloadCurrentSource != null)
        Builder(
          builder: (ctx) => _buildIntegratedButton(
            icon: Icons.download,
            onPressed: onDownloadCurrentSource!,
          ),
        ),
      Builder(
        builder: (ctx) => _buildIntegratedButton(
          icon: Icons.tune,
          onPressed: () => _showMobileSettingsMenu(ctx, isFullscreen: true),
        ),
      ),
      const SizedBox(width: 12),
      // 系统时间显示 - 只在全屏时显示，放在最右边
      _buildSystemTimeDisplay(),
    ];

    // 移动端 - 非全屏底部按钮栏
    // 注意：进度条由 media_kit 内置的 displaySeekBar 处理
    final mobileNormalBottomButtonBar = [
      const SizedBox(width: 8),
      const MaterialPlayOrPauseButton(),
      const SizedBox(width: 8),
      const MaterialPositionIndicator(),
      const Spacer(),
      const MaterialFullscreenButton(),
      const SizedBox(width: 8),
    ];

    // 移动端 - 全屏底部按钮栏
    // 注意：进度条由 media_kit 内置的 displaySeekBar 处理
    final mobileFullscreenBottomButtonBar = [
      const SizedBox(width: 16),
      if (!isFirstEpisode) ...[
        _buildSkipButton(
          icon: Icons.skip_previous,
          onPressed: () => _onSkipPrevious(),
        ),
        const SizedBox(width: 8),
      ],
      const MaterialPlayOrPauseButton(),
      if (!isLastEpisode) ...[
        const SizedBox(width: 8),
        _buildSkipButton(icon: Icons.skip_next, onPressed: () => _onSkipNext()),
      ],
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
    ];

    // 桌面端 - 非全屏顶部按钮栏（显示空降按钮）
    final desktopNormalTopButtonBar = [
      const Spacer(),
      _buildIntegratedButton(
        icon: Icons.fast_rewind,
        label: "空降-85s",
        onPressed: () => _onSkipTime(-85),
      ),
      const SizedBox(width: 8),
      _buildIntegratedButton(
        icon: Icons.fast_forward,
        label: "空降+85s",
        onPressed: () => _onSkipTime(85),
      ),
      const SizedBox(width: 16),
    ];

    // 桌面端 - 全屏顶部按钮栏（显示标题和空降按钮）
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
      _buildIntegratedButton(
        icon: Icons.fast_rewind,
        label: "空降-85s",
        onPressed: () => _onSkipTime(-85),
      ),
      const SizedBox(width: 8),
      _buildIntegratedButton(
        icon: Icons.fast_forward,
        label: "空降+85s",
        onPressed: () => _onSkipTime(85),
      ),
      const SizedBox(width: 16),
      // 系统时间显示 - 只在全屏时显示，放在最右边
      _buildSystemTimeDisplay(),
      const SizedBox(width: 16),
    ];

    final isFullscreenMode = isFullscreen(context);

    return ValueListenableBuilder<bool>(
      valueListenable: mobilePlayerLockNotifier,
      builder: (context, isMobilePlayerLocked, _) {
        final isLocked = isMobile && isFullscreenMode && isMobilePlayerLocked;

        return MaterialVideoControlsTheme(
          normal: MaterialVideoControlsThemeData(
            topButtonBar: isLocked ? const [] : mobileNormalTopButtonBar,
            bottomButtonBar: isLocked ? const [] : mobileNormalBottomButtonBar,
            primaryButtonBar: [], // 移除中间按钮
            displaySeekBar: !isLocked, // 使用 media_kit 内置进度条
            // 将进度条移到按钮栏上方，更容易点击
            seekBarMargin: const EdgeInsets.only(bottom: 48),
            seekBarThumbSize: 14, // 稍微增大滑块以便更容易点击
            // 调整触摸区域，让判定位置与视觉位置对齐
            seekBarContainerHeight: 24, // 减小触摸区域高度（默认36px）
            seekBarAlignment: Alignment.center, // 进度条在容器中居中对齐
          ),
          fullscreen: MaterialVideoControlsThemeData(
            topButtonBar: isLocked ? const [] : mobileFullscreenTopButtonBar,
            bottomButtonBar: isLocked
                ? const []
                : mobileFullscreenBottomButtonBar,
            primaryButtonBar: [], // 移除中间按钮
            displaySeekBar: !isLocked, // 使用 media_kit 内置进度条
            // 将进度条移到按钮栏上方，更容易点击
            seekBarMargin: const EdgeInsets.only(bottom: 48),
            seekBarThumbSize: 14, // 稍微增大滑块以便更容易点击
            // 调整触摸区域，让判定位置与视觉位置对齐
            seekBarContainerHeight: 24, // 减小触摸区域高度（默认36px）
            seekBarAlignment: Alignment.center, // 进度条在容器中居中对齐
          ),
          child: MaterialDesktopVideoControlsTheme(
            normal: MaterialDesktopVideoControlsThemeData(
              topButtonBar: desktopNormalTopButtonBar,
              bottomButtonBar: [
                const SizedBox(width: 8),
                // 左下角：播放控制
                if (!isFirstEpisode) ...[
                  _buildSkipButton(
                    icon: Icons.skip_previous,
                    onPressed: () => _onSkipPrevious(),
                  ),
                  const SizedBox(width: 8),
                ],
                const MaterialDesktopPlayOrPauseButton(iconSize: 32),
                if (!isLastEpisode) ...[
                  const SizedBox(width: 8),
                  _buildSkipButton(
                    icon: Icons.skip_next,
                    onPressed: () => _onSkipNext(),
                  ),
                ],
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
                ListenableBuilder(
                  listenable: subtitleService,
                  builder: (context, _) {
                    final hasSubtitles = subtitleService.hasSubtitles;
                    if (!hasSubtitles) return const SizedBox.shrink();
                    final isEnabled = subtitleService.isSubtitleVisible;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIntegratedButton(
                          icon: isEnabled
                              ? Icons.closed_caption
                              : Icons.closed_caption_off,
                          isActive: isEnabled,
                          onPressed: subtitleService.toggleEnabled,
                        ),
                        const SizedBox(width: 8),
                      ],
                    );
                  },
                ),
                _buildIntegratedButton(
                  icon: Icons.settings,
                  onPressed: () => _showSettingsMenu(context),
                ),
                if (onDownloadCurrentSource != null) ...[
                  const SizedBox(width: 8),
                  _buildIntegratedButton(
                    icon: Icons.download,
                    onPressed: onDownloadCurrentSource!,
                  ),
                ],
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
                if (!isFirstEpisode) ...[
                  _buildSkipButton(
                    icon: Icons.skip_previous,
                    onPressed: () => _onSkipPrevious(),
                  ),
                  const SizedBox(width: 8),
                ],
                const MaterialDesktopPlayOrPauseButton(iconSize: 32),
                if (!isLastEpisode) ...[
                  const SizedBox(width: 8),
                  _buildSkipButton(
                    icon: Icons.skip_next,
                    onPressed: () => _onSkipNext(),
                  ),
                ],
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
                ListenableBuilder(
                  listenable: subtitleService,
                  builder: (context, _) {
                    final hasSubtitles = subtitleService.hasSubtitles;
                    if (!hasSubtitles) return const SizedBox.shrink();
                    final isEnabled = subtitleService.isSubtitleVisible;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIntegratedButton(
                          icon: isEnabled
                              ? Icons.closed_caption
                              : Icons.closed_caption_off,
                          isActive: isEnabled,
                          onPressed: subtitleService.toggleEnabled,
                        ),
                        const SizedBox(width: 8),
                      ],
                    );
                  },
                ),
                _buildIntegratedButton(
                  icon: Icons.playlist_play,
                  onPressed: () => _showEpisodeSidePanel(context),
                ),
                const SizedBox(width: 8),
                _buildIntegratedButton(
                  icon: Icons.settings,
                  onPressed: () => _showSettingsMenu(context),
                ),
                if (onDownloadCurrentSource != null) ...[
                  const SizedBox(width: 8),
                  _buildIntegratedButton(
                    icon: Icons.download,
                    onPressed: onDownloadCurrentSource!,
                  ),
                ],
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
                      child: ValueListenableBuilder<double>(
                        valueListenable: currentVideoTimeListenable,
                        builder: (context, currentVideoTime, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: isVideoPausedListenable,
                            builder: (context, isVideoPaused, _) {
                              return DanmakuOverlay(
                                currentTime: currentVideoTime,
                                danmakuList: danmakuService.danmakuList,
                                settings: danmakuService.settings,
                                isPaused: isVideoPaused,
                                isPlaying: !isVideoPaused,
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

                  // 3. 原生控制层
                  AdaptiveVideoControls(state),

                  // 4. 移动端手势层 (在控制层之上，但不覆盖底部控件区域)
                  if (isMobile)
                    _MobileGestureAndLockLayer(
                      isEnabled: !isLocked,
                      isFullscreen: isFullscreenMode,
                      player: state.widget.controller.player,
                      onLeftDouble: () => _onSkipTime(-10),
                      onLeftTriple: () => _onSkipTime(-85),
                      onCenterDouble: _togglePlayPause,
                      onRightDouble: () => _onSkipTime(10),
                      onRightTriple: () => _onSkipTime(85),
                      onLock: () => mobilePlayerLockNotifier.value = true,
                    ),

                  // 5. 移动端全屏锁屏：锁定时吃掉屏幕触摸，只保留解锁入口
                  if (isLocked) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        onVerticalDragStart: (_) {},
                        onHorizontalDragStart: (_) {},
                        child: const SizedBox.expand(),
                      ),
                    ),
                    _buildFullscreenLockPositionedButton(
                      icon: Icons.lock,
                      tooltip: '解锁',
                      onPressed: () => mobilePlayerLockNotifier.value = false,
                    ),
                  ],

                  // 4. 右侧设置面板 (类似 Bilibili 风格)
                  ValueListenableBuilder<bool>(
                    valueListenable: showDanmakuSettingsListenable,
                    builder: (context, showDanmakuSettings, _) {
                      if (!showDanmakuSettings) return const SizedBox.shrink();
                      return Stack(
                        children: [
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
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建系统时间显示组件 - 只在全屏时显示
  Widget _buildSystemTimeDisplay() {
    return _SystemTimeDisplay();
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

  Widget _buildLockButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenLockPositionedButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Positioned(
      right: 24,
      top: 0,
      bottom: 0,
      child: SafeArea(
        child: Center(
          child: _buildLockButton(
            icon: icon,
            tooltip: tooltip,
            onPressed: onPressed,
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

  /// 跳转指定秒数（正数向前跳，负数向后跳）
  void _onSkipTime(int seconds) {
    final player = state.widget.controller.player;
    final currentPosition = player.state.position;
    final newPosition = currentPosition + Duration(seconds: seconds);

    // 确保新位置不小于0
    final targetPosition = newPosition < Duration.zero
        ? Duration.zero
        : newPosition;

    player.seek(targetPosition);
  }

  void _togglePlayPause() {
    final player = state.widget.controller.player;
    final isPlaying = player.state.playing;
    if (isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }

  double _resolveCurrentPlaybackSpeed() {
    final rate = state.widget.controller.player.state.rate;
    if (rate.isFinite && rate > 0) {
      return rate.clamp(0.25, 3.0).toDouble();
    }
    return playbackSpeed.clamp(0.25, 3.0).toDouble();
  }

  /// 移动端设置菜单
  void _showMobileSettingsMenu(
    BuildContext context, {
    required bool isFullscreen,
  }) {
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
              child: _SettingsPanel(
                isFullscreen: true,
                danmakuService: danmakuService,
                subtitleService: subtitleService,
                availableSources: availableSources,
                sourceIndexNotifier: sourceIndexNotifier,
                currentSourceLabel: currentSourceLabel,
                isAutoPlayNextEnabled: isAutoPlayNextEnabled,
                onToggleAutoPlayNext: onToggleAutoPlayNext,
                playbackSpeed: _resolveCurrentPlaybackSpeed(),
                onPlaybackSpeedChanged: onPlaybackSpeedChanged,
                onSourceSelected: (index) {
                  Navigator.pop(context);
                  onSourceSelected(index);
                },
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
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
          builder: (context, scrollController) => _SettingsPanel(
            isFullscreen: false,
            danmakuService: danmakuService,
            subtitleService: subtitleService,
            availableSources: availableSources,
            sourceIndexNotifier: sourceIndexNotifier,
            currentSourceLabel: currentSourceLabel,
            isAutoPlayNextEnabled: isAutoPlayNextEnabled,
            onToggleAutoPlayNext: onToggleAutoPlayNext,
            playbackSpeed: _resolveCurrentPlaybackSpeed(),
            onPlaybackSpeedChanged: onPlaybackSpeedChanged,
            onSourceSelected: (index) {
              Navigator.pop(context);
              onSourceSelected(index);
            },
            scrollController: scrollController,
          ),
        ),
      );
    }
  }

  void _showSettingsMenu(BuildContext context) {
    // 桌面端：使用侧边栏
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
            child: _SettingsPanel(
              isFullscreen: true,
              danmakuService: danmakuService,
              subtitleService: subtitleService,
              availableSources: availableSources,
              sourceIndexNotifier: sourceIndexNotifier,
              currentSourceLabel: currentSourceLabel,
              isAutoPlayNextEnabled: isAutoPlayNextEnabled,
              onToggleAutoPlayNext: onToggleAutoPlayNext,
              playbackSpeed: _resolveCurrentPlaybackSpeed(),
              onPlaybackSpeedChanged: onPlaybackSpeedChanged,
              onSourceSelected: (index) {
                Navigator.pop(context);
                onSourceSelected(index);
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
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
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
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
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // 选集列表
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                                    ? const Color(
                                        0xFFBB86FC,
                                      ).withValues(alpha: 0.2)
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
                                ep.sort.toInt().toString(),
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
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  // void _showEpisodeSelection(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: const Color(0xFF13131A),
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //     ),
  //     builder: (context) {
  //       return Container(
  //         height: 400,
  //         padding: const EdgeInsets.all(16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text(
  //               "选集",
  //               style: TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             const SizedBox(height: 16),
  //             Expanded(
  //               child: GridView.builder(
  //                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //                   crossAxisCount: 4,
  //                   mainAxisSpacing: 8,
  //                   crossAxisSpacing: 8,
  //                   childAspectRatio: 2.5,
  //                 ),
  //                 itemCount: allEpisodes.length,
  //                 itemBuilder: (context, index) {
  //                   final ep = allEpisodes[index];
  //                   final isSelected = ep == currentEpisode;
  //                   return InkWell(
  //                     onTap: () {
  //                       Navigator.pop(context);
  //                       onEpisodeSelected(ep);
  //                     },
  //                     child: Container(
  //                       alignment: Alignment.center,
  //                       decoration: BoxDecoration(
  //                         color: isSelected
  //                             ? const Color(0xFFBB86FC).withValues(alpha: 0.2)
  //                             : Colors.white.withValues(alpha: 0.05),
  //                         borderRadius: BorderRadius.circular(8),
  //                         border: Border.all(
  //                           color: isSelected
  //                               ? const Color(0xFFBB86FC)
  //                               : Colors.transparent,
  //                         ),
  //                       ),
  //                       child: Text(
  //                         ep.sort.toInt().toString(),
  //                         style: TextStyle(
  //                           color: isSelected
  //                               ? const Color(0xFFBB86FC)
  //                               : Colors.white70,
  //                         ),
  //                       ),
  //                     ),
  //                   );
  //                 },
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }
}

class _MobileGestureAndLockLayer extends StatefulWidget {
  final bool isEnabled;
  final bool isFullscreen;
  final Player player;
  final VoidCallback onLeftDouble;
  final VoidCallback onLeftTriple;
  final VoidCallback onCenterDouble;
  final VoidCallback onRightDouble;
  final VoidCallback onRightTriple;
  final VoidCallback onLock;

  const _MobileGestureAndLockLayer({
    required this.isEnabled,
    required this.isFullscreen,
    required this.player,
    required this.onLeftDouble,
    required this.onLeftTriple,
    required this.onCenterDouble,
    required this.onRightDouble,
    required this.onRightTriple,
    required this.onLock,
  });

  @override
  State<_MobileGestureAndLockLayer> createState() =>
      _MobileGestureAndLockLayerState();
}

class _MobileGestureAndLockLayerState
    extends State<_MobileGestureAndLockLayer> {
  static const Duration _lockButtonVisibleDuration = Duration(seconds: 3);

  bool _lockButtonVisible = false;
  Timer? _lockButtonTimer;

  @override
  void dispose() {
    _lockButtonTimer?.cancel();
    super.dispose();
  }

  void _handlePointerActivity() {
    if (!widget.isEnabled || !widget.isFullscreen) return;

    _lockButtonTimer?.cancel();
    if (_lockButtonVisible) {
      setState(() => _lockButtonVisible = false);
      return;
    }

    setState(() {
      _lockButtonVisible = true;
    });
    _lockButtonTimer = Timer(_lockButtonVisibleDuration, () {
      if (mounted) {
        setState(() => _lockButtonVisible = false);
      }
    });
  }

  void _handleLock() {
    _lockButtonTimer?.cancel();
    setState(() => _lockButtonVisible = false);
    widget.onLock();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 40,
          // 底部留出足够空间给进度条和按钮栏
          bottom: 80,
          child: _MobileMultiTapDetector(
            isEnabled: widget.isEnabled,
            player: widget.player,
            onPointerActivity: _handlePointerActivity,
            onLeftDouble: widget.onLeftDouble,
            onLeftTriple: widget.onLeftTriple,
            onCenterDouble: widget.onCenterDouble,
            onRightDouble: widget.onRightDouble,
            onRightTriple: widget.onRightTriple,
            child: const SizedBox.expand(),
          ),
        ),
        if (widget.isFullscreen && widget.isEnabled && _lockButtonVisible)
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Center(
                child: _MobileFloatingLockButton(
                  icon: Icons.lock_outline,
                  tooltip: '锁定',
                  onPressed: _handleLock,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MobileFloatingLockButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MobileFloatingLockButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

enum _MobileTapZone { left, center, right }

class _MobileMultiTapDetector extends StatefulWidget {
  final bool isEnabled;
  final Player player;
  final VoidCallback? onPointerActivity;
  final VoidCallback onLeftDouble;
  final VoidCallback onLeftTriple;
  final VoidCallback onCenterDouble;
  final VoidCallback onRightDouble;
  final VoidCallback onRightTriple;
  final Widget child;

  const _MobileMultiTapDetector({
    required this.isEnabled,
    required this.player,
    this.onPointerActivity,
    required this.onLeftDouble,
    required this.onLeftTriple,
    required this.onCenterDouble,
    required this.onRightDouble,
    required this.onRightTriple,
    required this.child,
  });

  @override
  State<_MobileMultiTapDetector> createState() =>
      _MobileMultiTapDetectorState();
}

class _MobileMultiTapDetectorState extends State<_MobileMultiTapDetector> {
  static const Duration _multiTapTimeout = Duration(milliseconds: 320);
  static const Duration _overlayDisplayDuration = Duration(milliseconds: 600);
  static const Duration _overlayFadeDuration = Duration(milliseconds: 160);

  Timer? _tapTimer;
  Timer? _overlayTimer;
  int _tapCount = 0;
  DateTime? _lastTapTime;
  _MobileTapZone? _lastZone;

  bool _isDragging = false;
  _MobileTapZone? _dragZone;
  double? _dragStartDy;
  double? _dragStartBrightness;
  double? _dragStartVolume;

  bool _isDraggingHorizontal = false;
  double? _dragStartDx;
  Duration? _dragStartPosition;
  Duration? _dragTargetPosition;

  bool _overlayVisible = false;
  IconData _overlayIcon = Icons.play_arrow;
  String _overlayLabel = '';

  // 长按快进状态
  bool _isLongPressFastForwarding = false;
  double? _originalPlaybackSpeed;

  @override
  void dispose() {
    _tapTimer?.cancel();
    _overlayTimer?.cancel();
    if (_isLongPressFastForwarding && _originalPlaybackSpeed != null) {
      widget.player.setRate(_originalPlaybackSpeed!);
    }
    super.dispose();
  }

  void _handleTap(PointerDownEvent event, BoxConstraints constraints) {
    if (!widget.isEnabled) return;
    if (_isDragging) return;
    if (event.kind != PointerDeviceKind.touch &&
        event.kind != PointerDeviceKind.stylus) {
      return;
    }
    widget.onPointerActivity?.call();

    final width = constraints.maxWidth;
    if (width <= 0) return;

    final zone = _resolveZone(event.localPosition.dx, width);
    final now = DateTime.now();

    final isSameZone = _lastZone == zone;
    final isWithinTimeout =
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= _multiTapTimeout;

    if (!isSameZone || !isWithinTimeout) {
      _tapCount = 0;
    }

    _tapCount += 1;
    _lastZone = zone;
    _lastTapTime = now;

    _tapTimer?.cancel();

    if (_tapCount >= 3) {
      _fireAction(zone, isTriple: true);
      _resetTapState();
      return;
    }

    _tapTimer = Timer(_multiTapTimeout, () {
      if (!mounted) return;
      if (_tapCount == 2) {
        _fireAction(zone, isTriple: false);
      }
      _resetTapState();
    });
  }

  void _handleVerticalDragStart(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;

    final zone = _resolveZone(details.localPosition.dx, constraints.maxWidth);
    if (zone == _MobileTapZone.center) return;

    _isDragging = true;
    _dragZone = zone;
    _dragStartDy = details.localPosition.dy;
    _resetTapState();

    if (zone == _MobileTapZone.left) {
      _prepareBrightnessOverlay();
    } else {
      // 隐藏系统音量条
      try {
        FlutterVolumeController.updateShowSystemUI(false);
      } catch (_) {}
      _prepareVolumeOverlay();
    }
  }

  void _handleVerticalDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;
    if (!_isDragging || _dragZone == null || _dragStartDy == null) return;
    if (constraints.maxHeight <= 0) return;

    final delta =
        (_dragStartDy! - details.localPosition.dy) / constraints.maxHeight;

    if (_dragZone == _MobileTapZone.left) {
      if (_dragStartBrightness == null) return;
      final target = (_dragStartBrightness! + delta).clamp(0.0, 1.0);
      _setBrightness(target);
      _showBrightnessOverlay(target);
    } else if (_dragZone == _MobileTapZone.right) {
      if (_dragStartVolume == null) return;
      final target = (_dragStartVolume! + delta).clamp(0.0, 1.0);
      _setSystemVolume(target);
      _showVolumeOverlay(target);
    }
  }

  void _handleVerticalDragEnd() {
    if (!_isDragging) return;

    // 恢复系统音量条显示
    if (_dragZone == _MobileTapZone.right) {
      try {
        FlutterVolumeController.updateShowSystemUI(true);
      } catch (_) {}
    }

    _isDragging = false;
    _dragZone = null;
    _dragStartDy = null;
    _dragStartBrightness = null;
    _dragStartVolume = null;
    _scheduleOverlayHide();
  }

  _MobileTapZone _resolveZone(double dx, double width) {
    final third = width / 3;
    if (dx < third) return _MobileTapZone.left;
    if (dx < third * 2) return _MobileTapZone.center;
    return _MobileTapZone.right;
  }

  void _fireAction(_MobileTapZone zone, {required bool isTriple}) {
    switch (zone) {
      case _MobileTapZone.left:
        if (isTriple) {
          _showOverlay(Icons.fast_rewind, '快退 85s');
          widget.onLeftTriple();
        } else {
          _showOverlay(Icons.replay_10, '快退 10s');
          widget.onLeftDouble();
        }
        break;
      case _MobileTapZone.center:
        if (!isTriple) {
          final isPlaying = widget.player.state.playing;
          _showOverlay(
            isPlaying ? Icons.pause : Icons.play_arrow,
            isPlaying ? '暂停' : '播放',
          );
          widget.onCenterDouble();
        }
        break;
      case _MobileTapZone.right:
        if (isTriple) {
          _showOverlay(Icons.fast_forward, '快进 85s');
          widget.onRightTriple();
        } else {
          _showOverlay(Icons.forward_10, '快进 10s');
          widget.onRightDouble();
        }
        break;
    }
  }

  void _showOverlay(IconData icon, String label) {
    _overlayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _overlayIcon = icon;
      _overlayLabel = label;
      _overlayVisible = true;
    });
    _overlayTimer = Timer(_overlayDisplayDuration, () {
      if (!mounted) return;
      setState(() => _overlayVisible = false);
    });
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayDisplayDuration, () {
      if (!mounted) return;
      setState(() => _overlayVisible = false);
    });
  }

  void _showBrightnessOverlay(double value) {
    final percent = (value * 100).round();
    _showOverlay(Icons.brightness_6, '亮度 $percent%');
  }

  void _showVolumeOverlay(double value) {
    final percent = (value * 100).round().clamp(0, 100);
    final icon = percent == 0
        ? Icons.volume_off
        : percent < 50
        ? Icons.volume_down
        : Icons.volume_up;
    _showOverlay(icon, '音量 $percent%');
  }

  Future<void> _prepareBrightnessOverlay() async {
    try {
      final current = await ScreenBrightness.instance.application;
      _dragStartBrightness = current;
      _showBrightnessOverlay(current);
    } catch (_) {
      _dragStartBrightness = null;
    }
  }

  Future<void> _setBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {
      // 忽略不支持的平台/权限错误
    }
  }

  Future<void> _prepareVolumeOverlay() async {
    try {
      final current = await FlutterVolumeController.getVolume();
      _dragStartVolume = current;
      _showVolumeOverlay(current ?? 0);
    } catch (_) {
      _dragStartVolume = null;
    }
  }

  Future<void> _setSystemVolume(double value) async {
    try {
      await FlutterVolumeController.setVolume(value);
    } catch (_) {
      // 忽略错误
    }
  }

  void _resetTapState() {
    _tapTimer?.cancel();
    _tapTimer = null;
    _tapCount = 0;
    _lastTapTime = null;
    _lastZone = null;
  }

  void _handleLongPressStart() {
    if (!widget.isEnabled) return;

    _tapTimer?.cancel();
    _resetTapState();

    _originalPlaybackSpeed = widget.player.state.rate;
    if (_originalPlaybackSpeed == null || _originalPlaybackSpeed! <= 0) {
      _originalPlaybackSpeed = 1.0;
    }

    _isLongPressFastForwarding = true;
    widget.player.setRate(2.0);

    _overlayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _overlayIcon = Icons.fast_forward;
      _overlayLabel = '长按快进 2x';
      _overlayVisible = true;
    });
  }

  void _handleLongPressEnd() {
    if (!_isLongPressFastForwarding) return;

    _isLongPressFastForwarding = false;

    final targetRate = _originalPlaybackSpeed ?? 1.0;
    widget.player.setRate(targetRate);
    _originalPlaybackSpeed = null;

    _scheduleOverlayHide();
  }

  void _handleHorizontalDragStart(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;

    _isDraggingHorizontal = true;
    _dragStartDx = details.localPosition.dx;
    _dragStartPosition = widget.player.state.position;
    _dragTargetPosition = _dragStartPosition;
    _resetTapState();

    _showSeekOverlay(_dragStartPosition!, _dragStartPosition!);
  }

  void _handleHorizontalDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;
    if (!_isDraggingHorizontal || _dragStartDx == null) return;
    if (constraints.maxWidth <= 0) return;

    final deltaPixels = details.localPosition.dx - _dragStartDx!;
    // 每100像素代表10秒
    final deltaSeconds = (deltaPixels / 100) * 10;

    final duration = widget.player.state.duration;
    final newPosition = (_dragStartPosition!.inSeconds + deltaSeconds.round())
        .clamp(0, duration.inSeconds);

    _dragTargetPosition = Duration(seconds: newPosition);
    _showSeekOverlay(_dragStartPosition!, _dragTargetPosition!);
  }

  void _handleHorizontalDragEnd() {
    if (!_isDraggingHorizontal) return;

    if (_dragTargetPosition != null) {
      widget.player.seek(_dragTargetPosition!);
    }

    _isDraggingHorizontal = false;
    _dragStartDx = null;
    _dragStartPosition = null;
    _dragTargetPosition = null;
    _scheduleOverlayHide();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _showSeekOverlay(Duration startPos, Duration targetPos) {
    final delta = targetPos.inSeconds - startPos.inSeconds;
    final icon = delta >= 0 ? Icons.fast_forward : Icons.fast_rewind;
    final label =
        '${_formatDuration(targetPos)} ${delta >= 0 ? "+" : ""}${delta}s';

    _overlayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _overlayIcon = icon;
      _overlayLabel = label;
      _overlayVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (details) =>
              _handleVerticalDragStart(details, constraints),
          onVerticalDragUpdate: (details) =>
              _handleVerticalDragUpdate(details, constraints),
          onVerticalDragEnd: (_) => _handleVerticalDragEnd(),
          onVerticalDragCancel: _handleVerticalDragEnd,
          onHorizontalDragStart: (details) =>
              _handleHorizontalDragStart(details, constraints),
          onHorizontalDragUpdate: (details) =>
              _handleHorizontalDragUpdate(details, constraints),
          onHorizontalDragEnd: (_) => _handleHorizontalDragEnd(),
          onHorizontalDragCancel: _handleHorizontalDragEnd,
          onLongPressStart: (_) => _handleLongPressStart(),
          onLongPressEnd: (_) => _handleLongPressEnd(),
          onLongPressCancel: () => _handleLongPressEnd(),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _handleTap(event, constraints),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _overlayVisible ? 1.0 : 0.0,
                      duration: _overlayFadeDuration,
                      child: AnimatedScale(
                        scale: _overlayVisible ? 1.0 : 0.9,
                        duration: _overlayFadeDuration,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_overlayIcon, color: Colors.white, size: 36),
                              const SizedBox(height: 6),
                              Text(
                                _overlayLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 设置面板组件 - 支持一级菜单导航
class _SettingsPanel extends StatefulWidget {
  final bool isFullscreen;
  final DanmakuService danmakuService;
  final SubtitleService subtitleService;
  final List<SearchPlayResult> availableSources;
  final ValueNotifier<int>? sourceIndexNotifier;
  final String currentSourceLabel;
  final Function(int) onSourceSelected;
  final bool isAutoPlayNextEnabled;
  final VoidCallback onToggleAutoPlayNext;
  final double playbackSpeed;
  final ValueChanged<double> onPlaybackSpeedChanged;
  final ScrollController? scrollController;

  const _SettingsPanel({
    required this.isFullscreen,
    required this.danmakuService,
    required this.subtitleService,
    required this.availableSources,
    this.sourceIndexNotifier,
    required this.currentSourceLabel,
    required this.onSourceSelected,
    required this.isAutoPlayNextEnabled,
    required this.onToggleAutoPlayNext,
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
    this.scrollController,
  });

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  // 0: 主菜单, 1: 弹幕设置, 2: 字幕设置, 3: 播放源, 4: 播放速度
  int _currentPage = 0;
  late int _currentSourceIndex;
  late double _currentPlaybackSpeed;

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
    _currentSourceIndex = widget.sourceIndexNotifier?.value ?? 0;
    _currentPlaybackSpeed = widget.playbackSpeed.clamp(0.25, 3.0).toDouble();
    widget.sourceIndexNotifier?.addListener(_onSourceIndexChanged);
  }

  @override
  void didUpdateWidget(_SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourceIndexNotifier != oldWidget.sourceIndexNotifier) {
      oldWidget.sourceIndexNotifier?.removeListener(_onSourceIndexChanged);
      widget.sourceIndexNotifier?.addListener(_onSourceIndexChanged);
      _currentSourceIndex = widget.sourceIndexNotifier?.value ?? 0;
    }
    if ((widget.playbackSpeed - oldWidget.playbackSpeed).abs() > 0.001) {
      _currentPlaybackSpeed = widget.playbackSpeed.clamp(0.25, 3.0).toDouble();
    }
  }

  @override
  void dispose() {
    widget.sourceIndexNotifier?.removeListener(_onSourceIndexChanged);
    super.dispose();
  }

  void _onSourceIndexChanged() {
    setState(() {
      _currentSourceIndex = widget.sourceIndexNotifier!.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isFullscreen ? 320 : double.infinity,
      height: widget.isFullscreen ? double.infinity : null,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
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
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // 标题栏
            _buildHeader(),
            const Divider(color: Colors.white12, height: 1),
            // 内容区域
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white70,
                size: 20,
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
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
          scrollController: widget.scrollController ?? ScrollController(),
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
          subtitle: widget.availableSources.isEmpty
              ? '暂无可用源'
              : '${widget.availableSources.isNotEmpty && _currentSourceIndex >= 0 && _currentSourceIndex < widget.availableSources.length ? widget.availableSources[_currentSourceIndex].sourceName : widget.currentSourceLabel} (${widget.availableSources.length}个可用)',
          onTap: () => setState(() => _currentPage = 3),
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.white12, height: 1),
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
        const Text(
          '常用倍速',
          style: TextStyle(
            color: Colors.white70,
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
        const Text(
          '提示：播放速度会同时影响视频与弹幕的时间同步。',
          style: TextStyle(color: Colors.white38, fontSize: 12),
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
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white70, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleSettings() {
    return ListenableBuilder(
      listenable: widget.subtitleService,
      builder: (context, _) {
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
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            // 字幕轨道选择
            const Text(
              '字幕轨道',
              style: TextStyle(
                color: Colors.white70,
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
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '当前视频没有内嵌字幕',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
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
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            // 字幕样式设置
            const Text(
              '字幕样式',
              style: TextStyle(
                color: Colors.white70,
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
            const Text(
              '字体颜色',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
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
                color: Colors.black,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFFBB86FC),
          inactiveTrackColor: Colors.white24,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              displayValue,
              style: const TextStyle(
                color: Color(0xFFBB86FC),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFBB86FC),
            inactiveTrackColor: Colors.white24,
            thumbColor: const Color(0xFFBB86FC),
            overlayColor: const Color(0xFFBB86FC).withValues(alpha: 0.2),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFBB86FC).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFBB86FC).withValues(alpha: 0.5)
                : Colors.transparent,
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
                          ? const Color(0xFFBB86FC)
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFBB86FC),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFFBB86FC) : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFBB86FC).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildSourceList() {
    if (widget.availableSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无可用播放源',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.availableSources.length,
      itemBuilder: (context, index) {
        final source = widget.availableSources[index];
        final isSelected = index == _currentSourceIndex;

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
                  ? const Color(0xFFBB86FC).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFBB86FC).withValues(alpha: 0.5)
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
                        ? const Color(0xFFBB86FC).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_circle_outline,
                    color: isSelected
                        ? const Color(0xFFBB86FC)
                        : Colors.white54,
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
                                    ? const Color(0xFFBB86FC)
                                    : Colors.white,
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
                                color: const Color(
                                  0xFFBB86FC,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(
                                    0xFFBB86FC,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                source.channelName!,
                                style: const TextStyle(
                                  color: Color(0xFFBB86FC),
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
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFFBB86FC),
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

/// 系统时间显示组件 - 使用 StatefulWidget 避免 Stream 多次监听问题
class _SystemTimeDisplay extends StatefulWidget {
  const _SystemTimeDisplay();

  @override
  State<_SystemTimeDisplay> createState() => _SystemTimeDisplayState();
}

class _SystemTimeDisplayState extends State<_SystemTimeDisplay> {
  late Timer _timer;
  late String _timeStr;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _timeStr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
