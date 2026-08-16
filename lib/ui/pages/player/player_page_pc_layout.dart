part of '../player_page.dart';

extension _PlayerPagePcLayout on _PlayerPageState {
  Widget _buildPCLayout(BuildContext context) {
    return PlayerPcLayout(
      animeTitle: widget.anime.title,
      currentEpisode: _episodeController.currentEpisode,
      currentSourceActions: _buildCurrentSourceActionButtons(),
      videoArea: _buildVideoPlayerPlaceholder(
        context,
        uiMode: PlayerUiMode.desktopWide,
      ),
      isDescriptionExpanded: _isDescriptionExpanded,
      onToggleDescription: () {
        _updateState(() {
          _isDescriptionExpanded = !_isDescriptionExpanded;
        });
      },
      playSourceSelector: _buildPlaySourceSelector(
        uiMode: PlayerUiMode.desktopWide,
      ),
      resourceList: _buildResourceList(),
      onairSites: _sidePanelLoader.onairSites,
      onairSitesScrollController: _onairSitesScrollController,
      commentSortButton: _buildSortButton(),
      comments: _sidePanelLoader.comments,
      isLoadingComments: _sidePanelLoader.isLoadingComments,
      commentsError: _sidePanelLoader.commentsError,
      playableEpisodes: _episodeController.playableEpisodes,
      episodeScrollController: _pcEpisodeScrollController,
      onEpisodeSelected: _onEpisodeSelected,
      recommendations: _sidePanelLoader.recommendations,
      isLoadingRecommendations: _sidePanelLoader.isLoadingRecommendations,
      onRecommendationTap: _navigateToAnime,
      mainScrollController: _pcMainScrollController,
      sidebarScrollController: _pcSidebarScrollController,
      // The workspace shell already draws Back + the anime title for this tab,
      // so the header drops its own copies when hosted.
      showInternalChrome: !DesktopPageChromeScope.hostsNavigation(context),
    );
  }
}
