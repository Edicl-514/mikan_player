import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    );

    if (!mounted) return;

    setState(() {
      _maxConcurrent = _dm.maxConcurrentDownloads;
      _downloadLimit = _dm.downloadLimitMbps;
      _uploadLimit = _dm.uploadLimitMbps;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).downloadSettingsTitle),
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
                AppLocalizations.of(context).downloadEngineTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                AppLocalizations.of(context).downloadEngineSubtitle,
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
                    child: Text('rqbit'),
                  ),
                  DropdownMenuItem(
                    value: BtBackendKind.libtorrent,
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
                        ? 'rqbit 基于 Rust 构建，内存占用低，启动快速，擅长边下边播（串流）场景，适合快速预览视频内容。'
                        : 'libtorrent 是成熟的 C++ BT 引擎，下载稳定高效，兼容性好，擅长完整下载和资源做种，适合长期保种场景。',
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

          // 并行下载数
          _buildNumberField(
            controller: _concurrentController,
            label: AppLocalizations.of(context).downloadParallelTasks,
            hint: AppLocalizations.of(context).downloadParallelHint,
            icon: Icons.sync_alt,
            allowDecimal: false,
          ),
          const SizedBox(height: 16),

          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              AppLocalizations.of(context).downloadSpeedLimitsHeader,
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
            label: AppLocalizations.of(context).downloadDownloadLimit,
            hint: AppLocalizations.of(context).downloadDownloadLimitHint,
            icon: Icons.download,
          ),
          const SizedBox(height: 16),

          // 上传限速
          _buildNumberField(
            controller: _uploadLimitController,
            label: AppLocalizations.of(context).downloadUploadLimit,
            hint: AppLocalizations.of(context).downloadUploadLimitHint,
            icon: Icons.upload,
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: Text(
              AppLocalizations.of(context).downloadSettingsSaveButton,
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
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
}
