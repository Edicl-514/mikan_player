part of '../player_page.dart';

extension _PlayerPageWebViewResultHost on _PlayerPageState {
  void _onWebViewResult(
    String pageKey,
    int resultLoadToken,
    VideoExtractResult result,
  ) {
    debugPrint(
      '[_onWebViewResult] pageKey=$pageKey, success=${result.success}, '
      'timedOut=${result.timedOut}, videoUrl=${result.videoUrl}, '
      'error=${result.error}',
    );
    if (!mounted) return;

    final sourceNameForKey = SourceChannelKey.fromPageKey(pageKey).sourceName;
    final isActiveIdentity = _useWorkerPool
        ? _scheduler.isActiveVideoJobIdentity(pageKey, resultLoadToken)
        : _activeWebViews[pageKey] == resultLoadToken;
    if (!isSearchGenerationCurrent(
          resultLoadToken: resultLoadToken,
          currentLoadToken: _sampleSourceController.sampleLoadToken,
          isDisposed: !mounted,
        ) ||
        !isActiveIdentity) {
      _webviewStats.onVideoJobLateAfterCancel(pageKey, sourceNameForKey);
      return;
    }

    _updateState(() {
      _recordVideoWorkerResult(pageKey, result);
      // 旧 [per-task] 路径在收到 result 时立即从 `_activeWebViews` 释放槽位；
      // pool 模式下由 [`_onWorkerIdle`] 在 worker 完成（或被取消）后统一释放
      // `_scheduler.activeVideoJobs` + slot 记账，避免在此处提前释放导致
      // build 阶段
      // 反查失配。
      if (!_useWorkerPool) {
        _activeWebViews.remove(pageKey);
      }
      _webViewStatus.remove(pageKey);

      // Late-callback no-op guard: 一旦某 Tier-0 源被接受并开始播放，任何其他
      // （刚被 `_cancelLowerPriorityExtraction` 取消的）非 Tier-0 提取任务的迟到
      // 结果都不得触发 probe/register/auto-play，否则会劫持当前播放。Tier-0 源
      // （含已接受源的其他 channel 与其他 Tier-0 源的 channel）的迟到结果仍按正常
      // 流程走 probe/register 以填充源列表作为后备。这里仍然清理上面的记账以释放
      // 并发槽位，然后只需更新状态、泵送任务池并提前返回。
      final tier = _sampleSourceController.sourceTiers[sourceNameForKey] ?? 999;
      final lateNonTier0 = isVideoResultLateAfterCancel(
        acceptedSourcePageKey: _acceptedSourcePageKey,
        tier: tier,
      );
      if (!mayProbeVideoExtractionResult(
        resultLoadToken: resultLoadToken,
        currentLoadToken: _sampleSourceController.sampleLoadToken,
        isDisposed: !mounted,
        isLateNonTier0AfterAccept: lateNonTier0,
      )) {
        _webviewStats.onVideoJobLateAfterCancel(pageKey, sourceNameForKey);
        _failedWebViewPageKeys.add(pageKey);
        final total = _sampleSourceController.samplePlayPages.length;
        final completed =
            _sampleSourceController.sampleSuccessfulSources.length;
        final active = _useWorkerPool
            ? _scheduler.activeVideoJobs.length
            : _activeWebViews.length;
        _sampleStatusMessageNotifier.value =
            '提取中: $completed/$total 完成，$active 并发运行';
        if (!_useWorkerPool) {
          _startNextWebViewExtraction();
        }
        // pool 模式下不在此处 pump: worker 同步在 `_complete` 之后还会调用
        // `widget.onIdle`，[_onWorkerIdle] 会 post-frame 调用
        // `_scheduleWebViewPoolPump(immediate: true)`。
        return;
      }

      _webviewStats.onVideoJobCompleted(
        success: result.success,
        timedOut: result.timedOut,
        pageKey: pageKey,
        sourceName: sourceNameForKey,
      );

      if (!result.success) {
        _failedWebViewPageKeys.add(pageKey);
      }

      if (result.success) {
        final key = SourceChannelKey.fromPageKey(pageKey);
        final sourceName = key.sourceName;
        final channelIndex = key.channelIndex?.toInt();

        // 找到对应的播放页并更新
        final pageIndex = _sampleSourceController.samplePlayPages.indexWhere((
          p,
        ) {
          final pIdx = p.channelIndex?.toInt();
          return p.sourceName == sourceName && (pIdx == channelIndex);
        });

        debugPrint(
          '[_onWebViewResult] resolved pageIndex=$pageIndex for sourceName=$sourceName channelIndex=$channelIndex',
        );

        if (pageIndex >= 0) {
          final page = _sampleSourceController.samplePlayPages[pageIndex];
          debugPrint(
            '[_onWebViewResult] matched page: playPageUrl=${page.playPageUrl} channelName=${page.channelName}',
          );

          final updatedPage = buildUpdatedPlayPageFromResult(
            page: page,
            result: result,
          );
          debugPrint(
            '[_onWebViewResult] Captured headers: ${updatedPage.headers?.keys.join(", ")}',
          );

          unawaited(
            _probeAndRegisterPlayableSource(
              updatedPage,
              autoPlayAfterProbe: true,
            ),
          );

          // 如果这是第一个成功提取且没有其他源在播放
          debugPrint(
            '[_onWebViewResult] selectedIntentUrl currently='
            '${_playbackController.sampleVideoUrl}',
          );
        } else {
          debugPrint(
            '[_onWebViewResult] No matching page found for pageKey=$pageKey',
          );
          // 打印当前的 sample play pages 简要信息，帮助调试匹配失败原因
          try {
            final summary = _sampleSourceController.samplePlayPages
                .map(
                  (p) =>
                      '${p.sourceName}#${p.channelIndex ?? -1}:${p.playPageUrl}',
                )
                .take(20)
                .join(' | ');
            debugPrint(
              '[_onWebViewResult] _sampleSourceController.samplePlayPages summary: $summary',
            );
          } catch (e) {
            debugPrint(
              '[_onWebViewResult] Failed to summarize _sampleSourceController.samplePlayPages: $e',
            );
          }
        }
      }

      // 更新状态消息
      final total = _sampleSourceController.samplePlayPages.length;
      final completed = _sampleSourceController.sampleSuccessfulSources.length;
      final active = _useWorkerPool
          ? _scheduler.activeVideoJobs.length
          : _activeWebViews.length;
      _sampleStatusMessageNotifier.value =
          '提取中: $completed/$total 完成，$active 并发运行';

      // 旧路径：立即 pump 下一个 task；pool 模式下 worker 接下来会触发
      // `widget.onIdle`，[`_onWorkerIdle`] 会 post-frame 释放 slot + pump。
      if (!_useWorkerPool) {
        _startNextWebViewExtraction();
      }
    });
    _logSchedulerState('videoResult');
  }

