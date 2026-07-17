part of '../player_page.dart';

extension _PlayerPageLayouts on _PlayerPageState {
  Widget _buildMobileLayout(BuildContext context) {
    return PlayerMobileLayout(
      videoArea: _buildVideoPlayerPlaceholder(context, isMobile: true),
      tabController: _mobileTabController,
      commentsCount: _sidePanelLoader.comments.length,
      infoTab: _buildMobileInfoTab(context),
      commentsTab: _buildCommentsTab(context),
    );
  }
}
