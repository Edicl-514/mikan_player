import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/services/bangumi_reverse_proxy_service.dart';
import 'package:mikan_player/services/bangumi_ech_service.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;
import 'package:mikan_player/src/rust/api/generic_scraper.dart'
    as generic_scraper;
import 'data_source_config_page.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

class DataSourceSettingsPage extends StatefulWidget {
  const DataSourceSettingsPage({super.key});

  @override
  State<DataSourceSettingsPage> createState() => _DataSourceSettingsPageState();
}

class _DataSourceSettingsPageState extends State<DataSourceSettingsPage> {
  final _bgmController = TextEditingController();
  final _bangumiController = TextEditingController();
  final _mikanController = TextEditingController();
  final _playbackSubController = TextEditingController();
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<generic_scraper.SourceState> _sources = [];
  Set<String> _disabledSources = {};
  bool _isAutoSettingBangumi = false;
  bool _isAutoSettingMikan = false;
  BangumiRequestMode _bangumiRequestMode = BangumiRequestMode.hybrid;
  bool _bangumiUseReverseProxy = false;
  bool _bangumiUseEch = true;
  bool _isRefreshingEch = false;
  String? _echRefreshResult;
  List<String> _dohEndpoints = const <String>[];
  bool _isDohBusy = false;
  final _dohAddController = TextEditingController();

  bool? _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  Map<String, bool> _parseDefaultEnabledOverrides(String content) {
    try {
      final root = jsonDecode(content);
      if (root is! Map) return {};

      final exported = root['exportedMediaSourceDataList'];
      if (exported is! Map) return {};

      final mediaSources = exported['mediaSources'];
      if (mediaSources is! List) return {};

      final overrides = <String, bool>{};
      for (final item in mediaSources) {
        if (item is! Map) continue;
        final arguments = item['arguments'];
        if (arguments is! Map) continue;
        if (!arguments.containsKey('defaultEnabled')) continue;

        final name = arguments['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;

        final parsed = _parseBool(arguments['defaultEnabled']);
        if (parsed == null) continue;
        overrides[name] = parsed;
      }
      return overrides;
    } catch (_) {
      return {};
    }
  }

  List<generic_scraper.SourceState> _buildSortedSources() {
    final sorted = List<generic_scraper.SourceState>.from(_sources);
    sorted.sort((a, b) {
      final aEnabled = !_disabledSources.contains(a.name);
      final bEnabled = !_disabledSources.contains(b.name);
      if (aEnabled != bEnabled) {
        return aEnabled ? -1 : 1;
      }

      final tierCompare = a.tier.compareTo(b.tier);
      if (tierCompare != 0) {
        return tierCompare;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _bgmController.dispose();
    _bangumiController.dispose();
    _mikanController.dispose();
    _playbackSubController.dispose();
    _dohAddController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 从本地缓存读取播放源列表
    List<generic_scraper.SourceState> sources = [];
    try {
      sources = await rust.getPlaybackSources();
    } catch (e) {
      debugPrint('Failed to load playback sources from cache: $e');
    }

    List<String> dohList = const <String>[];
    try {
      dohList = await BangumiEchService.getDohEndpoints();
    } catch (e) {
      debugPrint('Failed to load DoH endpoint list: $e');
    }

    setState(() {
      _bgmController.text =
          prefs.getString('bgmlist_url') ?? 'https://bgmlist.com';

      final bangumiUrl = prefs.getString('bangumi_url');
      if (bangumiUrl == null) {
        _bangumiController.text = 'https://bangumi.tv';
        // 第一次启动，后台自动检测最快源
        _autoSelectBangumiUrl(prefs: prefs, background: true);
      } else {
        _bangumiController.text = bangumiUrl;
      }

      final mikanUrl = prefs.getString('mikan_url');
      if (mikanUrl == null) {
        _mikanController.text = 'https://mikanani.kas.pub';
        _autoSelectMikanUrl(prefs: prefs, background: true);
      } else {
        _mikanController.text = mikanUrl;
      }
      _playbackSubController.text =
          prefs.getString('playback_sub_url') ??
          'https://gitee.com/edicl/online-subscription/raw/master/online.json';
      _bangumiRequestMode = BangumiRequestMode.fromValue(
        prefs.getString(BangumiRequestModeService.preferenceKey),
      );
      _bangumiUseReverseProxy =
          prefs.getBool(BangumiReverseProxyService.preferenceKey) ?? false;
      _bangumiUseEch =
          prefs.getBool(BangumiEchService.preferenceKey) ?? true;
      _dohEndpoints = dohList;

      _sources = sources;
      _disabledSources = sources
          .where((s) => !s.enabled)
          .map((s) => s.name)
          .toSet();

      _isLoading = false;
    });
  }

  Future<void> _refreshEchConfig() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isRefreshingEch = true;
      _echRefreshResult = null;
    });
    try {
      final size = await BangumiEchService.refresh();
      if (mounted) {
        setState(() {
          _echRefreshResult = size > 0
              ? l10n.bangumiEchRefreshSuccess(size)
              : l10n.bangumiEchRefreshFailed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _echRefreshResult = l10n.bangumiEchRefreshFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingEch = false;
        });
      }
    }
  }

  Future<void> _addDohEndpoint() async {
    final raw = _dohAddController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (raw.isEmpty) return;
    if (!raw.toLowerCase().startsWith('https://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bangumiEchDohAddInvalid)),
        );
      }
      return;
    }
    setState(() {
      _isDohBusy = true;
    });
    try {
      final list = await BangumiEchService.addDohEndpoint(raw);
      if (mounted) {
        setState(() {
          _dohEndpoints = list;
          _dohAddController.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDohBusy = false;
        });
      }
    }
  }

