part of '../player_page.dart';

extension _PlayerPageSourcePanel on _PlayerPageState {
  Widget _buildSortButton() {
    return PlayerCommentSortButton(
      sortMode: _sidePanelLoader.commentSortMode,
      onSelected: (value) {
        if (_sidePanelLoader.setCommentSortMode(value)) {
          _updateState(() {});
        }
      },
    );
  }

  Widget _buildPlaySourceSelector({required bool isMobile}) {
    final btCount = dedupBtResources([
      ..._sourceController.mikanResources,
      ..._sourceController.dmhyResources,
    ]).length;
    return PlayerSourceSelector(
      isMobile: isMobile,
      isExpanded: _isSourceControlExpanded,
      activeSource: _activeSource,
      btCount: btCount,
      onlineCount: _sampleSourceController.sampleSuccessfulSources.length,
      currentLabel: _playbackController.playingSourceLabel,
      isBtLoading:
          _sourceController.isLoadingMikan || _sourceController.isLoadingDmhy,
      hasBtError:
          _sourceController.mikanError != null ||
          _sourceController.dmhyError != null,
      isSampleLoading: _sampleSourceController.isLoadingSample,
      hasSampleError: _sampleSourceController.sampleError != null,
      onExpand: () => _updateState(() => _isSourceControlExpanded = true),
      onCollapse: () => _updateState(() => _isSourceControlExpanded = false),
      onSelectSource: (id) => _updateState(() => _activeSource = id),
    );
  }
}
