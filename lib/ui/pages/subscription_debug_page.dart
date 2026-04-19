import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart'
    as generic_scraper;
import 'package:mikan_player/utils/feature_flags.dart';

class SubscriptionDebugPage extends StatefulWidget {
  const SubscriptionDebugPage({super.key});

  @override
  State<SubscriptionDebugPage> createState() => _SubscriptionDebugPageState();
}

class _SubscriptionDebugPageState extends State<SubscriptionDebugPage> {
  final _jsonPathController = TextEditingController();
  final _animeNameController = TextEditingController();
  final _absoluteEpisodeController = TextEditingController();
  final _relativeEpisodeController = TextEditingController();
  final _sourceFilterController = TextEditingController();

  StreamSubscription<generic_scraper.SourceSearchProgress>? _searchSubscription;

  final Map<String, generic_scraper.SourceSearchProgress> _progressBySource =
      {};
  final List<String> _searchLogs = [];
  final List<String> _extractLogs = [];

  bool _isSearching = false;
  bool _showWebView = false;
  String? _searchError;

  int _extractSession = 0;
  String? _extractingSourceName;
  generic_scraper.SearchPlayResult? _extractTarget;
  String? _extractedVideoUrl;
  String? _extractError;
  Map<String, String> _extractHeaders = const {};

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _jsonPathController.dispose();
    _animeNameController.dispose();
    _absoluteEpisodeController.dispose();
    _relativeEpisodeController.dispose();
    _sourceFilterController.dispose();
    super.dispose();
  }

  int? _parseEpisodeOrNull(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text);
  }

  void _appendLog(List<String> logs, String message, {int maxLines = 200}) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    logs.add('[$timestamp] $message');
    if (logs.length > maxLines) {
      logs.removeRange(0, logs.length - maxLines);
    }
  }

  String _stepLabel(generic_scraper.SearchStep step) {
    switch (step) {
      case generic_scraper.SearchStep.pending:
        return '等待中';
      case generic_scraper.SearchStep.searching:
        return '搜索中';
      case generic_scraper.SearchStep.fetchingDetail:
        return '获取详情页';
      case generic_scraper.SearchStep.fetchingEpisodes:
        return '获取剧集';
      case generic_scraper.SearchStep.extractingVideo:
        return '提取播放页';
      case generic_scraper.SearchStep.success:
        return '成功';
      case generic_scraper.SearchStep.failed:
        return '失败';
    }
  }

  Color _stepColor(BuildContext context, generic_scraper.SearchStep step) {
    switch (step) {
      case generic_scraper.SearchStep.success:
        return Colors.green;
      case generic_scraper.SearchStep.failed:
        return Colors.redAccent;
      case generic_scraper.SearchStep.searching:
      case generic_scraper.SearchStep.fetchingDetail:
      case generic_scraper.SearchStep.fetchingEpisodes:
      case generic_scraper.SearchStep.extractingVideo:
        return Theme.of(context).colorScheme.primary;
      case generic_scraper.SearchStep.pending:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _stepIcon(generic_scraper.SearchStep step) {
    switch (step) {
      case generic_scraper.SearchStep.success:
        return Icons.check_circle;
      case generic_scraper.SearchStep.failed:
        return Icons.error;
      case generic_scraper.SearchStep.searching:
      case generic_scraper.SearchStep.fetchingDetail:
      case generic_scraper.SearchStep.fetchingEpisodes:
      case generic_scraper.SearchStep.extractingVideo:
        return Icons.autorenew;
      case generic_scraper.SearchStep.pending:
        return Icons.hourglass_empty;
    }
  }

  Future<void> _startDebugSearch() async {
    final jsonPath = _jsonPathController.text.trim();
    final animeName = _animeNameController.text.trim();

    if (jsonPath.isEmpty || animeName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写本地 JSON 路径和动漫名称')));
      return;
    }

    final absoluteEpisode = _parseEpisodeOrNull(
      _absoluteEpisodeController.text,
    );
    if (_absoluteEpisodeController.text.trim().isNotEmpty &&
        absoluteEpisode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('绝对集数必须是整数')));
      return;
    }

    final relativeEpisode = _parseEpisodeOrNull(
      _relativeEpisodeController.text,
    );
    if (_relativeEpisodeController.text.trim().isNotEmpty &&
        relativeEpisode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('相对集数必须是整数')));
      return;
    }

    if ((absoluteEpisode ?? 1) <= 0 || (relativeEpisode ?? 1) <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('集数必须大于 0')));
      return;
    }

    final file = File(jsonPath);
    if (!await file.exists()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('文件不存在: $jsonPath')));
      return;
    }

    await _searchSubscription?.cancel();

    final sourceFilter = _sourceFilterController.text.trim();

    setState(() {
      _isSearching = true;
      _searchError = null;
      _progressBySource.clear();
      _searchLogs.clear();
      _extractLogs.clear();
      _extractingSourceName = null;
      _extractTarget = null;
      _extractedVideoUrl = null;
      _extractError = null;
      _extractHeaders = const {};
      _appendLog(
        _searchLogs,
        '开始调试搜索: anime=$animeName, abs=${absoluteEpisode ?? '-'}, rel=${relativeEpisode ?? '-'}, filter=${sourceFilter.isEmpty ? '-' : sourceFilter}',
      );
    });

    _searchSubscription = generic_scraper
        .debugSearchWithLocalJson(
          jsonPath: jsonPath,
          animeName: animeName,
          absoluteEpisode: absoluteEpisode,
          relativeEpisode: relativeEpisode,
          sourceNameFilter: sourceFilter.isEmpty ? null : sourceFilter,
        )
        .listen(
          (progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _progressBySource[progress.sourceName] = progress;
              _appendLog(
                _searchLogs,
                '${progress.sourceName} -> ${_stepLabel(progress.step)}${progress.error != null ? ' | ${progress.error}' : ''}',
              );
            });
          },
          onError: (error, _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isSearching = false;
              _searchError = error.toString();
              _appendLog(_searchLogs, '搜索异常: $error');
            });
          },
          onDone: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _isSearching = false;
              _appendLog(_searchLogs, '搜索结束');
            });
          },
        );
  }

  void _startExtractVideoUrl(generic_scraper.SourceSearchProgress progress) {
    final playPageUrl = progress.playPageUrl;
    if (playPageUrl == null || playPageUrl.isEmpty) {
      return;
    }

    final target = generic_scraper.SearchPlayResult(
      sourceName: progress.sourceName,
      playPageUrl: playPageUrl,
      videoRegex: progress.videoRegex ?? r'$^',
      directVideoUrl: progress.directVideoUrl,
      cookies: progress.cookies,
      headers: progress.headers,
      channelName: progress.channelName,
      channelIndex: progress.channelIndex,
    );

    setState(() {
      _extractSession += 1;
      _extractingSourceName = progress.sourceName;
      _extractTarget = target;
      _extractError = null;
      _extractedVideoUrl = null;
      _extractHeaders = const {};
      _extractLogs.clear();
      _appendLog(_extractLogs, '开始提取: ${progress.sourceName}');
    });
  }

  void _clearResult() {
    _searchSubscription?.cancel();
    setState(() {
      _isSearching = false;
      _searchError = null;
      _progressBySource.clear();
      _searchLogs.clear();
      _extractLogs.clear();
      _extractingSourceName = null;
      _extractTarget = null;
      _extractedVideoUrl = null;
      _extractError = null;
      _extractHeaders = const {};
    });
  }

  Widget _buildInputForm(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _jsonPathController,
              decoration: const InputDecoration(
                labelText: '本地 JSON 路径',
                hintText: r'D:\temp\online.json',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _animeNameController,
              decoration: const InputDecoration(
                labelText: '动漫名称',
                hintText: '例如：机动战士高达GQuuuuuuX',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _absoluteEpisodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '绝对集数',
                      hintText: '可留空',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _relativeEpisodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '相对集数',
                      hintText: '可留空',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceFilterController,
              decoration: const InputDecoration(
                labelText: '源名过滤（可选）',
                hintText: '大小写不敏感，包含匹配',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _showWebView,
              contentPadding: EdgeInsets.zero,
              title: const Text('显示 WebView 调试开关'),
              subtitle: const Text('仅影响调试提取画面显示，不影响搜索逻辑'),
              onChanged: (value) {
                setState(() {
                  _showWebView = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSearching ? null : _startDebugSearch,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_isSearching ? '搜索中...' : '开始调试搜索'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clearResult,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('清空'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final progresses = _progressBySource.values.toList();
    final successCount = progresses
        .where((p) => p.step == generic_scraper.SearchStep.success)
        .length;
    final failedCount = progresses
        .where((p) => p.step == generic_scraper.SearchStep.failed)
        .length;
    final runningCount = progresses
        .where(
          (p) =>
              p.step != generic_scraper.SearchStep.success &&
              p.step != generic_scraper.SearchStep.failed,
        )
        .length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSummaryChip(context, '源数量', '${progresses.length}'),
        _buildSummaryChip(context, '成功', '$successCount', color: Colors.green),
        _buildSummaryChip(
          context,
          '失败',
          '$failedCount',
          color: Colors.redAccent,
        ),
        _buildSummaryChip(
          context,
          '进行中',
          '$runningCount',
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildSummaryChip(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    final chipColor = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: chipColor.withValues(alpha: 0.15),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Text('$label: $value', style: TextStyle(color: chipColor)),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final results = _progressBySource.values.toList()
      ..sort(
        (a, b) =>
            a.sourceName.toLowerCase().compareTo(b.sourceName.toLowerCase()),
      );

    if (results.isEmpty) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无结果。输入参数后点击“开始调试搜索”。'),
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final result = results[index];
          final canExtract =
              result.step == generic_scraper.SearchStep.success &&
              result.playPageUrl != null &&
              result.playPageUrl!.isNotEmpty;
          final stepColor = _stepColor(context, result.step);

          return ListTile(
            leading: Icon(_stepIcon(result.step), color: stepColor),
            title: Text(
              result.sourceName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '状态: ${_stepLabel(result.step)}',
                  style: TextStyle(color: stepColor),
                ),
                if (result.channelName != null &&
                    result.channelName!.isNotEmpty)
                  Text('线路: ${result.channelName}'),
                if (result.playPageUrl != null &&
                    result.playPageUrl!.isNotEmpty)
                  Text(
                    '播放页: ${result.playPageUrl}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (result.error != null && result.error!.isNotEmpty)
                  Text(
                    result.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: canExtract
                ? FilledButton.tonal(
                    onPressed: _extractingSourceName == null
                        ? () => _startExtractVideoUrl(result)
                        : null,
                    child: const Text('提取URL'),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildExtractorPanel() {
    if (_extractTarget == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '可播放 URL 提取调试',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('来源: ${_extractTarget!.sourceName}'),
            Text(
              '播放页: ${_extractTarget!.playPageUrl}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (_extractingSourceName != null)
              const LinearProgressIndicator(minHeight: 3),
            if (_extractError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '提取失败: $_extractError',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_extractedVideoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  '提取成功: $_extractedVideoUrl',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            if (_extractHeaders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Headers: ${_extractHeaders.keys.join(', ')}'),
              ),
            const SizedBox(height: 8),
            if (_extractingSourceName != null)
              SizedBox(
                width: _showWebView ? double.infinity : 1,
                height: _showWebView ? 300 : 1,
                child: WebViewVideoExtractorWidget(
                  key: ValueKey('subscription_debug_extract_$_extractSession'),
                  url: _extractTarget!.playPageUrl,
                  customVideoRegex: _extractTarget!.videoRegex != r'$^'
                      ? _extractTarget!.videoRegex
                      : null,
                  timeout: const Duration(seconds: 25),
                  showWebView: _showWebView,
                  onLog: (message) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _appendLog(_extractLogs, message, maxLines: 120);
                    });
                  },
                  onResult: (result) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _extractingSourceName = null;
                      _extractHeaders = result.headers;
                      if (result.success) {
                        _extractedVideoUrl = result.videoUrl;
                        _extractError = null;
                        _appendLog(
                          _extractLogs,
                          '提取成功: ${result.videoUrl}',
                          maxLines: 120,
                        );
                      } else {
                        _extractedVideoUrl = null;
                        _extractError = result.error ?? '提取失败';
                        _appendLog(
                          _extractLogs,
                          '提取失败: ${result.error}',
                          maxLines: 120,
                        );
                      }
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsPanel(
    BuildContext context,
    String title,
    List<String> logs,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: SelectableText(logs.isEmpty ? '暂无日志' : logs.join('\n')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enableSubscriptionDebug) {
      return Scaffold(
        appBar: AppBar(title: const Text('订阅源调试')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '当前构建未启用订阅调试。\n请使用 --dart-define=ENABLE_SUBSCRIPTION_DEBUG=true 启动。',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('订阅源 JSON 调试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('此页面仅用于调试：只读取本地 JSON，不会修改缓存文件、不会覆盖订阅设置、不会影响正式播放流程。'),
            ),
          ),
          const SizedBox(height: 12),
          _buildInputForm(context),
          const SizedBox(height: 12),
          _buildSummary(context),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            Text(
              '搜索错误: $_searchError',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 12),
          _buildSearchResults(context),
          const SizedBox(height: 12),
          _buildExtractorPanel(),
          const SizedBox(height: 12),
          _buildLogsPanel(context, '搜索日志', _searchLogs),
          const SizedBox(height: 12),
          _buildLogsPanel(context, '提取日志', _extractLogs),
        ],
      ),
    );
  }
}
