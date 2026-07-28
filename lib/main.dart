import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/src/rust/api/simple.dart';
import 'package:mikan_player/src/rust/rust_init.dart';
import 'package:mikan_player/ui/screens/home_screen.dart';
import 'package:mikan_player/ui/widgets/windows_desktop_frame.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_strip.dart';
import 'package:mikan_player/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/simple.dart' as rust;
import 'package:mikan_player/src/rust/api/network.dart' as network;
import 'package:mikan_player/src/rust/api/config.dart' as rust_config;
import 'package:mikan_player/src/http_overrides.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/services/bangumi_reverse_proxy_service.dart';
import 'package:mikan_player/services/bangumi_ech_service.dart';
import 'package:mikan_player/services/bangumi_data_service.dart';
import 'package:mikan_player/services/captcha_ocr_service.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/services/bangumi_auth_manager.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/services/settings_service.dart';
import 'package:mikan_player/services/workspace_lifecycle.dart';
import 'package:mikan_player/services/workspace_route_observer.dart';
import 'package:mikan_player/utils/app_directories.dart';
import 'package:mikan_player/utils/url_latency.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

/// 全局 WebView 环境（Windows 平台需要）
WebViewEnvironment? webViewEnvironment;
bool _windowsDesktopFrameEnabled = false;
const MethodChannel _appLifecycleChannel = MethodChannel(
  'mikan_player/app_lifecycle',
);

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorLogging();
      await _initializeWindowsDesktopFrame();

      // 桌面端保留较大的解码缓存；Android 需要限制长时间浏览图片时的
      // 常驻内存增长。
      if (!kIsWeb) {
        final cache = PaintingBinding.instance.imageCache;
        if (defaultTargetPlatform == TargetPlatform.android) {
          cache.maximumSize = 500;
          cache.maximumSizeBytes = 128 << 20;
        } else {
          cache.maximumSize = 2000;
          cache.maximumSizeBytes = 512 << 20;
        }
      }

      // Initialize Rust Logic with platform-specific paths
      // IMPORTANT: On Windows, use a unified app data directory to avoid debug/release path conflicts
      final appSupportDir = await AppDirectories.getUnifiedAppDataDirectory();
      final cacheDir = Directory('${appSupportDir.path}/cache');

      // Check for custom download directory setting
      final prefs = await SharedPreferences.getInstance();
      final customDownloadDir = prefs.getString('download_dir_custom');
      final downloadDirPath =
          customDownloadDir ?? '${appSupportDir.path}/downloads';
      final downloadDir = Directory(downloadDirPath);

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      debugPrint('App data directory: ${appSupportDir.path}');
      debugPrint('Cache directory: ${cacheDir.path}');
      debugPrint('Download directory: ${downloadDir.path}');

      await initRustLib();
      await rust.initEngine(
        cacheDir: cacheDir.path,
        downloadDir: downloadDir.path,
      );

      // Initialize Bangumi Cache Database
      await CacheManager.instance.initialize();

      // Restore any persisted Bangumi OAuth token first so it is in Rust
      // config before UserManager's /v0/me refresh runs.
      await BangumiAuthManager().init();

      // Initialize UserManager
      await UserManager().init();

      // Drain offline sync queue after auth/user init
      unawaited(drainBangumiSyncQueue());

      // Initialize SettingsService
      await SettingsService().init();

      // Initialize DownloadManager (load saved BT tasks)
      await DownloadManager().initialize();

      // Initialize MediaKit
      MediaKit.ensureInitialized();

      // Initialize WebView2 on Windows
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final availableVersion = await WebViewEnvironment.getAvailableVersion();
        if (availableVersion != null) {
          // 使用统一的应用数据目录存储 WebView2 数据
          final webViewDataPath = '${appSupportDir.path}\\WebView2';

          webViewEnvironment = await WebViewEnvironment.create(
            settings: WebViewEnvironmentSettings(
              userDataFolder: webViewDataPath,
            ),
          );
          debugPrint('WebView2 initialized: $availableVersion');
        } else {
          debugPrint(
            'WARNING: WebView2 Runtime not found. Some features may not work.',
          );
        }
      }

      // Apply local settings needed by the runtime before the first screen renders.
      // Network-bound warm-up is deferred until after the first frame.
      await _syncRuntimeSettings();

      // Setup Proxy
      final proxy = await network.getSystemProxy();
      if (proxy != null) {
        debugPrint('Setting global proxy: $proxy');
        HttpOverrides.global = MyHttpOverrides(proxy);
      }

      runApp(const MyApp());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runDeferredStartupTasks());
      });
    },
    (Object error, StackTrace stackTrace) {
      debugPrint('[Startup] Uncaught zone error: $error');
      debugPrint('$stackTrace');
    },
  );
}

