import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;
import 'package:mikan_player/services/webview_cookie_janitor.dart';

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
  static final WebViewVideoExtractor _instance =
      WebViewVideoExtractor._internal();
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
    // 图片流格式（部分站点实际可播资源）
    RegExp(r'https?://[^\s"<>]+\.image[^\s"<>]*', caseSensitive: false),
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

  /// 使用自定义正则提取URL（优先提取命名捕获组 'v'）
  String? _extractUrlWithCustomRegex(String url, String? regexStr) {
    if (regexStr == null || regexStr.isEmpty || regexStr == r'$^') {
      return null;
    }
    try {
      final regex = RegExp(regexStr);
      final match = regex.firstMatch(url);
      if (match != null) {
        String? candidate;
        // 尝试提取命名捕获组 'v'
        try {
          final capturedUrl = match.namedGroup('v');
          if (capturedUrl != null && capturedUrl.isNotEmpty) {
            candidate = capturedUrl;
          }
        } catch (e) {
          // 如果没有命名捕获组，使用第一个捕获组或整个匹配
        }
        // 如果没有命名捕获组 'v'，尝试使用第一个普通捕获组
        if (candidate == null && match.groupCount > 0) {
          final group1 = match.group(1);
          if (group1 != null && group1.isNotEmpty) {
            candidate = group1;
          }
        }
        // 最后才使用整个匹配
        candidate ??= match.group(0);
        if (candidate == null || candidate.isEmpty) {
          return null;
        }
        // 当提取到的候选值不是绝对 URL 时（例如正则只匹配到了路径/域名片段，
        // 如 "/video/tos/alisg/" 或 "bilivideo.com"），说明该自定义正则只是用来
        // 「判定」拦截到的请求 URL 是否为视频地址，真正的视频地址就是被拦截的完整
        // 请求 URL 本身。直接返回片段会导致后续探测因缺少 host 而失败，且若该片段
        // 被当作提取结果，会污染并发提取状态。此时应回退为完整的拦截 URL。
        if (_isAbsoluteUrl(candidate)) {
          return candidate;
        }
        return _isAbsoluteUrl(url) ? url : candidate;
      }
    } catch (e) {
      debugPrint('Error extracting with regex: $regexStr, error: $e');
    }
    return null;
  }

  bool _isAbsoluteUrl(String s) {
    return s.startsWith('http://') || s.startsWith('https://');
  }
}

/// WebView 视频提取 Widget
/// 这是一个隐藏的 WebView，用于加载播放页面并拦截视频URL
class WebViewVideoExtractorWidget extends StatefulWidget {
  final String url;
  final String? customVideoRegex;
  final bool enableNestedUrl;
  final String? matchNestedUrl;
  final Map<String, String>? headers;
  final String? cookies;
  final Duration timeout;
  final void Function(VideoExtractResult result) onResult;
  final void Function(String message)? onLog;
  final bool showWebView; // 是否显示 WebView（调试用）

  const WebViewVideoExtractorWidget({
    super.key,
    required this.url,
    this.customVideoRegex,
    this.enableNestedUrl = false,
    this.matchNestedUrl,
    this.headers,
    this.cookies,
    this.timeout = const Duration(seconds: 30),
    required this.onResult,
    this.onLog,
    this.showWebView = false,
  });

  @override
  State<WebViewVideoExtractorWidget> createState() =>
      _WebViewVideoExtractorWidgetState();
}

