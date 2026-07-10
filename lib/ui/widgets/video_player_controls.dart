import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/ui/widgets/danmaku_overlay.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/mobile_gesture_and_lock_layer.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/settings_panel.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/system_time_display.dart';

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
  final ValueListenable<BangumiEpisode>? currentEpisodeListenable;
  final Function(BangumiEpisode) onEpisodeSelected;

  // 播放源相关
  final List<SearchPlayResult> availableSources;
  final ValueListenable<List<SearchPlayResult>>? availableSourcesListenable;
  final ValueNotifier<int>? sourceIndexNotifier;
  final Function(int) onSourceSelected;
  final String currentSourceLabel;
  final ValueListenable<String>? currentSourceLabelListenable;

  // 播放设置
  final bool isAutoPlayNextEnabled;
  final VoidCallback onToggleAutoPlayNext;
  final double playbackSpeed;
  final ValueChanged<double> onPlaybackSpeedChanged;

  // 加载状态
  final bool isLoading;
  final VoidCallback onUserInteraction;

  // 移动端锁屏状态
  final ValueNotifier<bool> mobilePlayerLockNotifier;

  // 视频标题
  final String? videoTitle;
  final ValueListenable<String>? videoTitleListenable;

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
    this.currentEpisodeListenable,
    required this.onEpisodeSelected,
    required this.availableSources,
    this.availableSourcesListenable,
    this.sourceIndexNotifier,
    required this.onSourceSelected,
    this.currentSourceLabel = '未知',
    this.currentSourceLabelListenable,
    this.isLoading = false,
    required this.onUserInteraction,
    required this.mobilePlayerLockNotifier,
    this.videoTitle,
    this.videoTitleListenable,
    required this.isAutoPlayNextEnabled,
    required this.onToggleAutoPlayNext,
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      ...[
        currentEpisodeListenable,
        videoTitleListenable,
      ].whereType<Listenable>(),
    ];

    if (listenables.isEmpty) {
      return _buildControls(context);
    }

    return _ReactiveListenablesBuilder(
      listenables: listenables,
      builder: (context) => _buildControls(context),
    );
  }

  BangumiEpisode get _resolvedCurrentEpisode =>
      currentEpisodeListenable?.value ?? currentEpisode;

  String? get _resolvedVideoTitle => videoTitleListenable?.value ?? videoTitle;

  int get _resolvedCurrentEpisodeIndex {
    final currentEpisode = _resolvedCurrentEpisode;
    final idIndex = currentEpisode.id == 0
        ? -1
        : allEpisodes.indexWhere((episode) => episode.id == currentEpisode.id);
    if (idIndex != -1) {
      return idIndex;
    }

    final sortIndex = allEpisodes.indexWhere(
      (episode) => episode.sort == currentEpisode.sort,
    );
    if (sortIndex != -1) {
      return sortIndex;
    }

    return allEpisodes.indexOf(currentEpisode);
  }

  bool _isEpisodeSelected(BangumiEpisode episode) {
    final currentEpisode = _resolvedCurrentEpisode;
    if (episode.id != 0 && currentEpisode.id != 0) {
      return episode.id == currentEpisode.id;
    }
    return episode.sort == currentEpisode.sort;
  }

  Widget _buildControls(BuildContext context) {
    final videoTitle = _resolvedVideoTitle;

    // 计算当前集数索引，用于控制按钮显示
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
            context: context,
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
          context: context,
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
        _buildFullscreenTitleText(videoTitle),
      ],
      const Spacer(),
      ListenableBuilder(
        listenable: danmakuService,
        builder: (context, _) {
          final settings = danmakuService.settings;
          final hasData = danmakuService.danmakuList.isNotEmpty;
          return _buildIntegratedButton(
            context: context,
            icon: settings.enabled ? Icons.subtitles : Icons.subtitles_off,
            isActive: settings.enabled,
            onPressed: hasData ? danmakuService.toggleEnabled : null,
          );
        },
      ),
      const SizedBox(width: 4),
      Builder(
        builder: (ctx) => _buildIntegratedButton(
          context: context,
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
      _buildEpisodeSkipButton(direction: _EpisodeSkipDirection.previous),
      const MaterialPlayOrPauseButton(),
      _buildEpisodeSkipButton(direction: _EpisodeSkipDirection.next),
      const SizedBox(width: 8),
      const MaterialPositionIndicator(),
      const Spacer(),
      Builder(
        builder: (ctx) => _buildIntegratedButton(
          context: context,
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
        context: context,
        icon: Icons.fast_rewind,
        label: "空降-85s",
        onPressed: () => _onSkipTime(-85),
      ),
      const SizedBox(width: 8),
      _buildIntegratedButton(
        context: context,
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
        _buildFullscreenTitleText(videoTitle, isDesktop: true),
      ],
      const Spacer(),
      _buildIntegratedButton(
        context: context,
        icon: Icons.fast_rewind,
        label: "空降-85s",
        onPressed: () => _onSkipTime(-85),
      ),
      const SizedBox(width: 8),
      _buildIntegratedButton(
        context: context,
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

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => onUserInteraction(),
          onPointerMove: (_) => onUserInteraction(),
          onPointerUp: (_) => onUserInteraction(),
          onPointerSignal: (_) => onUserInteraction(),
          child: MaterialVideoControlsTheme(
            normal: MaterialVideoControlsThemeData(
              topButtonBar: isLocked ? const [] : mobileNormalTopButtonBar,
              bottomButtonBar: isLocked
                  ? const []
                  : mobileNormalBottomButtonBar,
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
                  _buildEpisodeSkipButton(
                    direction: _EpisodeSkipDirection.previous,
                  ),
                  const MaterialDesktopPlayOrPauseButton(iconSize: 32),
                  _buildEpisodeSkipButton(
                    direction: _EpisodeSkipDirection.next,
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
                        context: context,
                        icon: settings.enabled
                            ? Icons.comment
                            : Icons.comments_disabled,
                        isActive: settings.enabled,
                        onPressed: hasData
                            ? danmakuService.toggleEnabled
                            : null,
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
                            context: context,
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
                    context: context,
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
                  _buildEpisodeSkipButton(
                    direction: _EpisodeSkipDirection.previous,
                  ),
                  const MaterialDesktopPlayOrPauseButton(iconSize: 32),
                  _buildEpisodeSkipButton(
                    direction: _EpisodeSkipDirection.next,
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
                        context: context,
                        icon: settings.enabled
                            ? Icons.comment
                            : Icons.comments_disabled,
                        isActive: settings.enabled,
                        onPressed: hasData
                            ? danmakuService.toggleEnabled
                            : null,
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
                            context: context,
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
                    context: context,
                    icon: Icons.playlist_play,
                    onPressed: () => _showEpisodeSidePanel(context),
                  ),
                  const SizedBox(width: 8),
                  _buildIntegratedButton(
                    context: context,
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
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),

                    // 3. 原生控制层
                    AdaptiveVideoControls(state),

                    // 4. 移动端手势层 (在控制层之上，但不覆盖底部控件区域)
                    if (isMobile)
                      MobileGestureAndLockLayer(
                        isEnabled: !isLocked,
                        isFullscreen: isFullscreenMode,
                        player: state.widget.controller.player,
                        onLeftDouble: () => _onSkipTime(-10),
                        onLeftTriple: () => _onSkipTime(-85),
                        onCenterDouble: _togglePlayPause,
                        onRightDouble: () => _onSkipTime(10),
                        onRightTriple: () => _onSkipTime(85),
                        onLock: () => mobilePlayerLockNotifier.value = true,
                        onUserInteraction: onUserInteraction,
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
                        if (!showDanmakuSettings) {
                          return const SizedBox.shrink();
                        }
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
          ),
        );
      },
    );
  }

  Widget _buildFullscreenTitleText(String fallback, {bool isDesktop = false}) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: isDesktop ? 16 : 14,
      fontWeight: FontWeight.w500,
    );

    if (videoTitleListenable == null) {
      return Text(fallback, style: style);
    }

    return ValueListenableBuilder<String>(
      valueListenable: videoTitleListenable!,
      builder: (context, value, _) =>
          Text(value.isNotEmpty ? value : fallback, style: style),
    );
  }

  /// 构建系统时间显示组件 - 只在全屏时显示
  Widget _buildSystemTimeDisplay() {
    return SystemTimeDisplay();
  }

  /// 构建风格统一的工具栏按钮
  Widget _buildIntegratedButton({
    required BuildContext context,
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
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                size: 20,
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
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
  Widget _buildEpisodeSkipButton({required _EpisodeSkipDirection direction}) {
    final listenable = currentEpisodeListenable;
    if (listenable == null) {
      return _buildEpisodeSkipButtonContent(direction);
    }

    return ValueListenableBuilder<BangumiEpisode>(
      valueListenable: listenable,
      builder: (context, _, child) => _buildEpisodeSkipButtonContent(direction),
    );
  }

  Widget _buildEpisodeSkipButtonContent(_EpisodeSkipDirection direction) {
    final currentIndex = _resolvedCurrentEpisodeIndex;
    final isVisible = switch (direction) {
      _EpisodeSkipDirection.previous => currentIndex > 0,
      _EpisodeSkipDirection.next =>
        currentIndex >= 0 && currentIndex < allEpisodes.length - 1,
    };
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: direction == _EpisodeSkipDirection.previous
          ? [
              _buildSkipButton(
                icon: Icons.skip_previous,
                onPressed: () => _onSkipPrevious(),
              ),
              const SizedBox(width: 8),
            ]
          : [
              const SizedBox(width: 8),
              _buildSkipButton(
                icon: Icons.skip_next,
                onPressed: () => _onSkipNext(),
              ),
            ],
    );
  }

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
    final currentIndex = _resolvedCurrentEpisodeIndex;
    if (currentIndex > 0) {
      onEpisodeSelected(allEpisodes[currentIndex - 1]);
    }
  }

  /// 切换到下一集
  void _onSkipNext() {
    final currentIndex = _resolvedCurrentEpisodeIndex;
    if (currentIndex >= 0 && currentIndex < allEpisodes.length - 1) {
      onEpisodeSelected(allEpisodes[currentIndex + 1]);
    }
  }

  /// 跳转指定秒数（正数向前跳，负数向后跳）
  void _onSkipTime(int seconds) {
    onUserInteraction();
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
    onUserInteraction();
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
              child: SettingsPanel(
                isFullscreen: true,
                danmakuService: danmakuService,
                subtitleService: subtitleService,
                availableSources: availableSources,
                availableSourcesListenable: availableSourcesListenable,
                sourceIndexNotifier: sourceIndexNotifier,
                currentSourceLabel: currentSourceLabel,
                currentSourceLabelListenable: currentSourceLabelListenable,
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
          builder: (context, scrollController) => SettingsPanel(
            isFullscreen: false,
            danmakuService: danmakuService,
            subtitleService: subtitleService,
            availableSources: availableSources,
            availableSourcesListenable: availableSourcesListenable,
            sourceIndexNotifier: sourceIndexNotifier,
            currentSourceLabel: currentSourceLabel,
            currentSourceLabelListenable: currentSourceLabelListenable,
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
            child: SettingsPanel(
              isFullscreen: true,
              danmakuService: danmakuService,
              subtitleService: subtitleService,
              availableSources: availableSources,
              availableSourcesListenable: availableSourcesListenable,
              sourceIndexNotifier: sourceIndexNotifier,
              currentSourceLabel: currentSourceLabel,
              currentSourceLabelListenable: currentSourceLabelListenable,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBgColor = isDark
        ? const Color(0xFF1A1A24)
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white54
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final borderColor = isDark
        ? Colors.white12
        : Theme.of(context).colorScheme.outlineVariant;
    final closeIconColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final unselectedBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final unselectedBorderColor = isDark
        ? Colors.white12
        : Theme.of(context).colorScheme.outlineVariant;
    final unselectedTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭选集',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        final scrollController = createPlatformScrollController();
        final listenables = <Listenable>[
          ...[currentEpisodeListenable].whereType<Listenable>(),
        ];

        Widget buildPanel(BuildContext panelContext) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: panelBgColor,
                  borderRadius: const BorderRadius.horizontal(
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
                            Text(
                              '选集',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '共${allEpisodes.length}集',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(panelContext),
                              icon: Icon(Icons.close, color: closeIconColor),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: borderColor, height: 1),
                      // 选集列表
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
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
                            final isSelected = _isEpisodeSelected(ep);
                            return InkWell(
                              onTap: () {
                                Navigator.pop(panelContext);
                                onEpisodeSelected(ep);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(panelContext)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.2)
                                      : unselectedBgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(
                                            panelContext,
                                          ).colorScheme.primary
                                        : unselectedBorderColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  ep.sort.toInt().toString(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(
                                            panelContext,
                                          ).colorScheme.primary
                                        : unselectedTextColor,
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
        }

        if (listenables.isEmpty) {
          return buildPanel(context);
        }

        return _ReactiveListenablesBuilder(
          listenables: listenables,
          builder: buildPanel,
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
  //                             ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
  //                             : Colors.white.withValues(alpha: 0.05),
  //                         borderRadius: BorderRadius.circular(8),
  //                         border: Border.all(
  //                           color: isSelected
  //                               ? Theme.of(context).colorScheme.primary
  //                               : Colors.transparent,
  //                         ),
  //                       ),
  //                       child: Text(
  //                         ep.sort.toInt().toString(),
  //                         style: TextStyle(
  //                           color: isSelected
  //                               ? Theme.of(context).colorScheme.primary
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

enum _EpisodeSkipDirection { previous, next }

class _ReactiveListenablesBuilder extends StatefulWidget {
  final List<Listenable> listenables;
  final WidgetBuilder builder;

  const _ReactiveListenablesBuilder({
    required this.listenables,
    required this.builder,
  });

  @override
  State<_ReactiveListenablesBuilder> createState() =>
      _ReactiveListenablesBuilderState();
}

class _ReactiveListenablesBuilderState
    extends State<_ReactiveListenablesBuilder> {
  @override
  void initState() {
    super.initState();
    for (final listenable in widget.listenables) {
      listenable.addListener(_markNeedsBuild);
    }
  }

  @override
  void didUpdateWidget(_ReactiveListenablesBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.listenables, oldWidget.listenables)) {
      return;
    }
    for (final listenable in oldWidget.listenables) {
      listenable.removeListener(_markNeedsBuild);
    }
    for (final listenable in widget.listenables) {
      listenable.addListener(_markNeedsBuild);
    }
  }

  @override
  void dispose() {
    for (final listenable in widget.listenables) {
      listenable.removeListener(_markNeedsBuild);
    }
    super.dispose();
  }

  void _markNeedsBuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// 设置面板组件 - 支持一级菜单导航
// (Moved to lib/ui/widgets/video_player_controls/settings_panel.dart as SettingsPanel.)
