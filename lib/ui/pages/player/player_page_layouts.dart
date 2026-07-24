part of '../player_page.dart';

extension _PlayerPageLayouts on _PlayerPageState {
  Widget _buildMobileLayout(BuildContext context) {
    return PlayerMobileLayout(
      videoArea: _buildVideoPlayerPlaceholder(
        context,
        uiMode: PlayerUiMode.mobile,
      ),
      tabController: _mobileTabController,
      commentsCount: _sidePanelLoader.comments.length,
      infoTab: _buildMobileInfoTab(context, uiMode: PlayerUiMode.mobile),
      commentsTab: _buildCommentsTab(context),
    );
  }

  /// Windows 720-900 px keeps the single-column information hierarchy, but
  /// remains a desktop surface: mouse/keyboard controls and no touch lock UI.
  Widget _buildCompactLayout(BuildContext context) {
    return PlayerMobileLayout(
      videoArea: _buildVideoPlayerPlaceholder(
        context,
        uiMode: PlayerUiMode.desktopCompact,
      ),
      tabController: _mobileTabController,
      commentsCount: _sidePanelLoader.comments.length,
      infoTab: _buildMobileInfoTab(
        context,
        uiMode: PlayerUiMode.desktopCompact,
      ),
      commentsTab: _buildCommentsTab(context),
    );
  }
}
