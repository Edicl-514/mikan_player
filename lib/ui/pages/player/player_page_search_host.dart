part of '../player_page.dart';

extension _PlayerPageSearchHost on _PlayerPageState {
  Future<void> _cancelSearchSubscriptions() =>
      _searchSessionCoordinator.cancelAll();

  void _queueSearchCaptchaPreflightTask({
    required SourceState source,
    required String searchKeyword,
    required int loadToken,
    required void Function(SourceRuntimeOverride runtimeOverride) onCompleted,
  }) {
    _captchaCoordinator.queueSearchTask(
      source: source,
      searchKeyword: searchKeyword,
      loadToken: loadToken,
      onResult: (task, result) {
        final runtimeOverride = buildSearchCaptchaRuntimeOverride(
          source: task.source,
          result: result,
        );
        _handleSearchCaptchaPreflightResult(
          task: task,
          runtimeOverride: runtimeOverride,
          onCompleted: onCompleted,
        );
      },
    );
  }

  bool _isSearchStepFinished(SearchStep step) => isSearchStepTerminal(step);

  bool _isSourceSearchFinished() => allEnabledSourcesTerminal(
    enabledSourceNames: _sampleSourceController.enabledSourceNames,
    sourceProgressMap: _sampleSourceController.sourceProgressMap,
  );

  /// Round 4 Stage 3：把 [page] 追加到 `_sampleSourceController.samplePlayPages` 的统一入口。
  ///
  /// `_sampleSourceController.samplePlayPages` 每次接受完新增项后都会按 tier `sort()`，导致 `List`
  /// 下标不再稳定反映 arrival 顺序，而 source-affinity 调度需要在 tier 相同
  /// 时按“进入 pending 更早”做稳定 tie break。这里在 `add` 的同时把
  /// 单调递增的序号写入 [`_sampleSourceController.pageEnqueueSeq`]（key 为 pageKey），保证调度器
  /// 任何时候都能拿到稳定的 arrival 顺序。

  void _handleSearchCaptchaPreflightResult({
    required CaptchaPreflightTask task,
    required SourceRuntimeOverride runtimeOverride,
    required void Function(SourceRuntimeOverride runtimeOverride) onCompleted,
  }) {
    final sourceName = task.source.name;

    if (runtimeOverride.skipSearchError != null) {
      _updateState(() {
        _sampleSourceController.setSourceProgress(
          sourceName,
          SourceSearchProgress(
            sourceName: sourceName,
            step: SearchStep.failed,
            error: runtimeOverride.skipSearchError,
            playPageUrl: null,
            videoRegex: null,
            directVideoUrl: null,
            cookies: runtimeOverride.cookies,
            headers: null,
            captchaConfigJson: task.source.captchaConfigJson,
            enableNestedUrl: false,
          ),
        );
      });
    } else {
      _captchaCoordinator.setRuntimeOverride(sourceName, runtimeOverride);
      _updateState(() {
        _sampleSourceController.setSourceProgress(
          sourceName,
          SourceSearchProgress(
            sourceName: sourceName,
            step: SearchStep.pending,
            error: null,
            playPageUrl: null,
            videoRegex: null,
            directVideoUrl: null,
            cookies: runtimeOverride.cookies,
            headers: null,
            captchaConfigJson: task.source.captchaConfigJson,
            enableNestedUrl: false,
          ),
        );
      });
    }

    onCompleted(runtimeOverride);
  }

