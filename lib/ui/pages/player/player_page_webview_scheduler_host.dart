part of '../player_page.dart';

extension _PlayerPageWebViewSchedulerHost on _PlayerPageState {
  WebViewWorkerLeaseId _pooledLeaseId(int workerId) => WebViewWorkerLeaseId(
    playerSessionId: _playerSessionId,
    localWorkerId: workerId,
  );

  bool _requestPooledWorkerLease(int workerId) {
    if (!_sessionLifecycle.acceptsNewWork) return false;
    return WebViewResourceCoordinator.instance.requestLease(
      _pooledLeaseId(workerId),
    );
  }

  WebViewWorkerLeaseId? _ensureLegacyWorkerLease(String resourceKey) {
    if (!_sessionLifecycle.acceptsNewWork) return null;
    final workerId = _legacyWorkerIds.putIfAbsent(
      resourceKey,
      () => _nextLegacyWorkerId--,
    );
    final leaseId = WebViewWorkerLeaseId(
      playerSessionId: _playerSessionId,
      localWorkerId: workerId,
    );
    return WebViewResourceCoordinator.instance.requestLease(leaseId)
        ? leaseId
        : null;
  }

  WebViewWorkerLeaseId _legacyLeaseId(String resourceKey) =>
      WebViewWorkerLeaseId(
        playerSessionId: _playerSessionId,
        localWorkerId: _legacyWorkerIds[resourceKey]!,
      );

  void _onGlobalWebViewCapacityAvailable() {
    final coordinator = WebViewResourceCoordinator.instance;
    if (!mounted || !_sessionLifecycle.acceptsNewWork) {
      coordinator.releaseUnmaterializedOwnedBy(_playerSessionId);
      return;
    }
    final limit = coordinator.limit;
    if (_maxConcurrentWebViews != limit) {
      _updateState(() => _maxConcurrentWebViews = limit);
    }
    _scheduleWebViewPoolPump(immediate: true);
    coordinator.releaseUnmaterializedOwnedBy(_playerSessionId);
  }

  void _releaseIdleWorkersForGlobalQuota() {
    if (!mounted || _isDisposing || _idleWorkerReleaseScheduled) return;
    _idleWorkerReleaseScheduled = true;
    scheduleMicrotask(() {
      _idleWorkerReleaseScheduled = false;
      if (!mounted || _isDisposing) return;
      final limit = WebViewResourceCoordinator.instance.limit;
      final limitChanged = _maxConcurrentWebViews != limit;
      _maxConcurrentWebViews = limit;
      final busySlots =
          _scheduler.activeVideoJobCount + _scheduler.activeCaptchaJobCount;
      final removed = _scheduler.trimIdleWorkerSlotsToBudget(
        useWorkerPool: _useWorkerPool,
        maxConcurrent: busySlots,
      );
      if (removed.isEmpty && !limitChanged) return;
      _logDisposedIdleSlots(removed);
      _updateState(() {});
    });
  }

  void _addSamplePlayPage(SearchPlayResult page) {
    final pageKey = _buildSourceChannelKey(page.sourceName, page.channelIndex);
    _sampleSourceController.appendPlayPage(page, pageKey: pageKey);
    // 5B step 3：warm 同源 worker 候选已不再局限于 captcha slot —— 统一
    // 表中所有 idle（kind == null）且 lastSourceName 命中的 slot 都能
    // 在下次 pump 接到该 pageKey，affinity 选取会优先命中。这里日志沿用
    // 旧文案便于回归对比。
    final warmWorkerIds =
        _scheduler.slots.values
            .where(
              (slot) => slot.isIdle && slot.lastSourceName == page.sourceName,
            )
            .map((slot) => slot.workerId)
            .toList()
          ..sort();
    if (warmWorkerIds.isNotEmpty) {
      debugPrint(
        '$_sessionOwnerTag [WebViewScheduler] pending video $pageKey '
        'can reuse warm worker=${warmWorkerIds.first}',
      );
    }
  }

