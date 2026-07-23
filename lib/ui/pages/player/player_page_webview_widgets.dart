part of '../player_page.dart';

extension _PlayerPageWebViewWidgets on _PlayerPageState {
  Widget _buildWebViewExtractors() {
    return _useWorkerPool
        ? _buildWebViewExtractorsPool()
        : _buildWebViewExtractorsLegacy();
  }

  /// 把 [SearchPlayResult] 打包成派给 worker 的 [VideoExtractionJob]，与
  /// 旧 [`WebViewVideoExtractorWidget`] 构造参数语义一致。
  VideoExtractionJob _buildVideoExtractionJob(
    SearchPlayResult page, {
    required String pageKey,
    required int generation,
  }) {
    return VideoExtractionJob(
      jobKey: pageKey,
      generation: generation,
      sourceName: page.sourceName,
      url: page.playPageUrl,
      customVideoRegex: page.videoRegex != r'$^' ? page.videoRegex : null,
      enableNestedUrl: page.enableNestedUrl,
      matchNestedUrl: page.matchNestedUrl != r'$^' ? page.matchNestedUrl : null,
      headers: page.headers,
      cookies: page.cookies,
      timeout: const Duration(seconds: 20),
    );
  }

  CaptchaPreflightJob _buildCaptchaPreflightJob(CaptchaPreflightTask task) {
    return CaptchaPreflightJob(
      jobKey: task.taskKey,
      generation: task.loadToken,
      source: task.source,
      searchKeyword: task.searchKeyword,
      initialUrl: task.initialUrl,
      referer: task.referer,
      initialCookies: task.initialCookies,
      captchaConfig: task.captchaConfig,
      timeout: const Duration(seconds: 45),
    );
  }