  void _handleSearchProgressUpdate({
    required SourceSearchProgress progress,
    required String searchName,
    required int currentEpNumber,
  }) {
    // Debug: Print channel information
    if (progress.allChannels != null && progress.allChannels!.isNotEmpty) {
      debugPrint(
        '[Channel Info] ${progress.sourceName}: Found ${progress.allChannels!.length} channels: '
        '${progress.allChannels!.map((c) => '${c.name}(${c.index})').join(', ')}',
      );
    }

    // 更新该源的进度
    _sampleSourceController.setSourceProgress(progress.sourceName, progress);

    // 如果搜索成功，添加到成功列表
    if (progress.step == SearchStep.success && progress.playPageUrl != null) {
      // 调试输出channel信息
      debugPrint(
        '[Search Success] ${progress.sourceName}: '
        'channelName=${progress.channelName}, '
        'channelIndex=${progress.channelIndex}, '
        'allChannels=${progress.allChannels?.length ?? 0}',
      );

      // 标记是否需要为该源启动WebView提取
      bool needsWebViewExtraction = false;

      // 如果有多个channels，为每个channel创建一个结果
      if (progress.allChannels != null && progress.allChannels!.isNotEmpty) {
        debugPrint(
          '[Multi-Channel] ${progress.sourceName}: Creating results for ${progress.allChannels!.length} channels',
        );

        final selectedChannelIndex = progress.channelIndex;

        for (int i = 0; i < progress.allChannels!.length; i++) {
          final channel = progress.allChannels![i];
          final channelKey = _buildSourceChannelKey(
            progress.sourceName,
            channel.index,
          );
          final isSelectedChannel =
              i == 0 || selectedChannelIndex == channel.index;

          if (!isSelectedChannel) {
            final savedOverride =
                _captchaCoordinator.runtimeOverrides[progress.sourceName];
            unawaited(
              _resolveChannelPlayPageUrl(
                sourceName: progress.sourceName,
                animeName: searchName,
                channelIndex: channel.index,
                episodeNumber: currentEpNumber,
                channelName: channel.name,
                videoRegex: progress.videoRegex ?? '',
                cookies: progress.cookies ?? savedOverride?.cookies,
                headers: progress.headers,
                searchPageHtml: savedOverride?.searchPageHtml,
                searchPageUrl: savedOverride?.searchPageUrl,
                detailPageHtml: savedOverride?.detailPageHtml,
                detailPageUrl: savedOverride?.detailPageUrl,
              ),
            );
            continue;
          }

          final result = SearchPlayResult(
            sourceName: progress.sourceName,
            playPageUrl: progress.playPageUrl!,
            videoRegex: progress.videoRegex ?? '',
            directVideoUrl: progress.directVideoUrl,
            cookies: progress.cookies,
            headers: progress.headers,
            channelName: channel.name,
            channelIndex: channel.index,
            captchaConfigJson: progress.captchaConfigJson,
            enableNestedUrl: progress.enableNestedUrl,
            matchNestedUrl: progress.matchNestedUrl,
          );

          // 避免重复添加（使用sourceName + channelIndex作为唯一标识）
          if (!_sampleSourceController.samplePlayPages.any(
            (p) =>
                _buildSourceChannelKey(p.sourceName, p.channelIndex) ==
                channelKey,
          )) {
            debugPrint(
              '[Add Channel Result] ${progress.sourceName} - Channel: ${channel.name}(${channel.index})',
            );
            _addSamplePlayPage(result);

            // 如果没有直接视频URL，标记需要WebView提取
            if (progress.directVideoUrl == null ||
                progress.directVideoUrl!.isEmpty) {
              needsWebViewExtraction = true;
            }
          }

          // 如果有直接视频URL，也添加到成功列表
          if (progress.directVideoUrl != null &&
              progress.directVideoUrl!.isNotEmpty) {
            unawaited(
              _probeAndRegisterPlayableSource(result, autoPlayAfterProbe: true),
            );
          }
        }
      } else {
        // 兼容模式：如果没有allChannels信息，使用旧逻辑
        debugPrint(
          '[Single Result] ${progress.sourceName}: No channel info, using legacy mode',
        );

        final result = SearchPlayResult(
          sourceName: progress.sourceName,
          playPageUrl: progress.playPageUrl!,
          videoRegex: progress.videoRegex ?? '',
          directVideoUrl: progress.directVideoUrl,
          cookies: progress.cookies,
          headers: progress.headers,
          channelName: progress.channelName,
          channelIndex: progress.channelIndex,
          captchaConfigJson: progress.captchaConfigJson,
          enableNestedUrl: progress.enableNestedUrl,
          matchNestedUrl: progress.matchNestedUrl,
        );

        // 避免重复添加
        if (!_sampleSourceController.samplePlayPages.any(
          (p) => p.sourceName == progress.sourceName,
        )) {
          _addSamplePlayPage(result);

          // 如果没有直接视频URL，标记需要WebView提取
          if (progress.directVideoUrl == null ||
              progress.directVideoUrl!.isEmpty) {
            needsWebViewExtraction = true;
          }
        }

        // 如果有直接视频URL，添加到成功列表
        if (progress.directVideoUrl != null &&
            progress.directVideoUrl!.isNotEmpty) {
          unawaited(
            _probeAndRegisterPlayableSource(result, autoPlayAfterProbe: true),
          );
        }
      }

      // 如果该源需要WebView提取，立即尝试启动（不等待所有源完成）
      if (needsWebViewExtraction) {
        debugPrint(
          '[Immediate WebView] Starting WebView extraction for ${progress.sourceName}',
        );
        _sampleSourceController.sortPlayPagesByTier();
        _scheduleWebViewPoolPump();
      }
    }

    // 更新状态消息
    final completedCount = completedSearchSourceCount(
      _sampleSourceController.sourceProgressMap,
    );
    final activeCaptcha = _captchaCoordinator.activeTasks.length;
    final pendingCaptcha = _captchaCoordinator.pendingTasks.length;
    _sampleStatusMessageNotifier.value = sampleSearchProgressLabel(
      completedCount: completedCount,
      enabledCount: _sampleSourceController.enabledSourceNames.length,
      activeCaptcha: activeCaptcha,
      pendingCaptcha: pendingCaptcha,
    );

    // 手动触发搜索后不自动播放，等待用户主动点击“播放”
    if (_autoPlaySearchedSource) {
      _attemptAutoPlay();
    }
  }

