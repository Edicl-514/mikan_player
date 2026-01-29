import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;

class DataSourceSettingsPage extends StatefulWidget {
  const DataSourceSettingsPage({super.key});

  @override
  State<DataSourceSettingsPage> createState() => _DataSourceSettingsPageState();
}

class _DataSourceSettingsPageState extends State<DataSourceSettingsPage> {
  final _bgmController = TextEditingController();
  final _bangumiController = TextEditingController();
  final _mikanController = TextEditingController();
  final _btSubController = TextEditingController();
  final _playbackSubController = TextEditingController();
  bool _isLoading = true;

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
    _btSubController.dispose();
    _playbackSubController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bgmController.text =
          prefs.getString('bgmlist_url') ?? 'https://bgmlist.com';
      _bangumiController.text =
          prefs.getString('bangumi_url') ?? 'https://bangumi.tv';
      _mikanController.text =
          prefs.getString('mikan_url') ?? 'https://mikanani.kas.pub';
      _btSubController.text =
          prefs.getString('bt_sub_url') ??
          'https://sub.creamycake.org/v1/bt1.json';
      _playbackSubController.text =
          prefs.getString('playback_sub_url') ??
          'https://sub.creamycake.org/v1/css1.json';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bgmlist_url', _bgmController.text);
    await prefs.setString('bangumi_url', _bangumiController.text);
    await prefs.setString('mikan_url', _mikanController.text);
    await prefs.setString('bt_sub_url', _btSubController.text);
    await prefs.setString('playback_sub_url', _playbackSubController.text);

    // Sync to Rust
    await rust.updateConfig(
      bgm: _bgmController.text,
      bangumi: _bangumiController.text,
      mikan: _mikanController.text,
      btSub: _btSubController.text,
      playbackSub: _playbackSubController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
      Navigator.pop(context);
    }
  }

  void _resetDefaults() {
    setState(() {
      _bgmController.text = 'https://bgmlist.com';
      _bangumiController.text = 'https://bangumi.tv';
      _mikanController.text = 'https://mikanani.kas.pub';
      _btSubController.text = 'https://sub.creamycake.org/v1/bt1.json';
      _playbackSubController.text = 'https://sub.creamycake.org/v1/css1.json';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据源设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '恢复默认',
            onPressed: _resetDefaults,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
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
                  label: 'Bgmlist Base URL',
                  hint: 'https://bgmlist.com',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bangumiController,
                  label: 'Bangumi Base URL',
                  hint: 'https://bangumi.tv',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _mikanController,
                  label: 'Mikan Base URL',
                  hint: 'https://mikanani.kas.pub',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _btSubController,
                  label: '额外BT订阅地址',
                  hint: 'https://sub.creamycake.org/v1/bt1.json',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _playbackSubController,
                  label: '播放源订阅地址',
                  hint: 'https://sub.creamycake.org/v1/css1.json',
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('保存设置'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
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
    );
  }
}