  Widget _buildWebViewExtractorsPool() {
    final children = <Widget>[];

    // 5B step 3：调度器统一为单表 `_scheduler.slots`，按 workerId
    // 升序遍历。同一 workerId 在 build 内只 emit 一次
    // [`ReusableBrowserWorker`]（widget key 固定为
    // `ValueKey('worker_$workerId')`），job 切换仅通过 didUpdateWidget
    // 路由到对应 runner（captcha runner 或 video runner），不会因
    // widget key 不同被 Flutter 销毁 → InAppWebView 实例与站点
    // session/cookie 真正跨 kind 复用。
    final workerIds = _scheduler.slots.keys.toList()..sort();
    for (final workerId in workerIds) {
      final slot = _scheduler.slots[workerId]!;
      WebViewJob? job;
      void Function(CaptchaPreflightJob, CaptchaBypassResult)? onCaptchaResult;
      void Function(int, CaptchaPreflightJob)? onCaptchaIdle;
      void Function(VideoExtractionJob, VideoExtractResult)? onVideoResult;
      void Function(int, VideoExtractionJob)? onVideoIdle;

      switch (slot.kind) {
        case WebViewWorkerKind.captcha:
          final taskKey = slot.taskKey;
          final task = taskKey == null
              ? null
              : _captchaCoordinator.activeTasks[taskKey];
          if (task != null) {
            job = CaptchaJob(_buildCaptchaPreflightJob(task));
          }
          onCaptchaResult = (completedJob, result) => _onCaptchaPreflightResult(
            completedJob.jobKey,
            completedJob.generation,
            result,
          );
          onCaptchaIdle = _onCaptchaWorkerIdle;
        case WebViewWorkerKind.video:
          final pageKey = slot.pageKey;
          SearchPlayResult? matchedPage;
          if (pageKey != null) {
            final parsedKey = SourceChannelKey.fromPageKey(pageKey);
            final sourceName = parsedKey.sourceName;
            final channelIndex = parsedKey.channelIndex?.toInt();
            for (final page in _sampleSourceController.samplePlayPages) {
              final pIdx = page.channelIndex?.toInt();
              if (page.sourceName == sourceName && pIdx == channelIndex) {
                matchedPage = page;
                break;
              }
            }
          }
          final generation = slot.generation;
          if (matchedPage != null && pageKey != null && generation != null) {
            job = VideoJob(
              _buildVideoExtractionJob(
                matchedPage,
                pageKey: pageKey,
                generation: generation,
              ),
            );
          }
          onVideoResult = (completedJob, result) => _onWebViewResult(
            completedJob.jobKey,
            completedJob.generation,
            result,
          );
          onVideoIdle = _onWorkerIdle;
        case null:
          // slot idle：emit null job，worker 内部保持当前页等下一 job。
          break;
      }

      children.add(
        ReusableBrowserWorker(
          key: ValueKey('worker_$workerId'),
          workerId: workerId,
          job: job,
          onCaptchaResult: onCaptchaResult,
          onCaptchaIdle: onCaptchaIdle,
          onVideoResult: onVideoResult,
          onVideoIdle: onVideoIdle,
          onLog: (message) {
            debugPrint(
              '$_sessionOwnerTag [WebView][worker_$workerId] $message',
            );
          },
          showWebView: _showWebView,
          preserveCaptchaSessionOnIdle: slot.preserveCaptchaSessionOnIdle,
          stats: _webviewStats,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(children: children);
  }

  /// Legacy per-task widget 实现（[WebViewVideoExtractorWidget] 一次性模型）。
  /// pool 模式下不调用，行为等价于 Round 2 之前。
  Widget _buildWebViewExtractorsLegacy() {
    if (_activeWebViews.isEmpty && _captchaCoordinator.activeTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    final orphanPageKeys = <String>[];

    // 构建活动的视频提取 WebView
    for (final activeEntry in _activeWebViews.entries) {
      final pageKey = activeEntry.key;
      final generation = activeEntry.value;
      final key = SourceChannelKey.fromPageKey(pageKey);
      final sourceName = key.sourceName;
      final channelIndex = key.channelIndex?.toInt();

      SearchPlayResult? matchedPage;
      for (final page in _sampleSourceController.samplePlayPages) {
        final pIdx = page.channelIndex?.toInt();
        if (page.sourceName == sourceName && pIdx == channelIndex) {
          matchedPage = page;
          break;
        }
      }

      if (matchedPage == null) {
        // 活动任务找不到对应的播放页（例如列表被重建/重排后不匹配），
        // 这会导致没有 WebView 被创建、onResult 永远不会触发，
        // 于是该任务在“并发提取”面板里卡住不消失。收集这些孤儿任务，
        // 在本帧结束后清理并重新调度任务池。
        orphanPageKeys.add(pageKey);
        continue;
      }

      children.add(
        WebViewVideoExtractorWidget(
          key: ValueKey('webview_$pageKey'),
          url: matchedPage.playPageUrl,
          customVideoRegex: matchedPage.videoRegex != r'$^'
              ? matchedPage.videoRegex
              : null,
          enableNestedUrl: matchedPage.enableNestedUrl,
          matchNestedUrl: matchedPage.matchNestedUrl != r'$^'
              ? matchedPage.matchNestedUrl
              : null,
          headers: matchedPage.headers,
          cookies: matchedPage.cookies,
          timeout: const Duration(seconds: 20),
          generation: generation,
          showWebView: _showWebView,
          onResult: (result) => _onWebViewResult(pageKey, generation, result),
          onLog: (msg) =>
              debugPrint('$_sessionOwnerTag [WebView][$pageKey] $msg'),
          stats: _webviewStats,
          jobKey: pageKey,
        ),
      );
    }

    // 清理孤儿提取任务：这些任务被标记为活动，但在 _sampleSourceController.samplePlayPages 中已经
    // 找不到对应的播放页，因此不会有 WebView 被创建来驱动 onResult。如果放任
    // 不管，它们会一直占用并发槽位并停留在“正在提取”状态。build 阶段不能直接
    // setState，所以推迟到本帧渲染完成后清理并重新泵送任务池。
    if (orphanPageKeys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        var changed = false;
        for (final pageKey in orphanPageKeys) {
          if (_activeWebViews.remove(pageKey) != null) {
            _webViewStatus.remove(pageKey);
            _failedWebViewPageKeys.add(pageKey);
            _webviewStats.onVideoJobCancelled(
              pageKey,
              SourceChannelKey.fromPageKey(pageKey).sourceName,
            );
            changed = true;
            debugPrint(
              '$_sessionOwnerTag [_buildWebViewExtractors] Cleared orphan '
              'extraction task: $pageKey',
            );
          }
        }
        if (changed) {
          _updateState(() {});
          _updatePoolStatusMessage();
          _scheduleWebViewPoolPump(immediate: true);
          _maybeFinishSampleSearch();
        }
      });
    }

    // 构建活动的验证码预处理 WebView（与提取任务共用池子）
    for (final task in _captchaCoordinator.activeTasks.values) {
      children.add(
        CaptchaWebViewBypassWidget(
          key: ValueKey('captcha_pool_${task.taskKey}_${task.loadToken}'),
          source: task.source,
          searchKeyword: task.searchKeyword,
          initialUrl: task.initialUrl,
          referer: task.referer,
          initialCookies: task.initialCookies,
          captchaConfig: task.captchaConfig,
          timeout: const Duration(seconds: 45),
          generation: task.loadToken,
          onResult: (result) =>
              _onCaptchaPreflightResult(task.taskKey, task.loadToken, result),
          onLog: (message) {
            debugPrint(
              '$_sessionOwnerTag [CaptchaBypass][${task.taskKey}] $message',
            );
          },
          showWebView: _showWebView,
          stats: _webviewStats,
          jobKey: task.taskKey,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(children: children);
  }
}
