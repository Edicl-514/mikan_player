import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/services/webview_resource_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';

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
  bool _cancelLowPrioritySourcesOnPlay = true;

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
          (prefs.getInt('max_concurrent_webviews') ??
                  PlayerPage.kDefaultMaxConcurrentWebViews)
              .toString();
      _intervalController.text =
          (prefs.getInt('webview_launch_interval') ?? 200).toString();
      _searchConcurrencyController.text =
          (prefs.getInt('max_concurrent_searches') ?? 3).toString();
      _autoSearchOnline = prefs.getBool('auto_search_online') ?? true;
      _cancelLowPrioritySourcesOnPlay =
          prefs.getBool('cancel_low_priority_sources_on_play') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final concurrency =
        (int.tryParse(_concurrencyController.text) ??
                PlayerPage.kDefaultMaxConcurrentWebViews)
            .clamp(1, 64)
            .toInt();
    final interval = int.tryParse(_intervalController.text) ?? 200;
    final searchConcurrency =
        int.tryParse(_searchConcurrencyController.text) ?? 3;

    await prefs.setInt('max_concurrent_webviews', concurrency);
    await prefs.setInt('webview_launch_interval', interval);
    await prefs.setInt('max_concurrent_searches', searchConcurrency);
    await prefs.setBool('auto_search_online', _autoSearchOnline);
    await prefs.setBool(
      'cancel_low_priority_sources_on_play',
      _cancelLowPrioritySourcesOnPlay,
    );
    WebViewResourceCoordinator.instance.updateLimit(concurrency);

    // Update Rust runtime config
    await simple.setMaxConcurrentSearches(limit: searchConcurrency);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isHosted = DesktopPageChromeScope.hostsPageHeader(context);

    final formBody = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTextField(
                controller: _searchConcurrencyController,
                label: l10n.maxParallelSearchSources,
                hint: l10n.maxParallelSearchSourcesHint,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.webviewScraperSettingsTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              _buildTextField(
                controller: _concurrencyController,
                label: l10n.maxWebviewConcurrent,
                hint: l10n.maxWebviewConcurrentHint,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _intervalController,
                label: l10n.webviewLaunchInterval,
                hint: l10n.webviewLaunchIntervalHint,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Divider(),
              SwitchListTile(
                title: Text(l10n.autoSearchOnlineTitle),
                subtitle: Text(l10n.autoSearchOnlineSubtitle),
                value: _autoSearchOnline,
                onChanged: (bool value) {
                  setState(() {
                    _autoSearchOnline = value;
                  });
                },
              ),
              SwitchListTile(
                title: Text(l10n.cancelLowPrioritySourcesTitle),
                subtitle: Text(l10n.cancelLowPrioritySourcesSubtitle),
                value: _cancelLowPrioritySourcesOnPlay,
                onChanged: (bool value) {
                  setState(() {
                    _cancelLowPrioritySourcesOnPlay = value;
                  });
                },
              ),
            ],
          );

    return Scaffold(
      appBar: isHosted
          ? null
          : AppBar(
              title: Text(l10n.searchSettingsTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: l10n.save,
                  onPressed: _saveSettings,
                ),
              ],
            ),
      body: isHosted
          ? Column(
              children: [
                DesktopPageActionRow(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save),
                      tooltip: l10n.save,
                      onPressed: _saveSettings,
                    ),
                  ],
                ),
                Expanded(child: formBody),
              ],
            )
          : formBody,
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
