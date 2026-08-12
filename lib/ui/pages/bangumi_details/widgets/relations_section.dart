import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/stable_thumb_scrollbar.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';

/// Horizontal-scrolling list of related subjects (relations) for a Bangumi
/// details page.
///
/// Extracted from `_buildRelationsSection` in `bangumi_details_page.dart` to
/// isolate the display tree from the page's data-fetching and lifecycle logic.
/// The widget has no hidden service/global/navigation state — all data and
/// callbacks are passed through the constructor.
class RelationsSection extends StatelessWidget {
  final List<BangumiRelatedSubject> relations;
  final bool isLoading;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;
  final ScrollController scrollController;
  final void Function(BangumiRelatedSubject relation) onItemTap;

  const RelationsSection({
    super.key,
    required this.relations,
    required this.isLoading,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.loadingPlaceholder,
    required this.scrollController,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingPlaceholder(context);
    }

    if (relations.isEmpty) {
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
          child: SizedBox(
            height: 200,
            child: StableThumbScrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 10),
                itemCount: relations.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 16),
                    child: _RelationCard(
                      relation: relations[index],
                      isDarkBg: isDarkBg,
                      textColor: textColor,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      onTap: () => onItemTap(relations[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RelationCard extends StatelessWidget {
  final BangumiRelatedSubject relation;
  final bool isDarkBg;
  final Color? textColor;
  final Color? cardColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _RelationCard({
    required this.relation,
    required this.isDarkBg,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceLinkAction(
      onOpen: (disposition) =>
          WorkspaceNavigation.dispatchLink(disposition, onTap),
      builder: (context, activate) => GestureDetector(
        onTap: activate,
        child: SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 120,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: relation.image.isNotEmpty
                    ? Hero(
                        tag: 'bangumi_relation_${relation.id.toInt()}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: relation.image,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            deferOffscreenLoad: false,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: isDarkBg ? Colors.white24 : Colors.grey[400],
                          size: 32,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                relation.relation,
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkBg ? Colors.amber : Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                relation.nameCn.isNotEmpty ? relation.nameCn : relation.name,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor!.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
