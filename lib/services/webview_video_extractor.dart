import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;

/// 视频源信息
class VideoSourceInfo {
  final String sourceName;
  final String sourceIcon;
  final String searchUrl;
  final String? selectNames;
  final String? selectLinks;
  final String? selectEpisodeLists;
  final String? selectEpisodesFromList;
  final String? selectEpisodes;
  final String matchVideoUrl;
  final String? matchNestedUrl;
  final bool enableNestedUrl;

  VideoSourceInfo({
    required this.sourceName,
    required this.sourceIcon,
    required this.searchUrl,
    this.selectNames,
    this.selectLinks,
    this.selectEpisodeLists,
    this.selectEpisodesFromList,
    this.selectEpisodes,
    required this.matchVideoUrl,
    this.matchNestedUrl,
    this.enableNestedUrl = false,
  });
}

/// 搜索结果
class SearchResult {
  final String sourceName;
  final String sourceIcon;
  final String title;
  final String detailUrl;
  final List<ChannelInfo> channels;

  SearchResult({
    required this.sourceName,
    required this.sourceIcon,
    required this.title,
    required this.detailUrl,
    this.channels = const [],
  });
}

/// 线路信息
class ChannelInfo {
  final String name;
  final List<EpisodeInfo> episodes;

  ChannelInfo({required this.name, required this.episodes});
}

/// 剧集信息
class EpisodeInfo {
  final String name;
  final String playUrl;

  EpisodeInfo({required this.name, required this.playUrl});
}

/// WebView 视频提取结果
class VideoExtractResult {
  final String? videoUrl;
  final String? error;
  final Map<String, String> headers;

  VideoExtractResult({this.videoUrl, this.error, this.headers = const {}});

  bool get success => videoUrl != null && videoUrl!.isNotEmpty;
}

/// WebView 视频提取器
/// 通过 WebView 加载播放页面，拦截网络请求来获取真实视频 URL
class WebViewVideoExtractor {
  static final WebViewVideoExtractor _instance = WebViewVideoExtractor._internal();
  factory WebViewVideoExtractor() => _instance;
  WebViewVideoExtractor._internal();

  // 视频URL匹配正则
  static final List<RegExp> _videoPatterns = [
    RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*', caseSensitive: false),
    RegExp(r'https?://[^\s"<>]+\.mp4[^\s"<>]*', caseSensitive: false),
    RegExp(r'https?://[^\s"<>]+\.flv[^\s"<>]*', caseSensitive: false),
    RegExp(r'https?://[^\s"<>]+/playlist\.m3u8', caseSensitive: false),
    RegExp(r'akamaized\.net[^\s"<>]+', caseSensitive: false),
    RegExp(r'bilivideo\.com[^\s"<>]+', caseSensitive: false),
  ];

  // 需要排除的URL模式
  static final List<RegExp> _excludePatterns = [
    RegExp(r'\.js(\?|$)', caseSensitive: false),
    RegExp(r'\.css(\?|$)', caseSensitive: false),
    RegExp(r'\.png(\?|$)', caseSensitive: false),
    RegExp(r'\.jpg(\?|$)', caseSensitive: false),
    RegExp(r'\.gif(\?|$)', caseSensitive: false),
    RegExp(r'\.ico(\?|$)', caseSensitive: false),
    RegExp(r'\.woff', caseSensitive: false),
    RegExp(r'google', caseSensitive: false),
    RegExp(r'facebook', caseSensitive: false),
    RegExp(r'analytics', caseSensitive: false),
    RegExp(r'advertisement', caseSensitive: false),
  ];

  /// 检查URL是否是视频URL
  bool _isVideoUrl(String url) {
    // 先检查排除模式
    for (final pattern in _excludePatterns) {
      if (pattern.hasMatch(url)) {
        return false;
      }
    }
    // 再检查视频模式
    for (final pattern in _videoPatterns) {
      if (pattern.hasMatch(url)) {
        return true;
      }
    }
    return false;
  }

  /// 使用自定义正则检查URL
  bool _matchesCustomRegex(String url, String? regexStr) {
    if (regexStr == null || regexStr.isEmpty || regexStr == r'$^') {
      return false;
    }
    try {
      final regex = RegExp(regexStr);
      return regex.hasMatch(url);
    } catch (e) {
      debugPrint('Invalid regex: $regexStr, error: $e');
      return false;
    }
  }
}

/// WebView 视频提取 Widget
/// 这是一个隐藏的 WebView，用于加载播放页面并拦截视频URL
class WebViewVideoExtractorWidget extends StatefulWidget {
  final String url;
  final String? customVideoRegex;
  final Duration timeout;
  final void Function(VideoExtractResult result) onResult;
  final void Function(String message)? onLog;
  final bool showWebView; // 是否显示 WebView（调试用）

  const WebViewVideoExtractorWidget({
    super.key,
    required this.url,
    this.customVideoRegex,
    this.timeout = const Duration(seconds: 30),
    required this.onResult,
    this.onLog,
    this.showWebView = false,
  });

  @override
  State<WebViewVideoExtractorWidget> createState() => _WebViewVideoExtractorWidgetState();
}