Future<void> _initializeWindowsDesktopFrame() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;

  try {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(720, 520),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
    _windowsDesktopFrameEnabled = true;
  } catch (error, stackTrace) {
    // Keep the runner's native title bar when custom chrome is unavailable.
    debugPrint('Windows desktop frame initialization failed: $error');
    debugPrint('$stackTrace');
    try {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    } catch (_) {
      // The plugin itself may be unavailable; the runner remains usable.
    }
  }
}

void _installGlobalErrorLogging() {
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[Startup] FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('${details.stack}');
    }
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError =
      (Object error, StackTrace stackTrace) {
        debugPrint('[Startup] PlatformDispatcher error: $error');
        debugPrint('$stackTrace');
        return true;
      };
}

Future<void> _syncRuntimeSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final bgm = prefs.getString('bgmlist_url') ?? 'https://bgmlist.com';
    final bangumi = prefs.getString('bangumi_url') ?? 'https://bangumi.tv';
    final mikan = prefs.getString('mikan_url') ?? 'https://mikanani.kas.pub';
    final playbackSub =
        prefs.getString('playback_sub_url') ??
        'https://gitee.com/edicl/online-subscription/raw/master/online.json';
    final useReverseProxy = await BangumiReverseProxyService.load();
    final useEch = await BangumiEchService.load();

    await rust.updateConfig(
      bgm: bgm,
      bangumi: bangumi,
      mikan: mikan,
      playbackSub: playbackSub,
      useReverseProxy: useReverseProxy,
    );
    await rust.setBangumiUseEch(enabled: useEch);

    final disabledSources = prefs.getStringList('disabled_sources') ?? [];
    await rust.setDisabledSources(sources: disabledSources);

    await BangumiRequestModeService.syncToRust();

    final maxConcurrentSearches = prefs.getInt('max_concurrent_searches') ?? 3;
    await rust.setMaxConcurrentSearches(limit: maxConcurrentSearches);
  } catch (e) {
    debugPrint('Failed to sync runtime settings: $e');
  }
}

