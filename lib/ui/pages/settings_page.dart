import 'package:flutter/material.dart';
import 'package:mikan_player/ui/pages/data_source_settings_page.dart';
import 'package:mikan_player/ui/pages/search_settings_page.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';

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
        title: const Text('确认清除缓存'),
        content: const Text('这将删除所有缓存数据，包括番剧信息和图片缓存。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
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
            const SnackBar(content: Text('缓存已清除')),
          );
          _loadCacheStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除缓存失败: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isClearingCache = false);
        }
      }
    }
  }

  String _formatCacheStats() {
    if (_cacheStats == null) return '加载中...';
    
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
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            context,
            Icons.source,
            '数据源设置',
            '设置 bgmlist, bangumi, 蜜柑计划的 base URL',
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
            '搜索设置',
            '设置WebView并发数量和启动间隔',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchSettingsPage(),
                ),
              );
            },
          ),
          _buildCacheTile(context),
        ],
      ),
    );
  }

  Widget _buildCacheTile(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.storage,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text(
              '缓存管理',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: _isLoadingStats
                ? const Text('加载中...')
                : Text(_formatCacheStats()),
            trailing: _isClearingCache
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadCacheStats,
                    tooltip: '刷新',
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
                    label: const Text('清除全部缓存'),
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
