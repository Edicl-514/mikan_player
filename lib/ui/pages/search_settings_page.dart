import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikan_player/src/rust/api/simple.dart' as simple;

class SearchSettingsPage extends StatefulWidget {
  const SearchSettingsPage({super.key});

  @override
  State<SearchSettingsPage> createState() => _SearchSettingsPageState();
}

class _SearchSettingsPageState extends State<SearchSettingsPage> {
  final TextEditingController _concurrencyController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _searchConcurrencyController =
      TextEditingController();
  bool _isLoading = true;
  bool _autoSearchOnline = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _concurrencyController.dispose();
    _intervalController.dispose();
    _searchConcurrencyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _concurrencyController.text =
          (prefs.getInt('max_concurrent_webviews') ?? 1).toString();
      _intervalController.text =
          (prefs.getInt('webview_launch_interval') ?? 200).toString();
      _searchConcurrencyController.text =
          (prefs.getInt('max_concurrent_searches') ?? 3).toString();
      _autoSearchOnline = prefs.getBool('auto_search_online') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final concurrency = int.tryParse(_concurrencyController.text) ?? 1;
    final interval = int.tryParse(_intervalController.text) ?? 200;
    final searchConcurrency =
        int.tryParse(_searchConcurrencyController.text) ?? 3;

    await prefs.setInt('max_concurrent_webviews', concurrency);
    await prefs.setInt('webview_launch_interval', interval);
    await prefs.setInt('max_concurrent_searches', searchConcurrency);
    await prefs.setBool('auto_search_online', _autoSearchOnline);

    // Update Rust runtime config
    await simple.setMaxConcurrentSearches(limit: searchConcurrency);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索设置'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTextField(
                  controller: _searchConcurrencyController,
                  label: '最大并行搜索源数量',
                  hint: '默认为3，0为不限制（Generic Scraper）',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'WebView Scraper设置 (仅针对Dynamic Webview源)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildTextField(
                  controller: _concurrencyController,
                  label: '最大WebView并发数量',
                  hint: '建议值: 1-3',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _intervalController,
                  label: 'WebView启动间隔 (毫秒)',
                  hint: '建议值: 200-1000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Divider(),
                SwitchListTile(
                  title: const Text('自动搜索在线源'),
                  subtitle: const Text('关闭后，播放页将只自动搜索BT源'),
                  value: _autoSearchOnline,
                  onChanged: (bool value) {
                    setState(() {
                      _autoSearchOnline = value;
                    });
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        helperText: hint,
      ),
      keyboardType: keyboardType,
    );
  }
}