  /// Per-page extraction-eligibility predicate.
  ///
  ///行为等价于原 `_collectPendingWebViewExtractionTasks` 内联 `where` 闭包，
  /// 抽出来是为了让 `_collectPendingWebViewExtractionTasks`、`_hasPendingWebViewExtractionTasks`
  /// 与 Phase 0 的 `webviewSchedulerStats` 调度诊断共用同一份过滤规则，避免
  /// 后续 worker pool 重构时多处规则漂移。
  bool _pageIsPendingForExtraction(SearchPlayResult page) {
    final pageKey = _buildSourceChannelKey(page.sourceName, page.channelIndex);
    final hasPlayPageUrl = page.playPageUrl.trim().isNotEmpty;
    final alreadySuccessful = _sampleSourceController.sampleSuccessfulSources
        .any(
          (s) =>
              _buildSourceChannelKey(s.sourceName, s.channelIndex) == pageKey,
        );
    final alreadyActive = _useWorkerPool
        ? _scheduler.activeVideoJobs.containsKey(pageKey)
        : _activeWebViews.containsKey(pageKey);
    final alreadyFailed = _failedWebViewPageKeys.contains(pageKey);
    // Once autoplay has accepted a Tier-0 source, lower-priority pages that
    // arrive late from the search stream must not be dispatched into a warm
    // WebView. Their search result may still be useful for status/debugging,
    // but extraction is no longer part of the current autoplay decision.
    final acceptedSourcePageKey = _acceptedSourcePageKey;
    if (acceptedSourcePageKey != null) {
      final sourceTier =
          _sampleSourceController.sourceTiers[page.sourceName] ?? 999;
      if (sourceTier != 0) return false;
    }
    // A source whose WebView extraction just finished is being probed
    // asynchronously (_probingSourceKeys) or has already been registered as
    // playable (_playableSourceKeys). It MUST be excluded here, otherwise
    // _onWebViewResult removes it from _activeWebViews and the pool pump
    // (running synchronously in the same setState) re-queues it before the
    // probe completes. Because the WebViewVideoExtractorWidget is reused with
    // the same ValueKey, its State keeps _isCompleted=true and a cancelled
    // timeout, so it never fires onResult again and never times out — a
    // zombie that permanently occupies a concurrency slot.
    final isProbing = _probingSourceKeys.contains(pageKey);
    final alreadyPlayable = _playableSourceKeys.contains(pageKey);
    // Note: extraction eligibility is keyed on the full source+channel
    // pageKey, NOT on sourceName alone. Each channel of a source has its own
    // distinct play page URL, so multiple channels of the same source may be
    // extracted concurrently. Guarding by sourceName here previously caused
    // only one channel per source to ever be extracted (and a stuck/zombie
    // WebView would block its siblings forever).
    return hasPlayPageUrl &&
        !alreadySuccessful &&
        !alreadyActive &&
        !alreadyFailed &&
        !isProbing &&
        !alreadyPlayable;
  }

  List<SearchPlayResult> _collectPendingWebViewExtractionTasks() {
    final pending = _sampleSourceController.samplePlayPages
        .where(_pageIsPendingForExtraction)
        .toList();

    pending.sort((a, b) {
      final tierA = _sampleSourceController.sourceTiers[a.sourceName] ?? 999;
      final tierB = _sampleSourceController.sourceTiers[b.sourceName] ?? 999;
      return tierA.compareTo(tierB);
    });

    return pending;
  }

  bool _hasPendingWebViewExtractionTasks() {
    return _collectPendingWebViewExtractionTasks().isNotEmpty;
  }

  int get _activeWebViewTaskCount {
    if (_useWorkerPool) {
      return _scheduler.activeVideoJobCount +
          _captchaCoordinator.activeTasks.length;
    }
    return _activeWebViews.length + _captchaCoordinator.activeTasks.length;
  }

  int get _webViewWorkerSlotCount => _scheduler.workerCount;

  static const int _webViewWorkerFailureThreshold = 3;

  String _webViewWorkerPoolLabel() {
    if (!_useWorkerPool) {
      return 'legacy';
    }
    final videoCount = _scheduler.slots.values
        .where((slot) => slot.kind == WebViewWorkerKind.video)
        .length;
    final captchaCount = _scheduler.slots.values
        .where((slot) => slot.kind == WebViewWorkerKind.captcha)
        .length;
    return 'slots $_webViewWorkerSlotCount/$_maxConcurrentWebViews '
        '(video $videoCount, captcha $captchaCount)';
  }

  String _workerHealthLabel(WebViewWorkerHealth health) {
    return switch (health) {
      WebViewWorkerHealth.idle => 'idle',
      WebViewWorkerHealth.running => 'running',
      WebViewWorkerHealth.cancelling => 'cancelling',
      WebViewWorkerHealth.unhealthy => 'unhealthy',
    };
  }

  void _recordVideoWorkerResult(String pageKey, VideoExtractResult result) {
    final failed = !result.success || result.timedOut;
    final markedUnhealthy = _scheduler.recordVideoWorkerResult(
      pageKey,
      failed,
      _webViewWorkerFailureThreshold,
    );
    if (markedUnhealthy) {
      final workerId = _scheduler.activeVideoJobs[pageKey];
      debugPrint(
        '$_sessionOwnerTag [WebViewScheduler] video worker=$workerId '
        'marked unhealthy '
        'after ${_scheduler.slotOf(workerId)?.consecutiveFailures} '
        'consecutive failures',
      );
    }
  }

