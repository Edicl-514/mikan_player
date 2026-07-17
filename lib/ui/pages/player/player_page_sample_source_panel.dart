part of '../player_page.dart';

extension _PlayerPageSampleSourcePanel on _PlayerPageState {
  Widget _buildSampleSourceContent() {
    final hasActiveTasks =
        (_useWorkerPool
            ? _scheduler.activeVideoJobs.isNotEmpty
            : _activeWebViews.isNotEmpty) ||
        _captchaCoordinator.activeTasks.isNotEmpty;

    return PlayerSampleSourcePanel(
      isLoadingSample: _sampleSourceController.isLoadingSample,
      sampleError: _sampleSourceController.sampleError,
      enabledSourceNames: _sampleSourceController.enabledSourceNames,
      sourceProgressMap: _sampleSourceController.sourceProgressMap,
      successfulSources: _sampleSourceController.sampleSuccessfulSources,
      selectedSourceIndex: _playbackController.selectedSourceIndex,
      sampleVideoUrl: _playbackController.sampleVideoUrl,
      statusMessageListenable: _sampleStatusMessageNotifier,
      disableAutoSourceSearchForCurrentEpisode:
          _disableAutoSourceSearchForCurrentEpisode,
      autoSearchOnline: _autoSearchOnline,
      hasActiveWebViewTasks: hasActiveTasks,
      activeWebViewTaskCount: _activeWebViewTaskCount,
      maxConcurrentWebViews: _maxConcurrentWebViews,
      workerPoolLabel: _useWorkerPool ? _webViewWorkerPoolLabel() : null,
      webviewStatsLabel: _webviewStatsLabel(),
      perSourceStatusLabel: _perSourceStatusLabel(),
      showWebView: _showWebView,
      onShowWebViewChanged: (v) => _updateState(() => _showWebView = v),
      useWorkerPool: _useWorkerPool,
      onUseWorkerPoolChanged: _setUseWorkerPool,
      activeTaskRows: _buildSampleActiveTaskRows(),
      onSourceSelected: _onSourceSelected,
      onPlaySelected: _startPlaybackFromSelectedSource,
      onManualSearch: () => _loadSampleSource(manual: true),
    );
  }

  List<PlayerWebViewTaskRow> _buildSampleActiveTaskRows() {
    if (_useWorkerPool) {
      return _buildWebViewWorkerTaskRows();
    }

    final rows = <PlayerWebViewTaskRow>[];
    for (final task in _captchaCoordinator.activeTasks.values) {
      rows.add(
        PlayerWebViewTaskRow(title: '${task.label} - 正在跳过验证码', isBusy: true),
      );
    }
    for (final pageKey in _activeWebViews.keys) {
      final key = SourceChannelKey.fromPageKey(pageKey);
      final sourceName = key.sourceName;
      final channelIndex = key.channelIndex?.toInt();
      SearchPlayResult? page;
      for (final item in _sampleSourceController.samplePlayPages) {
        final pIdx = item.channelIndex?.toInt();
        if (item.sourceName == sourceName && pIdx == channelIndex) {
          page = item;
          break;
        }
      }
      rows.add(
        PlayerWebViewTaskRow(
          title: sourceName,
          trailing: (page?.channelName ?? '').isNotEmpty
              ? ' - ${page!.channelName}'
              : null,
          subtitle: page?.playPageUrl ?? '等待匹配播放页...',
          isBusy: true,
        ),
      );
    }
    return rows;
  }

  /// Maps scheduler slots to pure view-models for [PlayerSampleSourcePanel].
  List<PlayerWebViewTaskRow> _buildWebViewWorkerTaskRows() {
    final pendingBySource = <String, int>{};
    for (final page in _sampleSourceController.samplePlayPages) {
      if (_pageIsPendingForExtraction(page)) {
        pendingBySource[page.sourceName] =
            (pendingBySource[page.sourceName] ?? 0) + 1;
      }
    }

    final slots = _scheduler.slots.values.toList()
      ..sort((a, b) => a.workerId.compareTo(b.workerId));

    return slots.map((slot) {
      final lastSource = slot.lastSourceName;
      final sameSrcPending = lastSource == null
          ? 0
          : (pendingBySource[lastSource] ?? 0);
      final showAffinity = lastSource != null || sameSrcPending > 0;
      final healthLabel = _workerHealthLabel(slot.health);
      final kind = slot.kind;
      final isVideoBusy = kind == WebViewWorkerKind.video;
      final isCaptchaBusy = kind == WebViewWorkerKind.captcha;
      final isBusy = isVideoBusy || isCaptchaBusy;

      var sourceName = '';
      String? channelName;
      var urlLine = '等待匹配播放页...';
      if (isVideoBusy) {
        final pageKey = slot.pageKey!;
        final key = SourceChannelKey.fromPageKey(pageKey);
        sourceName = key.sourceName;
        final channelIndex = key.channelIndex?.toInt();
        for (final item in _sampleSourceController.samplePlayPages) {
          final pIdx = item.channelIndex?.toInt();
          if (item.sourceName == sourceName && pIdx == channelIndex) {
            channelName = item.channelName;
            urlLine = item.playPageUrl;
            break;
          }
        }
      } else if (isCaptchaBusy) {
        final task = _captchaCoordinator.activeTasks[slot.taskKey];
        sourceName = task?.source.name ?? '';
        urlLine = '正在跳过验证码';
      }

      final busyLabel = isVideoBusy
          ? '$sourceName (w${slot.workerId} · $healthLabel)'
          : isCaptchaBusy
          ? '$sourceName (c${slot.workerId} · $healthLabel)'
          : 'w${slot.workerId} · $healthLabel';

      return PlayerWebViewTaskRow(
        title: busyLabel,
        trailing: isVideoBusy && (channelName ?? '').isNotEmpty
            ? ' - $channelName'
            : null,
        subtitle: urlLine,
        affinityLine: showAffinity
            ? 'warm: ${lastSource ?? '-'} · same-src pending: $sameSrcPending'
            : null,
        isBusy: isBusy,
        highlightAffinity: sameSrcPending > 0,
      );
    }).toList();
  }
}
