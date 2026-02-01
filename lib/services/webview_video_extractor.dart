import 'dart:async';
import 'dart:convert';
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
    // 标准 m3u8 格式
    RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*', caseSensitive: false),
    // 标准 mp4 格式（包括 .f0.mp4 这样的变体）
    RegExp(r'https?://[^\s"<>]+\.mp4(\?[^\s"<>]*)?', caseSensitive: false),
    // flv 格式
    RegExp(r'https?://[^\s"<>]+\.flv[^\s"<>]*', caseSensitive: false),
    // playlist.m3u8
    RegExp(r'https?://[^\s"<>]+/playlist\.m3u8', caseSensitive: false),
    // CDN 特征
    RegExp(r'akamaized\.net[^\s"<>]+', caseSensitive: false),
    RegExp(r'bilivideo\.com[^\s"<>]+', caseSensitive: false),
    RegExp(r'qq\.com/[^\s"<>]*\.(mp4|m3u8)', caseSensitive: false),
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
  int _totalUrlsChecked = 0;
  int _navigationCount = 0; // 记录主动导航到解析接口的次数

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(widget.timeout, () {
      if (!_isCompleted) {
        _log('⏱️ 超时！共拦截 $_totalUrlsChecked 个URL，但未找到匹配的视频URL');
        _complete(VideoExtractResult(
          error: '提取超时，未能在 ${widget.timeout.inSeconds} 秒内找到视频链接（共检查了 $_totalUrlsChecked 个URL）',
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
    _log('🎉 提取完成！videoUrl=${result.videoUrl}, error=${result.error}');
    widget.onResult(result);
  }

  bool _checkAndCaptureUrl(String url) {
    if (_capturedUrls.contains(url)) return false;
    _capturedUrls.add(url);
    _totalUrlsChecked++;

    final extractor = WebViewVideoExtractor();
    
    // 检查是否看起来像视频URL（用于调试）
    final looksLikeVideo = url.contains('.m3u8') || 
                           url.contains('.mp4') || 
                           url.contains('.flv') ||
                           url.contains('akamaized') ||
                           url.contains('bilivideo') ||
                           url.contains('qq.com');
    
    if (looksLikeVideo) {
      _log('🔍 检测到疑似视频URL: $url');
    }
    
    // 检查是否是播放器解析接口（这些URL通常在iframe中，需要实际导航）
    // 1. 路径特征：包含 /player/ 或 /parse/
    // 2. 文件特征：是 .php 或者带有参数的 .html
    // 3. 排除：静态资源目录 /static/，加载页 loading.html，以及初始URL自身
    final uri = Uri.tryParse(url);
    final queryParams = uri?.queryParameters ?? {};
    final hasParserParams = queryParams.containsKey('url') || 
                            queryParams.containsKey('v') || 
                            queryParams.containsKey('vid') || 
                            queryParams.containsKey('id') ||
                            queryParams.containsKey('code') ||
                            queryParams.containsKey('api') ||
                            queryParams.containsKey('input');

    final isPlayerParser = (url.contains('/player/') || url.contains('/parse')) &&
                          (url.contains('.php') || (url.contains('.html') && hasParserParams)) &&
                          !url.contains('loading.html') &&
                          !url.contains('/static/') &&
                          !url.contains(widget.url);
    
    if (isPlayerParser) {
      if (_navigationCount >= 3) {
        _log('⚠️ 已达到最大跳转尝试次数 ($_navigationCount)，忽略此接口: $url');
        return false;
      }
      _navigationCount++;
      _log('🎬 检测到播放器解析接口 (第$_navigationCount次跳转): $url');
      _log('   将导航到此URL以拦截内部视频请求...');
      // 导航到播放器解析页面，这样可以拦截其内部的网络请求
      _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      return false; // 不标记为完成，继续等待视频URL
    }
    
    // 记录所有URL（方便调试）
    if (_totalUrlsChecked <= 50) {
      debugPrint('[WebView-URL#$_totalUrlsChecked] $url');
    }
    
    // 首先用自定义正则检查
    if (widget.customVideoRegex != null && widget.customVideoRegex!.isNotEmpty) {
      final matched = extractor._matchesCustomRegex(url, widget.customVideoRegex);
      if (looksLikeVideo) {
        _log('   自定义正则 "${widget.customVideoRegex}" 匹配结果: $matched');
      }
      if (matched) {
        _log('✓ 匹配自定义正则: $url');
        _foundVideoUrl = url;
        _complete(VideoExtractResult(videoUrl: url));
        return true;
      }
    }

    // 然后用内置模式检查
    final builtInMatched = extractor._isVideoUrl(url);
    if (looksLikeVideo) {
      _log('   内置模式匹配结果: $builtInMatched');
    }
    if (builtInMatched) {
      _log('✓ 匹配内置模式: $url');
      _foundVideoUrl = url;
      _complete(VideoExtractResult(videoUrl: url));
      return true;
    }

    return false;
  }

  /// 注入JS脚本来静音所有媒体元素并阻止自动播放
  void _injectMuteScript(InAppWebViewController controller) {
    controller.evaluateJavascript(source: '''
      (function() {
        // 静音并暂停所有现有的video和audio元素
        function muteAllMedia() {
          document.querySelectorAll('video, audio').forEach(function(el) {
            el.muted = true;
            el.volume = 0;
            el.pause();
            el.autoplay = false;
            // 移除src以彻底阻止播放
            // el.src = '';
          });
        }
        
        // 立即执行
        muteAllMedia();
        
        // 监听DOM变化，处理动态添加的媒体元素
        var observer = new MutationObserver(function(mutations) {
          muteAllMedia();
        });
        observer.observe(document.body || document.documentElement, {
          childList: true,
          subtree: true
        });
        
        // 覆盖HTMLMediaElement的play方法，阻止自动播放
        var originalPlay = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function() {
          this.muted = true;
          this.volume = 0;
          // 返回一个resolved的Promise，避免网站检测到播放失败
          return Promise.resolve();
        };
        
        // 覆盖Audio构造函数
        var OriginalAudio = window.Audio;
        window.Audio = function(src) {
          var audio = new OriginalAudio(src);
          audio.muted = true;
          audio.volume = 0;
          return audio;
        };
      })();
    ''');
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
        // 禁止自动播放媒体，防止后台WebView播放声音
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: false,
        // 静音所有媒体
        isFraudulentWebsiteWarningEnabled: false,
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
        // 立即注入JS来静音所有媒体元素
        _injectMuteScript(controller);
      },
      onLoadStart: (controller, url) {
        _log('开始加载: $url');
        // 每次导航开始时注入静音脚本
        _injectMuteScript(controller);
      },
      onLoadStop: (controller, url) async {
        _log('页面加载完成: $url');
        _log('已拦截 $_totalUrlsChecked 个URL');
        
        // 页面加载完成后再次注入静音脚本，确保所有动态创建的媒体元素都被静音
        _injectMuteScript(controller);
        
        // 如果已经找到视频URL，就不需要从HTML提取了
        if (_isCompleted) {
          _log('已找到视频URL，跳过HTML提取');
          return;
        }
        
        // 页面加载完成后，尝试从页面内容中提取视频URL
        // 有些网站的视频URL是通过JS动态生成的
        try {
          final html = await controller.getHtml();
          if (html != null) {
            await _tryExtractFromHtml(html);
          }
        } catch (e) {
          _log('获取页面HTML失败: $e');
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? false) {
          _log('页面加载错误: ${error.description} (URL: ${request.url})');
        }
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        if (request.isForMainFrame ?? false) {
          _log('HTTP 错误 (${errorResponse.statusCode}): ${request.url}');
        }
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
  Future<void> _tryExtractFromHtml(String html) async {
    _log('开始从HTML提取视频URL...');

    // 尝试直接匹配视频URL（更宽松的模式）
    // 匹配 .mp4（包括 .f0.mp4 这样的变体）
    final urlRegex = RegExp(r'''https?://[^\s"<>'\\]+\.mp4(\?[^\s"<>'\\]*)?''', caseSensitive: false);
    final urlMatches = urlRegex.allMatches(html);
    for (final urlMatch in urlMatches) {
      final url = urlMatch.group(0)!;
      _log('从HTML提取到URL: $url');
      if (_checkAndCaptureUrl(url)) {
        return;
      }
    }
    
    // 也尝试匹配 m3u8
    final m3u8Regex = RegExp(r'''https?://[^\s"<>'\\]+\.m3u8[^\s"<>'\\]*''', caseSensitive: false);
    final m3u8Matches = m3u8Regex.allMatches(html);
    for (final m3u8Match in m3u8Matches) {
      final url = m3u8Match.group(0)!;
      _log('从HTML提取到URL: $url');
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
