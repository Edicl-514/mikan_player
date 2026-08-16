import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/stable_thumb_scrollbar.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/widgets/site_icon_map.dart';

class SitesSection extends StatelessWidget {
  final List<BangumiDataSiteEntry> sites;
  final bool isDarkBg;
  final Widget sectionTitle;
  final ScrollController scrollController;
  final void Function(BangumiDataSiteEntry site) onSiteTap;

  const SitesSection({
    super.key,
    required this.sites,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.scrollController,
    required this.onSiteTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDarkBg ? Colors.white10 : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle,
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: StableThumbScrollbar(
            controller: scrollController,
            thumbVisibility: true,
            thickness: kHorizontalListScrollbarThickness,
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: kHorizontalListScrollbarClearance,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < sites.length; index++) ...[
                      if (index > 0) const SizedBox(width: 12),
                      _SiteCard(
                        site: sites[index],
                        textColor: textColor,
                        cardColor: cardColor!,
                        borderColor: borderColor,
                        isDarkBg: isDarkBg,
                        onTap: () => onSiteTap(sites[index]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SiteCard extends StatelessWidget {
  final BangumiDataSiteEntry site;
  final Color textColor;
  final Color cardColor;
  final Color borderColor;
  final bool isDarkBg;
  final VoidCallback onTap;

  const _SiteCard({
    required this.site,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    required this.isDarkBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackColor = isDarkBg ? Colors.white24 : Colors.grey[400]!;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
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
                    child: _SiteIcon(
                      siteKey: site.site,
                      fallbackColor: fallbackColor,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: _SiteKindBadge(kind: site.kind),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              site.title,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.9),
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
    );
  }
}

class _SiteIcon extends StatelessWidget {
  final String siteKey;
  final Color fallbackColor;

  const _SiteIcon({required this.siteKey, required this.fallbackColor});

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

class _SiteKindBadge extends StatelessWidget {
  final String kind;

  const _SiteKindBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = siteKindLabel(kind, AppLocalizations.of(context));
    final badgeColor = siteKindColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String siteKindLabel(String kind, AppLocalizations l10n) {
  switch (kind) {
    case 'onair':
      return l10n.bangumiDetailsSiteOnair;
    case 'info':
      return l10n.bangumiDetailsSiteInfo;
    case 'resource':
      return l10n.bangumiDetailsSiteResource;
    default:
      return kind;
  }
}

Color siteKindColor(String kind) {
  switch (kind) {
    case 'onair':
      return Colors.green;
    case 'info':
      return Colors.blue;
    case 'resource':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}
