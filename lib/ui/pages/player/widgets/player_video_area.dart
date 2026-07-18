import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/widgets/video_player_controls.dart';

/// Video surface + empty/loading/error placeholder for [PlayerPage].
///
/// Pure presentation: all player/controller objects are injected; no page State.
class PlayerVideoArea extends StatelessWidget {
  final bool isMobile;
  final bool isPlayerInitialized;
  final String? currentStreamUrl;
  final bool isLoadingVideo;
  final String? loadingMagnet;
  final String? videoError;
  final VideoController videoController;
  final DanmakuService danmakuService;
  final SubtitleService subtitleService;
  final ValueNotifier<double> currentVideoTimeListenable;
  final ValueNotifier<bool> isVideoPausedListenable;
  final ValueNotifier<bool> showDanmakuSettingsListenable;
  final VoidCallback onToggleDanmakuSettings;
  final List<BangumiEpisode> allEpisodes;
  final BangumiEpisode currentEpisode;
  final ValueListenable<BangumiEpisode> currentEpisodeListenable;
  final ValueChanged<BangumiEpisode> onEpisodeSelected;
  final bool isAutoPlayNextEnabled;
  final VoidCallback onToggleAutoPlayNext;
  final double playbackSpeed;
  final ValueChanged<double> onPlaybackSpeedChanged;
  final List<SearchPlayResult> availableSources;
  final ValueNotifier<List<SearchPlayResult>> availableSourcesListenable;
  final ValueNotifier<int> sourceIndexNotifier;
  final String currentSourceLabel;
  final ValueNotifier<String> currentSourceLabelListenable;
  final ValueChanged<int> onSourceSelected;
  final VoidCallback onUserInteraction;
  final ValueNotifier<bool> mobilePlayerLockNotifier;
  final String videoTitle;
  final ValueNotifier<String> videoTitleListenable;

  const PlayerVideoArea({
    super.key,
    required this.isMobile,
    required this.isPlayerInitialized,
    required this.currentStreamUrl,
    required this.isLoadingVideo,
    required this.loadingMagnet,
    required this.videoError,
    required this.videoController,
    required this.danmakuService,
    required this.subtitleService,
    required this.currentVideoTimeListenable,
    required this.isVideoPausedListenable,
    required this.showDanmakuSettingsListenable,
    required this.onToggleDanmakuSettings,
    required this.allEpisodes,
    required this.currentEpisode,
    required this.currentEpisodeListenable,
    required this.onEpisodeSelected,
    required this.isAutoPlayNextEnabled,
    required this.onToggleAutoPlayNext,
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
    required this.availableSources,
    required this.availableSourcesListenable,
    required this.sourceIndexNotifier,
    required this.currentSourceLabel,
    required this.currentSourceLabelListenable,
    required this.onSourceSelected,
    required this.onUserInteraction,
    required this.mobilePlayerLockNotifier,
    required this.videoTitle,
    required this.videoTitleListenable,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isPlayerInitialized && currentStreamUrl != null) {
      // 字幕由 CustomVideoControls 内的 SubtitleOverlay 渲染，
      // 关闭 media_kit 自带 SubtitleView，避免全屏双层字幕且样式不刷新。
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => onUserInteraction(),
        onPointerMove: (_) => onUserInteraction(),
        onPointerUp: (_) => onUserInteraction(),
        child: Video(
          controller: videoController,
          subtitleViewConfiguration: const SubtitleViewConfiguration(
            visible: false,
          ),
          controls: (state) => CustomVideoControls(
            state: state,
            isMobile: isMobile,
            danmakuService: danmakuService,
            subtitleService: subtitleService,
            currentVideoTimeListenable: currentVideoTimeListenable,
            isVideoPausedListenable: isVideoPausedListenable,
            showDanmakuSettingsListenable: showDanmakuSettingsListenable,
            onToggleDanmakuSettings: onToggleDanmakuSettings,
            allEpisodes: allEpisodes,
            currentEpisode: currentEpisode,
            currentEpisodeListenable: currentEpisodeListenable,
            onEpisodeSelected: onEpisodeSelected,
            isAutoPlayNextEnabled: isAutoPlayNextEnabled,
            onToggleAutoPlayNext: onToggleAutoPlayNext,
            playbackSpeed: playbackSpeed,
            onPlaybackSpeedChanged: onPlaybackSpeedChanged,
            availableSources: availableSources,
            availableSourcesListenable: availableSourcesListenable,
            sourceIndexNotifier: sourceIndexNotifier,
            currentSourceLabel: currentSourceLabel,
            currentSourceLabelListenable: currentSourceLabelListenable,
            onSourceSelected: onSourceSelected,
            isLoading: isLoadingVideo || loadingMagnet != null,
            onUserInteraction: onUserInteraction,
            mobilePlayerLockNotifier: mobilePlayerLockNotifier,
            videoTitle: videoTitle,
            videoTitleListenable: videoTitleListenable,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF000000), Color(0xFF1A1A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (isLoadingVideo || loadingMagnet != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.initializingPlayback,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.statusInitializing,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          )
        else if (videoError != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.playbackFailed,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    videoError!,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          )
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.chooseSourceToWatch,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.chooseSourceBelow,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        if (isMobile)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.back,
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.playerMoreOptions,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
