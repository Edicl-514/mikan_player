import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/services/bangumi_reverse_proxy_service.dart';
import 'package:mikan_player/services/bangumi_ech_service.dart';
import 'package:intl/intl.dart';
import 'package:mikan_player/src/rust/api/crawler.dart'
    show BangumiDataCacheStatus;
import 'package:mikan_player/services/bangumi_data_service.dart';
import 'package:mikan_player/services/base_url_list_service.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;
import 'package:mikan_player/utils/url_latency.dart';
import 'package:mikan_player/ui/widgets/url_dropdown_field.dart';

class NetworkSettingsPage extends StatefulWidget {
  const NetworkSettingsPage({super.key});

  @override
  State<NetworkSettingsPage> createState() => _NetworkSettingsPageState();
}

class _NetworkSettingsPageState extends State<NetworkSettingsPage> {
  bool _isLoading = true;

  String _selectedBgm = 'https://bgmlist.com';
  List<String> _allBgmUrls = const <String>[];

  String _selectedBangumi = 'https://bangumi.tv';
  List<String> _allBangumiUrls = const <String>[];

  String _selectedMikan = 'https://mikanani.kas.pub';
  List<String> _allMikanUrls = const <String>[];

  bool _isAutoSettingBangumi = false;
  bool _isAutoSettingMikan = false;

  BangumiRequestMode _bangumiRequestMode = BangumiRequestMode.hybrid;
  bool _bangumiUseReverseProxy = false;
  bool _bangumiUseEch = true;
  bool _isRefreshingEch = false;
  String? _echRefreshResult;

  bool _isRefreshingBangumiData = false;
  String? _bangumiDataRefreshResult;
  BangumiDataCacheStatus? _bangumiDataStatus;