  void _recordCaptchaWorkerResult(String taskKey, CaptchaBypassResult result) {
    final failed = !result.success;
    final markedUnhealthy = _scheduler.recordCaptchaWorkerResult(
      taskKey,
      failed,
      _webViewWorkerFailureThreshold,
    );
    if (markedUnhealthy) {
      final workerId = _scheduler.activeCaptchaJobs[taskKey];
      debugPrint(
        '$_sessionOwnerTag [WebViewScheduler] captcha worker=$workerId '
        'marked unhealthy '
        'after ${_scheduler.slotOf(workerId)?.consecutiveFailures} '
        'consecutive failures',
      );
    }
  }

  /// 把 scheduler 在 trim/acquire 过程中腾退的 idle slot 逐个复刻原来的
  /// `[WebViewScheduler] disposed idle ... worker=...` 日志。scheduler 本身
  /// 不持有 logging 职责，所以把腾退结果返回到本页来打点。
  void _logDisposedIdleSlots(List<WebViewWorkerSlotSnapshot> disposed) {
    for (final slot in disposed) {
      final kindLabel = switch (slot.kind) {
        WebViewWorkerKind.video => 'video',
        WebViewWorkerKind.captcha => 'captcha',
        null => 'idle',
      };
      debugPrint(
        '$_sessionOwnerTag [WebViewScheduler] disposed idle $kindLabel '
        'worker=${slot.workerId} to keep unified slot budget',
      );
    }
  }

  bool _trimIdleWebViewWorkerSlotsToBudget() {
    if (!_useWorkerPool) return false;
    final removed = _scheduler.trimIdleWorkerSlotsToBudget(
      useWorkerPool: _useWorkerPool,
      maxConcurrent: _maxConcurrentWebViews,
    );
    _logDisposedIdleSlots(removed);
    return removed.isNotEmpty;
  }

  bool _startOneCaptchaTask() {
    if (!_captchaCoordinator.hasPending) {
      return false;
    }
    if (_activeWebViewTaskCount >= _maxConcurrentWebViews) {
      return false;
    }

    // Per-source cooldown (latest-wins pending). Rapid EP switches / re-entry
    // used to cancel an in-flight captcha and immediately re-hit the same host,
    // which is exactly when OCR sources start returning blank images.
    final poll = _captchaCoordinator.pollNextReady(
      canStartNow: (sourceName, interval) => SourceRequestGate.instance
          .canSessionStartNow(_playerSessionId, sourceName, interval),
      intervalFor: (task) => SourceRequestGate.captchaIntervalMs(
        task.captchaConfig.initialDelayMs,
      ),
    );
    for (final sourceName in poll.coolingSources) {
      final coolingTask = poll.stillPending.firstWhere(
        (t) => t.source.name == sourceName,
      );
      SourceRequestGate.instance.scheduleWhenReady(
        sessionId: _playerSessionId,
        sourceName: sourceName,
        minInterval: SourceRequestGate.captchaIntervalMs(
          coolingTask.captchaConfig.initialDelayMs,
        ),
        token: coolingTask.loadToken,
        ownerTag: _sessionOwnerTag,
        onReady: () {
          if (!_acceptsSessionCallback(coolingTask.loadToken)) {
            return;
          }
          _scheduleWebViewPoolPump(immediate: true);
        },
      );
    }
    _captchaCoordinator.restorePending(poll.stillPending);
    final ready = poll.ready;
    if (ready == null) {
      return false;
    }
    if (!_acceptsSessionCallback(ready.loadToken) ||
        !mayStartSearchScopedJob(
          jobLoadToken: ready.loadToken,
          currentLoadToken: _sampleSourceController.sampleLoadToken,
          isDisposed: !mounted,
        )) {
      return false;
    }

    if (_useWorkerPool) {
      final slot = _acquireIdleCaptchaWorkerSlot();
      if (slot == null) {
        _captchaCoordinator.requeueFront(ready);
        return false;
      }
      _scheduler.startCaptchaJob(
        slot,
        ready.taskKey,
        ready.source.name,
        generation: ready.loadToken,
      );
      WebViewResourceCoordinator.instance.markLeaseMaterialized(
        _pooledLeaseId(slot.workerId),
      );
      WebViewResourceCoordinator.instance.markLeaseBusy(
        _pooledLeaseId(slot.workerId),
        busy: true,
      );
    } else {
      final lease = _ensureLegacyWorkerLease('captcha:${ready.taskKey}');
      if (lease == null) {
        _captchaCoordinator.requeueFront(ready);
        return false;
      }
      WebViewResourceCoordinator.instance.markLeaseMaterialized(lease);
      WebViewResourceCoordinator.instance.markLeaseBusy(lease, busy: true);
    }
    SourceRequestGate.instance.markStarted(
      ready.source.name,
      sessionId: _playerSessionId,
      ownerTag: _sessionOwnerTag,
    );
    _captchaCoordinator.markActive(ready);
    _webViewStatus[ready.taskKey] = AppLocalizations.of(
      context,
    ).playerWebviewCaptchaBypass;
    _webviewStats.onCaptchaJobStarted(ready.taskKey, ready.source.name);
    return true;
  }