  void _launchSearchStream({
    required String searchName,
    required int currentEpNumber,
    required int relativeEpNumber,
    required List<SourceRuntimeOverride> runtimeOverrides,
    required Set<String> targetSources,
    required int loadToken,
    required String streamTag,
  }) {
    _searchSessionCoordinator.launchStream(
      stream: genericSearchWithProgressRuntime(
        animeName: searchName,
        absoluteEpisode: currentEpNumber,
        relativeEpisode: relativeEpNumber,
        targetSourceNames: targetSources.toList(),
        runtimeOverrides: runtimeOverrides,
      ),
      targetSources: targetSources,
      loadToken: loadToken,
      currentLoadToken: () => _sampleSourceController.sampleLoadToken,
      isDisposed: () => !mounted,
      streamTag: streamTag,
      onProgress: (progress) {
        _updateState(() {
          _handleSearchProgressUpdate(
            progress: progress,
            searchName: searchName,
            currentEpNumber: currentEpNumber,
          );
        });
        _scheduleWebViewPoolPump(immediate: true);
        _maybeFinishSampleSearch();
      },
      onStreamError: (error, unfinishedSources) {
        _updateState(() {
          for (final sourceName in unfinishedSources) {
            final current =
                _sampleSourceController.sourceProgressMap[sourceName];
            final isFinished =
                current != null && _isSearchStepFinished(current.step);
            if (isFinished) {
              continue;
            }
            _sampleSourceController.setSourceProgress(
              sourceName,
              SourceSearchProgress(
                sourceName: sourceName,
                step: SearchStep.failed,
                error: error.toString(),
                playPageUrl: null,
                videoRegex: null,
                directVideoUrl: null,
                cookies: null,
                headers: null,
                enableNestedUrl: false,
              ),
            );
          }
        });
        _scheduleWebViewPoolPump();
        _maybeFinishSampleSearch();
      },
      onDoneOrMaybeFinish: _maybeFinishSampleSearch,
    );
  }

  void _startCaptchaSourceSearch({
    required SourceState source,
    required SourceRuntimeOverride runtimeOverride,
    required String searchName,
    required int currentEpNumber,
    required int relativeEpNumber,
    required int loadToken,
  }) {
    _launchSearchStream(
      searchName: searchName,
      currentEpNumber: currentEpNumber,
      relativeEpNumber: relativeEpNumber,
      runtimeOverrides: [runtimeOverride],
      targetSources: {source.name},
      loadToken: loadToken,
      streamTag: 'captcha-${source.name}',
    );
  }

