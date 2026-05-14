import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

      _sources = sources;
      _disabledSources = sources
          .where((s) => !s.enabled)
          .map((s) => s.name)
          .toSet();

      _isLoading = false;
    });
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
    );

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.refreshFailed(e.toString()))));
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
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
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
}