  /// 5B step 3：取一个 idle（kind == null）slot 用来跑 captcha job。
  /// 不区分原来 captcha/video 两条路径 —— 统一 slot 表里 kind == null
  /// 即空闲 worker，可被任意 kind 复用。
  WebViewWorkerSlotSnapshot? _acquireIdleCaptchaWorkerSlot() {
    final result = _scheduler.acquireIdleCaptchaWorkerSlot(
      useWorkerPool: _useWorkerPool,
      maxConcurrent: _maxConcurrentWebViews,
      canCreateWorker: _requestPooledWorkerLease,
    );
    _logDisposedIdleSlots(result.disposedIdleSlots);
    if (result.slot != null && result.createdNew) {
      debugPrint(
        '$_sessionOwnerTag [CaptchaScheduler] created '
        'worker=${result.slot!.workerId} for captcha '
        '(${_webViewWorkerPoolLabel()})',
      );
    }
    return result.slot;
  }

  bool _startOneWebViewExtractionTask() {
    if (!mounted || !_sessionLifecycle.acceptsNewWork) return false;
    final jobLoadToken = _sampleSourceController.sampleLoadToken;
    if (_activeWebViewTaskCount >= _maxConcurrentWebViews) {
      return false;
    }

    final pending = _collectPendingWebViewExtractionTasks();
    if (pending.isEmpty) {
      return false;
    }

    // Drop sources still in their per-source start cooldown so rapid re-entry
    // does not hammer the same host. Schedule a delayed pump for the earliest
    // waiter so work resumes once the gate opens.
    final gate = SourceRequestGate.instance;
    final readyPending = <SearchPlayResult>[];
    final coolingSources = <String>{};
    for (final page in pending) {
      if (gate.canStartNow(
            page.sourceName,
            SourceRequestGate.defaultVideoInterval,
          ) &&
          gate.canSessionStartNow(
            _playerSessionId,
            page.sourceName,
            SourceRequestGate.defaultVideoInterval,
          )) {
        readyPending.add(page);
      } else if (coolingSources.add(page.sourceName)) {
        final gateToken = jobLoadToken;
        gate.scheduleWhenReady(
          sessionId: _playerSessionId,
          sourceName: page.sourceName,
          minInterval: SourceRequestGate.defaultVideoInterval,
          token: gateToken,
          ownerTag: _sessionOwnerTag,
          onReady: () {
            if (!_acceptsSessionCallback(gateToken)) {
              return;
            }
            _scheduleWebViewPoolPump(immediate: true);
          },
        );
      }
    }
    if (readyPending.isEmpty) {
      return false;
    }

    if (_useWorkerPool) {
      // The scheduler owns source-affinity selection and returns a command;
      // page-owned request gating, logging, state, stats, and job start stay
      // here. This keeps the scheduler pure while making selection testable.
      final pageByKey = <String, SearchPlayResult>{};
      final pendingJobs = <PlayerWebViewPendingVideoJob>[];
      for (final page in readyPending) {
        final pageKey = _buildSourceChannelKey(
          page.sourceName,
          page.channelIndex,
        );
        pageByKey[pageKey] = page;
        pendingJobs.add(
          PlayerWebViewPendingVideoJob(
            pageKey: pageKey,
            sourceName: page.sourceName,
            priorityTier:
                _sampleSourceController.sourceTiers[page.sourceName] ?? 999,
            enqueueSequence:
                _sampleSourceController.pageEnqueueSeq[pageKey] ?? 0,
          ),
        );
      }
      final decision = _scheduler.planNextVideoDispatch(
        pendingJobs,
        useWorkerPool: _useWorkerPool,
        maxConcurrent: _maxConcurrentWebViews,
        canCreateWorker: _requestPooledWorkerLease,
      );
      _logDisposedIdleSlots(decision.disposedIdleSlots);
      final command = decision.command;
      if (command == null) {
        return false;
      }
      if (command.createdNew) {
        debugPrint(
          '$_sessionOwnerTag [WebViewScheduler] created '
          'worker=${command.slot.workerId} for video '
          '(${_webViewWorkerPoolLabel()})',
        );
      }
      _logAffinityPick(
        workerId: command.slot.workerId,
        lastSource: command.previousSourceName,
        pickedSource: command.job.sourceName,
        pageKey: command.job.pageKey,
        sameSource: command.usesSourceAffinity,
      );
      final page = pageByKey[command.job.pageKey]!;
      _scheduler.startVideoJob(
        command.slot,
        command.job.pageKey,
        command.job.sourceName,
        generation: jobLoadToken,
      );
      WebViewResourceCoordinator.instance.markLeaseMaterialized(
        _pooledLeaseId(command.slot.workerId),
      );
      WebViewResourceCoordinator.instance.markLeaseBusy(
        _pooledLeaseId(command.slot.workerId),
        busy: true,
      );
      gate.markStarted(
        command.job.sourceName,
        sessionId: _playerSessionId,
        ownerTag: _sessionOwnerTag,
      );
      _webViewStatus[command.job.pageKey] = AppLocalizations.of(
        context,
      ).playerWebviewExtracting;
      _webviewStats.onVideoJobStarted(
        command.job.pageKey,
        command.job.sourceName,
        page.channelIndex,
      );
      return true;
    }

    // Fallback：per-task widget 路径（旧逻辑，行为等价于 Round 2 之前）。
    final page = readyPending.first;
    final pageKey = _buildSourceChannelKey(page.sourceName, page.channelIndex);
    final legacyLease = _ensureLegacyWorkerLease('video:$pageKey');
    if (legacyLease == null) return false;
    _activeWebViews[pageKey] = jobLoadToken;
    WebViewResourceCoordinator.instance.markLeaseMaterialized(legacyLease);
    WebViewResourceCoordinator.instance.markLeaseBusy(legacyLease, busy: true);
    gate.markStarted(
      page.sourceName,
      sessionId: _playerSessionId,
      ownerTag: _sessionOwnerTag,
    );
    _webViewStatus[pageKey] = AppLocalizations.of(
      context,
    ).playerWebviewExtracting;
    _webviewStats.onVideoJobStarted(
      pageKey,
      page.sourceName,
      page.channelIndex,
    );
    return true;
  }

