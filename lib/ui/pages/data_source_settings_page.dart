import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/services/bangumi_reverse_proxy_service.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;
import 'package:mikan_player/src/rust/api/generic_scraper.dart'
    as generic_scraper;
import 'data_source_config_page.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';
import 'package:mikan_player/utils/debounced_async_action.dart';

class DataSourceSettingsPage extends StatefulWidget {
  const DataSourceSettingsPage({super.key});

  @override
  State<DataSourceSettingsPage> createState() => _DataSourceSettingsPageState();
}

class _DataSourceSettingsPageState extends State<DataSourceSettingsPage> {
  final _playbackSubController = TextEditingController();
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<generic_scraper.SourceState> _sources = [];
  Set<String> _disabledSources = {};
  final DebouncedAsyncAction _persistAction = DebouncedAsyncAction(
    debugLabel: 'data source settings',
  );

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
    _persistAction.dispose();
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

    if (!mounted) return;
    setState(() {
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

  /// Persists the subscription URL and per-source enabled state, syncing both
  /// to the Rust runtime.
  ///
  /// Called on every change so the page saves automatically without a save
  /// button. Base URLs / reverse-proxy are owned by the Network settings page;
  /// their current values are read back so `updateConfig` keeps the runtime in
  /// sync without clobbering them.
  Future<void> _persist({
    required String playbackSub,
    required List<String> disabledSources,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final bgm = prefs.getString('bgmlist_url') ?? 'https://bgmlist.com';
    final bangumi = prefs.getString('bangumi_url') ?? 'https://bangumi.tv';
    final mikan = prefs.getString('mikan_url') ?? 'https://mikanani.kas.pub';
    final useReverseProxy =
        prefs.getBool(BangumiReverseProxyService.preferenceKey) ?? false;

    await prefs.setString('playback_sub_url', playbackSub);
    await prefs.setStringList('disabled_sources', disabledSources);

    // Sync to Rust
    await rust.setDisabledSources(sources: disabledSources);
    await rust.updateConfig(
      bgm: bgm,
      bangumi: bangumi,
      mikan: mikan,
      playbackSub: playbackSub,
      useReverseProxy: useReverseProxy,
    );
  }

  Future<void> _persistNow() {
    final playbackSub = _playbackSubController.text;
    final disabledSources = _disabledSources.toList(growable: false);
    return _persistAction.run(
      () =>
          _persist(playbackSub: playbackSub, disabledSources: disabledSources),
    );
  }

  void _schedulePersist() {
    final playbackSub = _playbackSubController.text;
    final disabledSources = _disabledSources.toList(growable: false);
    _persistAction.schedule(
      () =>
          _persist(playbackSub: playbackSub, disabledSources: disabledSources),
    );
  }

  Future<void> _refreshPlaybackSources() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // A user-requested refresh reapplies remote defaultEnabled values. The
      // automatic startup refresh uses a separate mode and preserves switches.
      final result = await generic_scraper.refreshPlaybackSourceConfig();
      final content = result.content;
      final applyDefaultEnabled = result.applyDefaultEnabled;

      var syncCount = 0;
      if (applyDefaultEnabled) {
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
          syncCount = defaultEnabledOverrides.length;
        }
      }

      // 刷新源列表（从本地缓存读取）
      final sources = await rust.getPlaybackSources();
      final disabledSources = sources
          .where((s) => !s.enabled)
          .map((s) => s.name)
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('disabled_sources', disabledSources);

      if (mounted) {
        setState(() {
          _sources = sources;
          _disabledSources = disabledSources.toSet();
        });
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
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
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _playbackSubController.text =
          'https://gitee.com/edicl/online-subscription/raw/master/online.json';
    });
    await _persistNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sortedSources = _buildSortedSources();
    final isHosted = DesktopPageChromeScope.hostsPageHeader(context);

    final formBody = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                      onPressed: _isRefreshing ? null : _refreshPlaybackSources,
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        onTap: source.isManual
                            ? () async {
                                final changed = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      final page = DataSourceConfigPage(
                                        source: source,
                                      );
                                      return isHosted
                                          ? DesktopPageChromeScope(child: page)
                                          : page;
                                    },
                                  ),
                                );
                                if (changed == true) {
                                  _loadSettings();
                                }
                              }
                            : () {
                                final l10n = AppLocalizations.of(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.subscriptionSourceReadOnly,
                                    ),
                                  ),
                                );
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
                                    source.isManual
                                        ? l10n.manualSourceTag
                                        : l10n.subscriptionSourceTag,
                                    source.isManual
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.secondary
                                        : Theme.of(context).colorScheme.primary,
                                  ),
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
                                  if (source.defaultSubtitleLanguage.isNotEmpty)
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
                            _persistNow();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.restore),
                label: Text(l10n.restoreDefault),
              ),
              const SizedBox(height: 32),
            ],
          );

    return DesktopPageScaffold(
      title: Text(l10n.dataSourceSettings),
      body: formBody,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                const page = DataSourceConfigPage(source: null);
                return isHosted
                    ? const DesktopPageChromeScope(child: page)
                    : page;
              },
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
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
      ),
      onChanged: (_) => _schedulePersist(),
    );
  }
}