  List<String> _dohEndpoints = const <String>[];
  bool _isDohBusy = false;
  final _dohAddController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _dohAddController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      BangumiEchService.getDohEndpoints().catchError(
        (_) => <String>[],
        test: (_) => true,
      ),
      _reloadKindQuiet(BaseUrlKind.bgmlist),
      _reloadKindQuiet(BaseUrlKind.bangumi),
      _reloadKindQuiet(BaseUrlKind.mikan),
      BangumiDataService.getStatus().catchError(
        (_) => BangumiDataCacheStatus(
          cached: false,
          fileSize: BigInt.zero,
          version: '',
        ),
        test: (_) => true,
      ),
    ]);

    final prefs = results[0] as SharedPreferences;
    final dohList = results[1] as List<String>;
    final bgmState = results[2] as _UrlKindState?;
    final bangumiState = results[3] as _UrlKindState?;
    final mikanState = results[4] as _UrlKindState?;
    final status = results[5] as BangumiDataCacheStatus?;

    if (!mounted) return;

    setState(() {
      if (bgmState != null) {
        _allBgmUrls = bgmState.all;
        _selectedBgm = bgmState.selected;
      }
      if (bangumiState != null) {
        _allBangumiUrls = bangumiState.all;
        _selectedBangumi = bangumiState.selected;
      }
      if (mikanState != null) {
        _allMikanUrls = mikanState.all;
        _selectedMikan = mikanState.selected;
      }
      _bangumiRequestMode = BangumiRequestMode.fromValue(
        prefs.getString(BangumiRequestModeService.preferenceKey),
      );
      _bangumiUseReverseProxy =
          prefs.getBool(BangumiReverseProxyService.preferenceKey) ?? false;
      _bangumiUseEch = prefs.getBool(BangumiEchService.preferenceKey) ?? true;
      _dohEndpoints = dohList;
      _bangumiDataStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _reloadKind(BaseUrlKind kind) async {
    final state = await _reloadKindQuiet(kind);
    if (state != null && mounted) {
      setState(() => _applyKindState(kind, state.all, state.selected));
    }
  }

  Future<_UrlKindState?> _reloadKindQuiet(BaseUrlKind kind) async {
    final all = await BaseUrlListService.getAllUrls(kind);
    var selected = await BaseUrlListService.getSelected(kind);

    if (!all.contains(selected) &&
        !BaseUrlListService.isBuiltin(kind, selected)) {
      await BaseUrlListService.addCustomUrl(kind, selected);
      selected = await BaseUrlListService.getSelected(kind);
      final merged = await BaseUrlListService.getAllUrls(kind);
      return _UrlKindState(all: merged, selected: selected);
    }

    return _UrlKindState(all: all, selected: selected);
  }

  void _applyKindState(BaseUrlKind kind, List<String> all, String selected) {
    switch (kind) {
      case BaseUrlKind.bgmlist:
        _allBgmUrls = all;
        _selectedBgm = selected;
        break;
      case BaseUrlKind.bangumi:
        _allBangumiUrls = all;
        _selectedBangumi = selected;
        break;
      case BaseUrlKind.mikan:
        _allMikanUrls = all;
        _selectedMikan = selected;
        break;
    }
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

  Future<void> _refreshBangumiDataCache() async {
    setState(() {
      _isRefreshingBangumiData = true;
      _bangumiDataRefreshResult = null;
    });
    try {
      final ok = await BangumiDataService.refresh();
      BangumiDataCacheStatus? status;
      try {
        status = await BangumiDataService.getStatus();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _bangumiDataRefreshResult = ok ? '已更新离线放送数据' : '更新失败，请检查网络';
          _bangumiDataStatus = status;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingBangumiData = false;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.bangumiEchDohAddInvalid)));
      }
      return;
    }
    setState(() => _isDohBusy = true);
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
        setState(() => _isDohBusy = false);
      }
    }
  }

  Future<void> _removeDohEndpoint(String endpoint) async {
    setState(() => _isDohBusy = true);
    try {
      await _ensureDohListMaterialized();
      final list = await BangumiEchService.removeDohEndpoint(endpoint);
      if (mounted) {
        setState(() => _dohEndpoints = list);
      }
    } finally {
      if (mounted) {
        setState(() => _isDohBusy = false);
      }
    }
  }

  Future<void> _ensureDohListMaterialized() async {
    if (_dohEndpoints.isNotEmpty) return;
    final list = await BangumiEchService.setDohEndpoints(
      BangumiEchService.defaultDohEndpoints,
    );
    if (mounted) setState(() => _dohEndpoints = list);
  }

  Future<void> _moveDohEndpoint(int from, int to) async {
    if (from == to) return;
    setState(() => _isDohBusy = true);
    try {
      await _ensureDohListMaterialized();
      final list = await BangumiEchService.moveDohEndpoint(from, to);
      if (mounted) {
        setState(() => _dohEndpoints = list);
      }
    } finally {
      if (mounted) {
        setState(() => _isDohBusy = false);
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
    setState(() => _isDohBusy = true);
    try {
      final list = await BangumiEchService.resetDohEndpoints();
      if (mounted) {
        setState(() => _dohEndpoints = list);
      }
    } finally {
      if (mounted) {
        setState(() => _isDohBusy = false);
      }
    }
  }

  Future<void> _testDohEndpoint(String endpoint) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isDohBusy = true);
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
        setState(() => _isDohBusy = false);
      }
    }
  }

  Future<void> _autoSelect({
    required BaseUrlKind kind,
    required void Function(bool) setBusy,
    required void Function(String) setSelected,
  }) async {
    final candidates = BaseUrlListService.builtinFor(kind);
    setState(() => setBusy(true));
    final bestUrl = await selectFastestUrl(candidates);
    if (bestUrl == null) {
      if (mounted) {
        setState(() => setBusy(false));
      }
      return;
    }

    await BaseUrlListService.setSelected(kind, bestUrl);
    final latency = await tcpPing(bestUrl);
    if (!mounted) return;

    setState(() {
      setSelected(bestUrl);
      setBusy(false);
    });
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.fastestSourceSwitched(bestUrl, latency.toString())),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final playbackSub =
        prefs.getString('playback_sub_url') ??
        'https://gitee.com/edicl/online-subscription/raw/master/online.json';

    await BaseUrlListService.setSelected(BaseUrlKind.bgmlist, _selectedBgm);
    await BaseUrlListService.setSelected(BaseUrlKind.bangumi, _selectedBangumi);
    await BaseUrlListService.setSelected(BaseUrlKind.mikan, _selectedMikan);

    // Sync to Rust
    await rust.updateConfig(
      bgm: _selectedBgm,
      bangumi: _selectedBangumi,
      mikan: _selectedMikan,
      playbackSub: playbackSub,
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

  void _resetDefaults() {
    setState(() {
      _selectedBgm = BaseUrlListService.builtinFor(BaseUrlKind.bgmlist).first;
      _selectedBangumi = BaseUrlListService.builtinFor(
        BaseUrlKind.bangumi,
      ).first;
      _selectedMikan = BaseUrlListService.builtinFor(BaseUrlKind.mikan).first;
      _bangumiRequestMode = BangumiRequestMode.hybrid;
      _bangumiUseReverseProxy = false;
      _bangumiUseEch = true;
      _echRefreshResult = null;
      _bangumiDataRefreshResult = null;
    });
  }

  String _bangumiDataStatusSubtitle() {
    final status = _bangumiDataStatus;
    if (status == null) {
      return '加载中…';
    }
    if (!status.cached) {
      return '未缓存 · 点击下载离线兜底数据';
    }
    final sizeMB = (status.fileSize.toInt()) / (1024 * 1024);
    final sizeStr = sizeMB >= 1
        ? '${sizeMB.toStringAsFixed(1)} MB'
        : '${(status.fileSize.toInt() / 1024).toStringAsFixed(0)} KB';
    final parts = <String>['已缓存 $sizeStr'];
    if (status.lastModifiedSecs != null) {
      final mtime = DateTime.fromMillisecondsSinceEpoch(
        status.lastModifiedSecs!.toInt() * 1000,
        isUtc: true,
      ).toLocal();
      parts.add('同步于 ${DateFormat('yyyy-MM-dd HH:mm').format(mtime)}');
    }
    parts.add('v${status.version}');
    if (status.lastFailedSecs != null) {
      final ageMins = status.lastFailedSecs!.toInt() / 60;
      if (ageMins < 60) {
        parts.add('${ageMins.round()}分钟前同步失败');
      } else {
        final ageHours = ageMins / 60;
        parts.add('${ageHours.round()}小时前同步失败');
      }
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hideBangumiUrl = _bangumiUseEch || _bangumiUseReverseProxy;
    final dohDisplay = _dohEndpoints.isNotEmpty
        ? _dohEndpoints
        : BangumiEchService.defaultDohEndpoints;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkSettingsTitle),
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
                _sectionTitle(l10n.networkSectionBaseUrl),
                UrlDropdownField(
                  label: l10n.bgmBaseUrl,
                  hint: 'https://bgmlist.com',
                  kind: BaseUrlKind.bgmlist,
                  allUrls: _allBgmUrls,
                  selectedUrl: _selectedBgm,
                  onSelected: (url) => setState(() => _selectedBgm = url),
                  onUrlsChanged: () => _reloadKind(BaseUrlKind.bgmlist),
                ),
                const SizedBox(height: 16),
                UrlDropdownField(
                  label: l10n.mikanBaseUrl,
                  hint: 'https://mikanani.kas.pub',
                  kind: BaseUrlKind.mikan,
                  allUrls: _allMikanUrls,
                  selectedUrl: _selectedMikan,
                  onSelected: (url) => setState(() => _selectedMikan = url),
                  onUrlsChanged: () => _reloadKind(BaseUrlKind.mikan),
                  trailing: IconButton(
                    icon: _isAutoSettingMikan
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    tooltip: l10n.autoSelectFastestSource,
                    onPressed: _isAutoSettingMikan
                        ? null
                        : () => _autoSelect(
                            kind: BaseUrlKind.mikan,
                            setBusy: (v) => _isAutoSettingMikan = v,
                            setSelected: (url) => _selectedMikan = url,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (hideBangumiUrl)
                  _buildBangumiUrlHiddenCard(context)
                else
                  UrlDropdownField(
                    label: l10n.bangumiBaseUrl,
                    hint: 'https://bangumi.tv',
                    kind: BaseUrlKind.bangumi,
                    allUrls: _allBangumiUrls,
                    selectedUrl: _selectedBangumi,
                    onSelected: (url) => setState(() => _selectedBangumi = url),
                    onUrlsChanged: () => _reloadKind(BaseUrlKind.bangumi),
                    trailing: IconButton(
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
                          : () => _autoSelect(
                              kind: BaseUrlKind.bangumi,
                              setBusy: (v) => _isAutoSettingBangumi = v,
                              setSelected: (url) => _selectedBangumi = url,
                            ),
                    ),
                  ),
                const SizedBox(height: 24),
                _sectionTitle(l10n.networkSectionBangumiMode),
                DropdownButtonFormField<BangumiRequestMode>(
                  initialValue: _bangumiRequestMode,
                  decoration: const InputDecoration(
                    labelText: 'Bangumi 请求方式',
                    border: OutlineInputBorder(),
                    filled: true,
                    // helperText: '评论优先走 next.bgm.tv，失败时回退旧实现',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: BangumiRequestMode.legacy,
                      child: Text('旧版'),
                    ),
                    DropdownMenuItem(
                      value: BangumiRequestMode.hybrid,
                      child: Text('混合（推荐）'),
                    ),
                    DropdownMenuItem(
                      value: BangumiRequestMode.modern,
                      child: Text('新版'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _bangumiRequestMode = value);
                  },
                ),
                const SizedBox(height: 24),
                _sectionTitle(l10n.networkSectionAdvanced),
                _buildCard(
                  context,
                  child: SwitchListTile(
                    value: _bangumiUseReverseProxy,
                    onChanged: (value) {
                      setState(() => _bangumiUseReverseProxy = value);
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
                const SizedBox(height: 16),
                _buildCard(
                  context,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _bangumiUseEch,
                        onChanged: (value) {
                          setState(() => _bangumiUseEch = value);
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
                      if (_bangumiUseEch)
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title: Text(l10n.bangumiEchRefreshTitle),
                          subtitle: Text(
                            _echRefreshResult ??
                                l10n.bangumiEchRefreshDescription,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: _isRefreshingEch
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _isRefreshingEch ? null : _refreshEchConfig,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  context,
                  child: ListTile(
                    leading: Icon(
                      _bangumiDataStatus?.cached ?? false
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_download_outlined,
                    ),
                    title: const Text('离线放送数据'),
                    subtitle: Text(
                      _bangumiDataRefreshResult ?? _bangumiDataStatusSubtitle(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: _isRefreshingBangumiData
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isRefreshingBangumiData
                        ? null
                        : _refreshBangumiDataCache,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDohCard(context, dohDisplay),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildBangumiUrlHiddenCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _buildCard(
      context,
      child: ListTile(
        leading: Icon(
          Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(l10n.bangumiBaseUrl),
        subtitle: Text(
          l10n.bangumiBaseUrlHidden,
          style: const TextStyle(fontSize: 12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildDohCard(BuildContext context, List<String> displayList) {
    final l10n = AppLocalizations.of(context);
    return _buildCard(
      context,
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
          ...List.generate(displayList.length, (index) {
            final endpoint = displayList[index];
            return _buildDohRow(displayList, index, endpoint);
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
    );
  }

  Widget _buildDohRow(List<String> displayList, int index, String endpoint) {
    final l10n = AppLocalizations.of(context);
    final isFirst = index == 0;
    final isLast = index == displayList.length - 1;
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
              onPressed: _isDohBusy ? null : () => _removeDohEndpoint(endpoint),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrlKindState {
  final List<String> all;
  final String selected;
  const _UrlKindState({required this.all, required this.selected});
}
