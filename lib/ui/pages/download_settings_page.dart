import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector_windows/file_selector_windows.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/download_manager.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  final DownloadManager _dm = DownloadManager();
  late int _maxConcurrent;
  late double _downloadLimit;
  late double _uploadLimit;
  late BtBackendKind _backendKind;
  late bool _allowBackgroundDownload;
  late bool _keepSeedingInBackground;
  String? _customDownloadDir;

  final _concurrentController = TextEditingController();
  final _downloadLimitController = TextEditingController();
  final _uploadLimitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _maxConcurrent = _dm.maxConcurrentDownloads;
    _downloadLimit = _dm.downloadLimitMbps;
    _uploadLimit = _dm.uploadLimitMbps;
    _backendKind = _dm.backendKind;
    _allowBackgroundDownload = _dm.allowBackgroundDownload;
    _keepSeedingInBackground = _dm.keepSeedingInBackground;
    _customDownloadDir = _dm.hasCustomDownloadDir ? _dm.downloadDir : null;
    _concurrentController.text = _maxConcurrent.toString();
    _downloadLimitController.text = _formatLimitValue(_downloadLimit);
    _uploadLimitController.text = _formatLimitValue(_uploadLimit);
  }

  @override
  void dispose() {
    _concurrentController.dispose();
    _downloadLimitController.dispose();
    _uploadLimitController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context);
    final concurrent =
        (int.tryParse(_concurrentController.text) ?? _maxConcurrent).clamp(
          1,
          10,
        );
    final dlLimit = _parseLimit(_downloadLimitController.text);
    final ulLimit = _parseLimit(_uploadLimitController.text);
    if (dlLimit == null || ulLimit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.downloadSettingsInvalidNumber)),
      );
      return;
    }

    await _dm.setDownloadSettings(
      maxConcurrent: concurrent,
      downloadLimitMbps: dlLimit,
      uploadLimitMbps: ulLimit,
      allowBackgroundDownload: _allowBackgroundDownload,
      keepSeedingInBackground: _keepSeedingInBackground,
    );

    if (!mounted) return;

    setState(() {
      _maxConcurrent = _dm.maxConcurrentDownloads;
      _downloadLimit = _dm.downloadLimitMbps;
      _uploadLimit = _dm.uploadLimitMbps;
      _allowBackgroundDownload = _dm.allowBackgroundDownload;
      _keepSeedingInBackground = _dm.keepSeedingInBackground;
    });

    _concurrentController.text = _maxConcurrent.toString();
    _downloadLimitController.text = _formatLimitValue(_downloadLimit);
    _uploadLimitController.text = _formatLimitValue(_uploadLimit);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.downloadSettingsSaved)));
  }

  double? _parseLimit(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 0;
    final value = double.tryParse(text);
    if (value == null || value < 0) return null;
    return value;
  }

  String _formatLimitValue(double value) {
    // 如果是整数（例如 0.0、1.0），显示为不带小数点的整数；否则使用原始字符串
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    // 去掉尾部多余的 0（例如 1.500 -> 1.5），使用 Dart 的 toString() 已经可以满足大多数需求
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.downloadSettingsTitle),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BT 后端
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.hub_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                l10n.downloadEngineTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                l10n.downloadEngineSubtitle,
              ),
              trailing: DropdownButton<BtBackendKind>(
                value: _backendKind,
                underline: const SizedBox(),
                onChanged: (backend) async {
                  if (backend == null) return;
                  await _dm.setBackendKind(backend);
                  if (!mounted) return;
                  setState(() => _backendKind = backend);
                },
                items: const [
                  DropdownMenuItem(
                    value: BtBackendKind.rqbit,
                    // i18n-ignore: product name
                    child: Text('rqbit'),
                  ),
                  DropdownMenuItem(
                    value: BtBackendKind.libtorrent,
                    // i18n-ignore: product name
                    child: Text('libtorrent'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 引擎说明
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _backendKind == BtBackendKind.rqbit
                        ? l10n.downloadEngineRqbitDescription
                        : l10n.downloadEngineLibtorrentDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _buildSwitchCard(
            icon: Icons.cloud_download_outlined,
            title: l10n.allowBackgroundDownload,
            subtitle: l10n.allowBackgroundDownloadSubtitle,
            value: _allowBackgroundDownload,
            onChanged: (value) async {
              setState(() {
                _allowBackgroundDownload = value;
                if (!value) {
                  _keepSeedingInBackground = false;
                }
              });
              await _dm.setDownloadSettings(
                allowBackgroundDownload: _allowBackgroundDownload,
                keepSeedingInBackground: _keepSeedingInBackground,
              );
            },
          ),
          if (_allowBackgroundDownload) ...[
            const SizedBox(height: 8),
            _buildSwitchCard(
              icon: Icons.all_inclusive,
              title: l10n.keepSeedingMode,
              subtitle: l10n.keepSeedingModeSubtitle,
              value: _keepSeedingInBackground,
              onChanged: (value) async {
                setState(() => _keepSeedingInBackground = value);
                await _dm.setDownloadSettings(
                  keepSeedingInBackground: _keepSeedingInBackground,
                );
              },
            ),
          ],
          const SizedBox(height: 16),

          // 下载路径（仅 Windows 桌面平台）
          if (!kIsWeb && Platform.isWindows) ...[
            _buildDownloadDirCard(),
            const SizedBox(height: 16),
          ],

          // 并行下载数
          _buildNumberField(
            controller: _concurrentController,
            label: l10n.downloadParallelTasks,
            hint: l10n.downloadParallelHint,
            icon: Icons.sync_alt,
            allowDecimal: false,
          ),
          const SizedBox(height: 16),

          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.downloadSpeedLimitsHeader,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // 下载限速
          _buildNumberField(
            controller: _downloadLimitController,
            label: l10n.downloadDownloadLimit,
            hint: l10n.downloadDownloadLimitHint,
            icon: Icons.download,
          ),
          const SizedBox(height: 16),

          // 上传限速
          _buildNumberField(
            controller: _uploadLimitController,
            label: l10n.downloadUploadLimit,
            hint: l10n.downloadUploadLimitHint,
            icon: Icons.upload,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool allowDecimal = true,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.numberWithOptions(
                  decimal: allowDecimal,
                ),
                inputFormatters: allowDecimal
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                    : [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDownloadDir() async {
    final l10n = AppLocalizations.of(context);
    final result = await FileSelectorWindows().getDirectoryPath(
      initialDirectory: _customDownloadDir ?? _dm.downloadDir,
      confirmButtonText: l10n.downloadDirPickerTitle,
    );
    if (result != null) {
      try {
        await _dm.setDownloadDir(result);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        return;
      }
      if (!mounted) return;
      setState(() {
        _customDownloadDir = _dm.downloadDir;
      });
    }
  }

  Future<void> _resetDownloadDir() async {
    try {
      await _dm.setDownloadDir(null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    setState(() {
      _customDownloadDir = null;
    });
  }

  Widget _buildDownloadDirCard() {
    final l10n = AppLocalizations.of(context);
    final displayPath = _customDownloadDir ?? _dm.downloadDir;
    final isCustom = _customDownloadDir != null;
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.downloadDirTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayPath,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _pickDownloadDir,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(l10n.downloadDirBrowse),
                ),
                if (isCustom) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _resetDownloadDir,
                    icon: const Icon(Icons.restore, size: 18),
                    label: Text(l10n.restoreDefault),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
