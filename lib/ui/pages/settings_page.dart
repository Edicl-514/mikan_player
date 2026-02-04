import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/data_source_settings_page.dart';
import 'package:mikan_player/ui/pages/search_settings_page.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _cacheStats;
  bool _isLoadingStats = false;
  bool _isClearingCache = false;

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
          _loadCacheStats();
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
        }
      }
    }
  }

  String _formatCacheStats(BuildContext context) {
    if (_cacheStats == null) return AppLocalizations.of(context).loading;

    final subjects = _cacheStats!['subjects'] ?? 0;
    final characters = _cacheStats!['characters'] ?? 0;
    final relations = _cacheStats!['relations'] ?? 0;
    final timetables = _cacheStats!['timetables'] ?? 0;
    final rankings = _cacheStats!['rankings'] ?? 0;
    final imageSize = _cacheStats!['imageSizeFormatted'] ?? '0 B';

    return '条目: $subjects, 角色: $characters, 关联: $relations\n'
        '时间表: $timetables, 排行榜: $rankings\n'
        '图片缓存: $imageSize';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            context,
            Icons.source,
            AppLocalizations.of(context).dataSourceSettings,
            AppLocalizations.of(context).dataSourceSubtitle,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DataSourceSettingsPage(),
                ),
              );
            },
          ),
          _buildSettingTile(
            context,
            Icons.search,
            AppLocalizations.of(context).searchSettings,
            AppLocalizations.of(context).searchSubtitle,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchSettingsPage(),
                ),
              );
            },
          ),
          _buildLanguageTile(context),
          _buildCacheTile(context),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    final settings = SettingsService();
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
          value: settings.locale,
          underline: const SizedBox(),
          onChanged: (Locale? newLocale) {
            settings.setLocale(newLocale);
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
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
