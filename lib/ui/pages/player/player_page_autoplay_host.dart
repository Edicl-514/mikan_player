part of '../player_page.dart';

extension _PlayerPageAutoplayHost on _PlayerPageState {
  String _buildSourceChannelKey(String sourceName, BigInt? channelIndex) {
    return SourceChannelKey(
      sourceName: sourceName,
      channelIndex: channelIndex,
    ).toPageKey();
  }

  bool _containsPlayableSource(SearchPlayResult source) {
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    return _sampleSourceController.sampleSuccessfulSources.any(
      (item) =>
          _buildSourceChannelKey(item.sourceName, item.channelIndex) ==
          sourceKey,
    );
  }

  void _addPlayableSource(SearchPlayResult source) {
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    if (_playableSourceKeys.add(sourceKey) &&
        !_containsPlayableSource(source)) {
      _sampleSourceController.addSuccessfulSource(source);
      _publishPlayerControlSourceState();
    }
  }

  Future<void> _probeAndRegisterPlayableSource(
    SearchPlayResult source, {
    bool autoPlayAfterProbe = false,
  }) async {
    final directVideoUrl = source.directVideoUrl;
    if (directVideoUrl == null || directVideoUrl.isEmpty) {
      return;
    }
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    if (_playableSourceKeys.contains(sourceKey) ||
        _probingSourceKeys.contains(sourceKey)) {
      return;
    }

    final loadToken = _sampleSourceController.sampleLoadToken;
    _probingSourceKeys.add(sourceKey);
    final probeResult = await _videoUrlProbeService.probe(
      directVideoUrl,
      headers: PlayerPlaybackController.buildProbeHeaders(source),
      cookies: source.cookies,
    );
    _probingSourceKeys.remove(sourceKey);

    if (!isSearchGenerationCurrent(
      resultLoadToken: loadToken,
      currentLoadToken: _sampleSourceController.sampleLoadToken,
      isDisposed: !mounted,
    )) {
      return;
    }

    if (!probeResult.playable) {
      debugPrint(
        '[VideoProbe] Rejected ${source.sourceName} channel=${source.channelIndex}: '
        '${probeResult.error} status=${probeResult.statusCode} type=${probeResult.contentType}',
      );
      _failedWebViewPageKeys.add(sourceKey);
      _maybeFinishSampleSearch();
      return;
    }

    debugPrint(
      '[VideoProbe] Accepted ${source.sourceName} channel=${source.channelIndex} '
      'status=${probeResult.statusCode} latency=${probeResult.latency.inMilliseconds}ms',
    );

    _updateState(() {
      _addPlayableSource(source);
      _sampleStatusMessageNotifier.value = AppLocalizations.of(context)
          .playerAutoplaySearchDone(
            _sampleSourceController.sampleSuccessfulSources.length,
          );
    });

    if (autoPlayAfterProbe && _autoPlaySearchedSource) {
      _attemptAutoPlay();
    }

    _maybeFinishSampleSearch();
  }

  Future<void> _openOnlineSource(
    SearchPlayResult source, {
    required bool autoFallback,
    int? loadToken,
    int? autoPlayReservationId,
  }) async {
    final expectedLoadToken =
        loadToken ?? _sampleSourceController.sampleLoadToken;
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );

    if (!isSearchGenerationCurrent(
      resultLoadToken: expectedLoadToken,
      currentLoadToken: _sampleSourceController.sampleLoadToken,
      isDisposed: !mounted,
    )) {
      debugPrint(
        '[_openOnlineSource] drop stale open for $sourceKey '
        '(loadToken=$expectedLoadToken now=${_sampleSourceController.sampleLoadToken})',
      );
      // selectAutoPlayCandidate reserves the fallback latch before this method
      // runs. If we bail out here without reaching the controller, roll the
      // unstarted reservation back so a later same-generation autoplay is not
      // permanently blocked by `_isAutoPlayFallbackInProgress`.
      if (autoPlayReservationId != null) {
        _playbackController.cancelAutoPlayReservation(autoPlayReservationId);
      }
      return;
    }

