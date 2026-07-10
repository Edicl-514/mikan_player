import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/services/webview_cookie_janitor.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';

/// Pure controller for a long-lived WebView video extraction slot.
///
/// Round 7 / 5B step 1 extraction: takes a shared
/// [InAppWebViewController] (managed by the host widget) and drives one
/// [VideoExtractionJob] at a time. Job state — captured URL set, navigation
/// count, current job token, cookies written to the jar, etc. — lives here,
/// not in any widget State, so the host widget can be rebuilt (or replaced
/// with a unified [ReusableBrowserWorker]) without disturbing the in-flight
/// job's bookkeeping.
///
/// Lifecycle:
/// 1. Host widget creates the runner once (alongside the long-lived
///    [InAppWebView]).
/// 2. The host calls [attachController] from `onWebViewCreated` and
///    [acceptJob] whenever the scheduler dispatches a new job.
/// 3. The host forwards `InAppWebView` events to the matching
///    [onLoadStart] / [onLoadStop] / [shouldInterceptRequest] /
///    [onLoadResource] / [onConsoleMessage] / [onReceivedError] /
///    [onReceivedHttpError] hooks.
/// 4. The runner emits exactly one [VideoExtractionJobSink.onResult] and one
///    [VideoExtractionJobSink.onIdle] per job (success / failure / timeout /
///    cancel), then waits for the next [acceptJob].
/// 5. The host calls [dispose] when the worker is being torn down for good
///    (idle slot removed or worker unhealthy rebuilt).
class VideoExtractionJobRunner {
  VideoExtractionJobRunner({
    required this.workerId,
    required this.sink,
    required this.stats,
  }) : _extractor = WebViewVideoExtractor();

  final int workerId;
  final VideoExtractionJobSink sink;
  final WebViewSchedulerStats? stats;

  static const String _skipParserNavigationHeader =
      'x-opencode-skip-parser-navigation';

  final WebViewVideoExtractor _extractor;

  InAppWebViewController? _webViewController;
  VideoExtractionJob? _currentJob;

  /// Monotonic job token. Bumped on every [acceptJob] and every cancel so
  /// any in-flight async callback (e.g. `onLoadStop`'s `getHtml()`,
  /// `shouldInterceptRequest` racing with a navigation) drops its result
  /// instead of polluting the next job's state.
  int _currentJobToken = 0;
  bool _isCompleted = false;
  Timer? _timeoutTimer;
  int _navigationCount = 0;
  int _totalUrlsChecked = 0;
  final Set<String> _capturedUrls = {};
  final List<({String name, String domain, String path})> _cookiesWrittenToJar =
      [];

  /// True after [dispose] has been called. Mirrors the old State flag so
  /// async callbacks can short-circuit cleanly.
  bool get isDisposed =>
      _timeoutTimer == null &&
      _currentJob == null &&
      _webViewController == null &&
      _isCompleted &&
      _capturedUrls.isEmpty &&
      _cookiesWrittenToJar.isEmpty &&
      _navigationCount == 0 &&
      _totalUrlsChecked == 0;

  VideoExtractionJob? get currentJob => _currentJob;

  // --------------------- Lifecycle hooks ---------------------

  void attachController(InAppWebViewController controller) {
    _webViewController = controller;
    final current = _currentJob;
    if (current != null) {
      _log('WebView created, starting load: ${current.url}');
      if (_needsCookieJarInjection(current)) {
        unawaited(_setTaskCookiesInCookieManager(current));
      }
    } else {
      _log('WebView created, worker currently idle');
    }
    _injectMuteScript(controller);
  }

  /// Accept a new job: reset all per-job state, start the timeout, and ask
  /// the controller to navigate if it already exists. The host widget's
  /// `initialUrlRequest` will pick up the URL on first build when the
  /// controller is not yet mounted.
  void acceptJob(VideoExtractionJob job) {
    final token = ++_currentJobToken;
    _currentJob = job;
    _isCompleted = false;
    _navigationCount = 0;
    _totalUrlsChecked = 0;
    _capturedUrls.clear();
    _timeoutTimer?.cancel();
    _cookiesWrittenToJar.clear();

    _log('Worker $workerId accept job ${job.jobKey} url=${job.url}');

    _startTimeout(job, token);

    final controller = _webViewController;
    if (controller != null) {
      _loadJobUrl(controller, job, token);
    }
  }

