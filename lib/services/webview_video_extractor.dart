import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/services/webview_video_job_runner.dart';

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

  ChannelInfo({required this.name, this.episodes = const []});
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

  /// True when this result was produced by the extraction timeout timer,
  /// as opposed to a genuine success/failure. Carrying this signal on the
  /// result lets the scheduler distinguish a timed-out job from a failed one
  /// purely from the callback — it does not change any existing logic and
  /// stays false for every legacy call site.
  final bool timedOut;

  VideoExtractResult({
    this.videoUrl,
    this.error,
    this.headers = const {},
    this.timedOut = false,
  });

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
  bool isVideoUrl(String url) {
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
  bool matchesCustomRegex(String url, String? regexStr) {
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
  String? extractUrlWithCustomRegex(String url, String? regexStr) {
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

/// 一个视频 URL 提取作业。
///
/// player_page 的 `_activeWebViews` 以 `source+channel` 的 pageKey 为记账键，
/// 因此本类的 [jobKey] 通常就是这个 pageKey（由 `SourceChannelKey.toPageKey`
/// 生成）。worker 通过 jobKey 与调度器对齐，并在连续执行多个 job 时复用
/// 同一个 `InAppWebView` 实例。
@immutable
class VideoExtractionJob {
  /// 调度器记账 key（通常为 `sourceName\x00channelIndex`）。
  final String jobKey;
  final String? sourceName;
  final String url;
  final String? customVideoRegex;
  final bool enableNestedUrl;
  final String? matchNestedUrl;
  final Map<String, String>? headers;
  final String? cookies;
  final Duration timeout;

  const VideoExtractionJob({
    required this.jobKey,
    this.sourceName,
    required this.url,
    this.customVideoRegex,
    this.enableNestedUrl = false,
    this.matchNestedUrl,
    this.headers,
    this.cookies,
    this.timeout = const Duration(seconds: 30),
  });
}

/// 可复用的 WebView 视频提取 worker（5B 之后的容器 widget）。
///
/// 与一次性 [WebViewVideoExtractorWidget] 不同，本 worker 的 [InAppWebView]
/// 不会随 job 切换而销毁/重建：当 [job] 变化时通过 [didUpdateWidget] 触发
/// runner 的 [VideoExtractionJobRunner.acceptJob]，重置 job 级状态并通过
/// `controller.loadUrl()` 导航到新 URL。
///
/// 所有 job 级状态（captured URL set / navigation count / cookies written to
/// jar / job token / timeout timer）都委托给 [VideoExtractionJobRunner]，本
/// widget 本身只承担：
///
/// - 长期持有 [InAppWebView] 实例（key 固定为 `reusable_webview_$workerId`）。
/// - 在 `initState` 通知 runner stats 创建；在 `dispose` 调用 `runner.dispose`。
/// - 把 InAppWebView 的所有回调原样转发到 runner。
/// - 在 `didUpdateWidget` 把 widget.job 的变化通过
///   [VideoExtractionJobRunner.acceptJob] / `transitionToIdle` 派发下去。
///
/// 对外回调：
/// - [onResult]：每次 job 结束（成功/失败/超时）触发一次，附带 jobKey。
/// - [onIdle]：每次 job 结束（含被 [cancelCurrentJob] 取消）后触发一次，
///   让调度器重新分配本 worker 槽。
///
/// 调度器可通过持有 `GlobalKey<_ReusableWebViewVideoExtractorState>`
/// 调用 [cancelCurrentJob] 提前停止当前 job 而不卸载 WebView。
class ReusableWebViewVideoExtractor extends StatefulWidget {
  final int workerId;
  final VideoExtractionJob? job;
  final void Function(String pageKey, VideoExtractResult result)? onResult;
  final void Function(int workerId)? onIdle;
  final void Function(String message)? onLog;
  final bool showWebView;
  final WebViewSchedulerStats? stats;

  const ReusableWebViewVideoExtractor({
    super.key,
    required this.workerId,
    this.job,
    this.onResult,
    this.onIdle,
    this.onLog,
    this.showWebView = false,
    this.stats,
  });

  @override
  State<ReusableWebViewVideoExtractor> createState() =>
      _ReusableWebViewVideoExtractorState();
}

class _ReusableWebViewVideoExtractorState
    extends State<ReusableWebViewVideoExtractor> {
  late final VideoExtractionJobRunner _runner;
  late final VideoExtractionJobSink _sink;

  @override
  void initState() {
    super.initState();
    widget.stats?.onVideoWidgetCreated('worker_${widget.workerId}');
    _sink = VideoExtractionJobSink(
      onResult: widget.onResult,
      onIdle: widget.onIdle,
      onLog: widget.onLog,
    );
    _runner = VideoExtractionJobRunner(
      workerId: widget.workerId,
      sink: _sink,
      stats: widget.stats,
    );
    final job = widget.job;
    if (job != null) {
      _runner.acceptJob(job);
    }
  }

  @override
  void didUpdateWidget(covariant ReusableWebViewVideoExtractor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameJobConfig(oldWidget.job, widget.job)) return;
    if (widget.job == null) {
      _runner.transitionToIdle();
      return;
    }
    _runner.acceptJob(widget.job!);
  }

  bool _sameJobConfig(VideoExtractionJob? a, VideoExtractionJob? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.jobKey == b.jobKey &&
        a.url == b.url &&
        a.customVideoRegex == b.customVideoRegex &&
        a.enableNestedUrl == b.enableNestedUrl &&
        a.matchNestedUrl == b.matchNestedUrl &&
        a.cookies == b.cookies &&
        a.timeout == b.timeout &&
        _sameStringMap(a.headers, b.headers);
  }

  bool _sameStringMap(Map<String, String>? a, Map<String, String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// 调度器入口：在不卸载 WebView 的前提下停止当前 job。语义与旧的
  /// [ReusableWebViewVideoExtractor.cancelCurrentJob] 兼容。
  void cancelCurrentJob({bool silent = true}) {
    _runner.cancelCurrentJob(silent: silent);
  }

  @override
  void dispose() {
    widget.stats?.onVideoWidgetDisposed('worker_${widget.workerId}');
    _runner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = _runner.currentJob;
    final configuredHeaders = job != null
        ? _runnerHeadersForBuild(job)
        : <String, String>{};
    final configuredUserAgent =
        configuredHeaders['User-Agent'] ?? configuredHeaders['userAgent'];
    final initialHeaders = job != null
        ? _runnerHeadersForBuild(job, requestHeaders: configuredHeaders)
        : <String, String>{};

    final webView = InAppWebView(
      // 固定 key：job 切换不会重建 InAppWebView —— 这是 worker 复用前提。
      key: ValueKey('reusable_webview_${widget.workerId}'),
      initialUrlRequest: job != null
          ? URLRequest(
              url: WebUri(job.url),
              headers: initialHeaders.isEmpty ? null : initialHeaders,
            )
          : URLRequest(url: WebUri('about:blank')),
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
      onWebViewCreated: (controller) {
        _runner.attachController(controller);
      },
      onLoadStart: (controller, url) {
        _runner.onLoadStart(controller, url);
      },
      onLoadStop: (controller, url) async {
        await _runner.onLoadStop(controller, url);
      },
      shouldInterceptRequest: (controller, request) async {
        return _runner.shouldInterceptRequest(request);
      },
      onLoadResource: (controller, resource) {
        _runner.onLoadResource(resource);
      },
      onConsoleMessage: (controller, consoleMessage) {
        _runner.onConsoleMessage(consoleMessage);
      },
      onReceivedError: (controller, request, error) {
        _runner.onReceivedError(request, error);
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        _runner.onReceivedHttpError(request, errorResponse);
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

  /// Build-phase only: read the configured headers / merged headers directly
  /// off the [VideoExtractionJob] without leaking the runner's private
  /// header-merge helpers. The job is the single source of truth.
  Map<String, String> _runnerHeadersForBuild(
    VideoExtractionJob job, {
    Map<String, String>? requestHeaders,
  }) {
    final normalized = <String, String>{};
    final sourceHeaders = job.headers;
    if (sourceHeaders != null) {
      for (final entry in sourceHeaders.entries) {
        final rawKey = entry.key.trim();
        final value = entry.value.trim();
        if (rawKey.isEmpty || value.isEmpty) continue;
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
    if (requestHeaders != null) {
      for (final entry in requestHeaders.entries) {
        final key = entry.key.trim();
        final value = entry.value.trim();
        if (key.isEmpty || value.isEmpty) continue;
        final lowerKey = key.toLowerCase();
        final normalizedKey = switch (lowerKey) {
          'useragent' => 'User-Agent',
          'referer' => 'Referer',
          'cookie' => 'Cookie',
          _ => key,
        };
        normalized[normalizedKey] = value;
      }
    }
    final cookies = job.cookies?.trim();
    if (cookies != null && cookies.isNotEmpty) {
      normalized.putIfAbsent('Cookie', () => cookies);
    }
    if (!normalized.containsKey('Referer')) {
      final uri = Uri.tryParse(job.url);
      if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
        normalized['Referer'] = uri.origin.endsWith('/')
            ? uri.origin
            : '${uri.origin}/';
      }
    }
    return normalized;
  }
}

/// WebView 视频提取 Widget（一次性兼容包装）。
///
/// 旧调用方（`subscription_debug_page.dart`、`GlobalSearchManager` 等）按字段
/// 风格调用一次性提取；本 widget 在内部将字段打包成 [VideoExtractionJob]
/// 委托给 [ReusableWebViewVideoExtractor]（workerId 固定为 0）执行一次。
/// 行为与旧实现等价：job 完成后 worker 不会自行卸载 WebView，widget 离开
/// widget 树后才会触发 `dispose()`。
///
/// 播放页调度应当迁移到 worker slot 池 + 长期 worker；本 widget 仅在调试
/// 页等一次性入口继续使用。
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

  /// Phase 0 调试埋点句柄。非 null 时 worker 会把 WebView widget
  /// 创建/销毁事件上报给这个统计对象。传 null 保持静默、无额外日志。
  final WebViewSchedulerStats? stats;

  /// 关联键（通常就是 player page 的 pageKey），仅供 stats 日志对齐，
  /// 不参与任何调度或 keying 逻辑。调试页可传 null（此时 fallback 为 url）。
  final String? jobKey;

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
    this.stats,
    this.jobKey,
  });

  @override
  State<WebViewVideoExtractorWidget> createState() =>
      _WebViewVideoExtractorWidgetState();
}

class _WebViewVideoExtractorWidgetState
    extends State<WebViewVideoExtractorWidget> {
  late final VideoExtractionJob _job;

  @override
  void initState() {
    super.initState();
    _job = VideoExtractionJob(
      jobKey: widget.jobKey ?? widget.url,
      url: widget.url,
      customVideoRegex: widget.customVideoRegex,
      enableNestedUrl: widget.enableNestedUrl,
      matchNestedUrl: widget.matchNestedUrl,
      headers: widget.headers,
      cookies: widget.cookies,
      timeout: widget.timeout,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReusableWebViewVideoExtractor(
      key: const ValueKey('one_shot_video_extractor'),
      workerId: 0,
      job: _job,
      onResult: (_, result) => widget.onResult(result),
      onLog: widget.onLog,
      showWebView: widget.showWebView,
      stats: widget.stats,
    );
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
