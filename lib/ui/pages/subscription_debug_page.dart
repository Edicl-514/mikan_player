import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/src/rust/api/config.dart' as rust_config;
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
    final l10n = AppLocalizations.of(context);
    switch (step) {
      case generic_scraper.SearchStep.pending:
        return l10n.stepPending;
      case generic_scraper.SearchStep.searching:
        return l10n.stepSearching;
      case generic_scraper.SearchStep.fetchingDetail:
        return l10n.stepFetchingDetail;
      case generic_scraper.SearchStep.fetchingEpisodes:
        return l10n.stepFetchingEpisodes;
      case generic_scraper.SearchStep.extractingVideo:
        return l10n.stepExtractingVideo;
      case generic_scraper.SearchStep.success:
        return l10n.stepSuccess;
      case generic_scraper.SearchStep.failed:
        return l10n.stepFailed;
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

    if (animeName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).pleaseEnterAnimeName)));
      return;
    }

    final absoluteEpisode = _parseEpisodeOrNull(
      _absoluteEpisodeController.text,
    );
    if (_absoluteEpisodeController.text.trim().isNotEmpty &&
        absoluteEpisode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).absoluteEpisodeMustBeInteger)));
      return;
    }

    final relativeEpisode = _parseEpisodeOrNull(
      _relativeEpisodeController.text,
    );
    if (_relativeEpisodeController.text.trim().isNotEmpty &&
        relativeEpisode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).relativeEpisodeMustBeInteger)));
      return;
    }

    if ((absoluteEpisode ?? 1) <= 0 || (relativeEpisode ?? 1) <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).episodeMustBeGreaterThanZero)));
      return;
    }

    String resolvedJsonPath;
    try {
      resolvedJsonPath = jsonPath.isNotEmpty
          ? jsonPath
          : '${await rust_config.getCacheDir()}${Platform.pathSeparator}playback_sources_cache.json';
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).loadFailed(e.toString()))),
      );
      return;
    }

    final file = File(resolvedJsonPath);
    if (!await file.exists()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            jsonPath.isEmpty
                ? '缓存 JSON 不存在: $resolvedJsonPath'
                : '文件不存在: $resolvedJsonPath',
          ),
        ),
      );
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
        '开始调试搜索: anime=$animeName, abs=${absoluteEpisode ?? '-'}, rel=${relativeEpisode ?? '-'}, filter=${sourceFilter.isEmpty ? '-' : sourceFilter}, json=${jsonPath.isEmpty ? '缓存' : '本地'}',
      );
    });

    final runtimeOverrides = await _prepareCaptchaRuntimeOverrides(
      jsonPath: resolvedJsonPath,
      animeName: animeName,
      sourceFilter: sourceFilter,
    );

    if (!mounted) return;

    _searchSubscription = generic_scraper
        .debugSearchWithLocalJsonRuntime(
          jsonPath: resolvedJsonPath,
          animeName: animeName,
          absoluteEpisode: absoluteEpisode,
          relativeEpisode: relativeEpisode,
          sourceNameFilter: sourceFilter.isEmpty ? null : sourceFilter,
          runtimeOverrides: runtimeOverrides,
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

  Future<generic_scraper.SourceRuntimeOverride> _runCaptchaPreflight({
    required generic_scraper.SourceState source,
    String? searchKeyword,
    String? initialUrl,
    String? referer,
  }) async {
    final captchaConfig = CaptchaConfig.tryParse(source.captchaConfigJson);
    if (captchaConfig == null) {
      return generic_scraper.SourceRuntimeOverride(sourceName: source.name);
    }

    final completer = Completer<generic_scraper.SourceRuntimeOverride>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        if (!completer.isCompleted) {
          completer.complete(
            generic_scraper.SourceRuntimeOverride(
              sourceName: source.name,
              skipSearchError: '页面已关闭，无法完成验证码预处理',
            ),
          );
        }
        return;
      }

      final overlay = Overlay.of(context);
      OverlayEntry? entry;

      entry = OverlayEntry(
        builder: (context) => CaptchaWebViewBypassWidget(
          key: ValueKey('captcha_debug_${source.name}_$searchKeyword'),
          source: source,
          searchKeyword: searchKeyword,
          initialUrl: initialUrl,
          referer: referer,
          captchaConfig: captchaConfig,
          timeout: const Duration(seconds: 45),
          showWebView: _showWebView,
          onResult: (result) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final currentEntry = entry;
              if (currentEntry != null) {
                currentEntry.remove();
              }
              entry = null;
            });
            if (completer.isCompleted) return;

            if (result.success) {
              completer.complete(
                generic_scraper.SourceRuntimeOverride(
                  sourceName: source.name,
                  cookies: result.cookies,
                  searchPageHtml: result.searchPageHtml,
                  searchPageUrl: result.searchPageUrl,
                  detailPageHtml: result.detailPageHtml,
                  detailPageUrl: result.detailPageUrl,
                ),
              );
            } else {
              completer.complete(
                generic_scraper.SourceRuntimeOverride(
                  sourceName: source.name,
                  skipSearchError: result.error ?? 'Captcha preflight failed',
                ),
              );
            }
          },
          onLog: (message) {
            _appendLog(
              _searchLogs,
              '[captcha][${source.name}] $message',
              maxLines: 120,
            );
          },
        ),
      );

      overlay.insert(entry!);
    });

    return completer.future;
  }

  Future<List<generic_scraper.SourceRuntimeOverride>>
  _prepareCaptchaRuntimeOverrides({
    required String jsonPath,
    required String animeName,
    required String sourceFilter,
  }) async {
    final overrides = <generic_scraper.SourceRuntimeOverride>[];

    try {
      final jsonContent = await File(jsonPath).readAsString();
      final root = jsonDecode(jsonContent) as Map<String, dynamic>;
      final mediaSources =
          (root['exportedMediaSourceDataList']
                  as Map<String, dynamic>?)?['mediaSources']
              as List<dynamic>?;

      if (mediaSources == null) {
        return overrides;
      }

      final captchaSources = <generic_scraper.SourceState>[];
      for (final source in mediaSources) {
        final args = source['arguments'] as Map<String, dynamic>?;
        final name = args?['name'] as String? ?? '';
        final captchaConfigRaw =
            args?['captchaConfig'] as Map<String, dynamic>?;

        if (sourceFilter.isNotEmpty &&
            !name.toLowerCase().contains(sourceFilter.toLowerCase())) {
          continue;
        }

        final captchaConfig = CaptchaConfig.tryParse(
          captchaConfigRaw != null ? jsonEncode(captchaConfigRaw) : null,
        );
        if (captchaConfig == null) {
          continue;
        }

        final searchConfig =
            args?['searchConfig'] as Map<String, dynamic>? ?? const {};
        captchaSources.add(
          generic_scraper.SourceState(
            name: name,
            description: args?['description'] as String? ?? '',
            iconUrl: args?['iconUrl'] as String? ?? '',
            tier: args?['tier'] as int? ?? 1,
            defaultSubtitleLanguage:
                searchConfig['defaultSubtitleLanguage'] as String? ?? '',
            defaultResolution:
                searchConfig['defaultResolution'] as String? ?? '',
            searchUrl: searchConfig['searchUrl'] as String? ?? '',
            searchConfigJson: jsonEncode(searchConfig),
            captchaConfigJson: jsonEncode(captchaConfigRaw),
            enabled: true,
          ),
        );
      }

      captchaSources.sort((a, b) => a.tier.compareTo(b.tier));

      for (var i = 0; i < captchaSources.length; i++) {
        final source = captchaSources[i];
        if (!mounted) break;

        setState(() {
          _progressBySource[source.name] = generic_scraper.SourceSearchProgress(
            sourceName: source.name,
            step: generic_scraper.SearchStep.searching,
            error: null,
            playPageUrl: null,
            videoRegex: null,
            directVideoUrl: null,
            cookies: null,
            headers: null,
            captchaConfigJson: source.captchaConfigJson,
          );
          _appendLog(
            _searchLogs,
            '${source.name} -> 正在进行验证码预处理 (${i + 1}/${captchaSources.length})',
          );
        });

        final runtimeOverride = await _runCaptchaPreflight(
          source: source,
          searchKeyword: animeName,
        );
        overrides.add(runtimeOverride);

        if (!mounted) break;

        setState(() {
          _progressBySource[source.name] = generic_scraper.SourceSearchProgress(
            sourceName: source.name,
            step: runtimeOverride.skipSearchError == null
                ? generic_scraper.SearchStep.pending
                : generic_scraper.SearchStep.failed,
            error: runtimeOverride.skipSearchError,
            playPageUrl: null,
            videoRegex: null,
            directVideoUrl: null,
            cookies: runtimeOverride.cookies,
            headers: null,
            captchaConfigJson: source.captchaConfigJson,
          );
        });
      }
    } catch (e) {
      _appendLog(_searchLogs, '解析captcha源失败: $e');
    }

    return overrides;
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
    final l10n = AppLocalizations.of(context);
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
              decoration: InputDecoration(
                labelText: l10n.localJsonPathLabel,
                hintText: r'D:\temp\online.json，或留空',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _animeNameController,
              decoration: InputDecoration(
                labelText: l10n.animeNameLabel,
                hintText: l10n.animeNameHint,
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
                    decoration: InputDecoration(
                      labelText: l10n.absoluteEpisodeLabel,
                      hintText: l10n.optionalEmptyHint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _relativeEpisodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.relativeEpisodeLabel,
                      hintText: l10n.optionalEmptyHint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceFilterController,
              decoration: InputDecoration(
                labelText: l10n.sourceFilterLabel,
                hintText: l10n.sourceFilterHint,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _showWebView,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showWebViewDebugSwitch),
              subtitle: Text(l10n.showWebViewDebugSubtitle),
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
                    label: Text(_isSearching ? l10n.stepSearching : '开始调试搜索'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clearResult,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(l10n.clear),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        _buildSummaryChip(context, l10n.sourceCount, '${progresses.length}'),
        _buildSummaryChip(context, l10n.success, '$successCount', color: Colors.green),
        _buildSummaryChip(
          context,
          l10n.failure,
          '$failedCount',
          color: Colors.redAccent,
        ),
        _buildSummaryChip(
          context,
          l10n.inProgress,
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
      final l10n = AppLocalizations.of(context);
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.noDebugSearchResult),
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
                  AppLocalizations.of(context).debugStatus(_stepLabel(result.step)),
                  style: TextStyle(color: stepColor),
                ),
                if (result.channelName != null &&
                    result.channelName!.isNotEmpty)
                  Text(AppLocalizations.of(context).channelLine(result.channelName!)),
                if (result.playPageUrl != null &&
                    result.playPageUrl!.isNotEmpty)
                  Text(
                    AppLocalizations.of(context).playPage(result.playPageUrl!),
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
                    child: Text(AppLocalizations.of(context).extractUrl),
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
            Text(
              AppLocalizations.of(context).extractDebugTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('来源: ${_extractTarget!.sourceName}'),
            Text(
              AppLocalizations.of(context).playPage(_extractTarget!.playPageUrl),
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
                  AppLocalizations.of(context).extractFailed(_extractError ?? ''),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_extractedVideoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  AppLocalizations.of(context).extractSuccess(_extractedVideoUrl ?? ''),
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
              WebViewVideoExtractorWidget(
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
            child: SelectableText(
              logs.isEmpty ? AppLocalizations.of(context).logsEmpty : logs.join('\n'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enableSubscriptionDebug) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(l10n.subscriptionDebugTitle)),
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

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionDebugJsonTitle)),
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
              child: Text(
                '此页面仅用于调试：优先读取本地 JSON，留空时读取程序缓存中的 JSON，不会修改缓存文件、不会覆盖订阅设置、不会影响正式播放流程。',
              ),
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
              AppLocalizations.of(context).searchError(_searchError ?? ''),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 12),
          _buildSearchResults(context),
          const SizedBox(height: 12),
          _buildExtractorPanel(),
          const SizedBox(height: 12),
          _buildLogsPanel(context, l10n.searchLogs, _searchLogs),
          const SizedBox(height: 12),
          _buildLogsPanel(context, l10n.extractLogs, _extractLogs),
        ],
      ),
    );
  }
}