class _WebViewVideoExtractorWidgetState extends State<WebViewVideoExtractorWidget> {
  InAppWebViewController? _webViewController;
  final Set<String> _capturedUrls = {};
  String? _foundVideoUrl;
  Timer? _timeoutTimer;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(widget.timeout, () {
      if (!_isCompleted) {
        _complete(VideoExtractResult(
          error: '提取超时，未能在 ${widget.timeout.inSeconds} 秒内找到视频链接',
        ));
      }
    });
  }

  void _log(String message) {
    debugPrint('[WebViewExtractor] $message');
    widget.onLog?.call(message);
  }

  void _complete(VideoExtractResult result) {
    if (_isCompleted) return;
    _isCompleted = true;
    _timeoutTimer?.cancel();
    widget.onResult(result);
  }

  bool _checkAndCaptureUrl(String url) {
    if (_capturedUrls.contains(url)) return false;
    _capturedUrls.add(url);

    final extractor = WebViewVideoExtractor();
    
    // 首先用自定义正则检查
    if (extractor._matchesCustomRegex(url, widget.customVideoRegex)) {
      _log('✓ 匹配自定义正则: $url');
      _foundVideoUrl = url;
      _complete(VideoExtractResult(videoUrl: url));
      return true;
    }

    // 然后用内置模式检查
    if (extractor._isVideoUrl(url)) {
      _log('✓ 匹配内置模式: $url');
      _foundVideoUrl = url;
      _complete(VideoExtractResult(videoUrl: url));
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webView = InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
      webViewEnvironment: webViewEnvironment,  // 使用全局 WebView 环境（Windows 需要）
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useHybridComposition: true,
        useShouldInterceptRequest: true,
        // 允许混合内容
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        // 设置 User-Agent
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _log('WebView 创建完成，开始加载: ${widget.url}');
      },
      onLoadStart: (controller, url) {
        _log('开始加载: $url');
      },
      onLoadStop: (controller, url) async {
        _log('页面加载完成: $url');
        
        // 页面加载完成后，尝试从页面内容中提取视频URL
        // 有些网站的视频URL是通过JS动态生成的
        try {
          final html = await controller.getHtml();
          if (html != null) {
            _tryExtractFromHtml(html);
          }
        } catch (e) {
          _log('获取页面HTML失败: $e');
        }
      },
      onReceivedError: (controller, request, error) {
        _log('加载错误: ${error.description}');
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();
        _checkAndCaptureUrl(url);
        return null; // 继续正常请求
      },
      onLoadResource: (controller, resource) {
        final url = resource.url.toString();
        _checkAndCaptureUrl(url);
      },
      onConsoleMessage: (controller, consoleMessage) {
        // 监听控制台消息，有些网站会在控制台输出视频URL
        final message = consoleMessage.message;
        if (message.contains('m3u8') || message.contains('mp4')) {
          _log('控制台消息: $message');
          // 尝试从消息中提取URL
          final urlRegex = RegExp(r'https?://[^\s"<>]+');
          final matches = urlRegex.allMatches(message);
          for (final match in matches) {
            _checkAndCaptureUrl(match.group(0)!);
          }
        }
      },
    );

    if (widget.showWebView) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
        ),
        child: webView,
      );
    }

    // 隐藏的 WebView（1x1像素）
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0,
        child: webView,
      ),
    );
  }

  /// 尝试从HTML内容中提取视频URL
  void _tryExtractFromHtml(String html) {
    // 尝试提取 player_aaaa 变量
    final playerAaaaRegex = RegExp(r'var\s+player_aaaa\s*=\s*(\{[^;]+\})');
    final match = playerAaaaRegex.firstMatch(html);
    if (match != null) {
      _log('找到 player_aaaa 变量');
      // 这里可以进一步解析，但已经在 Rust 端实现了
    }

    // 尝试直接匹配视频URL
    final urlRegex = RegExp(r'''https?://[^\s"<>'\\]+\.(m3u8|mp4)[^\s"<>'\\]*''');
    final urlMatches = urlRegex.allMatches(html);
    for (final urlMatch in urlMatches) {
      final url = urlMatch.group(0)!;
      if (_checkAndCaptureUrl(url)) {
        return;
      }
    }
  }
}

/// 全网搜索管理器
class GlobalSearchManager {
  static final GlobalSearchManager _instance = GlobalSearchManager._internal();
  factory GlobalSearchManager() => _instance;
  GlobalSearchManager._internal();

  /// 从播放页面提取视频URL
  /// 返回一个 Widget 来执行提取，结果通过回调返回
  Widget extractVideoFromPage({
    required String pageUrl,
    String? customVideoRegex,
    Duration timeout = const Duration(seconds: 30),
    required void Function(VideoExtractResult result) onResult,
    void Function(String message)? onLog,
    bool showWebView = false,
  }) {
    return WebViewVideoExtractorWidget(
      url: pageUrl,
      customVideoRegex: customVideoRegex,
      timeout: timeout,
      onResult: onResult,
      onLog: onLog,
      showWebView: showWebView,
    );
  }
}
