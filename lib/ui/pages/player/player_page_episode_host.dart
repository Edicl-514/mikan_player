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
        _sampleStatusMessageNotifier.value = AppLocalizations.of(
          context,
        ).playerSearchLocalPlayedHint;
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
    final previousEpisode = _episodeController.currentEpisode;
    if (!ep.isReleased() || ep.id == previousEpisode.id) return;

    // Persist progress for the episode we are leaving before zeroing trackers.
    final leavingPosMs = (_currentVideoTimeNotifier.value * 1000).toInt();
    final leaveSaveMs = leavingPosMs > 1000
        ? leavingPosMs
        : (_lastSavedPositionMs > 0 ? _lastSavedPositionMs : leavingPosMs);
    if (_historyProgressGate.hasObservedProgress && leaveSaveMs > 0) {
      unawaited(
        _persistPlaybackHistory(
          currentEpisode: previousEpisode,
          positionMs: leaveSaveMs,
        ),
      );
    }

    // Keep the old episode authoritative until its media has stopped, so late
    // position/playing events cannot be attributed to the new episode.
    try {
      await _player.stop();
    } catch (e, st) {
      debugPrint('Error stopping playback before episode switch: $e\n$st');
    }
    if (!mounted) return;
    final result = _episodeController.selectEpisode(ep);
    if (!result.changed) return;

    // Invalidate in-flight online-source work.
    final nextToken = _sampleSourceController.bumpLoadToken();
    _setSessionGeneration(nextToken);
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
      _lowerPrioritySearchesFinalized = false;
      _webviewStats.reset();

      // Reset comments
      _sidePanelLoader.resetComments();
    });
    _updateWorkspacePageTitle();
    _publishPlayerControlSourceState();

    // New episode: clear in-page time trackers and any pending seek from the
    // previous source. Bump generation so an in-flight resume seek from the
    // previous open cannot re-apply the old target.
    _currentVideoTimeNotifier.value = 0;
    _pendingStartPositionMs = null;
    _resumeSeekGeneration++;
    _lastSavedPositionMs = 0;
    _historyProgressGate.reset();
    _furthestObservedPosition = Duration.zero;
    _isRecoveringUnexpectedJump = false;

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
        _sampleStatusMessageNotifier.value = AppLocalizations.of(
          context,
        ).playerSearchLocalPlayedHint;
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

  Future<void> _persistPlaybackHistory({
    BangumiEpisode? currentEpisode,
    required int positionMs,
  }) async {
    try {
      await _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: currentEpisode ?? _episodeController.currentEpisode,
        allEpisodes: widget.allEpisodes,
        lastPositionMs: positionMs,
      );
    } catch (e, st) {
      debugPrint('Error saving playback history: $e\n$st');
    }
  }

  /// Queue a progress write for the current episode.
  void _savePlaybackHistory({int? positionMs}) {
    if (positionMs == null || !_historyProgressGate.observe(positionMs)) {
      return;
    }
    _lastSavedPositionMs = positionMs;
    unawaited(_persistPlaybackHistory(positionMs: positionMs));
  }

  Future<void> _hydrateResumePositionFromHistory() async {
    try {
      final resumeMs = await _historyManager.resolveStartPositionMsFor(
        anime: widget.anime,
        episode: _episodeController.currentEpisode,
        fallbackPositionMs: _pendingStartPositionMs,
      );
      if (!mounted || resumeMs == null || resumeMs <= 0) return;
      // The manager is authoritative: route arguments can come from a stale
      // history/home snapshot that remained mounted while playback continued.
      _pendingStartPositionMs = resumeMs;
      _lastSavedPositionMs = resumeMs;
      debugPrint('[History] Hydrated resume position: ${resumeMs}ms');
    } catch (e) {
      debugPrint('Error hydrating resume position: $e');
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