Future<void> _runDeferredStartupTasks() async {
  try {
    debugPrint('[Startup] Deferred startup tasks start');
    final prefs = await SharedPreferences.getInstance();
    final initialUrls = await _ensureOptimalInitialBaseUrls(prefs);

    if (initialUrls.$1 != null || initialUrls.$2 != null) {
      final bgm = prefs.getString('bgmlist_url') ?? 'https://bgmlist.com';
      final bangumi =
          initialUrls.$1 ??
          prefs.getString('bangumi_url') ??
          'https://bangumi.tv';
      final mikan =
          initialUrls.$2 ??
          prefs.getString('mikan_url') ??
          'https://mikanani.kas.pub';
      final playbackSub =
          prefs.getString('playback_sub_url') ??
          'https://gitee.com/edicl/online-subscription/raw/master/online.json';
      final useReverseProxy = await BangumiReverseProxyService.load();

      await rust.updateConfig(
        bgm: bgm,
        bangumi: bangumi,
        mikan: mikan,
        playbackSub: playbackSub,
        useReverseProxy: useReverseProxy,
      );
    }

    debugPrint('Preloading playback source config after first frame...');
    await rust.preloadPlaybackSourceConfig();
    debugPrint('[Startup] Playback source preload done');

    // Warm up the ECHConfig cache so the first bangumi request can use ECH.
    // Failures are swallowed inside the Rust side; the HTTP layer will fall
    // back to plaintext SNI when no ECHConfig is available.
    await BangumiEchService.warmup();
    debugPrint('[Startup] ECH warmup done');

    // Warm the offline bangumi-data cache (fallback for the schedule API).
    // Fire-and-forget — the ~7 MB download must not block the UI, and the live
    // API remains the primary path.
    debugPrint('[Startup] bangumi-data warmup scheduled');
    unawaited(BangumiDataService.warmup());

    // Pre-warm the OCR model so it's ready before the first captcha is needed.
    // Cold start takes ~10s; inference is only ~20ms once loaded.
    unawaited(CaptchaOcrService.instance.ensureInitialized());
    debugPrint('[Startup] Captcha OCR warmup scheduled');

    if (prefs.getStringList('disabled_sources') == null) {
      final initialDisabledSources =
          await _loadInitialDisabledSourcesFromCache();
      await prefs.setStringList('disabled_sources', initialDisabledSources);
      await rust.setDisabledSources(sources: initialDisabledSources);
      debugPrint(
        'Initialized disabled_sources from subscription defaults: '
        '${initialDisabledSources.length} disabled',
      );
    }
    debugPrint('[Startup] Deferred startup tasks done');
  } catch (e) {
    debugPrint('Deferred startup tasks failed: $e');
  }
}

Future<(String?, String?)> _ensureOptimalInitialBaseUrls(
  SharedPreferences prefs,
) async {
  final hasBangumiUrl = prefs.getString('bangumi_url') != null;
  final hasMikanUrl = prefs.getString('mikan_url') != null;
  if (hasBangumiUrl && hasMikanUrl) {
    return (null, null);
  }

  final bangumiFuture = hasBangumiUrl
      ? Future<String?>.value(null)
      : selectFastestUrl([
          'https://bangumi.tv',
          'https://bgm.tv',
          'https://chii.in',
        ]);
  final mikanFuture = hasMikanUrl
      ? Future<String?>.value(null)
      : selectFastestUrl([
          'https://mikanani.kas.pub',
          'https://mikan2.yujiangqaq.com',
          'https://mikan.makura.cc',
          'https://mikanani.me',
        ]);

  final results = await Future.wait<String?>([bangumiFuture, mikanFuture]);
  final bangumiUrl = results[0];
  final mikanUrl = results[1];

  if (bangumiUrl != null) {
    await prefs.setString('bangumi_url', bangumiUrl);
    debugPrint('Initialized fastest Bangumi base URL: $bangumiUrl');
  }
  if (mikanUrl != null) {
    await prefs.setString('mikan_url', mikanUrl);
    debugPrint('Initialized fastest Mikan base URL: $mikanUrl');
  }

  return (bangumiUrl, mikanUrl);
}