  /// 根据 `_scheduler.activeVideoJobs` 统计当前每个 sourceName 上正在跑的
  /// worker 数。
  /// 用于 source-affinity 调度的 soft limit 判定。被选取的 idle worker 自身
  /// 不计入（其 pageKey 为 null）。
  Map<String, int> _activeSourceWorkerCounts() {
    final counts = <String, int>{};
    for (final pageKey in _scheduler.activeVideoJobs.keys) {
      final src = SourceChannelKey.fromPageKey(pageKey).sourceName;
      counts[src] = (counts[src] ?? 0) + 1;
    }
    return counts;
  }

  /// 结构化日志：记录一次 affinity 选取的结果。
  ///
  /// - `sameSource=true`：复用同源，命中 "selected same-source job" 文案。
  /// - `sameSource=false` 且 `lastSource` 非空：worker 从旧源切到新源，记
  ///   "stealing source"，便于排查慢源分流 / 源切换路径。
  /// - `sameSource=false` 且 `lastSource` 为空：worker 首次接活，记
  ///   "taking job"，无源切换语义。
  void _logAffinityPick({
    required int workerId,
    required String? lastSource,
    required String pickedSource,
    required String pageKey,
    required bool sameSource,
  }) {
    if (sameSource) {
      debugPrint(
        '$_sessionOwnerTag [WebViewScheduler] worker=$workerId selected '
        'same-source job $pickedSource ($pageKey)',
      );
      return;
    }
    final from = (lastSource == null || lastSource.isEmpty)
        ? '<new>'
        : lastSource;
    if (lastSource == null || lastSource.isEmpty) {
      debugPrint(
        '$_sessionOwnerTag [WebViewScheduler] worker=$workerId taking job '
        '$pickedSource ($pageKey)',
      );
    } else {
      debugPrint(
        '$_sessionOwnerTag [WebViewScheduler] worker=$workerId stealing source '
        '$pickedSource ($pageKey, from=$from)',
      );
    }
  }