  /// Job removed by the scheduler without completion — clear state and
  /// notify the sink so it can pick the next job.
  void transitionToIdle() {
    if (_currentJob == null) return;
    if (!_isCompleted) {
      _cancelCurrentJob(silent: true);
      return;
    }
    _timeoutTimer?.cancel();
    _currentJob = null;
    _capturedUrls.clear();
    _navigationCount = 0;
    _totalUrlsChecked = 0;
  }

  /// Scheduler entry point: stop the current job without unloading the
  /// WebView. `silent=true` (default) skips [VideoExtractionJobSink.onResult]
  /// since the scheduler is the source of truth for the cancel record.
  void cancelCurrentJob({bool silent = true}) =>
      _cancelCurrentJob(silent: silent);

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
    _currentJob = null;
    _webViewController = null;
    _isCompleted = true;
    _capturedUrls.clear();
    _navigationCount = 0;
    _totalUrlsChecked = 0;
  }

  // --------------------- InAppWebView hooks ---------------------

  void onLoadStart(InAppWebViewController controller, WebUri? url) {
    _log('Page load started: $url');
    _injectMuteScript(controller);
  }

  Future<void> onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final token = _currentJobToken;
    _log('Page loaded: $url');
    _log('Intercepted $_totalUrlsChecked URLs');
    _injectMuteScript(controller);

    if (token != _currentJobToken) return;
    if (_isCompleted) {
      _log('Already found a video URL, skipping HTML extraction');
      return;
    }
    try {
      final html = await controller.getHtml();
      if (token != _currentJobToken) return;
      if (html != null) {
        await _tryExtractFromHtml(html, token);
      }
    } catch (e) {
      _log('Failed to fetch page HTML: $e');
    }
  }

  Future<WebResourceResponse?> shouldInterceptRequest(
    WebResourceRequest request,
  ) async {
    final token = _currentJobToken;
    final url = request.url.toString();
    _checkAndCaptureUrl(url, headers: request.headers, token: token);
    return null;
  }

  void onLoadResource(LoadedResource resource) {
    final token = _currentJobToken;
    final url = resource.url?.toString() ?? '';
    if (url.isEmpty) return;
    _checkAndCaptureUrl(url, token: token);
  }

  void onConsoleMessage(ConsoleMessage consoleMessage) {
    final token = _currentJobToken;
    final message = consoleMessage.message;
    if (message.contains('m3u8') ||
        message.contains('mp4') ||
        message.contains('.image') ||
        message.contains('byteimg.com')) {
      _log('Console: $message');
      final urlRegex = RegExp(r'https?://[^\s"<>]+');
      final matches = urlRegex.allMatches(message);
      for (final match in matches) {
        _checkAndCaptureUrl(match.group(0)!, token: token);
      }
    }
  }

  void onReceivedError(WebResourceRequest request, WebResourceError error) {
    if (request.isForMainFrame ?? false) {
      _log('Page error: ${error.description} (URL: ${request.url})');
    }
  }

  void onReceivedHttpError(
    WebResourceRequest request,
    WebResourceResponse errorResponse,
  ) {
    if (request.isForMainFrame ?? false) {
      _log('HTTP error (${errorResponse.statusCode}): ${request.url}');
    }
  }

  // --------------------- Internal helpers ---------------------

  void _log(String message) {
    debugPrint('[WebViewExtractor] $message');
    sink.onLog?.call(message);
  }

  void _quietCurrentPage({bool stopLoading = false}) {
    final controller = _webViewController;
    if (controller == null) return;
    try {
      _injectMuteScript(controller);
    } catch (e) {
      debugPrint('[WebViewExtractor] quietCurrentPage mute error: $e');
    }
    if (stopLoading) {
      try {
        unawaited(controller.stopLoading());
      } catch (e) {
        debugPrint('[WebViewExtractor] quietCurrentPage stopLoading error: $e');
      }
    }
  }

  void _complete(int token, VideoExtractResult result) {
    if (token != _currentJobToken) return;
    if (_isCompleted) return;
    final job = _currentJob;
    if (job == null) return;
    _isCompleted = true;
    _timeoutTimer?.cancel();
    _quietCurrentPage();
    _log(
      '🎉 Extraction complete! videoUrl=${result.videoUrl}, '
      'error=${result.error}',
    );
    sink.onResult?.call(job.jobKey, result);
    sink.onIdle?.call(workerId);
  }

  void _cancelCurrentJob({required bool silent}) {
    final job = _currentJob;
    if (job == null) return;
    if (_isCompleted) return;

    _isCompleted = true;
    _timeoutTimer?.cancel();

    if (!silent) {
      sink.onResult?.call(
        job.jobKey,
        VideoExtractResult(error: 'cancelled', timedOut: false),
      );
    }

    _quietCurrentPage(stopLoading: true);
    _log('Worker $workerId cancelled job ${job.jobKey}');

    // Bump the token so any in-flight async callback for the cancelled job
    // is deterministically dropped.
    _currentJobToken++;
    _currentJob = null;
    _capturedUrls.clear();
    _navigationCount = 0;
    _totalUrlsChecked = 0;

    sink.onIdle?.call(workerId);
  }

  void _startTimeout(VideoExtractionJob job, int token) {
    _timeoutTimer = Timer(job.timeout, () {
      if (token != _currentJobToken) return;
      if (_isCompleted) return;
      _log('⏱️ Timeout: intercepted $_totalUrlsChecked URLs but never matched');
      _complete(
        token,
        VideoExtractResult(
          error:
              'Extraction timed out after ${job.timeout.inSeconds}s '
              'without finding a video URL '
              '($_totalUrlsChecked URLs checked)',
          timedOut: true,
        ),
      );
    });
  }

  void _loadJobUrl(
    InAppWebViewController controller,
    VideoExtractionJob job,
    int token,
  ) {
    if (token != _currentJobToken) return;
    final headers = _buildInitialHeaders(job);
    try {
      unawaited(
        controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(job.url),
            headers: headers.isEmpty ? null : headers,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[WebViewExtractor] loadUrl error: $e');
    }
  }

  Map<String, String> _buildInitialHeaders(VideoExtractionJob job) {
    final merged = _normalizedConfiguredHeaders(job);
    if (!merged.containsKey('Referer') && !merged.containsKey('referer')) {
      final uri = Uri.tryParse(job.url);
      if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
        merged['Referer'] = uri.origin.endsWith('/')
            ? uri.origin
            : '${uri.origin}/';
      }
    }
    return merged;
  }

  Map<String, String> _normalizedConfiguredHeaders(VideoExtractionJob job) {
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
    final cookies = job.cookies?.trim();
    if (cookies != null && cookies.isNotEmpty) {
      normalized.putIfAbsent('Cookie', () => cookies);
    }
    return normalized;
  }

  /// Whether this extraction task needs its cookies injected into the WebView
  /// [CookieManager] jar. See the original implementation note: every audited
  /// call site only echoes cookies via outbound `Cookie` headers, so jar
  /// injection is skipped by default.
  bool _needsCookieJarInjection(VideoExtractionJob job) {
    return false;
  }

  Future<void> _setTaskCookiesInCookieManager(VideoExtractionJob job) async {
    final cookies = job.cookies?.trim();
    if (cookies == null || cookies.isEmpty) return;
    final uri = Uri.tryParse(job.url);
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

  bool _shouldSkipParserNavigation(VideoExtractionJob job) {
    final headers = _normalizedConfiguredHeaders(job);
    final value = headers[_skipParserNavigationHeader]?.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes' || value == 'on';
  }

  String _defaultRefererFor(VideoExtractionJob job, String url) {
    final sourcePage = Uri.tryParse(job.url);
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
    return job.url;
  }

  Map<String, String> _mergeRequestHeaders(
    VideoExtractionJob job,
    String url, {
    Map<String, String>? requestHeaders,
  }) {
    final merged = _normalizedConfiguredHeaders(job);
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
        merged[normalizedKey] = value;
      }
    }

    if (!merged.containsKey('Referer') && !merged.containsKey('referer')) {
      merged['Referer'] = _defaultRefererFor(job, url);
    }
    return merged;
  }

  /// Synchronously inspect [url]; if it looks like (or is) the target video
  /// URL, drive completion. Navigates the controller to nested/parser URLs
  /// when needed. Returns true if the call caused the job to complete.
  bool _checkAndCaptureUrl(
    String url, {
    Map<String, String>? headers,
    required int token,
  }) {
    if (token != _currentJobToken) return false;
    final job = _currentJob;
    if (job == null || _isCompleted) return false;

    if (_capturedUrls.contains(url)) return false;
    _capturedUrls.add(url);
    _totalUrlsChecked++;

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
      _log('🔍 Possible video URL: $url');
    }

    final finalHeaders = _mergeRequestHeaders(
      job,
      url,
      requestHeaders: headers,
    );

    if (looksLikeVideo) {
      _log('   Provided headers: ${headers?.keys.join(", ")}');
    }

    if (looksLikeVideo && finalHeaders['Referer'] != null) {
      _log('   Effective Referer: ${finalHeaders['Referer']}');
    }

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
        !url.contains(job.url);

    final skipParserNavigation = _shouldSkipParserNavigation(job);

    final effectiveMatchNestedUrl =
        job.enableNestedUrl &&
            job.matchNestedUrl != null &&
            job.matchNestedUrl!.isNotEmpty &&
            job.matchNestedUrl != r'$^'
        ? job.matchNestedUrl
        : null;

    if (effectiveMatchNestedUrl != null &&
        _extractor.matchesCustomRegex(url, effectiveMatchNestedUrl)) {
      if (skipParserNavigation) {
        _log('⏭️ Skipping nested URL navigation per source config: $url');
        return false;
      }
      if (_navigationCount >= 3) {
        _log(
          '⚠️ Maximum navigation attempts ($_navigationCount) reached, '
          'ignoring nested URL: $url',
        );
        return false;
      }

      final extractedNestedUrl = _extractor.extractUrlWithCustomRegex(
        url,
        effectiveMatchNestedUrl,
      );
      final navigationUrl = extractedNestedUrl ?? url;

      _navigationCount++;
      _log(
        '🎬 matchNestedUrl matched nested URL '
        '(attempt $_navigationCount): $url',
      );
      _log('   Extracted nested URL: $navigationUrl');
      _log('   Navigating to intercept inner video requests...');
      final controller = _webViewController;
      if (controller != null && token == _currentJobToken) {
        unawaited(
          controller.loadUrl(
            urlRequest: URLRequest(
              url: WebUri(navigationUrl),
              headers: finalHeaders.isEmpty ? null : finalHeaders,
            ),
          ),
        );
      }
      return false;
    }

    if (isPlayerParser &&
        job.customVideoRegex != null &&
        job.customVideoRegex!.isNotEmpty) {
      final matched = _extractor.matchesCustomRegex(url, job.customVideoRegex);
      if (matched) {
        final extractedUrl = _extractor.extractUrlWithCustomRegex(
          url,
          job.customVideoRegex,
        );
        if (extractedUrl != null &&
            extractedUrl.isNotEmpty &&
            extractedUrl != url) {
          _log(
            '🎯 Extracted video URL via custom regex on parser URL: '
            '$extractedUrl',
          );
          _complete(
            token,
            VideoExtractResult(videoUrl: extractedUrl, headers: finalHeaders),
          );
          return true;
        }
      }
    }

    if (isPlayerParser) {
      if (skipParserNavigation) {
        _log('⏭️ Skipping inline parser navigation per source config: $url');
        return false;
      }
      if (_navigationCount >= 3) {
        _log(
          '⚠️ Maximum navigation attempts ($_navigationCount) reached, '
          'ignoring parser: $url',
        );
        return false;
      }
      _navigationCount++;
      _log('🎬 Detected parser URL (attempt $_navigationCount): $url');
      _log('   Navigating to intercept inner network requests...');
      final controller = _webViewController;
      if (controller != null && token == _currentJobToken) {
        unawaited(
          controller.loadUrl(
            urlRequest: URLRequest(
              url: WebUri(url),
              headers: finalHeaders.isEmpty ? null : finalHeaders,
            ),
          ),
        );
      }
      return false;
    }

    if (_totalUrlsChecked <= 50) {
      debugPrint('[WebView-URL#$_totalUrlsChecked] $url');
    }

    if (job.customVideoRegex != null && job.customVideoRegex!.isNotEmpty) {
      final matched = _extractor.matchesCustomRegex(url, job.customVideoRegex);
      if (looksLikeVideo) {
        _log('   Custom regex "${job.customVideoRegex}" matched: $matched');
      }
      if (matched) {
        final extractedUrl = _extractor.extractUrlWithCustomRegex(
          url,
          job.customVideoRegex,
        );
        if (extractedUrl != null && extractedUrl.isNotEmpty) {
          _log('✓ Custom regex matched, capture group: $extractedUrl');
          _complete(
            token,
            VideoExtractResult(videoUrl: extractedUrl, headers: finalHeaders),
          );
          return true;
        } else {
          _log('✓ Custom regex matched (no capture group): $url');
          _complete(
            token,
            VideoExtractResult(videoUrl: url, headers: finalHeaders),
          );
          return true;
        }
      }
      // With a configured regex, don't fall through to the built-in matcher
      // — a coarse fallback would only add false positives.
      return false;
    }

    final builtInMatched = _extractor.isVideoUrl(url);
    if (looksLikeVideo) {
      _log('   Built-in pattern matched: $builtInMatched');
    }
    if (builtInMatched) {
      _log('✓ Built-in pattern matched: $url');
      _complete(
        token,
        VideoExtractResult(videoUrl: url, headers: finalHeaders),
      );
      return true;
    }

    return false;
  }

  /// Inject a JS snippet that mutes all media and blocks autoplay, so the
  /// background WebView does not leak sound while it is parked between jobs.
  void _injectMuteScript(InAppWebViewController controller) {
    try {
      unawaited(
        controller
            .evaluateJavascript(
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
            )
            .catchError((e) {
              debugPrint('[WebViewExtractor] injectMuteScript async error: $e');
              return null;
            }),
      );
    } catch (e) {
      debugPrint('[WebViewExtractor] injectMuteScript error: $e');
    }
  }

  /// Try to extract a video URL directly from the rendered HTML — some
  /// sites only expose the m3u8/mp4 URL once the page has fully rendered.
  Future<void> _tryExtractFromHtml(String html, int token) async {
    if (token != _currentJobToken) return;
    _log('Starting HTML-based video URL extraction...');

    final urlRegex = RegExp(
      r'''https?://[^\s"<>'\\]+\.(?:mp4|image)(\?[^\s"<>'\\]*)?''',
      caseSensitive: false,
    );
    final urlMatches = urlRegex.allMatches(html);
    for (final urlMatch in urlMatches) {
      if (token != _currentJobToken) return;
      final url = urlMatch.group(0)!;
      _log('Extracted URL from HTML: $url');
      if (_checkAndCaptureUrl(url, token: token)) {
        return;
      }
    }

    final m3u8Regex = RegExp(
      r'''https?://[^\s"<>'\\]+\.m3u8[^\s"<>'\\]*''',
      caseSensitive: false,
    );
    final m3u8Matches = m3u8Regex.allMatches(html);
    for (final m3u8Match in m3u8Matches) {
      if (token != _currentJobToken) return;
      final url = m3u8Match.group(0)!;
      _log('Extracted URL from HTML: $url');
      if (_checkAndCaptureUrl(url, token: token)) {
        return;
      }
    }
  }
}

/// External callbacks the runner emits. Decoupled from the host widget so the
/// runner is portable across the current [ReusableWebViewVideoExtractor] and
/// the future [ReusableBrowserWorker].
class VideoExtractionJobSink {
  VideoExtractionJobSink({this.onResult, this.onIdle, this.onLog});

  final void Function(String pageKey, VideoExtractResult result)? onResult;
  final void Function(int workerId)? onIdle;
  final void Function(String message)? onLog;
}
