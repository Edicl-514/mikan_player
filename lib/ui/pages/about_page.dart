import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCard(
            context,
            title: AppLocalizations.of(context).aboutIntro,
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            title: AppLocalizations.of(context).aboutSourceCode,
            content: InkWell(
              onTap: () =>
                  _launchUrl('https://github.com/Edicl-514/mikan_player'),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'https://github.com/Edicl-514/mikan_player',
                  style: TextStyle(
                    color: colors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.primary,
                  ),
                ),
              ),
            ),
            icon: Icons.code,
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            title: AppLocalizations.of(context).aboutTechStack,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).techStackFlutter,
                ),
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).techStackRust,
                ),
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).techStackIsar,
                ),
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).techStackMediaKit,
                ),
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).techStackDanmaku,
                ),
              ],
            ),
            icon: Icons.construction,
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            title: AppLocalizations.of(context).aboutDataSources,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).sourceMeta,
                ),
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).sourceTorrent,
                ),
                _buildBulletPoint(
                  context,
                  AppLocalizations.of(context).sourceDanmaku,
                ),
              ],
            ),
            icon: Icons.dataset_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            title: AppLocalizations.of(context).aboutDisclaimer,
            icon: Icons.info_outline,
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    Widget? content,
    required IconData icon,
    bool isHighlight = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isHighlight
          ? colors.secondaryContainer.withValues(alpha: 0.3)
          : colors.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isHighlight ? colors.secondary : colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isHighlight ? colors.secondary : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (content != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 36.0),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  child: content,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // Silently fail or handling can be improved if needed
    }
  }
}