  bool _pumpWebViewPoolNow() {
    var startedAny = false;
    while (_activeWebViewTaskCount < _maxConcurrentWebViews) {
      final slotsRemaining = _maxConcurrentWebViews - _activeWebViewTaskCount;
      final hasPendingExtraction = _hasPendingWebViewExtractionTasks();
      final hasActiveExtraction = _useWorkerPool
          ? _scheduler.activeVideoJobs.isNotEmpty
          : _activeWebViews.isNotEmpty;

      final canStartCaptcha =
          PlayerWebViewScheduler.shouldStartCaptchaBeforeVideo(
            hasPendingExtraction: hasPendingExtraction,
            hasActiveExtraction: hasActiveExtraction,
            slotsRemaining: slotsRemaining,
          );

      if (canStartCaptcha && _startOneCaptchaTask()) {
        startedAny = true;
        continue;
      }
      if (_startOneWebViewExtractionTask()) {
        startedAny = true;
        continue;
      }
      break;
    }
    return startedAny;
  }

  int _completedSearchSourceCount() {
    return _sampleSourceController.sourceProgressMap.values
        .where((p) => _isSearchStepFinished(p.step))
        .length;
  }

  String _searchProgressLabel() {
    return AppLocalizations.of(context).playerWebviewSchedulerProgress(
      _completedSearchSourceCount(),
      _sampleSourceController.enabledSourceNames.length,
    );
  }

  String _captchaActiveLabel() {
    return AppLocalizations.of(
      context,
    ).playerWebviewCaptchaActive(_captchaCoordinator.activeTasks.length);
  }

  String _extractionActiveLabel() {
    final active = _useWorkerPool
        ? _scheduler.activeVideoJobs.length
        : _activeWebViews.length;
    return AppLocalizations.of(
      context,
    ).playerWebviewExtractionActive(active, _maxConcurrentWebViews);
  }

  /// Phase 0 单行调试计数汇总（widget 创建/释放 + 视频/验证码 job 生命周期）。
  String _webviewStatsLabel() {
    return _webviewStats.shortSummary();
  }

  /// Phase 0: 按 sourceName 汇总 pending/active/completed 三个维度。
  /// 输出形如 `源A [2|1|0], 源B [0|0|1]`，方括号内依次为
  /// `pending|active|completed`。pending 复用 `_pageIsPendingForExtraction`，
  /// active 计 `_activeWebViews` + `_captchaCoordinator.activeTasks`，completed 计
  /// `_sampleSourceController.sampleSuccessfulSources`。仅用于调试，不参与调度。
  String _perSourceStatusLabel() {
    final pending = <String, int>{};
    for (final page in _sampleSourceController.samplePlayPages) {
      if (_pageIsPendingForExtraction(page)) {
        pending[page.sourceName] = (pending[page.sourceName] ?? 0) + 1;
      }
    }
    final active = <String, int>{};
    final activeExtractionKeys = _useWorkerPool
        ? _scheduler.activeVideoJobs.keys
        : _activeWebViews.keys;
    for (final key in activeExtractionKeys) {
      final src = SourceChannelKey.fromPageKey(key).sourceName;
      active[src] = (active[src] ?? 0) + 1;
    }
    for (final task in _captchaCoordinator.activeTasks.values) {
      active[task.source.name] = (active[task.source.name] ?? 0) + 1;
    }
    final completed = <String, int>{};
    for (final s in _sampleSourceController.sampleSuccessfulSources) {
      completed[s.sourceName] = (completed[s.sourceName] ?? 0) + 1;
    }
    final names = <String>{
      ...pending.keys,
      ...active.keys,
      ...completed.keys,
    }.toList()..sort();
    if (names.isEmpty) return 'no sources yet';
    final parts = <String>[];
    for (final name in names) {
      final p = pending[name] ?? 0;
      final a = active[name] ?? 0;
      final c = completed[name] ?? 0;
      if (p == 0 && a == 0 && c == 0) continue;
      parts.add('$name [$p|$a|$c]');
    }
    return parts.isEmpty ? 'no active sources' : parts.join(', ');
  }

  /// Phase 0: 输出一行结构化的调度快照日志，便于后续 worker pool 重构对比基线。
  void _logSchedulerState(String reason) {
    debugPrint(
      '$_sessionOwnerTag [WebViewScheduler] state ($reason): '
      '${_extractionActiveLabel()} · ${_captchaActiveLabel()} · '
      '${_webViewWorkerPoolLabel()} · '
      'per-source: ${_perSourceStatusLabel()} · '
      'workers: ${_workerAffinitySummary()} · '
      'stats: ${_webviewStatsLabel()}',
    );
  }

