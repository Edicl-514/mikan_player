import 'package:flutter/material.dart';
import 'package:mikan_player/services/subtitle_service.dart';

/// 应用侧字幕覆盖层。
///
/// 不依赖 media_kit 的 [SubtitleView] / `Video.subtitleViewConfiguration`。
/// 全屏时 media_kit 会再推一层路由，仅更新父树 Video 配置无法实时反映到
/// 全屏实例；把字幕画在 controls 层，任意设置变更都能立刻生效。
class SubtitleOverlay extends StatelessWidget {
  final SubtitleService subtitleService;

  const SubtitleOverlay({super.key, required this.subtitleService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: subtitleService,
      builder: (context, _) {
        final settings = subtitleService.settings;
        if (!settings.enabled) {
          return const SizedBox.shrink();
        }

        final lines = subtitleService.currentSubtitleText
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(growable: false);

        if (lines.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, settings.bottomPadding),
            child: Text(
              lines.join('\n'),
              textAlign: TextAlign.center,
              style: settings.toTextStyle(),
            ),
          ),
        );
      },
    );
  }
}
