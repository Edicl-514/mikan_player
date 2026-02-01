import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/src/rust/api/simple.dart';
import 'package:mikan_player/src/rust/frb_generated.dart';
import 'package:mikan_player/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;
import 'package:mikan_player/src/rust/api/network.dart' as network;
import 'package:mikan_player/src/http_overrides.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// 全局 WebView 环境（Windows 平台需要）
WebViewEnvironment? webViewEnvironment;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Rust Logic with platform-specific paths
  final appSupportDir = await getApplicationSupportDirectory();
  final cacheDir = Directory('${appSupportDir.path}/cache');
  final downloadDir = Directory('${appSupportDir.path}/downloads');

  if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
  if (!await downloadDir.exists()) await downloadDir.create(recursive: true);

  await RustLib.init();
  await rust.initEngine(cacheDir: cacheDir.path, downloadDir: downloadDir.path);

  // Initialize MediaKit
  MediaKit.ensureInitialized();

  // Initialize WebView2 on Windows
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    if (availableVersion != null) {
      // 使用应用数据目录存储 WebView2 数据
      final appDataDir = await getApplicationSupportDirectory();
      final webViewDataPath = '${appDataDir.path}\\WebView2';

      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: webViewDataPath),
      );
      debugPrint('WebView2 initialized: $availableVersion');
    } else {
      debugPrint(
        'WARNING: WebView2 Runtime not found. Some features may not work.',
      );
    }
  }

  // Load and sync settings
  await _syncSettings();

  // Setup Proxy
  final proxy = await network.getSystemProxy();
  if (proxy != null) {
    debugPrint('Setting global proxy: $proxy');
    HttpOverrides.global = MyHttpOverrides(proxy);
  }

  runApp(const MyApp());
}

Future<void> _syncSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final bgm = prefs.getString('bgmlist_url') ?? 'https://bgmlist.com';
    final bangumi = prefs.getString('bangumi_url') ?? 'https://bangumi.tv';
    final mikan = prefs.getString('mikan_url') ?? 'https://mikanani.kas.pub';
    final playbackSub =
        prefs.getString('playback_sub_url') ??
        'https://sub.creamycake.org/v1/css1.json';

    await rust.updateConfig(
      bgm: bgm,
      bangumi: bangumi,
      mikan: mikan,
      playbackSub: playbackSub,
    );

    final disabledSources = prefs.getStringList('disabled_sources') ?? [];
    await rust.setDisabledSources(sources: disabledSources);

    // 应用启动时预加载播放源配置
    debugPrint('Preloading playback source config on app startup...');
    await rust.preloadPlaybackSourceConfig();
  } catch (e) {
    debugPrint('Failed to sync settings: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mikan Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Player player;
  late final VideoController controller;

  final TextEditingController _magnetController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = 'Enter a magnet link to start';

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
  }

  @override
  void dispose() {
    player.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  Future<void> _handlePlay() async {
    final magnet = _magnetController.text.trim();
    if (magnet.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing torrent...';
    });

    try {
      // Call Rust backend to get the stream URL
      final streamUrl = await startTorrent(magnet: magnet);

      setState(() {
        _statusMessage = 'Playing: $streamUrl';
      });

      await player.open(Media(streamUrl));
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mikan Player')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(child: Video(controller: controller)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoading)
                  const LinearProgressIndicator()
                else
                  Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _magnetController,
                        decoration: const InputDecoration(
                          hintText: 'magnet:?xt=urn:btih:...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handlePlay,
                      child: const Text('Play'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