  Future<void> _removeDohEndpoint(String endpoint) async {
    setState(() {
      _isDohBusy = true;
    });
    try {
      final list = await BangumiEchService.removeDohEndpoint(endpoint);
      if (mounted) {
        setState(() {
          _dohEndpoints = list;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDohBusy = false;
        });
      }
    }
  }

  Future<void> _moveDohEndpoint(int from, int to) async {
    if (from == to) return;
    setState(() {
      _isDohBusy = true;
    });
    try {
      final list = await BangumiEchService.moveDohEndpoint(from, to);
      if (mounted) {
        setState(() {
          _dohEndpoints = list;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDohBusy = false;
        });
      }
    }
  }

  Future<void> _resetDohEndpoints() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(l10n.bangumiEchDohResetConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.bangumiEchDohReset),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() {
      _isDohBusy = true;
    });
    try {
      final list = await BangumiEchService.resetDohEndpoints();
      if (mounted) {
        setState(() {
          _dohEndpoints = list;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDohBusy = false;
        });
      }
    }
  }

  Future<void> _testDohEndpoint(String endpoint) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isDohBusy = true;
    });
    try {
      final size = await BangumiEchService.testDohEndpoint(endpoint);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              size > 0
                  ? l10n.bangumiEchDohTestSuccess(size)
                  : l10n.bangumiEchDohTestFailed,
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDohBusy = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bgmlist_url', _bgmController.text);
    await prefs.setString('bangumi_url', _bangumiController.text);
    await prefs.setString('mikan_url', _mikanController.text);
    await prefs.setString('playback_sub_url', _playbackSubController.text);
    await prefs.setStringList('disabled_sources', _disabledSources.toList());

    // Sync to Rust
    await rust.setDisabledSources(sources: _disabledSources.toList());
    await rust.updateConfig(
      bgm: _bgmController.text,
      bangumi: _bangumiController.text,
      mikan: _mikanController.text,
      playbackSub: _playbackSubController.text,
      useReverseProxy: _bangumiUseReverseProxy,
    );
    await BangumiRequestModeService.save(_bangumiRequestMode);
    await BangumiReverseProxyService.save(_bangumiUseReverseProxy);
    await BangumiEchService.save(_bangumiUseEch);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
      Navigator.pop(context);
    }
  }

  Future<void> _refreshPlaybackSources() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // 从订阅地址重新拉取JSON并保存到本地
      final content = await generic_scraper.refreshPlaybackSourceConfig();
      final defaultEnabledOverrides = _parseDefaultEnabledOverrides(content);

      if (defaultEnabledOverrides.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final syncedDisabled =
            (prefs.getStringList('disabled_sources') ?? <String>[]).toSet();

        for (final entry in defaultEnabledOverrides.entries) {
          if (entry.value) {
            syncedDisabled.remove(entry.key);
          } else {
            syncedDisabled.add(entry.key);
          }
        }

        final syncedDisabledList = syncedDisabled.toList();
        await prefs.setStringList('disabled_sources', syncedDisabledList);
        await rust.setDisabledSources(sources: syncedDisabledList);
      }

      // 刷新源列表（从本地缓存读取）
      final sources = await rust.getPlaybackSources();
      final disabledSources = sources
          .where((s) => !s.enabled)
          .map((s) => s.name)
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('disabled_sources', disabledSources);

      setState(() {
        _sources = sources;
        _disabledSources = disabledSources.toSet();
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final syncCount = defaultEnabledOverrides.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncCount > 0
                  ? l10n.playbackSourceRefreshedSynced(syncCount)
                  : l10n.playbackSourceRefreshed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.refreshFailed(e.toString()))),
        );
      }
      debugPrint('Failed to refresh playback sources: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _resetDefaults() {
    setState(() {
      _bgmController.text = 'https://bgmlist.com';
      _bangumiController.text = 'https://bangumi.tv';
      _mikanController.text = 'https://mikanani.kas.pub';
      _playbackSubController.text =
          'https://gitee.com/edicl/online-subscription/raw/master/online.json';
    });
  }

  Future<int> _tcpPing(String url) async {
    try {
      final uri = Uri.parse(url);
      final port = uri.port != 0
          ? uri.port
          : (uri.scheme == 'https' ? 443 : 80);
      final stopwatch = Stopwatch()..start();
      if (uri.scheme == 'https') {
        final socket = await SecureSocket.connect(
          uri.host,
          port,
          timeout: const Duration(seconds: 3),
          onBadCertificate: (_) => true,
        );
        stopwatch.stop();
        await socket.close();
      } else {
        final socket = await Socket.connect(
          uri.host,
          port,
          timeout: const Duration(seconds: 2),
        );
        stopwatch.stop();
        await socket.close();
      }
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return 999999;
    }
  }

  Future<void> _autoSelectBangumiUrl({
    SharedPreferences? prefs,
    bool background = false,
  }) async {
    if (!background) {
      setState(() {
        _isAutoSettingBangumi = true;
      });
    }

    final urls = ['https://bangumi.tv', 'https://bgm.tv', 'https://chii.in'];
    int minLatency = 999999;
    String bestUrl = urls[0];

    for (final url in urls) {
      final latency = await _tcpPing(url);
      if (!background) {
        debugPrint('Ping $url: ${latency}ms');
      }
      if (latency < minLatency) {
        minLatency = latency;
        bestUrl = url;
      }
    }

    // 保存到缓存
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString('bangumi_url', bestUrl);

    if (mounted) {
      if (!background) {
        setState(() {
          _bangumiController.text = bestUrl;
          _isAutoSettingBangumi = false;
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.fastestSourceSwitched(bestUrl, minLatency.toString()),
            ),
          ),
        );
      } else {
        // 如果是后台运行，且用户没有修改过，更新UI（可选，但用户体验更好）
        // 这里选择只更新 TextController，不弹窗
        if (_bangumiController.text == 'https://bangumi.tv') {
          setState(() {
            _bangumiController.text = bestUrl;
          });
        }
      }
    }
  }

  Future<void> _autoSelectMikanUrl({
    SharedPreferences? prefs,
    bool background = false,
  }) async {
    if (!background) {
      setState(() {
        _isAutoSettingMikan = true;
      });
    }

    final urls = [
      'https://mikanani.kas.pub',
      'https://mikan2.yujiangqaq.com',
      'https://mikan.makura.cc',
      'https://mikanani.me',
    ];
    int minLatency = 999999;
    String bestUrl = urls[0];

    for (final url in urls) {
      final latency = await _tcpPing(url);
      if (!background) {
        debugPrint('Ping $url: ${latency}ms');
      }
      if (latency < minLatency) {
        minLatency = latency;
        bestUrl = url;
      }
    }

    // 保存到缓存
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString('mikan_url', bestUrl);

    if (mounted) {
      if (!background) {
        setState(() {
          _mikanController.text = bestUrl;
          _isAutoSettingMikan = false;
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.fastestSourceSwitched(bestUrl, minLatency.toString()),
            ),
          ),
        );
      } else {
        // 如果是后台运行，且用户没有修改过，更新UI
        if (_mikanController.text == 'https://mikanani.kas.pub') {
          setState(() {
            _mikanController.text = bestUrl;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sortedSources = _buildSortedSources();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataSourceSettings),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.restoreDefault,
            onPressed: _resetDefaults,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.save,
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTextField(
                  controller: _bgmController,
                  label: l10n.bgmBaseUrl,
                  hint: 'https://bgmlist.com',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bangumiController,
                  label: l10n.bangumiBaseUrl,
                  hint: 'https://bangumi.tv',
                  suffixIcon: IconButton(
                    icon: _isAutoSettingBangumi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    tooltip: l10n.autoSelectFastestSource,
                    onPressed: _isAutoSettingBangumi
                        ? null
                        : _autoSelectBangumiUrl,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BangumiRequestMode>(
                  initialValue: _bangumiRequestMode,
                  decoration: const InputDecoration(
                    labelText: 'Bangumi 请求方式',
                    border: OutlineInputBorder(),
                    filled: true,
                    helperText: '混合版推荐：评论优先走 next.bgm.tv，失败时回退旧实现',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: BangumiRequestMode.legacy,
                      child: Text('旧版（稳定兼容）'),
                    ),
                    DropdownMenuItem(
                      value: BangumiRequestMode.hybrid,
                      child: Text('混合版（推荐）'),
                    ),
                    DropdownMenuItem(
                      value: BangumiRequestMode.modern,
                      child: Text('新版（逐步迁移）'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _bangumiRequestMode = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor.withAlpha(50),
                    ),
                  ),
                  child: SwitchListTile(
                    value: _bangumiUseReverseProxy,
                    onChanged: (value) {
                      setState(() {
                        _bangumiUseReverseProxy = value;
                      });
                    },
                    title: Text(l10n.bangumiReverseProxyTitle),
                    subtitle: Text(
                      l10n.bangumiReverseProxyDescription,
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: const Icon(Icons.dns_outlined),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor.withAlpha(50),
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _bangumiUseEch,
                        onChanged: (value) {
                          setState(() {
                            _bangumiUseEch = value;
                          });
                        },
                        title: Text(l10n.bangumiEchTitle),
                        subtitle: Text(
                          l10n.bangumiEchDescription,
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: const Icon(Icons.lock_outline),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.refresh),
                        title: Text(l10n.bangumiEchRefreshTitle),
                        subtitle: Text(
                          _echRefreshResult ?? l10n.bangumiEchRefreshDescription,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _isRefreshingEch
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isRefreshingEch ? null : _refreshEchConfig,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor.withAlpha(50),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.dns),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.bangumiEchDohListTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.restore, size: 18),
                              label: Text(l10n.bangumiEchDohReset),
                              onPressed: _isDohBusy ? null : _resetDohEndpoints,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Text(
                          l10n.bangumiEchDohListDescription,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (_dohEndpoints.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            l10n.bangumiEchDohListEmpty,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ),
                        )
                      else
                        ...List.generate(_dohEndpoints.length, (index) {
                          final endpoint = _dohEndpoints[index];
                          return _buildDohRow(index, endpoint);
                        }),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _dohAddController,
                                enabled: !_isDohBusy,
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: l10n.bangumiEchDohAddHint,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.add_link),
                                ),
                                onSubmitted: (_) => _addDohEndpoint(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(l10n.bangumiEchDohAddTitle),
                              onPressed: _isDohBusy ? null : _addDohEndpoint,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _mikanController,
                  label: l10n.mikanBaseUrl,
                  hint: 'https://mikanani.kas.pub',
                  suffixIcon: IconButton(
                    icon: _isAutoSettingMikan
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    tooltip: l10n.autoSelectFastestSource,
                    onPressed: _isAutoSettingMikan ? null : _autoSelectMikanUrl,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _playbackSubController,
                        label: l10n.playbackSourceSubscriptionUrl,
                        hint:
                            'https://gitee.com/edicl/online-subscription/raw/master/online.json',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        icon: _isRefreshing
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : const Icon(Icons.refresh),
                        onPressed: _isRefreshing
                            ? null
                            : _refreshPlaybackSources,
                        tooltip: l10n.refreshPlaybackSource,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_sources.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      l10n.subscriptionSwitchTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedSources.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final source = sortedSources[index];
                      final isEnabled = !_disabledSources.contains(source.name);
                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor.withAlpha(50),
                          ),
                        ),
                        child: ListTile(
                          onTap: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DataSourceConfigPage(source: source),
                              ),
                            );
                            if (changed == true) {
                              _loadSettings();
                            }
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: source.iconUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: source.iconUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      width: 40,
                                      height: 40,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.source),
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.source),
                                  ),
                          ),
                          title: Text(
                            source.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.description.isNotEmpty
                                      ? source.description
                                      : l10n.customSourceDescription,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildInfoTag(
                                      context,
                                      'Tier ${source.tier}',
                                      Theme.of(context).colorScheme.tertiary,
                                    ),
                                    if (source.defaultResolution.isNotEmpty)
                                      _buildInfoTag(
                                        context,
                                        source.defaultResolution,
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    if (source
                                        .defaultSubtitleLanguage
                                        .isNotEmpty)
                                      _buildInfoTag(
                                        context,
                                        source.defaultSubtitleLanguage,
                                        Theme.of(context).colorScheme.secondary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: Switch(
                            value: isEnabled,
                            onChanged: (val) {
                              setState(() {
                                if (val) {
                                  _disabledSources.remove(source.name);
                                } else {
                                  _disabledSources.add(source.name);
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DataSourceConfigPage(source: null),
            ),
          );
          if (changed == true) {
            _loadSettings();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoTag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildDohRow(int index, String endpoint) {
    final l10n = AppLocalizations.of(context);
    final isFirst = index == 0;
    final isLast = index == _dohEndpoints.length - 1;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.bangumiEchDohPriority(index + 1),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                endpoint,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
              ),
            ),
            IconButton(
              tooltip: l10n.bangumiEchDohTestTitle,
              icon: const Icon(Icons.network_check, size: 20),
              onPressed: _isDohBusy ? null : () => _testDohEndpoint(endpoint),
            ),
            IconButton(
              tooltip: l10n.bangumiEchDohMoveUp,
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: isFirst || _isDohBusy
                  ? null
                  : () => _moveDohEndpoint(index, index - 1),
            ),
            IconButton(
              tooltip: l10n.bangumiEchDohMoveDown,
              icon: const Icon(Icons.arrow_downward, size: 20),
              onPressed: isLast || _isDohBusy
                  ? null
                  : () => _moveDohEndpoint(index, index + 1),
            ),
            IconButton(
              tooltip: l10n.bangumiEchDohRemove,
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: _isDohBusy
                  ? null
                  : () => _removeDohEndpoint(endpoint),
            ),
          ],
        ),
      ),
    );
  }
}