  void _maybeFinishSampleSearch() {
    final activeExtraction = _useWorkerPool
        ? _scheduler.activeVideoJobs.isNotEmpty
        : _activeWebViews.isNotEmpty;
    // Probes run asynchronously after a WebView extraction completes. The
    // search is not truly finished until every in-flight probe has resolved
    // (accepted -> registered as playable, or rejected -> marked failed),
    // otherwise the UI could briefly report "所有源都无法提取" right before a
    // late probe accepts a source.
    if (!mayMarkSampleSearchIdle(
      isMounted: mounted,
      isLoadingSample: _sampleSourceController.isLoadingSample,
      searchSubscriptionsNonEmpty: _searchSessionCoordinator.hasSubscriptions,
      pendingOrActiveCaptcha:
          _captchaCoordinator.pendingTasks.isNotEmpty ||
          _captchaCoordinator.activeTasks.isNotEmpty,
      activeExtraction: activeExtraction,
      resolvingChannelKeysNonEmpty: _resolvingChannelPlayPageKeys.isNotEmpty,
      probingSourceKeysNonEmpty: _probingSourceKeys.isNotEmpty,
      hasPendingExtraction: _hasPendingWebViewExtractionTasks(),
      allSourcesTerminal: _isSourceSearchFinished(),
    )) {
      return;
    }

    final finish = sampleSearchFinishMessage(
      playPageCount: _sampleSourceController.samplePlayPages.length,
      successfulSourceCount:
          _sampleSourceController.sampleSuccessfulSources.length,
    );
    _updateState(() {
      _sampleSourceController.markSampleIdle();
      if (finish.error != null) {
        _sampleSourceController.setSampleError(finish.error);
      } else if (finish.status != null) {
        _sampleStatusMessageNotifier.value = finish.status!;
      }
    });
  }

  Future<void> _loadSampleSource({bool manual = false}) async {
    if (!manual && _disableAutoSourceSearchForCurrentEpisode) {
      if (mounted) {
        _updateState(() {
          _sampleSourceController.markSampleIdle();
          _sampleSourceController.setSampleError(null);
          _sampleStatusMessageNotifier.value = '已播放本地资源，点击刷新可手动搜索在线源';
        });
      }
      return;
    }

    // Refresh the preference before deciding whether this automatic entry may
    // start a search. Manual taps intentionally bypass the gate.
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSearchOnline = prefs.getBool('auto_search_online') ?? true;
    } catch (e) {
      debugPrint('Error refreshing settings in loadSampleSource: $e');
    }

    // auto_search_online only gates automatic entry-time / episode-switch
    // search. Manual taps on "搜索在线源" must still run even when the
    // preference is off — bail out before any destructive reset so the empty
    // "尚未开始搜索" state (and its search button) remains usable.
    if (!manual && !_autoSearchOnline) {
      if (mounted) {
        _updateState(() {
          _sampleSourceController.markSampleIdle();
          _sampleSourceController.setSampleError(null);
          _sampleStatusMessageNotifier.value = '在线搜索已关闭，可手动搜索在线源';
        });
      }
      return;
    }

    final loadToken = _sampleSourceController.bumpLoadToken();
    await _cancelSearchSubscriptions();

    if (!isSearchGenerationCurrent(
      resultLoadToken: loadToken,
      currentLoadToken: _sampleSourceController.sampleLoadToken,
      isDisposed: !mounted,
    )) {
      return;
    }

    // First check if there's already a BT download for this episode
    final btTask = _downloadManager.getAvailableBtTaskForEpisode(
      widget.anime.title,
      _episodeController.currentEpisode.sort.toInt(),
    );

    if (btTask != null && _playbackController.currentStreamUrl == null) {
      final streamUrl = await _downloadManager.getOrCreateStreamUrl(btTask.id);
      if (!isSearchGenerationCurrent(
        resultLoadToken: loadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      )) {
        return;
      }
      if (streamUrl != null) {
        debugPrint(
          '[Sample] Found existing BT download, using it as primary source',
        );
        _playBtStreamUrl(streamUrl);
        // Continue loading other sources in background for alternatives
      }
    }

    _updateState(() {
      _sampleSourceController.beginNewSearchReset();
      _playbackController.resetForNewSearch();
      _autoPlaySearchedSource = !manual;
      // A BT card start belongs to the prior search generation. Once the
      // token above invalidates it, its late return must not leave the source
      // panel permanently blocked by a stale spinner.
      _loadingMagnet = null;
      _playableSourceKeys.clear();
      _probingSourceKeys.clear();
      _activeWebViews.clear();
      // Keep worker slots across searches so captcha cookies / warm WebViews
      // survive. resetForNewSearch clears job fields and returns slots to idle
      // so they are reacquired instead of minting new workers (which would
      // dispose the old ones and run the cookie janitor).
      _captchaCoordinator.resetForNewSearch();
      _scheduler.resetForNewSearch();
      _searchSessionCoordinator.clearTracking();
      _webViewStatus.clear();
      _failedWebViewPageKeys.clear();
      _resolvingChannelPlayPageKeys.clear();
      _sampleStatusMessageNotifier.value = '正在获取播放源列表...';
      _acceptedSourcePageKey = null;
      _webviewStats.reset();
    });
    _publishPlayerControlSourceState();