  /// Round 4 Stage 3：worker pool affinity 调度快照字符串，形如
  /// `w0[S#a,jobs#0,warmS,ss#3] w1[idle,warmS,ss#3] w2[idle,warm-,ss#0]`。
  /// 每项含义：`w$workerId` 后方括号内依次为 busy 时 `源#channel`（idle 时
  /// 空）、该源 active 数、`warm$lastSourceName`、`ss#$sameSrcPending`。
  /// 仅用于日志，不参与调度。
  /// Round 4 Stage 3 / 5B step 3：worker pool affinity 调度快照字符串。
  ///
  /// 5B step 3 之后渲染统一遍历 [`_scheduler.slots`]，按 workerId 升序输
  /// 出形如 `w0[V#S#a,warmS,ss#3] w1[C#taskKey,warmS,ss#0] w2[idle,warm-,ss#0]`。
  /// 每项含义：`w$workerId` 后方括号内依次为：
  /// - 视频 busy：`V#源#channel`；空闲或非视频：`idle`
  /// - 验证码 busy：`C#taskKey`
  /// - `warm$lastSourceName`
  /// - `ss#$sameSrcPending`
  /// - `h$health`
  /// 仅用于日志，不参与调度。
  String _workerAffinitySummary() {
    if (_scheduler.slots.isEmpty) {
      return 'none';
    }
    final pendingBySource = <String, int>{};
    for (final page in _sampleSourceController.samplePlayPages) {
      if (_pageIsPendingForExtraction(page)) {
        pendingBySource[page.sourceName] =
            (pendingBySource[page.sourceName] ?? 0) + 1;
      }
    }
    final activeBySource = _activeSourceWorkerCounts();
    final slots = _scheduler.slots.values.toList()
      ..sort((a, b) => a.workerId.compareTo(b.workerId));
    final parts = <String>[];
    for (final slot in slots) {
      final last = slot.lastSourceName ?? '-';
      final ss = slot.lastSourceName == null ? 0 : (pendingBySource[last] ?? 0);
      final health = _workerHealthLabel(slot.health);
      String cur;
      switch (slot.kind) {
        case WebViewWorkerKind.video:
          final pageKey = slot.pageKey;
          if (pageKey == null) {
            cur = 'idle,jobs${activeBySource[last] ?? 0}';
          } else {
            final k = SourceChannelKey.fromPageKey(pageKey);
            cur = 'V#${k.sourceName}#${k.channelIndex ?? '-'}';
          }
        case WebViewWorkerKind.captcha:
          cur = 'C#${slot.taskKey ?? '-'}';
        case null:
          cur = 'idle,jobs${activeBySource[last] ?? 0}';
      }
      parts.add('w${slot.workerId}[$cur,warm$last,ss#$ss,h$health]');
    }
    return parts.join(' ');
  }

  void _updatePoolStatusMessage() {
    _sampleStatusMessageNotifier.value =
        '${_searchProgressLabel()}，'
        '${_captchaActiveLabel()}，'
        '${_extractionActiveLabel()}';
    _logSchedulerState('poolStatus');
  }

  void _scheduleWebViewPoolPump({bool immediate = false}) {
    if (!mounted || !_sessionLifecycle.acceptsNewWork) return;

    if (immediate) {
      final startedAny = _scheduler.pumpCoordinator.scheduleImmediate(
        _pumpWebViewPoolNow,
      );
      if (startedAny && mounted) {
        _updateState(() {});
        _updatePoolStatusMessage();
      }
      _maybeFinishSampleSearch();
      return;
    }

    unawaited(
      _scheduler.pumpCoordinator.scheduleStaggered(_pumpWebViewPoolStaggered),
    );
  }

  Future<void> _pumpWebViewPoolStaggered(int token) async {
    var startedAny = false;
    var isFirst = true;

    while (_activeWebViewTaskCount < _maxConcurrentWebViews) {
      if (!_sessionLifecycle.acceptsNewWork ||
          !mounted ||
          !_scheduler.pumpCoordinator.isCurrentToken(token)) {
        break;
      }

      if (!isFirst && _webViewLaunchInterval > 0) {
        await Future.delayed(Duration(milliseconds: _webViewLaunchInterval));
        if (!_sessionLifecycle.acceptsNewWork ||
            !mounted ||
            !_scheduler.pumpCoordinator.isCurrentToken(token)) {
          break;
        }
      }
      isFirst = false;

      final slotsRemaining = _maxConcurrentWebViews - _activeWebViewTaskCount;
      final hasPendingExtraction = _hasPendingWebViewExtractionTasks();
      final hasActiveExtraction = _useWorkerPool
          ? _scheduler.activeVideoJobs.isNotEmpty
          : _activeWebViews.isNotEmpty;

      final canStartCaptcha =
          PlayerWebViewScheduler.shouldStartCaptchaBeforeVideo(
            hasPendingExtraction: hasPendingExtraction,
            hasActiveExtraction: hasActiveExtraction,
            slotsRemaining: slotsRemaining,
          );

      var didStart = false;
      if (canStartCaptcha && _startOneCaptchaTask()) {
        didStart = true;
      } else if (_startOneWebViewExtractionTask()) {
        didStart = true;
      }

      if (didStart) {
        startedAny = true;
        if (mounted) {
          _updateState(() {});
        }
      } else {
        break;
      }
    }

    if (startedAny && mounted) {
      _updatePoolStatusMessage();
    }
    if (mounted) {
      _maybeFinishSampleSearch();
    }
  }

