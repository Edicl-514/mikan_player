part of '../player_page.dart';

extension _PlayerPageEpisodeHost on _PlayerPageState {
  Future<void> _handleWidgetEpisodeChanged() async {
    final hasDownloadedPlayback = await _checkAndPlayExistingBtDownload();
    if (!mounted) {
      return;
    }

    _updateState(() {
      _disableAutoSourceSearchForCurrentEpisode = hasDownloadedPlayback;
      if (hasDownloadedPlayback) {
        _sampleStatusMessageNotifier.value = '已播放本地资源，可手动搜索在线源';
      }
    });

    if (hasDownloadedPlayback) {
      return;
    }

    if (_sourceController.mikanAnime != null) {
      _reloadMikanResourcesForEpisode();
    } else {
      _loadMikanSource();
    }
    _loadDmhySource();
    _loadSampleSource();
  }

  Future<void> _reloadMikanResourcesForEpisode() =>
      reloadMikanResourcesForEpisode(
        controller: _sourceController,
        sink: _btSourceLoadSink,
        targetEpisode: _episodeController.currentEpisode.sort.toInt(),
      );

  void _onSkipNext() {
    final next = _episodeController.resolveByOffset(1);
    if (next != null) _onEpisodeSelected(next);
  }

  Future<void> _onEpisodeSelected(BangumiEpisode ep) async {
    final result = _episodeController.selectEpisode(ep);
    if (!result.changed) return;

    // Stop current player and invalidate in-flight online-source work.
    _player.stop();
    _sampleSourceController.bumpLoadToken();
    unawaited(_cancelSearchSubscriptions());

    // Update current episode and reset all states
    _updateState(() {
      // Reset video playback state
      _playbackController.resetForSwitching();
      _loadingMagnet = null;

      // Reset all source states (mikanAnime preserved — see controller)
      _sourceController.resetForSwitching();
      _sampleSourceController.resetForSwitching();

      _activeWebViews.clear();
      // Keep the pool slot table (warm InAppWebView + site cookies). Clearing
      // jobs + marking idle is enough for runners to cancel via didUpdateWidget
      // and accept the next captcha/video job without dispose/cookie wipe.
      _captchaCoordinator.resetForNewSearch();
      _scheduler.resetForNewSearch();
      _webViewStatus.clear();
      _failedWebViewPageKeys.clear();
      _resolvingChannelPlayPageKeys.clear();
      _sampleStatusMessageNotifier.value = '';
      _acceptedSourcePageKey = null;
      _webviewStats.reset();

      // Reset comments
      _sidePanelLoader.resetComments();
    });
    _videoTitleNotifier.value = '${widget.anime.title} - 第${ep.sort.toInt()}集';
    _publishPlayerControlSourceState();

    _savePlaybackHistory();

    // Clear and reload danmaku
    _danmakuService.clearDanmaku();
    _loadDanmaku();

    // Reload comments
    _loadComments();

    // If this episode already has a BT download ready, play it immediately.
    // This mirrors initState's behavior — without it, switching to an already
    // downloaded episode would silently fall through to Mikan/DMHY/sample
    // search even though a local stream is available.
    final hasDownloadedPlayback = await _checkAndPlayExistingBtDownload();
    if (!mounted) {
      return;
    }

    _updateState(() {
      _disableAutoSourceSearchForCurrentEpisode = hasDownloadedPlayback;
      if (hasDownloadedPlayback) {
        _sampleStatusMessageNotifier.value = '已播放本地资源，可手动搜索在线源';
      }
    });

    if (hasDownloadedPlayback) {
      return;
    }

    // Reload video sources
    if (_sourceController.mikanAnime != null) {
      _reloadMikanResourcesForEpisode();
    } else {
      _loadMikanSource();
    }
    _loadDmhySource();
    _loadSampleSource();
  }

  void _savePlaybackHistory() {
    try {
      final posMs = (_currentVideoTimeNotifier.value * 1000).toInt();
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _episodeController.currentEpisode,
        allEpisodes: widget.allEpisodes,
        lastPositionMs: posMs,
      );
      _lastSavedPositionMs = posMs;
    } catch (e) {
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _episodeController.currentEpisode,
        allEpisodes: widget.allEpisodes,
      );
    }
  }

  void _publishPlayerControlSourceState() {
    _playbackController.clampSelectedSourceIndex(
      _sampleSourceController.sampleSuccessfulSources.length,
    );
    final nextSourceIndex = _playbackController.selectedSourceIndex;
    _selectedSourceIndexNotifier.value = nextSourceIndex;
    _availableSourcesNotifier.value = List<SearchPlayResult>.unmodifiable(
      _sampleSourceController.sampleSuccessfulSources,
    );
    _playingSourceLabelNotifier.value = _playbackController.playingSourceLabel;
  }

  void _onSourceSelected(int index) {
    if (index < 0 ||
        index >= _sampleSourceController.sampleSuccessfulSources.length) {
      return;
    }

    final source = _sampleSourceController.sampleSuccessfulSources[index];
    if (source.directVideoUrl == null) return;

    _updateState(() {
      if (!_playbackController.selectSource(index, source)) return;
      _selectedSourceIndexNotifier.value = index;
      // We no longer set currentStreamUrl or call _player.open here.
      // This allows the user to click and see selection without loading the data.
    });
    _publishPlayerControlSourceState();
    debugPrint(
      '[_onSourceSelected] Source $index selected: ${source.sourceName}',
    );
  }

  void _startPlaybackFromSelectedSource() {
    if (_playbackController.selectedSourceIndex < 0 ||
        _playbackController.selectedSourceIndex >=
            _sampleSourceController.sampleSuccessfulSources.length) {
      return;
    }

    final source = _sampleSourceController
        .sampleSuccessfulSources[_playbackController.selectedSourceIndex];
    if (source.directVideoUrl == null) return;

    // Save current position for resuming playback after source switch
    // Check if we are actually playing something (duration > 0)
    if (_player.state.duration > Duration.zero) {
      final currentPos = _player.state.position.inMilliseconds;
      // Only resume if played more than 1 second to avoid resume-loop at start
      if (currentPos > 1000) {
        _pendingStartPositionMs = currentPos;
        debugPrint(
          '[_startPlayback] Will resume from: ${_pendingStartPositionMs}ms',
        );
      }
    }

    unawaited(_openOnlineSource(source, autoFallback: false));
  }
}
