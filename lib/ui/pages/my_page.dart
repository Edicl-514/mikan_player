import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/pages/settings_page.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/pages/favorites_page.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/ui/pages/about_page.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/services/playback_history_manager.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final DownloadManager _downloadManager = DownloadManager();
  final UserManager _userManager = UserManager();

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onStateUpdate);
    _userManager.addListener(_onStateUpdate);
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_onStateUpdate);
    _userManager.removeListener(_onStateUpdate);
    super.dispose();
  }

  void _onStateUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    Widget body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Header
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              if (_userManager.isLoggedIn) {
                _showLogoutDialog();
              } else {
                _showLoginDialog();
              }
            },
            child: UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              accountName: Text(
                _userManager.user?.nickname ??
                    AppLocalizations.of(context).loginPrompt,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                _userManager.user != null
                    ? "@${_userManager.user!.username}"
                    : AppLocalizations.of(context).loginSubtitle,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                ),
                clipBehavior: Clip.antiAlias,
                child: _userManager.user != null
                    ? CachedNetworkImage(
                        imageUrl: _userManager.user!.avatar.large,
                        fit: BoxFit.cover,
                        errorWidget: Icon(
                          Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Downloads Section with badge
        _buildDownloadsTile(context),

        _buildTile(
          context,
          Icons.history,
          AppLocalizations.of(context).historyTitle,
          AppLocalizations.of(context).historySubtitle,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryPage()),
            );
          },
        ),
        _buildTile(
          context,
          Icons.favorite,
          AppLocalizations.of(context).favoritesTitle,
          AppLocalizations.of(context).favoritesSubtitle,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesPage()),
            );
          },
        ),
        const Divider(),
        _buildTile(
          context,
          Icons.settings,
          AppLocalizations.of(context).navSettings,
          AppLocalizations.of(context).settingsSubtitle,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
        ),
        _buildTile(
          context,
          Icons.info,
          AppLocalizations.of(context).aboutTitle,
          AppLocalizations.of(context).version('1.0.0'),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
            );
          },
        ),
      ],
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context).navMy,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: AppLocalizations.of(context).searchHint,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
            ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildDownloadsTile(BuildContext context) {
    final activeCount = _downloadManager.activeCount;
    final seedingCount = _downloadManager.seedingCount;

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
            // Show red badge only for active downloads (not seeding)
            if (activeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
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
            // Show green badge for seeding only if no active downloads
            if (activeCount == 0 && seedingCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$seedingCount',
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
        title: Text(
          AppLocalizations.of(context).downloadTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          activeCount > 0
              ? '$activeCount ${AppLocalizations.of(context).downloading}${seedingCount > 0 ? ', $seedingCount ${AppLocalizations.of(context).seeding}' : ''}'
              : seedingCount > 0
              ? '$seedingCount ${AppLocalizations.of(context).seeding}'
              : AppLocalizations.of(context).downloadSubtitle,
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

  Future<void> _showLoginDialog() async {
    final controller = TextEditingController();
    bool loading = false;
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.loginDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.loginDialogMessage),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: l10n.loginUsernameLabel,
                    border: const OutlineInputBorder(),
                    hintText: l10n.loginUsernameHint,
                    errorText: error,
                  ),
                  enabled: !loading,
                  autofocus: true,
                  onSubmitted: (_) async {
                    // Initial trigger handled by button but TextField enter is nice too
                    // Skipping for simplicity or logic duplication avoidance
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (controller.text.trim().isEmpty) return;

                        setState(() {
                          loading = true;
                          error = null;
                        });

                        try {
                          await _userManager.login(controller.text.trim());
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            setState(() {
                              loading = false;
                              error = l10n.loginError;
                            });
                          }
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.confirm),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutTitle),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _userManager.logout();
    }
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
  DownloadTaskStatus? _statusFilter;
  final Set<String> _collapsedGroups = {};
  final ScrollController _scrollController = createPlatformScrollController();

  bool get _forceDeleteFilesOnAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _downloadManager.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _downloadManager.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  List<DownloadTask> get _filteredTasks {
    var tasks = _downloadManager.tasks;
    if (_statusFilter != null) {
      tasks = tasks.where(_matchesStatusFilter).toList();
    }
    return tasks;
  }

  bool _matchesStatusFilter(DownloadTask task) {
    switch (_statusFilter) {
      case null:
        return true;
      case DownloadTaskStatus.downloading:
        return task.status == DownloadTaskStatus.downloading ||
            task.status == DownloadTaskStatus.pending ||
            task.status == DownloadTaskStatus.metadata ||
            task.status == DownloadTaskStatus.checking ||
            task.status == DownloadTaskStatus.queued;
      case DownloadTaskStatus.completed:
        return task.status == DownloadTaskStatus.completed ||
            task.status == DownloadTaskStatus.seeding;
      case DownloadTaskStatus.pending:
      case DownloadTaskStatus.metadata:
      case DownloadTaskStatus.checking:
      case DownloadTaskStatus.queued:
      case DownloadTaskStatus.seeding:
      case DownloadTaskStatus.paused:
      case DownloadTaskStatus.error:
        return task.status == _statusFilter;
    }
  }

  Map<String?, List<DownloadTask>> get _groupedByAnime {
    final grouped = <String?, List<DownloadTask>>{};
    for (final task in _filteredTasks) {
      final key = task.animeName;
      grouped.putIfAbsent(key, () => []).add(task);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _downloadManager.tasks;
    final groupedTasks = _groupedByAnime;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.downloadTitle),
        actions: [
          if (tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: l10n.clearCompleted,
              onPressed: () async {
                final completedCount = tasks
                    .where(
                      (t) =>
                          t.status == DownloadTaskStatus.completed ||
                          t.status == DownloadTaskStatus.seeding,
                    )
                    .length;

                if (completedCount == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).noCompletedTasks,
                      ),
                    ),
                  );
                  return;
                }

                final forceDeleteFiles = _forceDeleteFilesOnAndroid;
                bool deleteFiles = forceDeleteFiles;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setDialogState) => AlertDialog(
                      title: Text(
                        AppLocalizations.of(context).clearConfirmTitle,
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(
                              context,
                            ).clearConfirmMessage(completedCount),
                          ),
                          if (forceDeleteFiles) ...[
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context).deleteFiles,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              title: Text(
                                AppLocalizations.of(context).deleteFiles,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: deleteFiles,
                              onChanged: (val) => setDialogState(
                                () => deleteFiles = val ?? false,
                              ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(AppLocalizations.of(context).cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(AppLocalizations.of(context).confirm),
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
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).clearedTasks(completedCount),
                        ),
                      ),
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
                    AppLocalizations.of(context).noDownloads,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).startDownloadHint,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Status filter chips
                _buildFilterChips(l10n),
                // Task list grouped by anime
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: groupedTasks.length,
                    itemBuilder: (context, index) {
                      final entry = groupedTasks.entries.elementAt(index);
                      return _buildAnimeGroup(entry.key, entry.value, l10n);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text(l10n.filterAll),
              selected: _statusFilter == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _statusFilter = null);
                }
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.filterActive),
              selected: _statusFilter == DownloadTaskStatus.downloading,
              onSelected: (selected) {
                setState(
                  () => _statusFilter = selected
                      ? DownloadTaskStatus.downloading
                      : null,
                );
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.filterPaused),
              selected: _statusFilter == DownloadTaskStatus.paused,
              onSelected: (selected) {
                setState(
                  () => _statusFilter = selected
                      ? DownloadTaskStatus.paused
                      : null,
                );
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.filterCompleted),
              selected: _statusFilter == DownloadTaskStatus.completed,
              onSelected: (selected) {
                setState(
                  () => _statusFilter = selected
                      ? DownloadTaskStatus.completed
                      : null,
                );
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.filterError),
              selected: _statusFilter == DownloadTaskStatus.error,
              onSelected: (selected) {
                setState(
                  () => _statusFilter = selected
                      ? DownloadTaskStatus.error
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeGroup(
    String? animeName,
    List<DownloadTask> tasks,
    AppLocalizations l10n,
  ) {
    final displayName = animeName ?? l10n.others;
    final groupStatus = _resolveGroupStatus(tasks);
    final groupColor = _getStatusColor(groupStatus);
    final groupIcon = _getStatusIcon(groupStatus);

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    final groupKey = animeName ?? '__others__';
    final isCollapsed = _collapsedGroups.contains(groupKey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: groupColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: groupColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Bag header (tappable to collapse/expand) ─────────────
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: isCollapsed ? const Radius.circular(14) : Radius.zero,
              bottomRight: isCollapsed
                  ? const Radius.circular(14)
                  : Radius.zero,
            ),
            child: InkWell(
              onTap: () => setState(() {
                if (isCollapsed) {
                  _collapsedGroups.remove(groupKey);
                } else {
                  _collapsedGroups.add(groupKey);
                }
              }),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      groupColor.withValues(alpha: 0.22),
                      groupColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: groupColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(groupIcon, color: groupColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            l10n.tasksCount(tasks.length),
                            style: TextStyle(
                              color: groupColor.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        color: groupColor.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Divider + cards (hidden when collapsed) ──────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: isCollapsed
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: groupColor.withValues(alpha: 0.2),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 3,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: groupColor.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: tasks
                                      .map(
                                        (task) => _buildDownloadItem(
                                          task,
                                          groupColor,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  DownloadTaskStatus _resolveGroupStatus(List<DownloadTask> tasks) {
    if (tasks.isEmpty) return DownloadTaskStatus.pending;

    DownloadTaskStatus best = _normalizeGroupStatus(tasks.first.status);
    int bestPriority = _groupStatusPriority(best);

    for (int index = 1; index < tasks.length; index++) {
      final candidate = _normalizeGroupStatus(tasks[index].status);
      final candidatePriority = _groupStatusPriority(candidate);
      if (candidatePriority > bestPriority) {
        best = candidate;
        bestPriority = candidatePriority;
      }
    }

    return best;
  }

  DownloadTaskStatus _normalizeGroupStatus(DownloadTaskStatus status) {
    if (status == DownloadTaskStatus.seeding) {
      return DownloadTaskStatus.completed;
    }
    if (status == DownloadTaskStatus.pending ||
        status == DownloadTaskStatus.queued) {
      return DownloadTaskStatus.downloading;
    }
    return status;
  }

  int _groupStatusPriority(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.error:
        return 6;
      case DownloadTaskStatus.paused:
        return 5;
      case DownloadTaskStatus.metadata:
        return 4;
      case DownloadTaskStatus.checking:
        return 3;
      case DownloadTaskStatus.queued:
        return 3;
      case DownloadTaskStatus.downloading:
        return 2;
      case DownloadTaskStatus.completed:
        return 1;
      case DownloadTaskStatus.pending:
      case DownloadTaskStatus.seeding:
        return 0;
    }
  }

  Widget _buildDownloadItem(DownloadTask task, [Color? accentColor]) {
    final statusColor = _getStatusColor(task.status);
    final statusIcon = _getStatusIcon(task.status);
    final isHttp = task.taskType == DownloadTaskType.http;
    final canPlay = isHttp
        ? task.status == DownloadTaskStatus.completed
        : task.status == DownloadTaskStatus.downloading ||
              task.status == DownloadTaskStatus.seeding ||
              task.status == DownloadTaskStatus.completed ||
              task.status == DownloadTaskStatus.paused && task.progress > 5;

    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shadowColor: statusColor.withValues(alpha: 0.15),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withValues(alpha: 0.18), width: 1),
      ),
      child: InkWell(
        onTap: canPlay ? () => _playTask(task) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Status label tag
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusLabel(task.status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Action buttons
                  _buildTaskActions(task),
                ],
              ),

              // Anime name (only shown when not grouped or has episode info)
              if (task.animeName != null && task.episodeNumber != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第${task.episodeNumber}集',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ),
                    if (canPlay)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 2),
                            Text(
                              AppLocalizations.of(context).clickToPlay,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ] else if (canPlay) ...[
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 2),
                        Text(
                          AppLocalizations.of(context).clickToPlay,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress / 100.0,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 5,
                ),
              ),

              const SizedBox(height: 7),

              // Stats row
              Row(
                children: [
                  // Progress percentage
                  Text(
                    '${task.progress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Download speed (for downloading / metadata / checking)
                  if (task.status == DownloadTaskStatus.downloading ||
                      task.status == DownloadTaskStatus.metadata ||
                      task.status == DownloadTaskStatus.checking) ...[
                    const Icon(Icons.download, size: 11, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(
                      task.formattedSpeed,
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Upload speed (for seeding, BT only)
                  if (task.status == DownloadTaskStatus.seeding &&
                      task.taskType != DownloadTaskType.http) ...[
                    const Icon(Icons.upload, size: 11, color: Colors.green),
                    const SizedBox(width: 3),
                    Text(
                      task.formattedUploadSpeed,
                      style: const TextStyle(color: Colors.green, fontSize: 10),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Downloaded / Total size
                  Text(
                    '${task.formattedDownloaded} / ${task.formattedSize}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),

                  const Spacer(),

                  // Peers count (BT only)
                  if (task.peers > 0 &&
                      task.taskType != DownloadTaskType.http) ...[
                    const Icon(
                      Icons.people_outline,
                      size: 11,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      AppLocalizations.of(context).peers(task.peers),
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                ],
              ),

              // Error message
              if (task.errorMessage != null) ...[
                const SizedBox(height: 6),
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
      ),
    );
  }

  Widget _buildTaskActions(DownloadTask task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pause/Resume button
        if (task.status == DownloadTaskStatus.downloading ||
            task.status == DownloadTaskStatus.metadata ||
            task.status == DownloadTaskStatus.checking ||
            task.status == DownloadTaskStatus.queued)
          IconButton(
            icon: const Icon(Icons.pause, size: 20, color: Colors.orange),
            tooltip: AppLocalizations.of(context).pause,
            onPressed: () async {
              final success = await _downloadManager.pauseTask(task.id);
              if (mounted && !success) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).pauseFailed),
                  ),
                );
              }
            },
          )
        else if (task.status == DownloadTaskStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20, color: Colors.green),
            tooltip: AppLocalizations.of(context).resume,
            onPressed: () async {
              final success = await _downloadManager.resumeTask(task.id);
              if (mounted && !success) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).resumeFailed),
                  ),
                );
              }
            },
          )
        else if (task.taskType == DownloadTaskType.http &&
            task.status == DownloadTaskStatus.completed)
          // Play button for completed HTTP tasks
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20, color: Colors.green),
            tooltip: AppLocalizations.of(context).playButton,
            onPressed: () => _playTask(task),
          ),

        // Delete button
        IconButton(
          icon: const Icon(Icons.close, size: 20, color: Colors.grey),
          tooltip: AppLocalizations.of(context).deleteTask,
          onPressed: () => _showDeleteDialog(task),
        ),
      ],
    );
  }

  Future<void> _playTask(DownloadTask task) async {
    final streamUrl = await _downloadManager.getOrCreateStreamUrl(task.id);
    if (streamUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).cannotGetPlaybackUrl)),
        );
      }
      return;
    }

    // Try to find anime info from playback history
    final historyManager = PlaybackHistoryManager();
    final history = await historyManager.getHistory();

    AnimeInfo? anime;
    List<BangumiEpisode> allEpisodes = [];
    BangumiEpisode? currentEpisode;

    // Search for matching history item by anime name
    if (task.animeName != null) {
      for (final item in history) {
        if (item.title == task.animeName) {
          // Found matching anime in history, restore full info
          anime = AnimeInfo(
            title: item.title,
            subTitle: item.subTitle,
            bangumiId: item.bangumiId,
            mikanId: item.mikanId,
            coverUrl: item.coverUrl,
            siteUrl: item.siteUrl,
            broadcastDay: item.broadcastDay,
            broadcastTime: item.broadcastTime,
            score: item.score,
            rank: item.rank,
            tags: item.tags,
            fullJson: item.fullJson,
          );

          // Restore episodes from history
          allEpisodes = item.toEpisodes().releasedEpisodes();

          // Find the matching episode
          final epNumber = task.episodeNumber ?? 1;
          for (final ep in allEpisodes) {
            if (ep.sort.toInt() == epNumber) {
              currentEpisode = ep;
              break;
            }
          }
          break;
        }
      }
    }

    // Fallback: create minimal anime/episode info if not found in history
    anime ??= AnimeInfo(
      title: task.animeName ?? task.name,
      subTitle: null,
      bangumiId: null,
      mikanId: null,
      coverUrl: null,
      siteUrl: null,
      broadcastDay: null,
      broadcastTime: null,
      score: null,
      rank: null,
      tags: const [],
      fullJson: null,
    );

    currentEpisode ??= BangumiEpisode(
      id: 0,
      sort: (task.episodeNumber ?? 1).toDouble(),
      name: task.animeName ?? task.name, // Use anime name as episode name
      nameCn: task.animeName != null
          ? '\u7b2c${task.episodeNumber ?? 1}\u96c6'
          : '',
      duration: '',
      airdate: '',
      description: '',
    );

    if (allEpisodes.isEmpty) {
      allEpisodes = [currentEpisode];
    } else if (!currentEpisode.isReleased()) {
      currentEpisode = allEpisodes.latestReleasedEpisode();
    }

    if (currentEpisode == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).cannotLoadEpisodes)));
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          anime: anime!,
          currentEpisode: currentEpisode!,
          allEpisodes: allEpisodes,
          btStreamUrl: streamUrl,
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(DownloadTask task) async {
    final forceDeleteFiles = _forceDeleteFilesOnAndroid;
    bool deleteFiles = forceDeleteFiles;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).confirm),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.status == DownloadTaskStatus.downloading ||
                        task.status == DownloadTaskStatus.seeding ||
                        task.status == DownloadTaskStatus.metadata ||
                        task.status == DownloadTaskStatus.checking ||
                        task.status == DownloadTaskStatus.queued
                    ? '此任务正在运行中，确定要停止并删除吗？'
                    : AppLocalizations.of(
                        context,
                      ).logoutConfirm, // Using loginConfirm as a generic "are you sure"
              ),
              if (forceDeleteFiles) ...[
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).deleteFiles,
                  style: const TextStyle(fontSize: 14),
                ),
              ] else ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text(
                    AppLocalizations.of(context).deleteFiles,
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: deleteFiles,
                  onChanged: (val) =>
                      setDialogState(() => deleteFiles = val ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                AppLocalizations.of(context).confirm,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _downloadManager.removeTask(task.id, deleteFiles: deleteFiles);
    }
  }

  Color _getStatusColor(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.pending:
        return Colors.orange;
      case DownloadTaskStatus.metadata:
        return Colors.deepPurple;
      case DownloadTaskStatus.checking:
        return Colors.teal;
      case DownloadTaskStatus.queued:
        return Colors.amber;
      case DownloadTaskStatus.downloading:
        return Colors.blue;
      case DownloadTaskStatus.seeding:
        return const Color(0xFF26A69A); // teal-ish green
      case DownloadTaskStatus.paused:
        return Colors.grey;
      case DownloadTaskStatus.completed:
        return Colors.green;
      case DownloadTaskStatus.error:
        return Colors.red;
    }
  }

  String _getStatusLabel(DownloadTaskStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case DownloadTaskStatus.pending:
        return l10n.statusPending;
      case DownloadTaskStatus.metadata:
        return l10n.statusMetadata;
      case DownloadTaskStatus.checking:
        return l10n.statusChecking;
      case DownloadTaskStatus.queued:
        return l10n.statusQueued;
      case DownloadTaskStatus.downloading:
        return l10n.downloading;
      case DownloadTaskStatus.seeding:
        return l10n.seeding;
      case DownloadTaskStatus.paused:
        return l10n.paused;
      case DownloadTaskStatus.completed:
        return l10n.statusCompleted;
      case DownloadTaskStatus.error:
        return l10n.filterError;
    }
  }

  IconData _getStatusIcon(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.pending:
        return Icons.hourglass_empty;
      case DownloadTaskStatus.metadata:
        return Icons.cloud_download;
      case DownloadTaskStatus.checking:
        return Icons.verified_user;
      case DownloadTaskStatus.queued:
        return Icons.schedule;
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