  /// Pool 模式下 video runner 自报 idle 的入口（与 captcha 的
  /// [`_onCaptchaWorkerIdle`] 分开）。可能源自两种路径：
  ///
  /// 1. **Worker 完成/超时/失败**：在
  ///    [`VideoExtractionJobRunner._complete`] 里同步先调用
  ///    `sink.onResult` -> [`_onWebViewResult`]（处理 result 业务逻辑），
  ///    再调用本函数 onIdle（5B step 3 之后由 [`ReusableBrowserWorker`]
  ///    的 `onVideoIdle` 转发）。这里只需要释放 slot 记账并 pump 下一
  ///    个 job。
  /// 2. **Worker 被取消**：当前 job 通过 `didUpdateWidget`（job 从 non-null 变
  ///    null，例如搜索重置、`_cancelLowerPriorityExtraction`、`_useWorkerPool`
  ///    实时切换）触发 `_cancelCurrentJob(silent: true)`，进而同步调用
  ///    [`VideoExtractionJobRunner.cancelCurrentJob`]。本函数仅做 pump。
  ///
  /// 因为路径 2 可能发生在 **build 阶段**（`didUpdateWidget` 内同步），直接
  /// `setState` 会触发 "setState() called during build" 异常。所以统一用
  /// `addPostFrameCallback` 把状态修改 + pump 推迟到本帧结束之后。
  void _onWorkerIdle(int workerId, VideoExtractionJob completedJob) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onWorkerIdlePostFrame(workerId, completedJob);
    });
  }

  void _onWorkerIdlePostFrame(int workerId, VideoExtractionJob completedJob) {
    if (!mounted) return;
    final slot = _scheduler.slotOf(workerId);
    if (slot == null) return;
    if (slot.kind != null &&
        !_scheduler.slotMatchesJobIdentity(
          workerId: workerId,
          kind: WebViewWorkerKind.video,
          jobKey: completedJob.jobKey,
          generation: completedJob.generation,
        )) {
      // A post-frame idle from the previous generation must not clear a new
      // same-key assignment already running on this retained worker.
      return;
    }

    // 释放 slot 记账（pageKey/taskKey 通常还没被移除：因为 _onWebViewResult
    // 在 pool 模式下不动它；_cancelLowerPriorityExtraction 已在 setState 内
    // 同步删除但走第 (b) 路径时 onIdle 也是 post-frame 到来，绝不冲突）。已
    // 经清空的字段也安全（null = no-op）。
    final prevPageKey = _scheduler.releaseVideoSlotOnIdle(workerId);
    var needsSetState = false;
    if (prevPageKey != null) {
      _webViewStatus.remove(prevPageKey);
      needsSetState = true;
    }
    final slotAfterHealth = _scheduler.healthOf(workerId);

    if (slotAfterHealth == WebViewWorkerHealth.unhealthy) {
      _scheduler.removeSlot(workerId);
      debugPrint(
        '[WebViewScheduler] rebuilt video worker=$workerId by removing '
        'unhealthy idle slot',
      );
      needsSetState = true;
    } else {
      _scheduler.markSlotIdle(workerId);
    }

    if (_trimIdleWebViewWorkerSlotsToBudget()) {
      needsSetState = true;
    }

    // 让 build 把 worker 切到 idle 状态（emit null job，触发 didUpdateWidget
    // 进入`_cancelCurrentJob` 早返回路径——worker 内部 `_isCompleted=true` 守
    // 卫会直接 short-circuit）。
    if (needsSetState) {
      _updateState(() {});
    }

    // 继续泵送；下一个 job 可能直接落到本 slot。
    _scheduleWebViewPoolPump(immediate: true);
    _maybeFinishSampleSearch();
    _logSchedulerState('workerIdle#$workerId');
  }

  /// 调试面板 live toggle：实时切换 worker pool / legacy 调度路径。
  ///
  /// 切换时清空两条路径的活跃记账 + 丢掉 pool slot 实例，避免旧路径下的
  /// `_activeWebViews` 残留或 pool 模式下 slot 与 widget 树不对齐。下一帧
  /// 起重按新路径调度；captcha active task 保留，但 slot 反查按目标路径重建。
  void _setUseWorkerPool(bool next) {
    _updateState(() {
      _useWorkerPool = next;
      _activeWebViews.clear();
      // 把 pool slot 整体丢弃：worker widget 在下次 build 不被 emit → 框架
      // 负责 dispose；scheduler 侧不再引用已 dispose 的 state。
      _scheduler.clearForPoolToggle();
      if (next) {
        for (final task in _captchaCoordinator.activeTasks.values) {
          final slot = _acquireIdleCaptchaWorkerSlot();
          if (slot == null) continue;
          _scheduler.startCaptchaJob(
            slot,
            task.taskKey,
            task.source.name,
            generation: task.loadToken,
          );
        }
      }
      _webViewStatus.clear();
    });
    _scheduleWebViewPoolPump(immediate: true);
  }

  /// 启动下一个WebView提取任务
  /// 启动下一个WebView提取任务
  void _startNextWebViewExtraction() {
    _scheduleWebViewPoolPump(immediate: true);
  }
}