class _WebViewVideoExtractorWidgetState
    extends State<WebViewVideoExtractorWidget> {
  static const String _skipParserNavigationHeader =
      'x-opencode-skip-parser-navigation';
  InAppWebViewController? _webViewController;
  final Set<String> _capturedUrls = {};
  Timer? _timeoutTimer;
  bool _isCompleted = false;
  int _totalUrlsChecked = 0;
  int _navigationCount = 0;
  final List<({String name, String domain, String path})> _cookiesWrittenToJar = [];

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(widget.timeout, () {
      if (!_isCompleted) {
        _log('⏱️ 超时！共拦截 $_totalUrlsChecked 个URL，但未找到匹配的视频URL');
        _complete(
          VideoExtractResult(
            error:
                '提取超时，未能在 ${widget.timeout.inSeconds} 秒内找到视频链接（共检查了 $_totalUrlsChecked 个URL）',
          ),
        );
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

  /// Idempotent, externally-safe cancellation. Marks this worker as completed
  /// so any in-flight async op will no longer fire `widget.onResult`, cancels
  /// the timeout, and best-effort stops any ongoing WebView load.
  ///
  /// NOTE: 在当前步骤里 `_PlayerPageState._cancelLowerPriorityExtraction`
  /// 并不直接调用本方法 —— 它只能拿到 pageKey 而无法拿到这里的 State 句柄。
  /// 真正的拆解靠 (a) `_activeWebViews` 记账移除 + (b) `_onWebViewResult`
  /// late-callback 守卫 + (c) 下次 build 因子节点不在列表触发的
  /// dispose-on-unmount。本方法为未来可拿到句柄时预留，且在 dispose 路径
  /// 之外提供显式停止能力。
  void cancel() {
    if (_isCompleted) return;
    _isCompleted = true;
    _timeoutTimer?.cancel();
    final controller = _webViewController;
    if (controller != null) {
      try {
        unawaited(controller.stopLoading());
      } catch (e) {
        debugPrint('[WebViewExtractor] cancel() stopLoading error: $e');
      }
    }
  }

  Map<String, String> _normalizedConfiguredHeaders() {
    final normalized = <String, String>{};
    final sourceHeaders = widget.headers;
    if (sourceHeaders != null) {
      for (final entry in sourceHeaders.entries) {
        final rawKey = entry.key.trim();
        final value = entry.value.trim();
        if (rawKey.isEmpty || value.isEmpty) {
          continue;
        }
        final lowerKey = rawKey.toLowerCase();
        final normalizedKey = switch (lowerKey) {
          'useragent' => 'User-Agent',
          'referer' => 'Referer',
          'cookie' => 'Cookie',
          _ => rawKey,
        };
        normalized[normalizedKey] = value;
      }
    }
    final cookies = widget.cookies?.trim();
    if (cookies != null && cookies.isNotEmpty) {
      normalized.putIfAbsent('Cookie', () => cookies);
    }
    return normalized;
  }

  /// Whether this extraction task needs its cookies injected into the WebView
  /// [CookieManager] jar (versus merely echoed on outbound request headers,
  /// which [_normalizedConfiguredHeaders] already handles via the `Cookie`
  /// header).
  ///
  /// The STEP 1.0 audit confirmed that every [WebViewVideoExtractorWidget]
  /// call site (`player_page.dart` and `subscription_debug_page.dart`) passes
  /// `cookies` that originate from `MatchVideo.cookies` and are attached
  /// purely as outbound `Cookie` headers by the Rust side. No source config
  /// or play-page JS documented in the audit reads `document.cookie`, and no
  /// bundled source JSON sets non-empty cookies. The only confirmed
  /// jar-dependent WebView flow in this codebase lives in
  /// [CaptchaWebViewBypassWidget] (a different widget), which reads cookies
  /// back out of the jar via `_getCookiesForUrl`. We therefore default this
  /// extraction widget to header-only and skip the jar write/delete entirely.
  /// confirmed (e.g. a source whose play-page JS reads `document.cookie`),
  /// introduce a widget flag/field that identifies it and return `true` here
  /// for that case. Do NOT hardcode source URLs/hostnames without evidence.
  bool _needsCookieJarInjection() {
    return false;
  }

  Future<void> _setTaskCookiesInCookieManager() async {
    final cookies = widget.cookies?.trim();
    if (cookies == null || cookies.isEmpty) return;
    final uri = Uri.tryParse(widget.url);
    if (uri == null || uri.host.isEmpty) return;
    try {
      final cookieManager = CookieManager();
      _log('Injecting task cookies into CookieManager (jar-dependent source)');
      for (final part in cookies.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex < 0) continue;
        final name = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();
        if (name.isEmpty) continue;
        cookieManager.setCookie(
          url: WebUri('${uri.scheme}://${uri.host}'),
          name: name,
          value: value,
          domain: uri.host,
          path: '/',
        );
        _cookiesWrittenToJar.add((name: name, domain: uri.host, path: '/'));
      }
    } catch (e) {
      _log('Failed to set cookies in CookieManager: $e');
    }
  }

  bool _shouldSkipParserNavigation() {
    final headers = _normalizedConfiguredHeaders();
    final value = headers[_skipParserNavigationHeader]?.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes' || value == 'on';
  }

  String _defaultRefererFor(String url) {
    final sourcePage = Uri.tryParse(widget.url);
    if (sourcePage != null &&
        sourcePage.scheme.isNotEmpty &&
        sourcePage.host.isNotEmpty) {
      return sourcePage.origin.endsWith('/')
          ? sourcePage.origin
          : '${sourcePage.origin}/';
    }
    final parsed = Uri.tryParse(url);
    if (parsed != null && parsed.scheme.isNotEmpty && parsed.host.isNotEmpty) {
      return parsed.origin.endsWith('/') ? parsed.origin : '${parsed.origin}/';
    }
    return widget.url;
  }

  Map<String, String> _mergeRequestHeaders(
    String url, {
    Map<String, String>? requestHeaders,
  }) {
    final merged = _normalizedConfiguredHeaders();
    if (requestHeaders != null) {
      for (final entry in requestHeaders.entries) {
        final key = entry.key.trim();
        final value = entry.value.trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        final lowerKey = key.toLowerCase();
        final normalizedKey = switch (lowerKey) {
          'useragent' => 'User-Agent',
          'referer' => 'Referer',
          'cookie' => 'Cookie',
          _ => key,
        };
        merged[normalizedKey] = value;
      }
    }

    if (!merged.containsKey('Referer') && !merged.containsKey('referer')) {
      merged['Referer'] = _defaultRefererFor(url);
    }
    return merged;
  }

  bool _checkAndCaptureUrl(String url, {Map<String, String>? headers}) {
    if (_capturedUrls.contains(url)) return false;
    _capturedUrls.add(url);
    _totalUrlsChecked++;

    final extractor = WebViewVideoExtractor();

    // 检查是否看起来像视频URL（用于调试）
    final looksLikeVideo =
        url.contains('.m3u8') ||
        url.contains('.mp4') ||
        url.contains('.flv') ||
        url.contains('.image') ||
        url.contains('akamaized') ||
        url.contains('bilivideo') ||
        url.contains('qq.com') ||
        url.contains('byteimg.com');

    if (looksLikeVideo) {
      _log('🔍 检测到疑似视频URL: $url');
    }

    // 确保 headers 包含 Referer，如果没有则使用初始页面URL
    final finalHeaders = _mergeRequestHeaders(url, requestHeaders: headers);

    if (looksLikeVideo) {
      _log('   Headers provided: ${headers?.keys.join(", ")}');
    }

    if (looksLikeVideo && finalHeaders['Referer'] != null) {
      _log('   Effective Referer: ${finalHeaders['Referer']}');
    }

    // 检查是否是播放器解析接口（这些URL通常在iframe中，需要实际导航）
    // 1. 路径特征：包含 /player/ 或 /parse/
    // 2. 文件特征：是 .php 或者带有参数的 .html
    // 3. 排除：静态资源目录 /static/，加载页 loading.html，以及初始URL自身
    final uri = Uri.tryParse(url);
    final queryParams = uri?.queryParameters ?? {};
    final hasParserParams =
        queryParams.containsKey('url') ||
        queryParams.containsKey('v') ||
        queryParams.containsKey('vid') ||
        queryParams.containsKey('id') ||
        queryParams.containsKey('code') ||
        queryParams.containsKey('api') ||
        queryParams.containsKey('input');

    final isPlayerParser =
        ((url.contains('/player/') ||
                url.contains('/parse') ||
                (uri?.host.contains('player.') ?? false)) &&
            (url.contains('.php') ||
                url.contains('.html') ||
                hasParserParams)) &&
        !url.contains('loading.html') &&
        !url.contains('/static/') &&
        !url.contains(widget.url);

    final skipParserNavigation = _shouldSkipParserNavigation();

    // 当 enableNestedUrl 且 matchNestedUrl 有效时，使用配置的正则检测嵌套URL
    final effectiveMatchNestedUrl =
        widget.enableNestedUrl &&
                widget.matchNestedUrl != null &&
                widget.matchNestedUrl!.isNotEmpty &&
                widget.matchNestedUrl != r'$^'
            ? widget.matchNestedUrl
            : null;

    if (effectiveMatchNestedUrl != null &&
        extractor._matchesCustomRegex(url, effectiveMatchNestedUrl)) {
      if (skipParserNavigation) {
        _log('⏭️ 已按源配置跳过嵌套URL导航: $url');
        return false;
      }
      if (_navigationCount >= 3) {
        _log('⚠️ 已达到最大跳转尝试次数 ($_navigationCount)，忽略此嵌套URL: $url');
        return false;
      }

      final extractedNestedUrl = extractor._extractUrlWithCustomRegex(
        url,
        effectiveMatchNestedUrl,
      );
      final navigationUrl = extractedNestedUrl ?? url;

      _navigationCount++;
      _log('🎬 matchNestedUrl匹配到嵌套URL (第$_navigationCount次跳转): $url');
      _log('   提取的嵌套URL: $navigationUrl');
      _log('   将导航到此URL以拦截内部视频请求...');
      _webViewController?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(navigationUrl),
          headers: finalHeaders.isEmpty ? null : finalHeaders,
        ),
      );
      return false;
    }

    // 当URL命中播放器解析接口时，先尝试用自定义正则直接提取视频URL
    // 这对于 url=(?<v>...) 这种能直接从参数中提取真实视频地址的场景特别重要
    if (isPlayerParser && widget.customVideoRegex != null && widget.customVideoRegex!.isNotEmpty) {
      final matched = extractor._matchesCustomRegex(url, widget.customVideoRegex);
      if (matched) {
        final extractedUrl = extractor._extractUrlWithCustomRegex(url, widget.customVideoRegex);
        if (extractedUrl != null && extractedUrl.isNotEmpty && extractedUrl != url) {
          _log('🎯 播放器接口中通过自定义正则直接提取到视频URL: $extractedUrl');
          _complete(VideoExtractResult(videoUrl: extractedUrl, headers: finalHeaders));
          return true;
        }
      }
    }

    if (isPlayerParser) {
      if (skipParserNavigation) {
        _log('⏭️ 已按源配置跳过内联播放器导航: $url');
        return false;
      }
      if (_navigationCount >= 3) {
        _log('⚠️ 已达到最大跳转尝试次数 ($_navigationCount)，忽略此接口: $url');
        return false;
      }
      _navigationCount++;
      _log('🎬 检测到播放器解析接口 (第$_navigationCount次跳转): $url');
      _log('   将导航到此URL以拦截内部视频请求...');
      // 导航到播放器解析页面，这样可以拦截其内部的网络请求
      _webViewController?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(url),
          headers: finalHeaders.isEmpty ? null : finalHeaders,
        ),
      );
      return false; // 不标记为完成，继续等待视频URL
    }

    // 记录所有URL（方便调试）
    if (_totalUrlsChecked <= 50) {
      debugPrint('[WebView-URL#$_totalUrlsChecked] $url');
    }

    // 首先用自定义正则检查
    if (widget.customVideoRegex != null &&
        widget.customVideoRegex!.isNotEmpty) {
      final matched = extractor._matchesCustomRegex(
        url,
        widget.customVideoRegex,
      );
      if (looksLikeVideo) {
        _log('   自定义正则 "${widget.customVideoRegex}" 匹配结果: $matched');
      }
      if (matched) {
        // 优先提取捕获组 'v' 的值，如果没有则使用整个URL
        final extractedUrl = extractor._extractUrlWithCustomRegex(
          url,
          widget.customVideoRegex,
        );
        if (extractedUrl != null && extractedUrl.isNotEmpty) {
          _log('✓ 匹配自定义正则并提取捕获组: $extractedUrl');
          _complete(
            VideoExtractResult(videoUrl: extractedUrl, headers: finalHeaders),
          );
          return true;
        } else {
          _log('✓ 匹配自定义正则（无捕获组）: $url');
          _complete(VideoExtractResult(videoUrl: url, headers: finalHeaders));
          return true;
        }
      }
      // 如果有自定义正则但不匹配，不继续用内置模式（防止被不精确的兜底规则捕获）
      return false;
    }

    // 只有在没有自定义正则时，才用内置模式检查
    final builtInMatched = extractor._isVideoUrl(url);
    if (looksLikeVideo) {
      _log('   内置模式匹配结果: $builtInMatched');
    }
    if (builtInMatched) {
      _log('✓ 匹配内置模式: $url');
      _complete(VideoExtractResult(videoUrl: url, headers: finalHeaders));
      return true;
    }

    return false;
  }

  /// 注入JS脚本来静音所有媒体元素并阻止自动播放
  void _injectMuteScript(InAppWebViewController controller) {
    controller.evaluateJavascript(
      source: '''
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
    ''',
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    if (_cookiesWrittenToJar.isNotEmpty) {
      final janitor = WebViewCookieJanitor();
      for (final entry in _cookiesWrittenToJar) {
        janitor.requestCleanup(
          host: entry.domain,
          cookieName: entry.name,
          path: entry.path,
        );
      }
      _cookiesWrittenToJar.clear();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configuredHeaders = _normalizedConfiguredHeaders();
    final configuredUserAgent =
        configuredHeaders['User-Agent'] ?? configuredHeaders['userAgent'];
    final webView = InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.url),
        headers: configuredHeaders.isEmpty
            ? null
            : _mergeRequestHeaders(widget.url, requestHeaders: configuredHeaders),
      ),
      webViewEnvironment: webViewEnvironment, // 使用全局 WebView 环境（Windows 需要）
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
        userAgent:
            configuredUserAgent ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (controller) async {
        _webViewController = controller;
        _log('WebView 创建完成，开始加载: ${widget.url}');
        if (_needsCookieJarInjection()) {
          await _setTaskCookiesInCookieManager();
        }
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
        _checkAndCaptureUrl(url, headers: request.headers);
        return null; // 继续正常请求
      },
      onLoadResource: (controller, resource) {
        final url = resource.url.toString();
        _checkAndCaptureUrl(url);
      },
      onConsoleMessage: (controller, consoleMessage) {
        // 监听控制台消息，有些网站会在控制台输出视频URL
        final message = consoleMessage.message;
        if (message.contains('m3u8') ||
            message.contains('mp4') ||
            message.contains('.image') ||
            message.contains('byteimg.com')) {
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
      return LayoutBuilder(
        builder: (context, constraints) {
          const maxWidth = 960.0;
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : maxWidth;
          final width = math.min(availableWidth, maxWidth);
          final height = width * 9 / 16;

          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: webView,
              ),
            ),
          );
        },
      );
    }

    // 隐藏的 WebView（1x1像素）
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(opacity: 0, child: webView),
    );
  }

  /// 尝试从HTML内容中提取视频URL
  Future<void> _tryExtractFromHtml(String html) async {
    _log('开始从HTML提取视频URL...');

    // 尝试直接匹配视频URL（更宽松的模式）
    // 匹配 .mp4（包括 .f0.mp4 这样的变体）
    final urlRegex = RegExp(
      r'''https?://[^\s"<>'\\]+\.(?:mp4|image)(\?[^\s"<>'\\]*)?''',
      caseSensitive: false,
    );
    final urlMatches = urlRegex.allMatches(html);
    for (final urlMatch in urlMatches) {
      final url = urlMatch.group(0)!;
      _log('从HTML提取到URL: $url');
      if (_checkAndCaptureUrl(url)) {
        return;
      }
    }

    // 也尝试匹配 m3u8
    final m3u8Regex = RegExp(
      r'''https?://[^\s"<>'\\]+\.m3u8[^\s"<>'\\]*''',
      caseSensitive: false,
    );
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
    bool enableNestedUrl = false,
    String? matchNestedUrl,
    Duration timeout = const Duration(seconds: 30),
    required void Function(VideoExtractResult result) onResult,
    void Function(String message)? onLog,
    bool showWebView = false,
  }) {
    return WebViewVideoExtractorWidget(
      url: pageUrl,
      customVideoRegex: customVideoRegex,
      enableNestedUrl: enableNestedUrl,
      matchNestedUrl: matchNestedUrl,
      timeout: timeout,
      onResult: onResult,
      onLog: onLog,
      showWebView: showWebView,
    );
  }
}
