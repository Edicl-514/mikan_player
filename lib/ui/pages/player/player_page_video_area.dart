part of '../player_page.dart';

extension _PlayerPageVideoArea on _PlayerPageState {
  String? _localizedVideoError(BuildContext context) {
    final error = _playbackController.videoError;
    if (error == null) return null;

    final l10n = AppLocalizations.of(context);
    return switch (error.kind) {
      PlayerPlaybackErrorKind.raw => error.detail,
      PlayerPlaybackErrorKind.openFailed => l10n.playerPlaybackOpenFailed(
        error.detail ?? '',
      ),
      PlayerPlaybackErrorKind.startupTimeout =>
        l10n.playerPlaybackStartupTimeout,
    };
  }

  Widget _buildVideoPlayerPlaceholder(
    BuildContext context, {
    required bool isMobile,
  }) {
    return PlayerVideoArea(
      isMobile: isMobile,
      isPlayerInitialized: _isPlayerInitialized,
      currentStreamUrl: _playbackController.currentStreamUrl,
      isLoadingVideo: _playbackController.isLoadingVideo,
      loadingMagnet: _loadingMagnet,
      videoError: _localizedVideoError(context),
      videoController: _videoController,
      danmakuService: _danmakuService,
      subtitleService: _subtitleService,
      currentVideoTimeListenable: _currentVideoTimeNotifier,
      isVideoPausedListenable: _isVideoPausedNotifier,
      showDanmakuSettingsListenable: _showDanmakuSettingsNotifier,
      onToggleDanmakuSettings: () => _showDanmakuSettingsNotifier.value =
          !_showDanmakuSettingsNotifier.value,
      allEpisodes: _episodeController.playableEpisodes,
      currentEpisode: _episodeController.currentEpisode,
      currentEpisodeListenable: _episodeController.currentEpisodeListenable,
      onEpisodeSelected: _onEpisodeSelected,
      isAutoPlayNextEnabled: _isAutoPlayNextEnabled,
      onToggleAutoPlayNext: () {
        final newValue = !_isAutoPlayNextEnabled;
        _updateState(() {
          _isAutoPlayNextEnabled = newValue;
        });
        _saveAutoPlaySetting(newValue);
      },
      playbackSpeed: _playbackSpeed,
      onPlaybackSpeedChanged: _onPlaybackSpeedChanged,
      availableSources: _sampleSourceController.sampleSuccessfulSources,
      availableSourcesListenable: _availableSourcesNotifier,
      sourceIndexNotifier: _selectedSourceIndexNotifier,
      currentSourceLabel: _playbackController.playingSourceLabel,
      currentSourceLabelListenable: _playingSourceLabelNotifier,
      onSourceSelected: (index) {
        _onSourceSelected(index);
        _startPlaybackFromSelectedSource();
      },
      onUserInteraction: _markUserInteraction,
      mobilePlayerLockNotifier: _mobilePlayerLockNotifier,
      videoTitle: _videoTitleNotifier.value,
      videoTitleListenable: _videoTitleNotifier,
      onPlayRequested: () => unawaited(_playWithFocus()),
      onEnterFullscreen: () async {
        _isVideoFullscreen = true;
      },
      onExitFullscreen: () async {
        _isVideoFullscreen = false;
      },
    );
  }
}
