part of '../player_page.dart';

extension _PlayerPagePlaybackHost on _PlayerPageState {
  /// 把进入播放页时启动的"重活"（评论 / 推荐 / 番剧 onair / 弹幕 / 在线源
  /// 搜索等）统一延后到首帧 + 转场动画结束之后再触发，避免页面刚加载时
  /// 多个网络请求 / WebView 启动 / 弹幕解析同时争抢主线程导致首屏卡一下。
  void _scheduleDeferredEntryWork() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_sessionLifecycle.acceptsNewWork) return;
      await Future.delayed(_PlayerPageState._entryAnimationGuard);
      if (!mounted || !_sessionLifecycle.acceptsNewWork) return;
      unawaited(_loadComments());
      unawaited(_loadRecommendations());
      unawaited(_loadOnairSites());
      unawaited(_loadDanmaku());
      unawaited(_maybeApplyEpisodeRefresh());
      unawaited(_initializePlaybackAndSourceLoading());
    });
  }

  Future<void> _initializePlaybackAndSourceLoading() async {
    // Resolve resume position before opening any media so applyPendingStartPosition
    // runs with a real target on the first open.
    // Always reconcile the route argument with the live history snapshot. A
    // long-lived history/home page may pass an older position.
    await _hydrateResumePositionFromHistory();
    if (!mounted || !_sessionLifecycle.acceptsNewWork) return;

    var hasDownloadedPlayback = false;

    // Check if we have a direct BT stream URL to play
    if (widget.btStreamUrl != null) {
      _playBtStreamUrl(widget.btStreamUrl!);
      hasDownloadedPlayback = true;
    } else {
      // Check for existing BT download for this episode
      hasDownloadedPlayback = await _checkAndPlayExistingBtDownload();
    }

    if (!mounted || !_sessionLifecycle.acceptsNewWork) {
      return;
    }

    _updateState(() {
      _disableAutoSourceSearchForCurrentEpisode = hasDownloadedPlayback;
      if (hasDownloadedPlayback) {
        final l10n = AppLocalizations.of(context);
        _sampleStatusMessageNotifier.value = l10n.playerSearchLocalPlayedHint;
      }
    });

    await _loadSettings(autoLoadSample: !hasDownloadedPlayback);

    if (!mounted ||
        !_sessionLifecycle.acceptsNewWork ||
        hasDownloadedPlayback) {
      return;
    }

    _loadMikanSource();
    _loadDmhySource();
  }

  /// Check existing downloads for this episode and auto-play with BT priority.
  Future<bool> _checkAndPlayExistingBtDownload() async {
    final loadToken = _sampleSourceController.sampleLoadToken;

    // Check BT first
    final btTask = _downloadManager.getAvailableBtTaskForEpisode(
      widget.anime.title,
      _episodeController.currentEpisode.sort.toInt(),
    );

    if (btTask != null) {
      final streamUrl = await _downloadManager.getOrCreateStreamUrl(btTask.id);
      if (!_acceptsSessionCallback(loadToken) || streamUrl == null) {
        return false;
      }
      debugPrint(
        '[Player] Found existing BT download for this episode: ${btTask.name}',
      );
      _playBtStreamUrl(streamUrl, loadToken: loadToken);
      return true;
    }

    // Check completed HTTP download
    final httpTask = _downloadManager.getCompletedHttpTaskForEpisode(
      widget.anime.title,
      _episodeController.currentEpisode.sort.toInt(),
    );
    if (httpTask != null && httpTask.localFilePath != null) {
      final filePath = httpTask.localFilePath!;
      final file = File(filePath);
      if (await file.exists()) {
        if (!_acceptsSessionCallback(loadToken)) {
          return false;
        }
        debugPrint(
          '[Player] Found existing HTTP download for this episode: ${httpTask.name}',
        );
        _updateState(() {
          _playbackController.markLocalPlayback(
            filePath,
            label: AppLocalizations.of(context).playerSourceLabelOnline,
            clearCurrentOnlineSource: false,
          );
        });
        _publishPlayerControlSourceState();
        _temporarilyAllowPositionReset();
        _resumeSeekGeneration++;
        final openGeneration = _resumeSeekGeneration;
        unawaited(
          _openWithFocus(_mediaForPlayback(filePath)).then((_) async {
            if (!_acceptsSessionCallback(loadToken)) {
              return;
            }
            await _applyPlaybackSpeed();
            if (!_acceptsSessionCallback(loadToken)) {
              return;
            }
            await _applyPendingStartPosition(generation: openGeneration);
          }),
        );
        return true;
      }
    }

    return false;
  }

  /// Play a BT stream URL directly
  void _playBtStreamUrl(String streamUrl, {int? loadToken}) {
    final expectedLoadToken =
        loadToken ?? _sampleSourceController.sampleLoadToken;
    if (!_acceptsSessionCallback(expectedLoadToken)) {
      return;
    }
    _updateState(() {
      _playbackController.markLocalPlayback(
        streamUrl,
        label: AppLocalizations.of(context).playerSourceLabelBt,
      );
    });
    _publishPlayerControlSourceState();

    // 通知下载管理器BT流现在活跃（防止libtorrent流被移除）
    final btHash = _extractBtHashFromStreamUrl(streamUrl);
    if (btHash != null) {
      DownloadManager().setActiveStream(btHash);
      debugPrint(
        '[Player] Notified DownloadManager: stream active for $btHash',
      );
    }

    debugPrint('[Player] Playing BT stream: $streamUrl');
    _temporarilyAllowPositionReset();
    _resumeSeekGeneration++;
    final openGeneration = _resumeSeekGeneration;
    unawaited(
      _openWithFocus(_mediaForPlayback(streamUrl)).then((_) async {
        if (!_acceptsSessionCallback(expectedLoadToken)) {
          return;
        }
        await _applyPlaybackSpeed();
        if (!_acceptsSessionCallback(expectedLoadToken)) {
          return;
        }
        await _applyPendingStartPosition(generation: openGeneration);
      }),
    );
  }

  /// 从BT流URL中提取info hash
  String? _extractBtHashFromStreamUrl(String streamUrl) =>
      extractBtHashFromStreamUrl(streamUrl);

  /// Download the currently playing online source
  Future<void> _onDownloadCurrentSource() async {
    final source = _playbackController.currentOnlineSource;
    if (source == null || source.directVideoUrl == null) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playerNoDownloadableSource)),
        );
      }
      return;
    }

    // Start from the playback browser context (UA + play-page Referer). The
    // download job walks a header-strategy fallback chain on 403/401 so CDNs
    // that ACL-deny a foreign Referer still succeed without a host denylist.
    final headers = PlayerPlaybackController.buildPlaybackHeaders(source);

    final episodeName = _episodeController.currentEpisode.nameCn.isNotEmpty
        ? _episodeController.currentEpisode.nameCn
        : _episodeController.currentEpisode.name;
    final l10n = AppLocalizations.of(context);
    final localizedEpisodeName = episodeName.isNotEmpty
        ? episodeName
        : l10n.playerEpisodeNumber(
            _episodeController.currentEpisode.sort.toInt(),
          );
    final downloadName = l10n.playerDownloadTaskName(
      widget.anime.title,
      localizedEpisodeName,
      source.sourceName,
    );

    try {
      await _downloadManager.startHttpDownload(
        url: source.directVideoUrl!,
        name: downloadName,
        headers: headers.isNotEmpty ? headers : null,
        cookies: source.cookies,
        animeName: widget.anime.title,
        episodeNumber: _episodeController.currentEpisode.sort.toInt(),
      );
    } catch (e) {
      debugPrint('[Download] Failed to add current online source: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playerAddDownloadTaskFailed)),
        );
      }
      return;
    }

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.playerAddDownloadTaskSuccess)),
      );
    }
  }

  void _onCopyCurrentSourceUrl() {
    final url = _playbackController.currentOnlineSource?.directVideoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.playerNoCopyableLink)));
      }
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.playerDownloadLinkCopied)));
    }
  }

  Widget _buildCurrentSourceActionButtons({bool compact = false}) {
    final canAct =
        _playbackController.currentOnlineSource != null &&
        _playbackController.currentOnlineSource!.directVideoUrl != null;
    return PlayerCurrentSourceActions(
      canAct: canAct,
      compact: compact,
      onDownload: _onDownloadCurrentSource,
      onCopyUrl: _onCopyCurrentSourceUrl,
    );
  }

  /// Builds a [Media] that asks the native player to open at the resume point.
  ///
  /// media_kit maps [Media.start] to mpv's `start` property, which is more
  /// reliable than a post-open seek for many local/HTTP sources. The pending
  /// position is intentionally NOT consumed here — [_applyPendingStartPosition]
  /// still verifies and falls back to an explicit seek.
  Media _mediaForPlayback(String url) {
    final startMs = _pendingStartPositionMs;
    if (startMs != null && startMs > 0) {
      return Media(url, start: Duration(milliseconds: startMs));
    }
    return Media(url);
  }

  /// Waits until the player reports a positive duration (or [timeout] elapses).
  ///
  /// Important: `player.stream.duration` is a broadcast stream and does not
  /// replay the latest value. Always check [Player.state.duration] first, and
  /// re-check after subscribing, or a late subscriber can miss the emission
  /// that landed between the state read and the listen.
  Future<bool> _waitForSeekableMedia({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_player.state.duration.inMilliseconds > 0) {
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> sub;
    sub = _player.stream.duration.listen((duration) {
      if (duration.inMilliseconds > 0 && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    // Close the race window: duration may have arrived between the initial
    // state read and the subscription above.
    if (_player.state.duration.inMilliseconds > 0) {
      await sub.cancel();
      return true;
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return _player.state.duration.inMilliseconds > 0;
    } catch (_) {
      return _player.state.duration.inMilliseconds > 0;
    } finally {
      await sub.cancel();
    }
  }

  bool _isNearResumeTarget(Duration target, {int toleranceMs = 2500}) {
    final posMs = _player.state.position.inMilliseconds;
    return (posMs - target.inMilliseconds).abs() <= toleranceMs;
  }

  /// Seeks to the pending resume position after media open.
  ///
  /// [generation] must match the page's current [_resumeSeekGeneration] so an
  /// older open (source switch / episode switch) cannot steal a newer target
  /// or apply a seek after the pending value was intentionally cleared.
  Future<void> _applyPendingStartPosition({int? generation}) async {
    final targetMs = _pendingStartPositionMs;
    if (targetMs == null || targetMs <= 0) {
      return;
    }
    if (generation != null && generation != _resumeSeekGeneration) {
      debugPrint(
        '[Seek] Drop stale resume apply '
        '(gen=$generation current=$_resumeSeekGeneration)',
      );
      return;
    }

    final target = Duration(milliseconds: targetMs);
    try {
      final ready = await _waitForSeekableMedia();
      if (!mounted) return;
      if (generation != null && generation != _resumeSeekGeneration) {
        return;
      }
      // Pending was replaced while we waited (e.g. source switch).
      if (_pendingStartPositionMs != targetMs) {
        debugPrint(
          '[Seek] Resume target changed while waiting '
          '($targetMs -> $_pendingStartPositionMs)',
        );
        return;
      }
      if (!ready) {
        debugPrint(
          '[Seek] Duration not ready; keeping pending resume at ${targetMs}ms',
        );
        return;
      }

      final duration = _player.state.duration;
      var seekTarget = target;
      if (duration > Duration.zero && seekTarget >= duration) {
        // Avoid landing on EOF / completed; leave a small tail.
        final clamped = duration - const Duration(seconds: 3);
        seekTarget = clamped > Duration.zero ? clamped : Duration.zero;
      }
      if (seekTarget <= Duration.zero) {
        _pendingStartPositionMs = null;
        return;
      }

      // Media.start may already have landed us near the target.
      if (_isNearResumeTarget(seekTarget)) {
        _pendingStartPositionMs = null;
        _lastSavedPositionMs = seekTarget.inMilliseconds;
        _furthestObservedPosition = seekTarget;
        debugPrint(
          '[Seek] Resume already near target: '
          '${_player.state.position.inMilliseconds}ms '
          '(wanted ${seekTarget.inMilliseconds}ms)',
        );
        return;
      }

      // A few attempts: some streams ignore the first seek while still probing.
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!mounted) return;
        if (generation != null && generation != _resumeSeekGeneration) {
          return;
        }
        if (_pendingStartPositionMs != targetMs) {
          return;
        }

        _temporarilyAllowPositionReset();
        // Keep anti-ad baseline from snapping the resume seek back to 0 after
        // the short grace window ends with furthest still near zero.
        _furthestObservedPosition = seekTarget;
        await _player.seek(seekTarget);
        debugPrint(
          '[Seek] Applied start position attempt ${attempt + 1}: '
          '${seekTarget.inMilliseconds}ms',
        );

        // Give the player a beat to report the new position.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;

        if (_isNearResumeTarget(seekTarget)) {
          _pendingStartPositionMs = null;
          _lastSavedPositionMs = seekTarget.inMilliseconds;
          _furthestObservedPosition = seekTarget;
          debugPrint(
            '[Seek] Resume confirmed at '
            '${_player.state.position.inMilliseconds}ms',
          );
          return;
        }
      }

      debugPrint(
        '[Seek] Resume seek did not stick '
        '(pos=${_player.state.position.inMilliseconds}ms, '
        'wanted=${seekTarget.inMilliseconds}ms); keeping pending',
      );
    } catch (e) {
      debugPrint('Error applying start position: $e');
    }
  }

  Future<void> _loadSettings({bool autoLoadSample = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPlaybackSpeed = (prefs.getDouble('playback_speed') ?? 1.0)
          .clamp(0.25, 3.0)
          .toDouble();
      final appWideWebViewLimit =
          (prefs.getInt('max_concurrent_webviews') ??
                  PlayerPage.kDefaultMaxConcurrentWebViews)
              .clamp(1, 64);
      final normalizedAppWideWebViewLimit = appWideWebViewLimit.toInt();
      WebViewResourceCoordinator.instance.updateLimit(
        normalizedAppWideWebViewLimit,
      );
      if (mounted) {
        _updateState(() {
          _isAutoPlayNextEnabled = prefs.getBool('auto_play_next') ?? true;
          _autoSearchOnline = prefs.getBool('auto_search_online') ?? true;
          _maxConcurrentWebViews = WebViewResourceCoordinator.instance.limit;
          _trimIdleWebViewWorkerSlotsToBudget();
          _cancelLowPrioritySourcesOnPlay =
              prefs.getBool('cancel_low_priority_sources_on_play') ?? true;
          _webViewLaunchInterval =
              prefs.getInt('webview_launch_interval') ?? 200;
          _playbackSpeed = savedPlaybackSpeed;
        });
      }
      await _applyPlaybackSpeed();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    // Load sample source after settings to respect _autoSearchOnline
    if (mounted && autoLoadSample) {
      _loadSampleSource();
    }
  }

  Future<void> _saveAutoPlaySetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_play_next', value);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _savePlaybackSpeedSetting(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('playback_speed', value);
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  Future<void> _applyPlaybackSpeed() async {
    try {
      await _player.setRate(_playbackSpeed);
    } catch (e) {
      debugPrint('Error applying playback speed: $e');
    }
  }

  void _onPlaybackSpeedChanged(double value) {
    final clampedSpeed = value.clamp(0.25, 3.0).toDouble();
    _updateState(() {
      _playbackSpeed = clampedSpeed;
    });
    unawaited(_applyPlaybackSpeed());
    unawaited(_savePlaybackSpeedSetting(clampedSpeed));
  }

  // Load danmaku based on anime title and episode
  Future<void> _loadDanmaku() async {
    final animeTitle = widget.anime.title;
    final n = _episodeController.currentEpisodeNumbers;
    final episodeNumber = n.absolute;
    final relativeEpNumber = n.relative;

    debugPrint(
      '[Danmaku] Loading danmaku for: $animeTitle EP$episodeNumber (rel: $relativeEpNumber)',
    );

    // Prefer Bangumi TV subject_id if available for more accurate matching
    if (widget.anime.bangumiId != null && widget.anime.bangumiId!.isNotEmpty) {
      final subjectId = int.tryParse(widget.anime.bangumiId!);
      if (subjectId != null) {
        debugPrint('[Danmaku] Using Bangumi TV subject_id: $subjectId');
        await _danmakuService.loadDanmakuByBangumiId(
          subjectId,
          episodeNumber.toString(),
          relativeEpisode: relativeEpNumber,
          animeTitle: animeTitle, // 传入动漫名称用于失败重试
        );
        return;
      }
    }

    // Fallback to title-based search
    debugPrint('[Danmaku] Using title-based search');
    await _danmakuService.loadDanmakuByTitle(
      animeTitle,
      episodeNumber.toString(),
      relativeEpisode: relativeEpNumber,
    );
  }
}
