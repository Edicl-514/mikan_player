import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/widgets/bangumi_site_launcher.dart';
import 'package:mikan_player/ui/widgets/site_icon_map.dart';

/// Horizontal onair-site chip list for the player side panel.
class PlayerOnairSitesList extends StatelessWidget {
  final List<BangumiDataSiteEntry> sites;

  const PlayerOnairSitesList({super.key, required this.sites});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallbackColor = isDark ? Colors.white24 : Colors.grey[400]!;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDark ? Colors.white10 : Colors.grey[300]!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sites.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            GestureDetector(
              onTap: () => launchBangumiSiteUrl(sites[i].url),
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
                        siteKey: sites[i].site,
                        fallbackColor: fallbackColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sites[i].title,
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
          ],
        ],
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
