import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/bangumi_site_launcher.dart';
import 'package:mikan_player/ui/widgets/site_icon_map.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/widgets/stable_thumb_scrollbar.dart';

/// Horizontal onair-site chip list for the player side panel.
class PlayerOnairSitesList extends StatefulWidget {
  final List<BangumiDataSiteEntry> sites;
  final ScrollController? scrollController;

  const PlayerOnairSitesList({
    super.key,
    required this.sites,
    this.scrollController,
  });

  @override
  State<PlayerOnairSitesList> createState() => _PlayerOnairSitesListState();
}

class _PlayerOnairSitesListState extends State<PlayerOnairSitesList> {
  ScrollController? _internalController;

  /// Falls back to a platform-aware controller so the strip keeps the Windows
  /// smooth-wheel behaviour it had under `PlatformSmoothSingleChildScrollView`
  /// when no host controller is supplied.
  ScrollController get _effectiveController =>
      widget.scrollController ??
      (_internalController ??= createPlatformScrollController());

  @override
  void didUpdateWidget(PlayerOnairSitesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      if (widget.scrollController != null) {
        _internalController?.dispose();
        _internalController = null;
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sites.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallbackColor = isDark ? Colors.white24 : Colors.grey[400]!;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDark ? Colors.white10 : Colors.grey[300]!;

    return StableThumbScrollbar(
      controller: _effectiveController,
      thumbVisibility: true,
      thickness: kHorizontalListScrollbarThickness,
      child: SingleChildScrollView(
        controller: _effectiveController,
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: kHorizontalListScrollbarClearance,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.sites.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                WorkspaceLinkAction(
                  onOpen: (disposition) => WorkspaceNavigation.dispatchLink(
                    disposition,
                    () => launchBangumiSiteUrl(widget.sites[i].url),
                  ),
                  builder: (context, activate) => GestureDetector(
                    onTap: activate,
                    child: SizedBox(
                      width: 112,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: _OnairSiteIcon(
                              siteKey: widget.sites[i].site,
                              fallbackColor: fallbackColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.sites[i].title,
                            style: TextStyle(
                              fontSize: 12,
                              color: (isDark ? Colors.white : Colors.black87)
                                  .withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OnairSiteIcon extends StatelessWidget {
  final String siteKey;
  final Color fallbackColor;

  const _OnairSiteIcon({required this.siteKey, required this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    final assetPath = siteIconAssetPath(siteKey);
    if (assetPath == null) {
      return Icon(Icons.public, color: fallbackColor, size: 36);
    }
    return Image.asset(
      assetPath,
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.public, color: fallbackColor, size: 36),
    );
  }
}