    try {
      // 获取所有源（包括详细信息如Tier）
      final sources = await getPlaybackSources();
      final enabledSources = sources.where((s) => s.enabled).toList();
      if (enabledSources.isEmpty) {
        if (isSearchGenerationCurrent(
          resultLoadToken: loadToken,
          currentLoadToken: _sampleSourceController.sampleLoadToken,
          isDisposed: !mounted,
        )) {
          _updateState(() {
            _sampleSourceController.setSampleErrorAndIdle('未启用任何播放源');
          });
        }
        return;
      }

      final enabledNames = enabledSources.map((s) => s.name).toList();
      final cohorts = partitionEnabledSources(enabledSources);
      final captchaSources = cohorts.captchaSources;
      final nonCaptchaSources = cohorts.nonCaptchaSources;

      // 使用带进度的流式API，传入当前集号
      final n = _episodeController.currentEpisodeNumbersAgainst(
        widget.allEpisodes,
      );
      final currentEpNumber = n.absolute;
      final relativeEpNumber = n.relative;

      final searchName = _buildSearchNameForSources();
      final captchaPreflightKeyword = _buildCaptchaPreflightKeyword();

      if (!isSearchGenerationCurrent(
        resultLoadToken: loadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      )) {
        return;
      }

      _updateState(() {
        _sampleSourceController.setEnabledSources(
          names: enabledNames,
          tiers: {for (var s in enabledSources) s.name: s.tier},
        );
        _sampleSourceController.initPendingProgressForEnabled();
        _sampleStatusMessageNotifier.value = captchaSources.isEmpty
            ? '正在搜索 ${enabledSources.length} 个源...'
            : '非验证码源先行搜索，验证码源并发预处理中...';
      });

      if (captchaSources.isNotEmpty) {
        _updateState(() {
          for (final source in captchaSources) {
            _sampleSourceController.setSourceProgress(
              source.name,
              SourceSearchProgress(
                sourceName: source.name,
                step: SearchStep.searching,
                error: null,
                playPageUrl: null,
                videoRegex: null,
                directVideoUrl: null,
                cookies: null,
                headers: null,
                captchaConfigJson: source.captchaConfigJson,
                enableNestedUrl: false,
              ),
            );
          }
        });
      }

      if (nonCaptchaSources.isNotEmpty) {
        _launchSearchStream(
          searchName: searchName,
          currentEpNumber: currentEpNumber,
          relativeEpNumber: relativeEpNumber,
          runtimeOverrides: [],
          targetSources: nonCaptchaSources.map((source) => source.name).toSet(),
          loadToken: loadToken,
          streamTag: 'non-captcha',
        );
      }

      for (final source in captchaSources) {
        _queueSearchCaptchaPreflightTask(
          source: source,
          searchKeyword: captchaPreflightKeyword,
          loadToken: loadToken,
          onCompleted: (runtimeOverride) {
            if (!isSearchGenerationCurrent(
              resultLoadToken: loadToken,
              currentLoadToken: _sampleSourceController.sampleLoadToken,
              isDisposed: !mounted,
            )) {
              return;
            }
            if (runtimeOverride.skipSearchError != null) {
              _maybeFinishSampleSearch();
              return;
            }
            _startCaptchaSourceSearch(
              source: source,
              runtimeOverride: runtimeOverride,
              searchName: searchName,
              currentEpNumber: currentEpNumber,
              relativeEpNumber: relativeEpNumber,
              loadToken: loadToken,
            );
          },
        );
      }

      _scheduleWebViewPoolPump();
      _maybeFinishSampleSearch();
    } catch (e) {
      debugPrint("Error loading Sample source: $e");
      if (isSearchGenerationCurrent(
        resultLoadToken: loadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
      )) {
        _updateState(() {
          _sampleSourceController.setSampleErrorAndIdle(e.toString());
        });
      }
    }
  }
}
