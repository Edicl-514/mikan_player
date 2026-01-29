import 'package:flutter/material.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:mikan_player/ui/pages/settings_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final DownloadManager _downloadManager = DownloadManager();

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onDownloadUpdate);
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_onDownloadUpdate);
    super.dispose();
  }

  void _onDownloadUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Header
        UserAccountsDrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          accountName: Text(
            "Otaku User",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          accountEmail: Text(
            "user@example.com",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          currentAccountPicture: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 40),
          ),
        ),
        const SizedBox(height: 16),

        // Downloads Section with badge
        _buildDownloadsTile(context),

        _buildTile(context, Icons.history, 'History', 'Continue watching'),
        _buildTile(
          context,
          Icons.favorite,
          'Favorites',
          'Your collected anime',
        ),
        const Divider(),
        _buildTile(
          context,
          Icons.settings,
          'Settings',
          'App configuration',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
        ),
        _buildTile(context, Icons.info, 'About', 'Version 1.0.0', () {}),
      ],
    );
  }

  Widget _buildDownloadsTile(BuildContext context) {
    final activeCount = _downloadManager.activeCount;

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          children: [
            Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
            if (activeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: const Text(
          'Downloads',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          activeCount > 0
              ? '$activeCount active downloads'
              : 'Manage cached episodes',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DownloadManagerPage(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, [
    VoidCallback? onTap,
  ]) {
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
        onTap: onTap ?? () {},
      ),
    );
  }
}

/// Download Manager Page - Shows all download tasks
class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final DownloadManager _downloadManager = DownloadManager();

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _downloadManager.tasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: [
          if (tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清除已完成',
              onPressed: () async {
                final completedCount = tasks
                    .where(
                      (t) =>
                          t.status == DownloadTaskStatus.completed ||
                          t.status == DownloadTaskStatus.seeding,
                    )
                    .length;

                if (completedCount == 0) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('没有已完成的任务')));
                  return;
                }

                bool deleteFiles = false;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setDialogState) => AlertDialog(
                      title: const Text('确认清除'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('将清除 $completedCount 个已完成的任务'),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            title: const Text(
                              '同时删除物理文件',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: deleteFiles,
                            onChanged: (val) => setDialogState(
                              () => deleteFiles = val ?? false,
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  ),
                );

                if (confirmed == true) {
                  await _downloadManager.clearCompleted(
                    deleteFiles: deleteFiles,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已清除 $completedCount 个任务')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无下载任务',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在播放页面选择资源开始下载',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return _buildDownloadItem(tasks[index]);
              },
            ),
    );
  }

  Widget _buildDownloadItem(DownloadTask task) {
    final statusColor = _getStatusColor(task.status);
    final statusIcon = _getStatusIcon(task.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  tooltip: '删除任务',
                  onPressed: () async {
                    bool deleteFiles = false;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setDialogState) => AlertDialog(
                          title: const Text('确认删除'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.status == DownloadTaskStatus.downloading ||
                                        task.status ==
                                            DownloadTaskStatus.seeding
                                    ? '此任务正在下载中，确定要停止并删除吗？'
                                    : '确定要删除此任务吗？',
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                title: const Text(
                                  '同时删除物理文件',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: deleteFiles,
                                onChanged: (val) => setDialogState(
                                  () => deleteFiles = val ?? false,
                                ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                '删除',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (confirmed == true) {
                      await _downloadManager.removeTask(
                        task.id,
                        deleteFiles: deleteFiles,
                      );
                    }
                  },
                ),
              ],
            ),

            // Anime name
            if (task.animeName != null) ...[
              const SizedBox(height: 4),
              Text(
                task.animeName!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress / 100.0,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                // Progress percentage
                Text(
                  '${task.progress.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),

                // Download speed
                if (task.status == DownloadTaskStatus.downloading) ...[
                  const Icon(Icons.download, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    task.formattedSpeed,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                ],

                // Downloaded / Total size
                Text(
                  '${task.formattedDownloaded} / ${task.formattedSize}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),

                const Spacer(),

                // Peers count
                if (task.peers > 0) ...[
                  const Icon(
                    Icons.people_outline,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${task.peers} peers',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),

            // Error message
            if (task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                task.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.pending:
        return Colors.orange;
      case DownloadTaskStatus.downloading:
        return Colors.blue;
      case DownloadTaskStatus.seeding:
        return Colors.green;
      case DownloadTaskStatus.paused:
        return Colors.grey;
      case DownloadTaskStatus.completed:
        return Colors.green;
      case DownloadTaskStatus.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.pending:
        return Icons.hourglass_empty;
      case DownloadTaskStatus.downloading:
        return Icons.downloading;
      case DownloadTaskStatus.seeding:
        return Icons.cloud_upload;
      case DownloadTaskStatus.paused:
        return Icons.pause;
      case DownloadTaskStatus.completed:
        return Icons.check_circle;
      case DownloadTaskStatus.error:
        return Icons.error;
    }
  }
}
