part of '../player_page.dart';

extension _PlayerPageSidePanelWidgets on _PlayerPageState {
  Widget _buildResourceList() {
    final content = resolvePlayerResourceContent(
      isExpanded: _isSourceControlExpanded,
      activeSource: _activeSource,
    );
    if (content == PlayerResourceContent.hidden) {
      return const SizedBox.shrink();
    }
    if (content == PlayerResourceContent.sample) {
      return _buildSampleSourceContent();
    }
    final deduped = sortBtResourcesByTitle(
      dedupBtResources([
        ..._sourceController.mikanResources,
        ..._sourceController.dmhyResources,
      ]),
    );
    return BtResourceList(
      isExpanded: _isSourceControlExpanded,
      resources: toBtResourceViewModels(deduped),
      isLoading:
          _sourceController.isLoadingMikan || _sourceController.isLoadingDmhy,
      hasError:
          _sourceController.mikanError != null ||
          _sourceController.dmhyError != null,
      loadingMagnet: _loadingMagnet,
      isPlayBlocked:
          _playbackController.isLoadingVideo || _loadingMagnet != null,
      onRetrySearch: () {
        _updateState(() {
          _disableAutoSourceSearchForCurrentEpisode = false;
        });
        _loadMikanSource();
        _loadDmhySource();
      },
      onCopyMagnet: (res) {
        Clipboard.setData(ClipboardData(text: res.magnet));
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.playerSidePanelCopyMagnet)));
      },
      onDownload: (res) async {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playerSidePanelDownloadHint)),
        );
        await _downloadManager.startDownload(
          magnet: res.magnet,
          name: res.title,
          animeName: widget.anime.title,
          episodeNumber: res.episode,
        );
      },
      onPlay: (res) async {
        final loadToken = _sampleSourceController.sampleLoadToken;
        _updateState(() {
          _loadingMagnet = res.magnet;
          _playbackController.setVideoError(null);
        });
        try {
          final streamUrl = await _downloadManager.startDownload(
            magnet: res.magnet,
            name: res.title,
            animeName: widget.anime.title,
            episodeNumber: res.episode,
            forPlayback: true,
          );
          if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          if (streamUrl == null) {
            _updateState(() {
              _playbackController.setVideoError(
                AppLocalizations.of(context).playerSidePanelLoadFailed,
              );
              _loadingMagnet = null;
            });
            return;
          }
          debugPrint('[Player] Got stream URL: $streamUrl');
          _updateState(() {
            _playbackController.markLocalPlayback(
              streamUrl,
              label: AppLocalizations.of(context).playerSourceTabBt,
            );
          });
          final btHash = _extractBtHashFromStreamUrl(streamUrl);
          if (btHash != null) {
            _downloadManager.setActiveStream(btHash);
            debugPrint(
              '[Player] Notified DownloadManager: stream active for $btHash',
            );
          }
          await _player.stop();
          if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          _resumeSeekGeneration++;
          final openGeneration = _resumeSeekGeneration;
          await _openWithFocus(_mediaForPlayback(streamUrl));
          if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          await _applyPlaybackSpeed();
          await _applyPendingStartPosition(generation: openGeneration);
          if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          _updateState(() {
            _loadingMagnet = null;
          });
          _publishPlayerControlSourceState();
        } catch (e) {
          debugPrint('[Player] Error playing magnet: $e');
          if (!isSearchGenerationCurrent(
            resultLoadToken: loadToken,
            currentLoadToken: _sampleSourceController.sampleLoadToken,
            isDisposed: !mounted,
          )) {
            return;
          }
          _updateState(() {
            _playbackController.setVideoError(e.toString());
            _loadingMagnet = null;
          });
        }
      },
    );
  }

  Widget _buildCommentsTab(BuildContext context) {
    return PlayerComments(
      comments: _sidePanelLoader.comments,
      isLoading: _sidePanelLoader.isLoadingComments,
      error: _sidePanelLoader.commentsError,
      scrollController: _commentsScrollController,
      sortButton: _buildSortButton(),
    );
  }
}