  void _onCaptchaPreflightResult(
    String taskKey,
    int resultLoadToken,
    CaptchaBypassResult result,
  ) {
    final task = _captchaCoordinator.activeTasks[taskKey];

    if (task == null) {
      _releaseCaptchaSlotForTask(taskKey, generation: resultLoadToken);
      _webviewStats.onCaptchaJobLateAfterCancel(taskKey);
      if (mounted) _updateState(() {});
      _scheduleWebViewPoolPump(immediate: true);
      return;
    }

    // A stable task key (for example search:<source>) can be reused by the
    // next episode. Never remove or release that new task for an old result.
    if (task.loadToken != resultLoadToken) {
      _webviewStats.onCaptchaJobStaleResult(taskKey);
      return;
    }

    _captchaCoordinator.removeActive(taskKey);
    _webViewStatus.remove(taskKey);

    if (!_acceptsSessionCallback(resultLoadToken) ||
        !mayApplyCaptchaResult(
          resultLoadToken: resultLoadToken,
          currentLoadToken: _sampleSourceController.sampleLoadToken,
          isDisposed: !mounted,
          activeTaskPresent: true,
          activeTaskKey: task.taskKey,
          resultTaskKey: taskKey,
        )) {
      _releaseCaptchaSlotForTask(taskKey, generation: resultLoadToken);
      _webviewStats.onCaptchaJobStaleResult(taskKey);
      if (mounted) _updateState(() {});
      _scheduleWebViewPoolPump(immediate: true);
      return;
    }

    _recordCaptchaWorkerResult(taskKey, result);
    _releaseCaptchaSlotForTask(taskKey, generation: resultLoadToken);
    _webviewStats.onCaptchaJobCompleted(
      success: result.success,
      timedOut: result.timedOut,
      jobKey: taskKey,
      sourceName: task.source.name,
    );
    task.onResult(task, result);
    if (mounted) _updateState(() {});
    _scheduleWebViewPoolPump(immediate: true);
    _maybeFinishSampleSearch();
    _logSchedulerState('captchaResult');
  }

  void _releaseCaptchaSlotForTask(String taskKey, {int? generation}) {
    _scheduler.releaseCaptchaSlot(taskKey, generation: generation);
  }

  void _onCaptchaWorkerIdle(int workerId, CaptchaPreflightJob _) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final slot = _scheduler.slotOf(workerId);
      if (slot == null) return;
      WebViewResourceCoordinator.instance.markLeaseBusy(
        _pooledLeaseId(workerId),
        busy: false,
      );
      // A reset can reassign this worker before the cancelled predecessor's
      // post-frame idle notification arrives. In that case the slot already
      // carries a new job; the stale notification must not mark it idle or
      // clear its fresh scheduler bookkeeping.
      if (!mayProcessCaptchaWorkerIdle(slotHasActiveKind: slot.kind != null)) {
        return;
      }
      final taskKey = slot.taskKey;
      if (shouldClearCaptchaSlotOnIdle(
        slotTaskKey: taskKey,
        activeCaptchaTasksContainsKey: _captchaCoordinator.activeTasks
            .containsKey(taskKey),
      )) {
        _scheduler.clearStaleCaptchaSlotOnIdle(workerId);
      }
      final health = _scheduler.healthOf(workerId);
      if (health == WebViewWorkerHealth.unhealthy) {
        _scheduler.removeSlot(workerId);
        debugPrint(
          '$_sessionOwnerTag [WebViewScheduler] rebuilt captcha '
          'worker=$workerId by removing unhealthy idle slot',
        );
      } else {
        _scheduler.markSlotIdle(workerId);
      }
      _trimIdleWebViewWorkerSlotsToBudget();
      _updateState(() {});
      _updatePoolStatusMessage();
      _scheduleWebViewPoolPump(immediate: true);
      _maybeFinishSampleSearch();
    });
  }
}
