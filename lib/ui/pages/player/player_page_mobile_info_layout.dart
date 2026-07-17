part of '../player_page.dart';

extension _PlayerPageMobileInfoLayout on _PlayerPageState {
  Widget _buildMobileInfoTab(BuildContext context) {
    return PlayerMobileInfoLayout(
      animeTitle: widget.anime.title,
      currentEpisode: _episodeController.currentEpisode,
      playableEpisodeCount: _episodeController.playableEpisodes.length,
      isDescriptionExpanded: _isDescriptionExpanded,
      onToggleDescription: () {
        _updateState(() {
          _isDescriptionExpanded = !_isDescriptionExpanded;
        });
      },
      currentSourceActions: _buildCurrentSourceActionButtons(compact: true),
      episodeStrip: PlayerMobileEpisodeStrip(
        episodes: _episodeController.playableEpisodes,
        currentEpisode: _episodeController.currentEpisode,
        isExpanded: _isEpisodesExpanded,
        scrollController: _mobileEpisodeScrollController,
        onToggleExpanded: () {
          _updateState(() {
            _isEpisodesExpanded = !_isEpisodesExpanded;
            if (_isEpisodesExpanded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_mobileEpisodeScrollController.hasClients) {
                  final index = _episodeController.playableEpisodes.indexOf(
                    _episodeController.currentEpisode,
                  );
                  if (index != -1) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    // Item width 140 + separator 12 = 152
                    final targetOffset =
                        (index * 152.0) -
                        (screenWidth / 2) +
                        (140 / 2) +
                        16; // 16 is padding

                    _mobileEpisodeScrollController.animateTo(
                      targetOffset.clamp(
                        0.0,
                        _mobileEpisodeScrollController.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                }
              });
            }
          });
        },
        // Must stay on the same PlayerPage State. pushReplacement with a fresh
        // PlayerPage disposes the entire WebView worker pool (and captcha
        // CookieManager sessions), which is the rapid EP1→EP2→EP1 captcha
        // failure mode on mobile. PC list / skip next already call
        // `_onEpisodeSelected` in-place so warm workers survive.
        onEpisodeSelected: (ep) => unawaited(_onEpisodeSelected(ep)),
      ),
      playSourceSelector: _buildPlaySourceSelector(isMobile: true),
      resourceList: _buildResourceList(),
      onairSites: _sidePanelLoader.onairSites,
      recommendations: _sidePanelLoader.recommendations,
      isLoadingRecommendations: _sidePanelLoader.isLoadingRecommendations,
      onRecommendationTap: _navigateToAnime,
      scrollController: _mobileInfoScrollController,
    );
  }
}
