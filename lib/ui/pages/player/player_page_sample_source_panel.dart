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
    final l10n = AppLocalizations.of(context);
    if (_useWorkerPool) {
      return _buildWebViewWorkerTaskRows();
    }

    final rows = <PlayerWebViewTaskRow>[];
    for (final task in _captchaCoordinator.activeTasks.values) {
      rows.add(
        PlayerWebViewTaskRow(
          title: task.source.name.isNotEmpty ? task.source.name : task.label,
          statusLabel: l10n.playerWebViewBypassingCaptcha,
          isBusy: true,
        ),
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
          statusLabel: l10n.playerWebViewExtractingVideo,
          channelName: page?.channelName,
          subtitle: page?.playPageUrl ?? l10n.waitingForPlayPage,
          isBusy: true,
        ),
      );
    }
    return rows;
  }

  /// Maps scheduler slots to pure view-models for [PlayerSampleSourcePanel].
  List<PlayerWebViewTaskRow> _buildWebViewWorkerTaskRows() {
    final l10n = AppLocalizations.of(context);

    final slots = _scheduler.slots.values.toList()
      ..sort((a, b) => a.workerId.compareTo(b.workerId));

    return slots.map((slot) {
      final kind = slot.kind;
      final isVideoBusy = kind == WebViewWorkerKind.video;
      final isCaptchaBusy = kind == WebViewWorkerKind.captcha;
      final isBusy = isVideoBusy || isCaptchaBusy;

      var sourceName = '';
      String? channelName;
      String statusLabel;
      String? urlLine;
      String? debugLine;

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
        statusLabel = l10n.playerWebViewExtractingVideo;
        debugLine = 'worker ${slot.workerId} · ${_workerHealthLabel(slot.health)}';
      } else if (isCaptchaBusy) {
        final task = _captchaCoordinator.activeTasks[slot.taskKey];
        sourceName = task?.source.name ?? '';
        statusLabel = l10n.playerWebViewBypassingCaptcha;
        debugLine = 'worker ${slot.workerId} · ${_workerHealthLabel(slot.health)}';
      } else {
        statusLabel = l10n.playerWebViewIdle;
        debugLine = 'worker ${slot.workerId} · ${_workerHealthLabel(slot.health)}'
            '${slot.lastSourceName != null ? ' · warm: ${slot.lastSourceName}' : ''}';
      }

      final displayTitle = sourceName.isNotEmpty ? sourceName : statusLabel;

      return PlayerWebViewTaskRow(
        title: displayTitle,
        statusLabel: statusLabel,
        channelName: channelName,
        subtitle: urlLine,
        debugLine: debugLine,
        isBusy: isBusy,
      );
    }).toList();
  }
}
