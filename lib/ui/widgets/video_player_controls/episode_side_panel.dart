import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';

/// 选集面板 - 280px 宽、从右侧滑入的全屏侧边栏。
///
/// 复刻 `video_player_controls.dart` 中 `_showEpisodeSidePanel` 的页面内容
/// 布局、配色、选集点击、关闭行为；将 [showGeneralDialog] 包装壳与主题色
/// 计算保留在调用方。
class EpisodeSidePanel extends StatelessWidget {
  final List<BangumiEpisode> allEpisodes;
  final BangumiEpisode currentEpisode;
  final ValueListenable<BangumiEpisode>? currentEpisodeListenable;
  final Function(BangumiEpisode) onEpisodeSelected;
  final ScrollController? scrollController;

  const EpisodeSidePanel({
    super.key,
    required this.allEpisodes,
    required this.currentEpisode,
    this.currentEpisodeListenable,
    required this.onEpisodeSelected,
    this.scrollController,
  });

  bool _isEpisodeSelected(BangumiEpisode current, BangumiEpisode episode) {
    if (episode.id != 0 && current.id != 0) {
      return episode.id == current.id;
    }
    return episode.sort == current.sort;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBgColor = isDark
        ? const Color(0xFF1A1A24)
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white54
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final borderColor = isDark
        ? Colors.white12
        : Theme.of(context).colorScheme.outlineVariant;
    final closeIconColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final unselectedBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final unselectedBorderColor = isDark
        ? Colors.white12
        : Theme.of(context).colorScheme.outlineVariant;
    final unselectedTextColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          height: double.infinity,
          decoration: BoxDecoration(
            color: panelBgColor,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '选集',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '共${allEpisodes.length}集',
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: closeIconColor),
                      ),
                    ],
                  ),
                ),
                Divider(color: borderColor, height: 1),
                Expanded(
                  child: _EpisodeGrid(
                    allEpisodes: allEpisodes,
                    currentEpisodeListenable: currentEpisodeListenable,
                    currentEpisode: currentEpisode,
                    isSelected: _isEpisodeSelected,
                    onEpisodeSelected: onEpisodeSelected,
                    scrollController: scrollController,
                    unselectedBgColor: unselectedBgColor,
                    unselectedBorderColor: unselectedBorderColor,
                    unselectedTextColor: unselectedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeGrid extends StatelessWidget {
  final List<BangumiEpisode> allEpisodes;
  final BangumiEpisode currentEpisode;
  final ValueListenable<BangumiEpisode>? currentEpisodeListenable;
  final bool Function(BangumiEpisode current, BangumiEpisode episode)
  isSelected;
  final Function(BangumiEpisode) onEpisodeSelected;
  final ScrollController? scrollController;
  final Color unselectedBgColor;
  final Color unselectedBorderColor;
  final Color unselectedTextColor;

  const _EpisodeGrid({
    required this.allEpisodes,
    required this.currentEpisode,
    required this.currentEpisodeListenable,
    required this.isSelected,
    required this.onEpisodeSelected,
    required this.scrollController,
    required this.unselectedBgColor,
    required this.unselectedBorderColor,
    required this.unselectedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final controller = scrollController ?? createPlatformScrollController();

    Widget buildGrid(BuildContext ctx, BangumiEpisode current) {
      return GridView.builder(
        controller: controller,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemCount: allEpisodes.length,
        itemBuilder: (context, index) {
          final ep = allEpisodes[index];
          final selected = isSelected(current, ep);
          return InkWell(
            onTap: () {
              Navigator.pop(context);
              onEpisodeSelected(ep);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2)
                    : unselectedBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : unselectedBorderColor,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                ep.sort.toInt().toString(),
                style: TextStyle(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : unselectedTextColor,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      );
    }

    final listenable = currentEpisodeListenable;
    if (listenable == null) {
      return buildGrid(context, currentEpisode);
    }

    return ValueListenableBuilder<BangumiEpisode>(
      valueListenable: listenable,
      builder: (context, current, _) => buildGrid(context, current),
    );
  }
}
