part of '../player_page.dart';

extension _PlayerPagePlaybackHost on _PlayerPageState {
  /// 把进入播放页时启动的"重活"（评论 / 推荐 / 番剧 onair / 弹幕 / 在线源
  /// 搜索等）统一延后到首帧 + 转场动画结束之后再触发，避免页面刚加载时
  /// 多个网络请求 / WebView 启动 / 弹幕解析同时争抢主线程导致首屏卡一下。
  void _scheduleDeferredEntryWork() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(_PlayerPageState._entryAnimationGuard);
      if (!mounted) return;
      unawaited(_loadComments());
      unawaited(_loadRecommendations());
      unawaited(_loadOnairSites());
      unawaited(_loadDanmaku());
      unawaited(_initializePlaybackAndSourceLoading());
    });
  }

  Future<void> _initializePlaybackAndSourceLoading() async {
    var hasDownloadedPlayback = false;

    // Check if we have a direct BT stream URL to play
    if (widget.btStreamUrl != null) {
      _playBtStreamUrl(widget.btStreamUrl!);
      hasDownloadedPlayback = true;
    } else {
      // Check for existing BT download for this episode
      hasDownloadedPlayback = await _checkAndPlayExistingBtDownload();
    }

    if (!mounted) {
      return;
    }

    _updateState(() {
      _disableAutoSourceSearchForCurrentEpisode = hasDownloadedPlayback;
      if (hasDownloadedPlayback) {
        _sampleStatusMessageNotifier.value = '已播放本地资源，可手动搜索在线源';
      }
    });

    await _loadSettings(autoLoadSample: !hasDownloadedPlayback);

    if (!mounted || hasDownloadedPlayback) {
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
      if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          ) ||
          streamUrl == null) {
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
        if (!isSearchGenerationCurrent(
          resultLoadToken: loadToken,
          currentLoadToken: _sampleSourceController.sampleLoadToken,
          isDisposed: !mounted,
        )) {
          return false;
        }
        debugPrint(
          '[Player] Found existing HTTP download for this episode: ${httpTask.name}',
        );
        _updateState(() {
          _playbackController.markLocalPlayback(
            filePath,
            label: '在线源下载',
            clearCurrentOnlineSource: false,
          );
        });
        _publishPlayerControlSourceState();
        _temporarilyAllowPositionReset();
        _player.open(Media(filePath), play: true).then((_) async {
          if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          await _applyPlaybackSpeed();
          if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          await _applyPendingStartPosition();
        });
        return true;
      }
    }

    return false;
  }

  /// Play a BT stream URL directly
  void _playBtStreamUrl(String streamUrl, {int? loadToken}) {
    final expectedLoadToken =
        loadToken ?? _sampleSourceController.sampleLoadToken;
    if (!isSearchGenerationCurrent(
      resultLoadToken: expectedLoadToken,
      currentLoadToken: _sampleSourceController.sampleLoadToken,
      isDisposed: !mounted,
    )) {
      return;
    }
    _updateState(() {
      _playbackController.markLocalPlayback(streamUrl, label: 'BT下载');
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
    _player.open(Media(streamUrl), play: true).then((_) async {
      if (!isSearchGenerationCurrent(
        resultLoadToken: expectedLoadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      )) {
        return;
      }
      await _applyPlaybackSpeed();
      if (!isSearchGenerationCurrent(
        resultLoadToken: expectedLoadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      )) {
        return;
      }
      await _applyPendingStartPosition();
    });
  }

  /// 从BT流URL中提取info hash
  String? _extractBtHashFromStreamUrl(String streamUrl) =>
      extractBtHashFromStreamUrl(streamUrl);

  /// Download the currently playing online source
  Future<void> _onDownloadCurrentSource() async {
    final source = _playbackController.currentOnlineSource;
    if (source == null || source.directVideoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有可下载的在线源')));
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
    final downloadName =
        '${widget.anime.title} - ${episodeName.isNotEmpty ? episodeName : '第${_episodeController.currentEpisode.sort.toInt()}集'} (${source.sourceName})';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加下载任务失败，请稍后重试')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加到下载任务')));
    }
  }

  void _onCopyCurrentSourceUrl() {
    final url = _playbackController.currentOnlineSource?.directVideoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有可复制的下载链接')));
      }
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下载链接已复制')));
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

  Future<void> _applyPendingStartPosition() async {
    if (_pendingStartPositionMs != null) {
      final targetPosition = _pendingStartPositionMs!;
      _pendingStartPositionMs = null;

      try {
        // Wait for media to be ready (duration > 0)
        await for (final duration in _player.stream.duration) {
          if (duration.inMilliseconds > 0) {
            // Media is ready, now seek
            _temporarilyAllowPositionReset();
            await _player.seek(Duration(milliseconds: targetPosition));
            debugPrint('[Seek] Applied start position: ${targetPosition}ms');
            break;
          }
        }
      } catch (e) {
        debugPrint('Error applying start position: $e');
      }
    }
  }

  Future<void> _loadSettings({bool autoLoadSample = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPlaybackSpeed = (prefs.getDouble('playback_speed') ?? 1.0)
          .clamp(0.25, 3.0)
          .toDouble();
      if (mounted) {
        _updateState(() {
          _isAutoPlayNextEnabled = prefs.getBool('auto_play_next') ?? true;
          _autoSearchOnline = prefs.getBool('auto_search_online') ?? true;
          _maxConcurrentWebViews =
              prefs.getInt('max_concurrent_webviews') ??
              PlayerPage.kDefaultMaxConcurrentWebViews;
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
    final n = _episodeController.currentEpisodeNumbersAgainst(
      widget.allEpisodes,
    );
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
