import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/services/webview_resource_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';
import 'package:mikan_player/utils/debounced_async_action.dart';

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
  final DebouncedAsyncAction _persistAction = DebouncedAsyncAction(
    debugLabel: 'search settings',
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _persistAction.dispose();
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

  /// Persists the current field values. Called on every change so the page
  /// saves automatically without a save button. Number fields are parsed and
  /// clamped for storage only; the controller text is left untouched so typing
  /// is never interrupted.
  void _schedulePersist() {
    final rawConcurrency = int.tryParse(_concurrencyController.text);
    final rawInterval = int.tryParse(_intervalController.text);
    final rawSearchConcurrency = int.tryParse(
      _searchConcurrencyController.text,
    );
    if (rawConcurrency == null ||
        rawInterval == null ||
        rawSearchConcurrency == null) {
      return;
    }
    final concurrency = rawConcurrency.clamp(1, 64).toInt();
    final interval = rawInterval.clamp(0, 60000).toInt();
    final searchConcurrency = rawSearchConcurrency.clamp(1, 64).toInt();
    final autoSearchOnline = _autoSearchOnline;
    final cancelLowPrioritySourcesOnPlay = _cancelLowPrioritySourcesOnPlay;
    _persistAction.schedule(
      () => _persist(
        concurrency: concurrency,
        interval: interval,
        searchConcurrency: searchConcurrency,
        autoSearchOnline: autoSearchOnline,
        cancelLowPrioritySourcesOnPlay: cancelLowPrioritySourcesOnPlay,
      ),
    );
  }

  Future<void> _persistFlagsNow() {
    final autoSearchOnline = _autoSearchOnline;
    final cancelLowPrioritySourcesOnPlay = _cancelLowPrioritySourcesOnPlay;
    return _persistAction.run(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_search_online', autoSearchOnline);
      await prefs.setBool(
        'cancel_low_priority_sources_on_play',
        cancelLowPrioritySourcesOnPlay,
      );
    });
  }

  Future<void> _persist({
    required int concurrency,
    required int interval,
    required int searchConcurrency,
    required bool autoSearchOnline,
    required bool cancelLowPrioritySourcesOnPlay,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('max_concurrent_webviews', concurrency);
    await prefs.setInt('webview_launch_interval', interval);
    await prefs.setInt('max_concurrent_searches', searchConcurrency);
    await prefs.setBool('auto_search_online', autoSearchOnline);
    await prefs.setBool(
      'cancel_low_priority_sources_on_play',
      cancelLowPrioritySourcesOnPlay,
    );
    WebViewResourceCoordinator.instance.updateLimit(concurrency);

    // Update Rust runtime config
    await simple.setMaxConcurrentSearches(limit: searchConcurrency);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DesktopPageScaffold(
      title: Text(l10n.searchSettingsTitle),
      body: _isLoading
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
                    _persistFlagsNow();
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
                    _persistFlagsNow();
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
      onChanged: (_) => _schedulePersist(),
    );
  }
}