    _temporarilyAllowPositionReset();
    // Invalidate in-flight resume seeks from a previous open before capturing
    // the generation for this open's post-open seek.
    _resumeSeekGeneration++;
    final openGeneration = _resumeSeekGeneration;
    final result = await _playbackController.openOnlineSource(
      source,
      autoFallback: autoFallback,
      loadToken: expectedLoadToken,
      isLoadTokenCurrent: (token) => isSearchGenerationCurrent(
        resultLoadToken: token,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      ),
      autoPlayReservationId: autoPlayReservationId,
      proxyUrlBuilder: (url, headers) => _headerProxy.registerUrl(url, headers),
      callbacks: PlayerPlaybackOpenCallbacks(
        stopPlayer: _player.stop,
        openUrl: (url) => _player.open(_mediaForPlayback(url), play: true),
        hasPlaybackStarted: () =>
            _player.state.playing || _player.state.position > Duration.zero,
        applyPlaybackSpeed: _applyPlaybackSpeed,
        applyPendingStartPosition: () =>
            _applyPendingStartPosition(generation: openGeneration),
        onStateChanged: _onPlaybackControllerStateChanged,
        onFallbackRequested: (request) {
          if (!isSearchGenerationCurrent(
            resultLoadToken: request.loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          _attemptAutoPlay(
            excludedSourceKey: request.sourceKey,
            forceRetry: true,
          );
        },
      ),
    );

    if (result.status == PlayerPlaybackOpenStatus.opened) {
      debugPrint('[_openOnlineSource] Media loading started for $sourceKey');
    } else if (result.status == PlayerPlaybackOpenStatus.failed) {
      debugPrint('[_openOnlineSource] ERROR loading media: ${result.error}');
    }
  }

  void _onPlaybackControllerStateChanged() {
    if (!mounted) return;
    _updateState(() {});
    _publishPlayerControlSourceState();
  }

  Future<void> _resolveChannelPlayPageUrl({
    required String sourceName,
    required String animeName,
    required BigInt channelIndex,
    required int episodeNumber,
    required String channelName,
    required String videoRegex,
    String? cookies,
    Map<String, String>? headers,
    String? searchPageHtml,
    String? searchPageUrl,
    String? detailPageHtml,
    String? detailPageUrl,
  }) async {
    final pageKey = _buildSourceChannelKey(sourceName, channelIndex);
    if (_resolvingChannelPlayPageKeys.contains(pageKey)) {
      return;
    }

    final hasAnyCaptchaContext =
        cookies != null ||
        searchPageHtml != null ||
        searchPageUrl != null ||
        detailPageHtml != null ||
        detailPageUrl != null;
    final runtimeOverride = hasAnyCaptchaContext
        ? SourceRuntimeOverride(
            sourceName: sourceName,
            cookies: cookies,
            searchPageHtml: searchPageHtml,
            searchPageUrl: searchPageUrl,
            detailPageHtml: detailPageHtml,
            detailPageUrl: detailPageUrl,
          )
        : null;

    final loadToken = _sampleSourceController.sampleLoadToken;
    _resolvingChannelPlayPageKeys.add(pageKey);
    try {
      final resolved = await getEpisodePlayUrl(
        sourceName: sourceName,
        animeName: animeName,
        channelIndex: channelIndex,
        episodeNumber: episodeNumber,
        runtimeOverride: runtimeOverride,
      );

      if (!isSearchGenerationCurrent(
        resultLoadToken: loadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      )) {
        return;
      }

      _updateState(() {
        final mergedHeaders = <String, String>{};
        if (headers != null) {
          mergedHeaders.addAll(headers);
        }
        if (resolved.headers != null) {
          mergedHeaders.addAll(resolved.headers!);
        }

        final channelResult = SearchPlayResult(
          sourceName: sourceName,
          playPageUrl: resolved.playPageUrl,
          videoRegex: resolved.videoRegex.isNotEmpty
              ? resolved.videoRegex
              : videoRegex,
          directVideoUrl: resolved.directVideoUrl,
          cookies: resolved.cookies ?? cookies,
          headers: mergedHeaders.isEmpty ? null : mergedHeaders,
          channelName: channelName,
          channelIndex: channelIndex,
          captchaConfigJson: resolved.captchaConfigJson,
          enableNestedUrl: resolved.enableNestedUrl,
          matchNestedUrl: resolved.matchNestedUrl,
        );

        final existingIndex = _sampleSourceController.samplePlayPages
            .indexWhere(
              (page) =>
                  _buildSourceChannelKey(page.sourceName, page.channelIndex) ==
                  pageKey,
            );

        if (existingIndex >= 0) {
          _sampleSourceController.replacePlayPageAt(
            existingIndex,
            channelResult,
          );
        } else {
          _addSamplePlayPage(channelResult);
        }

        if (channelResult.directVideoUrl != null &&
            channelResult.directVideoUrl!.isNotEmpty) {
          unawaited(
            _probeAndRegisterPlayableSource(
              channelResult,
              autoPlayAfterProbe: true,
            ),
          );
        }

        _sampleSourceController.sortPlayPagesByTier();
      });
    } catch (e, st) {
      debugPrint(
        '[Channel Resolve] Failed to resolve play page for $sourceName channel=$channelName($channelIndex): $e\n$st',
      );
    } finally {
      _resolvingChannelPlayPageKeys.remove(pageKey);
      if (isSearchGenerationCurrent(
        resultLoadToken: loadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      )) {
        _startNextWebViewExtraction();
      }
    }
  }

  void _attemptAutoPlay({String? excludedSourceKey, bool forceRetry = false}) {
    final decision = _playbackController.selectAutoPlayCandidate(
      _sampleSourceController.sampleSuccessfulSources,
      sourceTiers: _sampleSourceController.sourceTiers,
      excludedSourceKey: excludedSourceKey,
      forceRetry: forceRetry,
    );

    debugPrint(
      '[_attemptAutoPlay] ${decision.hasCandidate ? 'selected ${decision.source!.sourceName}' : 'blocked (${decision.blockReason})'}. '
      'Total sources: ${_sampleSourceController.sampleSuccessfulSources.length}',
    );

    if (decision.hasCandidate) {
      _playSource(decision);
    }
  }

  /// 一旦某 Tier-0 源被接受并开始播放，取消其他低优先级（仍在运行或在队列中）
  /// 提取任务以释放并发槽位，并阻止它们的迟到 onResult 触发 probe/autoplay。
  /// 已完成的发现结果（`_sampleSourceController.samplePlayPages`/`_sampleSourceController.sampleSuccessfulSources`）保持不变。
  ///
  /// 取消策略（tiers-aware）：只取消非 Tier-0 源的任务。Tier-0 源是用户配置的
  /// 高优先级源，其提取应跑完以便在源选择器里保留为后备候选。`except` 指向的
  /// 已接受 pageKey 永远不会被取消。与已接受源同名的 channel（即便 Tier 检查
  /// 不变）也会因 Tier 仍为 0 而继续，从而保证同源其他 channel 的迟到结果能
  /// 正常流过 `_onWebViewResult` 注册到源列表。
  ///
  /// 拆解机制说明：`WebViewVideoExtractorWidget` 由 `_buildWebViewExtractors`
  /// 构建并以子节点形式存活在 widget 树里。从这里只能拿到 pageKey 而无法直接
  /// 拿到它们的 State 句柄，因此真正的拆解靠三件事：(a) 下面从 `_activeWebViews`
  /// 等记账中移除，(b) `_onWebViewResult` 里的 late-callback 守卫跳过 probe，以及
  /// (c) 下次 build 因为子节点不在列表里触发的 dispose-on-unmount（会进入
  /// `State.dispose` 取消 `_timeoutTimer` 并清理 cookie）。worker 上新增的
  /// `cancel()` 方法为未来可拿到句柄时预留，本步骤不调用。
  void _cancelLowerPriorityExtraction({required String except}) {
    bool isCancellableBySourceName(String sourceName) =>
        isCancellableSourceAfterAccept(
          sourceName: sourceName,
          acceptedPageKey: except,
          sourceTiers: _sampleSourceController.sourceTiers,
        );

    // (a) 清理待处理 captcha 任务。captcha taskKey 是 'search:源名' 格式，与
    //     WebView pageKey 命名空间不同，不能用 fromPageKey 反解；直接用
    //     task.source.name 查 tier。
    final cancellablePendingCaptcha = _captchaCoordinator.removePendingWhere(
      (task) => isCancellableBySourceName(task.source.name),
    );
    for (final task in cancellablePendingCaptcha) {
      _webviewStats.onCaptchaJobCancelledWhilePending(
        task.taskKey,
        task.source.name,
      );
    }
    // (b) 取消活动 captcha 任务：从记账中移除，后续 onResult 因 task == null
    //     提前返回。仅取消非 Tier-0 源的任务。
    final captchaKeys = captchaTaskKeysToCancelAfterAccept(
      activeTaskKeyToSourceName: {
        for (final e in _captchaCoordinator.activeTasks.entries)
          e.key: e.value.source.name,
      },
      acceptedPageKey: except,
      sourceTiers: _sampleSourceController.sourceTiers,
    );
    for (final key in captchaKeys) {
      final task = _captchaCoordinator.removeActive(key);
      if (task != null) {
        _webviewStats.onCaptchaJobCancelled(key, task.source.name);
      }
      _scheduler.cancelCaptchaSlot(key);
      _webViewStatus.remove(key);
    }

    // (c) 取消活动 WebView 提取任务：从记账中移除并标记为失败键，防止
    //     `_collectPendingWebViewExtractionTasks` 通过 `alreadyFailed` 检查
    //     重新排队。WebView key 是 pageKey 格式，用 fromPageKey 反解 sourceName。
    bool isCancellableWebViewKey(String pageKey) =>
        isCancellableWebViewPageKeyAfterAccept(
          pageKey: pageKey,
          acceptedPageKey: except,
          sourceTiers: _sampleSourceController.sourceTiers,
        );

    if (_useWorkerPool) {
      // Pool 模式：把对应 slot 的 pageKey 清 null。下一次 build 时
      // `_buildWebViewExtractors` 会让该 worker 拿到 `job: null`，触发
      // `didUpdateWidget` -> `_cancelCurrentJob(silent: true)` -> onIdle，
      // 后者通过 post-frame 调 [`_onWorkerIdlePostFrame`] 完成空 pump。
      // 调度器侧此处同步移除 `_scheduler.activeVideoJobs[pageKey]` 让后续
      // pump/统计立刻看到槽位空闲，避免一帧延迟期间重复派活。
      final videoPageKeys = videoPageKeysToCancelAfterAccept(
        activeVideoPageKeys: _scheduler.activeVideoJobs.keys,
        acceptedPageKey: except,
        sourceTiers: _sampleSourceController.sourceTiers,
      );
      for (final pageKey in videoPageKeys) {
        _scheduler.cancelVideoJob(pageKey);
        _webViewStatus.remove(pageKey);
        _failedWebViewPageKeys.add(pageKey);
        final srcName = SourceChannelKey.fromPageKey(pageKey).sourceName;
        _webviewStats.onVideoJobCancelled(pageKey, srcName);
      }
    } else {
      // Legacy 路径：靠 widget unmount 触发 dispose 取消 `_timeoutTimer`，并
      // 由 `_onWebViewResult` 的 tier guard 跳过迟到 probe/autoplay。
      final webViewKeys = _activeWebViews.keys
          .where(isCancellableWebViewKey)
          .toList();
      for (final key in webViewKeys) {
        final srcName = SourceChannelKey.fromPageKey(key).sourceName;
        _webviewStats.onVideoJobCancelled(key, srcName);
        _activeWebViews.remove(key);
        _webViewStatus.remove(key);
        _failedWebViewPageKeys.add(key);
      }
    }
    _logSchedulerState('cancelLowerPriority');
  }

  void _playSource(PlayerPlaybackAutoPlayDecision decision) {
    final source = decision.source!;
    final reservationId = decision.reservationId!;
    debugPrint(
      "Auto-playing source: ${source.sourceName} (Tier ${_sampleSourceController.sourceTiers[source.sourceName]})",
    );

    final acceptedKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    // Capture generation at accept time so a rapid episode switch cannot let
    // this open finish and re-arm current playback state for a later
    // generation (which permanently blocks autoplay).
    final loadToken = _sampleSourceController.sampleLoadToken;

    _updateState(() {
      if (_cancelLowPrioritySourcesOnPlay) {
        _acceptedSourcePageKey = acceptedKey;
        _cancelLowerPriorityExtraction(except: acceptedKey);
      }
      _selectedSourceIndexNotifier.value =
          _playbackController.selectedSourceIndex;
    });

    // freed slots can be reused (or stay empty — either way the pump must run
    // to avoid stale entries).
    _scheduleWebViewPoolPump(immediate: true);

    unawaited(
      _openOnlineSource(
        source,
        autoFallback: true,
        loadToken: loadToken,
        autoPlayReservationId: reservationId,
      ),
    );
  }

  /// WebView 提取结果回调（并发版本）
}