bool? _parseSubscriptionBool(dynamic value) {
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

Future<List<String>> _loadInitialDisabledSourcesFromCache() async {
  try {
    final cacheDir = await rust_config.getCacheDir();
    final cacheFile = File(
      '$cacheDir${Platform.pathSeparator}playback_sources_cache.json',
    );
    if (!await cacheFile.exists()) {
      return const [];
    }

    final content = await cacheFile.readAsString();
    final root = jsonDecode(content);
    if (root is! Map) return const [];

    final exported = root['exportedMediaSourceDataList'];
    if (exported is! Map) return const [];

    final mediaSources = exported['mediaSources'];
    if (mediaSources is! List) return const [];

    final disabledSources = <String>[];
    for (final item in mediaSources) {
      if (item is! Map) continue;
      final arguments = item['arguments'];
      if (arguments is! Map) continue;

      final name = arguments['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;

      final parsed = _parseSubscriptionBool(arguments['defaultEnabled']);
      if (parsed == false) {
        disabledSources.add(name);
      }
    }

    return disabledSources;
  } catch (e) {
    debugPrint('Failed to initialize source toggles from cache: $e');
    return const [];
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final WorkspaceTabController _workspaceController;
  late final WorkspaceTabHostController _workspaceHostController;

  @override
  void initState() {
    _workspaceController = WorkspaceTabController();
    _workspaceHostController = WorkspaceTabHostController();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && Platform.isWindows) {
      _appLifecycleChannel.setMethodCallHandler(_handleNativeLifecycleCall);
      unawaited(_notifyNativeCloseHandlerReady());
    }
  }

  Future<void> _notifyNativeCloseHandlerReady() async {
    try {
      await _appLifecycleChannel.invokeMethod<void>('ready');
    } on MissingPluginException {
      // Widget tests and non-runner embeddings retain default close behavior.
    }
  }

  @override
  void dispose() {
    _workspaceHostController.dispose();
    _workspaceController.dispose();
    DownloadManager().saveLibtorrentResumeDataForShutdown();
    if (!kIsWeb && Platform.isWindows) {
      _appLifecycleChannel.setMethodCallHandler(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleNativeLifecycleCall(MethodCall call) async {
    if (call.method != 'requestClose') return;
    DownloadManager().saveLibtorrentResumeDataForShutdown();
    await AppShutdownCoordinator.instance.prepareToClose();
    await _appLifecycleChannel.invokeMethod<void>('closeReady');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DownloadManager().handleAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      DownloadManager().saveLibtorrentResumeDataForShutdown();
    }
  }

  @override
  Future<ui.AppExitResponse> didRequestAppExit() async {
    DownloadManager().saveLibtorrentResumeDataForShutdown();
    await AppShutdownCoordinator.instance.prepareToClose();
    return ui.AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        return ExcludeSemantics(
          child: MaterialApp(
            locale: SettingsService().locale,
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(
              seedColor: SettingsService().seedColor,
              useMaterial3Color: SettingsService().useMaterial3Color,
              pureBackground: SettingsService().pureBackground,
            ),
            darkTheme: AppTheme.dark(
              seedColor: SettingsService().seedColor,
              useMaterial3Color: SettingsService().useMaterial3Color,
              pureBackground: SettingsService().pureBackground,
            ),
            themeMode: SettingsService().themeMode,
            navigatorObservers: [workspaceRouteObserver],
            builder: (context, child) {
              if (!_windowsDesktopFrameEnabled) {
                return child ?? const SizedBox.shrink();
              }
              return WindowsDesktopFrame(
                tabStrip: WorkspaceTabStrip(
                  controller: _workspaceController,
                  hostController: _workspaceHostController,
                ),
                contextToolbar: WorkspaceContextToolbar(
                  controller: _workspaceController,
                  hostController: _workspaceHostController,
                ),
                onNewTab: () => _workspaceController.create(),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _windowsDesktopFrameEnabled
                ? WorkspaceTabHost(
                    controller: _workspaceController,
                    hostController: _workspaceHostController,
                  )
                : const HomeScreen(),
          ),
        );
      },
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
  String _statusMessage = '';

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
      _statusMessage = AppLocalizations.of(context).statusInitializing;
    });

    try {
      // Call Rust backend to get the stream URL
      final streamUrl = await startTorrent(magnet: magnet);

      setState(() {
        _statusMessage = AppLocalizations.of(context).statusPlaying(streamUrl);
      });

      await player.open(Media(streamUrl));
    } catch (e) {
      setState(() {
        _statusMessage = AppLocalizations.of(context).statusError(e.toString());
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _statusMessage = _statusMessage.isEmpty
        ? AppLocalizations.of(context).statusEnterMagnet
        : _statusMessage;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).homeTitle)),
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
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).magnetHint,
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
                      child: Text(AppLocalizations.of(context).playButton),
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
