import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/src/rust/api/simple.dart';
import 'package:mikan_player/src/rust/frb_generated.dart';
import 'package:mikan_player/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Rust Logic
  await RustLib.init();

  // Initialize MediaKit
  MediaKit.ensureInitialized();

  // Load and sync settings
  await _syncSettings();

  runApp(const MyApp());
}

Future<void> _syncSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final bgm = prefs.getString('bgmlist_url') ?? 'https://bgmlist.com';
    final bangumi = prefs.getString('bangumi_url') ?? 'https://bangumi.tv';
    final mikan = prefs.getString('mikan_url') ?? 'https://mikanani.kas.pub';
    final btSub =
        prefs.getString('bt_sub_url') ??
        'https://sub.creamycake.org/v1/bt1.json';
    final playbackSub =
        prefs.getString('playback_sub_url') ??
        'https://sub.creamycake.org/v1/css1.json';

    await rust.updateConfig(
      bgm: bgm,
      bangumi: bangumi,
      mikan: mikan,
      btSub: btSub,
      playbackSub: playbackSub,
    );
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
