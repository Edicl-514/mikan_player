import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/ui/widgets/danmaku_overlay.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';
import 'package:mikan_player/ui/widgets/subtitle_overlay.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/episode_side_panel.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/mobile_gesture_and_lock_layer.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/settings_panel.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/source_list_panel.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/system_time_display.dart';
import 'package:mikan_player/ui/pages/player/player_ui_mode.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';

/// 自定义视频播放器控件 - 整合弹幕与播放控制
/// 深度集成 media_kit_video 的 Material 风格控件
class CustomVideoControls extends StatefulWidget {
  final VideoState state;
  final PlayerUiMode uiMode;
  @Deprecated('Use uiMode')
  final bool? isMobile;

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
  final VoidCallback onPlayRequested;

  const CustomVideoControls({
    super.key,
    required this.state,
    this.uiMode = PlayerUiMode.mobile,
    @Deprecated('Use uiMode') this.isMobile,
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
    // i18n-ignore: protocol sentinel shared with player_playback_controller
    this.currentSourceLabel = kPlayerSourceLabelUnknown,
    this.currentSourceLabelListenable,
    this.isLoading = false,
    required this.onUserInteraction,
    required this.mobilePlayerLockNotifier,
    this.videoTitle,
    this.videoTitleListenable,
    required this.onPlayRequested,
    required this.isAutoPlayNextEnabled,
    required this.onToggleAutoPlayNext,
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  BangumiEpisode get _resolvedCurrentEpisode =>
      widget.currentEpisodeListenable?.value ?? widget.currentEpisode;

  String? get _resolvedVideoTitle =>
      widget.videoTitleListenable?.value ?? widget.videoTitle;

  int get _resolvedCurrentEpisodeIndex {
    final currentEpisode = _resolvedCurrentEpisode;
    final idIndex = currentEpisode.id == 0
        ? -1
        : widget.allEpisodes.indexWhere(
            (episode) => episode.id == currentEpisode.id,
          );
    if (idIndex != -1) {
      return idIndex;
    }

    final sortIndex = widget.allEpisodes.indexWhere(
      (episode) => episode.sort == currentEpisode.sort,
    );
    if (sortIndex != -1) {
      return sortIndex;
    }

    return widget.allEpisodes.indexOf(currentEpisode);
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      ...[
        widget.currentEpisodeListenable,
        widget.videoTitleListenable,
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

  /// 选集按钮方向枚举保留在 controls 文件中；
  /// 选集高亮判断已随 `EpisodeSidePanel` 一并抽出。

  Widget _buildControls(BuildContext context) {
    final videoTitle = _resolvedVideoTitle;
    final danmakuService = widget.danmakuService;
    final subtitleService = widget.subtitleService;
    final isMobile = widget.isMobile ?? widget.uiMode.isMobile;
    final isLoading = widget.isLoading;
    final onUserInteraction = widget.onUserInteraction;
    final mobilePlayerLockNotifier = widget.mobilePlayerLockNotifier;
    final currentVideoTimeListenable = widget.currentVideoTimeListenable;
    final isVideoPausedListenable = widget.isVideoPausedListenable;
    final showDanmakuSettingsListenable = widget.showDanmakuSettingsListenable;
    final onToggleDanmakuSettings = widget.onToggleDanmakuSettings;
    final state = widget.state;

    final l10n = AppLocalizations.of(context);

    // 计算当前集数索引，用于控制按钮显示
    // 移动端 - 非全屏顶部按钮栏
    final mobileNormalTopButtonBar = [
      IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        tooltip: l10n.back,
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
            label: l10n.danmaku,
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
        tooltip: l10n.back,
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
      const _MobileFullscreenButton(),
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
          label: l10n.selectEpisode,
          onPressed: () => _showEpisodeSidePanel(ctx),
        ),
      ),
      const SizedBox(width: 8),
      const _MobileFullscreenButton(),
      const SizedBox(width: 16),
    ];

    // 桌面端 - 非全屏顶部按钮栏（显示空降按钮）
    final desktopNormalTopButtonBar = [
      const Spacer(),
      _buildIntegratedButton(
        context: context,
        icon: Icons.fast_rewind,
        label: l10n.skipBack85,
        onPressed: () => _onSkipTime(-85),
      ),
      const SizedBox(width: 8),
      _buildIntegratedButton(
        context: context,
        icon: Icons.fast_forward,
        label: l10n.skipForward85,
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
        label: l10n.skipBack85,
        onPressed: () => _onSkipTime(-85),
      ),
      const SizedBox(width: 8),
      _buildIntegratedButton(
        context: context,
        icon: Icons.fast_forward,
        label: l10n.skipForward85,
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
                  _DesktopAppFullscreenButton(
                    enterTooltip: l10n.playerAppFullscreen,
                    exitTooltip: l10n.playerAppFullscreenExit,
                  ),
                  const SizedBox(width: 8),
                  _DesktopWindowFullscreenButton(
                    enterTooltip: l10n.playerWindowFullscreen,
                    exitTooltip: l10n.playerWindowFullscreenExit,
                  ),
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
                  _DesktopAppFullscreenButton(
                    enterTooltip: l10n.playerAppFullscreen,
                    exitTooltip: l10n.playerAppFullscreenExit,
                  ),
                  const SizedBox(width: 8),
                  _DesktopWindowFullscreenButton(
                    enterTooltip: l10n.playerWindowFullscreen,
                    exitTooltip: l10n.playerWindowFullscreenExit,
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. 应用侧字幕层（避开 media_kit 全屏路由里 SubtitleView 不刷新的问题）
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SubtitleOverlay(
                          subtitleService: subtitleService,
                        ),
                      ),
                    ),

                    // 2. 弹幕渲染层 (在视频/字幕之后，控件之前)
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

                    // 3. 加载选集提示
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

                    // 4. 原生控制层
                    AdaptiveVideoControls(state),

                    // 5. 移动端手势层 (在控制层之上，但不覆盖底部控件区域)
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

                    // 6. 移动端全屏锁屏：锁定时吃掉屏幕触摸，只保留解锁入口
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
                        tooltip: AppLocalizations.of(context).unlock,
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

    final videoTitleListenable = widget.videoTitleListenable;
    if (videoTitleListenable == null) {
      return Text(fallback, style: style);
    }

    return ValueListenableBuilder<String>(
      valueListenable: videoTitleListenable,
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
    final listenable = widget.currentEpisodeListenable;
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
        currentIndex >= 0 && currentIndex < widget.allEpisodes.length - 1,
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
      widget.onEpisodeSelected(widget.allEpisodes[currentIndex - 1]);
    }
  }

  /// 切换到下一集
  void _onSkipNext() {
    final currentIndex = _resolvedCurrentEpisodeIndex;
    if (currentIndex >= 0 && currentIndex < widget.allEpisodes.length - 1) {
      widget.onEpisodeSelected(widget.allEpisodes[currentIndex + 1]);
    }
  }

  /// 跳转指定秒数（正数向前跳，负数向后跳）
  void _onSkipTime(int seconds) {
    widget.onUserInteraction();
    final player = widget.state.widget.controller.player;
    final currentPosition = player.state.position;
    final newPosition = currentPosition + Duration(seconds: seconds);

    // 确保新位置不小于0
    final targetPosition = newPosition < Duration.zero
        ? Duration.zero
        : newPosition;

    player.seek(targetPosition);
  }

  void _togglePlayPause() {
    widget.onUserInteraction();
    final player = widget.state.widget.controller.player;
    final isPlaying = player.state.playing;
    if (isPlaying) {
      player.pause();
    } else {
      widget.onPlayRequested();
    }
  }

  double _resolveCurrentPlaybackSpeed() {
    final rate = widget.state.widget.controller.player.state.rate;
    if (rate.isFinite && rate > 0) {
      return rate.clamp(0.25, 3.0).toDouble();
    }
    return widget.playbackSpeed.clamp(0.25, 3.0).toDouble();
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
        barrierLabel: AppLocalizations.of(context).closeSettingsBarrier,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SettingsPanel(
                isFullscreen: true,
                danmakuService: widget.danmakuService,
                subtitleService: widget.subtitleService,
                availableSources: widget.availableSources,
                availableSourcesListenable: widget.availableSourcesListenable,
                sourceIndexNotifier: widget.sourceIndexNotifier,
                currentSourceLabel: widget.currentSourceLabel,
                currentSourceLabelListenable:
                    widget.currentSourceLabelListenable,
                isAutoPlayNextEnabled: widget.isAutoPlayNextEnabled,
                onToggleAutoPlayNext: widget.onToggleAutoPlayNext,
                playbackSpeed: _resolveCurrentPlaybackSpeed(),
                onPlaybackSpeedChanged: widget.onPlaybackSpeedChanged,
                onSourceSelected: (index) {
                  Navigator.pop(context);
                  widget.onSourceSelected(index);
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
            danmakuService: widget.danmakuService,
            subtitleService: widget.subtitleService,
            availableSources: widget.availableSources,
            availableSourcesListenable: widget.availableSourcesListenable,
            sourceIndexNotifier: widget.sourceIndexNotifier,
            currentSourceLabel: widget.currentSourceLabel,
            currentSourceLabelListenable: widget.currentSourceLabelListenable,
            isAutoPlayNextEnabled: widget.isAutoPlayNextEnabled,
            onToggleAutoPlayNext: widget.onToggleAutoPlayNext,
            playbackSpeed: _resolveCurrentPlaybackSpeed(),
            onPlaybackSpeedChanged: widget.onPlaybackSpeedChanged,
            onSourceSelected: (index) {
              Navigator.pop(context);
              widget.onSourceSelected(index);
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
      barrierLabel: AppLocalizations.of(context).closeSettingsBarrier,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SettingsPanel(
              isFullscreen: true,
              danmakuService: widget.danmakuService,
              subtitleService: widget.subtitleService,
              availableSources: widget.availableSources,
              availableSourcesListenable: widget.availableSourcesListenable,
              sourceIndexNotifier: widget.sourceIndexNotifier,
              currentSourceLabel: widget.currentSourceLabel,
              currentSourceLabelListenable: widget.currentSourceLabelListenable,
              isAutoPlayNextEnabled: widget.isAutoPlayNextEnabled,
              onToggleAutoPlayNext: widget.onToggleAutoPlayNext,
              playbackSpeed: _resolveCurrentPlaybackSpeed(),
              onPlaybackSpeedChanged: widget.onPlaybackSpeedChanged,
              onSourceSelected: (index) {
                Navigator.pop(context);
                widget.onSourceSelected(index);
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
      barrierLabel: AppLocalizations.of(context).closeEpisodesBarrier,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return EpisodeSidePanel(
          allEpisodes: widget.allEpisodes,
          currentEpisode: _resolvedCurrentEpisode,
          currentEpisodeListenable: widget.currentEpisodeListenable,
          onEpisodeSelected: widget.onEpisodeSelected,
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

class _MobileFullscreenButton extends StatefulWidget {
  const _MobileFullscreenButton();

  @override
  State<_MobileFullscreenButton> createState() =>
      _MobileFullscreenButtonState();
}

class _MobileFullscreenButtonState extends State<_MobileFullscreenButton> {
  bool _transitioning = false;

  Future<void> _toggle() async {
    if (_transitioning) return;
    _transitioning = true;
    final fullscreen = isFullscreen(context);
    try {
      if (fullscreen) {
        await exitFullscreen(context);
        return;
      }

      // media_kit invokes onEnterFullscreen after pushing its route. Prepare
      // the mobile viewport first so the fullscreen video is built once at
      // its final landscape size instead of visibly relaying out afterward.
      final usesNativeMobileFullscreen =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (usesNativeMobileFullscreen) {
        await defaultEnterNativeFullscreen();
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) {
        if (usesNativeMobileFullscreen) {
          await defaultExitNativeFullscreen();
        }
        return;
      }
      try {
        await enterFullscreen(context);
      } catch (_) {
        if (usesNativeMobileFullscreen) {
          await defaultExitNativeFullscreen();
        }
        rethrow;
      }
    } finally {
      _transitioning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = isFullscreen(context);
    final l10n = AppLocalizations.of(context);
    return IconButton(
      onPressed: _transitioning ? null : _toggle,
      icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
      color: Colors.white,
      tooltip: fullscreen
          ? l10n.playerAppFullscreenExit
          : l10n.playerAppFullscreen,
    );
  }
}

class _DesktopAppFullscreenButton extends StatelessWidget {
  const _DesktopAppFullscreenButton({
    required this.enterTooltip,
    required this.exitTooltip,
  });

  final String enterTooltip;
  final String exitTooltip;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: WindowsDesktopFrameController.instance,
      builder: (context, _) {
        // The combined window+player fullscreen action owns the exit path;
        // keeping this button mounted would allow two competing transitions.
        if (WindowsDesktopFrameController.instance.isWindowFullscreen) {
          return const SizedBox.shrink();
        }
        final fullscreen = isFullscreen(context);
        return Tooltip(
          message: fullscreen ? exitTooltip : enterTooltip,
          child: IconButton(
            onPressed: () => toggleFullscreen(context),
            icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            iconSize: 24,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class _DesktopWindowFullscreenButton extends StatefulWidget {
  const _DesktopWindowFullscreenButton({
    required this.enterTooltip,
    required this.exitTooltip,
  });

  final String enterTooltip;
  final String exitTooltip;

  @override
  State<_DesktopWindowFullscreenButton> createState() =>
      _DesktopWindowFullscreenButtonState();
}

class _DesktopWindowFullscreenButtonState
    extends State<_DesktopWindowFullscreenButton>
    with WindowListener {
  static Future<void> _operation = Future<void>.value();
  static bool _nativeTransitionInProgress = false;
  bool? _requestedFullscreen;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncState() async {
    try {
      final isFullscreen = await windowManager.isFullScreen();
      WindowsDesktopFrameController.instance.setWindowFullscreen(isFullscreen);
    } catch (_) {
      // window_manager is unavailable on non-desktop platforms; this widget
      // is only inserted in the desktop controls tree.
    }
  }

  @override
  void onWindowEnterFullScreen() {
    final controller = WindowsDesktopFrameController.instance;
    controller.setWindowFullscreen(true);
    if (!_nativeTransitionInProgress && !controller.isContentFullscreen) {
      _enqueue(() => _enterPlayerFullscreen(context));
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    final controller = WindowsDesktopFrameController.instance;
    controller.setWindowFullscreen(false);
    if (!_nativeTransitionInProgress && controller.isContentFullscreen) {
      _enqueue(() => _exitPlayerFullscreen(context));
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _operation.then((_) => action());
    _operation = next.catchError((_) {});
    return next;
  }

  Future<void> _enterPlayerFullscreen(BuildContext context) async {
    final controller = WindowsDesktopFrameController.instance;
    if (!controller.isContentFullscreen && mounted) {
      await enterFullscreen(context);
    }
  }

  Future<void> _exitPlayerFullscreen(BuildContext context) async {
    final controller = WindowsDesktopFrameController.instance;
    if (!controller.isContentFullscreen || !mounted) return;
    if (isFullscreen(context)) {
      await exitFullscreen(context);
    } else {
      // The button below the fullscreen route remains mounted. Pop only when
      // the player page confirms that its content fullscreen route is active.
      await Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  Future<void> _setCombinedFullscreen(bool value) async {
    final controller = WindowsDesktopFrameController.instance;
    if (value) {
      await _enterPlayerFullscreen(context);
      if (!controller.isWindowFullscreen) {
        // Hide the app-only button before the native transition starts. The
        // native event arrives asynchronously and must not expose a second
        // exit path during that gap.
        controller.setWindowFullscreen(true);
        _nativeTransitionInProgress = true;
        try {
          await windowManager.setFullScreen(true);
        } finally {
          _nativeTransitionInProgress = false;
        }
      }
    } else {
      if (controller.isWindowFullscreen) {
        _nativeTransitionInProgress = true;
        try {
          await windowManager.setFullScreen(false);
        } finally {
          _nativeTransitionInProgress = false;
        }
        controller.setWindowFullscreen(false);
      }
      if (!mounted) return;
      await _exitPlayerFullscreen(context);
    }
  }

  Future<void> _toggle() {
    final controller = WindowsDesktopFrameController.instance;
    final target = !(_requestedFullscreen ?? controller.isWindowFullscreen);
    _requestedFullscreen = target;
    return _enqueue(() async {
      await _setCombinedFullscreen(target);
      if (_requestedFullscreen == target) _requestedFullscreen = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: WindowsDesktopFrameController.instance,
      builder: (context, _) {
        final isFullscreen =
            WindowsDesktopFrameController.instance.isWindowFullscreen;
        return Tooltip(
          message: isFullscreen ? widget.exitTooltip : widget.enterTooltip,
          child: IconButton(
            onPressed: _toggle,
            icon: Icon(
              isFullscreen ? Icons.fullscreen_exit : Icons.open_in_full,
            ),
            iconSize: 24,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

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
