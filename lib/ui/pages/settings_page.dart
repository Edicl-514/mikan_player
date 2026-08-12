import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/settings_service.dart';
import 'package:mikan_player/utils/feature_flags.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  final ScrollController _scrollController = createPlatformScrollController();
  Map<String, dynamic>? _cacheStats;
  bool _isLoadingStats = false;
  bool _isClearingCache = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await CacheManager.instance.getCacheStats();
      if (mounted) {
        setState(() {
          _cacheStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).confirmClearCache),
        content: Text(AppLocalizations.of(context).clearCacheMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearingCache = true);
      try {
        await CacheManager.instance.clearAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).cacheCleared)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).cacheClearedFailed(e.toString()),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isClearingCache = false);
          await _loadCacheStats();
        }
      }
    }
  }

  String _formatCacheStats(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_cacheStats == null) return l10n.loading;

    final subjects = (_cacheStats!['subjects'] as num?)?.toInt() ?? 0;
    final characters = (_cacheStats!['characters'] as num?)?.toInt() ?? 0;
    final relations = (_cacheStats!['relations'] as num?)?.toInt() ?? 0;
    final timetables = (_cacheStats!['timetables'] as num?)?.toInt() ?? 0;
    final rankings = (_cacheStats!['rankings'] as num?)?.toInt() ?? 0;
    final imageSize = _cacheStats!['imageSizeFormatted']?.toString() ?? '0 B';
    final htmlImageSize =
        _cacheStats!['htmlImageSizeFormatted']?.toString() ?? '0 B';
    final webViewCacheSize =
        _cacheStats!['webViewCacheSizeFormatted']?.toString() ?? '0 B';
    final webViewStorageSize =
        _cacheStats!['webViewStorageSizeFormatted']?.toString() ?? '0 B';
    final totalSize = _cacheStats!['totalSizeFormatted']?.toString() ?? '0 B';

    return l10n.cacheStatsSummary(
      subjects,
      characters,
      relations,
      timetables,
      rankings,
      imageSize,
      htmlImageSize,
      webViewCacheSize,
      webViewStorageSize,
      totalSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopPageScaffold(
      title: Text(AppLocalizations.of(context).settingsTitle),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            context,
            Icons.source,
            AppLocalizations.of(context).dataSourceSettings,
            AppLocalizations.of(context).dataSourceSubtitle,
            WorkspaceDestinations.dataSourceSettings(context),
          ),
          _buildSettingTile(
            context,
            Icons.network_wifi,
            AppLocalizations.of(context).networkSettings,
            AppLocalizations.of(context).networkSettingsSubtitle,
            WorkspaceDestinations.networkSettings(context),
          ),
          _buildSettingTile(
            context,
            Icons.search,
            AppLocalizations.of(context).searchSettings,
            AppLocalizations.of(context).searchSubtitle,
            WorkspaceDestinations.searchSettings(context),
          ),
          if (enableSubscriptionDebug)
            _buildSettingTile(
              context,
              Icons.bug_report,
              AppLocalizations.of(context).subscriptionDebugEntryTitle,
              AppLocalizations.of(context).subscriptionDebugEntrySubtitle,
              WorkspaceDestinations.subscriptionDebug(context),
            ),
          _buildSettingTile(
            context,
            Icons.download,
            AppLocalizations.of(context).downloadSettingsTitle,
            AppLocalizations.of(context).downloadSettingsEntrySubtitle,
            WorkspaceDestinations.downloadSettings(context),
          ),
          _buildSettingTile(
            context,
            Icons.palette,
            AppLocalizations.of(context).themeSettings,
            AppLocalizations.of(context).themeSettingsSubtitle,
            WorkspaceDestinations.themeSettings(context),
          ),
          _buildLanguageTile(context),
          _buildCacheTile(context),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          Icons.language,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          AppLocalizations.of(context).language,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(AppLocalizations.of(context).languageSubtitle),
        trailing: DropdownButton<Locale?>(
          value: _settingsService.locale,
          underline: const SizedBox(),
          onChanged: (Locale? newLocale) {
            _settingsService.setLocale(newLocale);
          },
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(AppLocalizations.of(context).auto),
            ),
            DropdownMenuItem(
              value: const Locale('zh'),
              child: Text(AppLocalizations.of(context).chinese),
            ),
            DropdownMenuItem(
              value: const Locale('en'),
              child: Text(AppLocalizations.of(context).english),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheTile(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.storage,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              AppLocalizations.of(context).cacheManagement,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: _isLoadingStats
                ? Text(AppLocalizations.of(context).loading)
                : Text(_formatCacheStats(context)),
            trailing: _isClearingCache
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadCacheStats,
                    tooltip: AppLocalizations.of(context).refresh,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isClearingCache ? null : _clearCache,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(AppLocalizations.of(context).clearCache),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    WorkspaceDestination destination,
  ) {
    return WorkspaceLink(
      destination: destination,
      builder: (context, activate) => Card(
        elevation: 0,
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: activate,
        ),
      ),
    );
  }
}
