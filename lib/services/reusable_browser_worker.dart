import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/services/webview_captcha_job_runner.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/services/webview_video_job_runner.dart';

/// 5B step 2: 长期统一的浏览器 worker (单一 [InAppWebView] 实例) 。
///
/// 与 [ReusableWebViewVideoExtractor] / [ReusableCaptchaWebViewBypasser]
/// 各自持有一个 InAppWebView 不同,本 widget 始终只持有一个 InAppWebView,
/// 通过 [job] 字段 (sealed [WebViewJob] 联合类型) 在视频提取和验证码预处理
/// 两类 job 之间路由 —— 验证码通过后同源视频提取能落在同一个 workerId 的
/// 同一个 InAppWebView 实例上, 真正复用浏览器 session/反爬状态。
///
/// job 切换通过 [didUpdateWidget] → 对应 runner 的 `acceptJob` / `transitionToIdle`
/// 实现; 整个 widget 生命周期内 [InAppWebView] 不会随 job 变化重建 (固定 key
/// `reusable_browser_webview_$workerId`)。
///
/// 所有 job 级状态 (token、captured URLs、visited hosts、flow stage、cookies
/// written to jar 等) 都仍由对应的 runner ([VideoExtractionJobRunner] /
/// [CaptchaJobRunner]) 管理, 本 widget 只负责:
///
/// 1. 长期持有 [InAppWebView] 实例。
/// 2. 在 `initState` 通知 stats 创建; 在 `dispose` 调两个 runner 的 dispose。
/// 3. 把 InAppWebView 的所有回调原样转发给当前 active runner。
/// 4. 在 `didUpdateWidget` 按 [WebViewJob.kind] 路由:
///    - 旧/新 job 都为 null → 忽略;
///    - 旧 job 为 null, 新 job 非空 → 激活对应 runner;
///    - 旧 job 非空, 新 job 为 null → 把当前 active runner 切回 idle;
///    - 旧/新 job 都非空, kind 相同 → 把新 job 派给同 runner (acceptJob);
///    - 旧/新 job 都非空, kind 不同 → 先把旧 runner 切回 idle, 再激活新
///      runner (同 worker 不同 job kind 切换, 不重建 InAppWebView)。
///
/// 对外回调:
/// - [onCaptchaResult]: 验证码 job 结束 (成功/失败/超时/取消) 触发一次。
/// - [onVideoResult]: 视频提取 job 结束触发一次。
/// - [onCaptchaIdle] / [onVideoIdle]: job 结束后触发一次, 让调度器重新派
///   job。workerId 与 [WebViewJob.jobKey] 不参与路由, 仅作日志和回调查找。
///
/// 调试页 / 一次性入口请继续使用 [WebViewVideoExtractorWidget] /
/// [CaptchaWebViewBypassWidget] (它们内部仍走
/// [ReusableWebViewVideoExtractor] / [ReusableCaptchaWebViewBypasser],
/// 行为完全兼容)。
class ReusableBrowserWorker extends StatefulWidget {
  final int workerId;
  final WebViewJob? job;
  final void Function(CaptchaPreflightJob job, CaptchaBypassResult result)?
  onCaptchaResult;
  final void Function(int workerId, CaptchaPreflightJob job)? onCaptchaIdle;
  final void Function(VideoExtractionJob job, VideoExtractResult result)?
  onVideoResult;
  final void Function(int workerId, VideoExtractionJob job)? onVideoIdle;
  final void Function(String message)? onLog;
  final bool showWebView;
  final bool preserveCaptchaSessionOnIdle;
  final WebViewSchedulerStats? stats;

  const ReusableBrowserWorker({
    super.key,
    required this.workerId,
    this.job,
    this.onCaptchaResult,
    this.onCaptchaIdle,
    this.onVideoResult,
    this.onVideoIdle,
    this.onLog,
    this.showWebView = false,
    this.preserveCaptchaSessionOnIdle = false,
    this.stats,
  });

  @override
  State<ReusableBrowserWorker> createState() => _ReusableBrowserWorkerState();
}

class _ReusableBrowserWorkerState extends State<ReusableBrowserWorker> {
  static const String _minimalStealthScript = r'''
(function() {
  if (window.__mikanCaptchaStealthInstalled) {
    return;
  }

  try {
    Object.defineProperty(window, '__mikanCaptchaStealthInstalled', {
      value: true,
      configurable: false,
      enumerable: false,
      writable: false
    });
  } catch (_) {}

  function overrideGetter(target, key, getter) {
    if (!target) return false;
    try {
      Object.defineProperty(target, key, {
        configurable: true,
        enumerable: false,
        get: getter
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  function defineValue(target, key, value) {
    if (!target) return false;
    try {
      Object.defineProperty(target, key, {
        configurable: true,
        enumerable: false,
        writable: false,
        value: value
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  function tryDelete(target, key) {
    if (!target) return;
    try {
      delete target[key];
    } catch (_) {}
  }

  function sanitizeConsoleArg(arg) {
    if (arg == null) return arg;
    var type = typeof arg;
    if (type === 'string' || type === 'number' || type === 'boolean') {
      return arg;
    }
    if (arg instanceof Error) {
      return arg.stack || arg.message || '[Error]';
    }
    try {
      return Object.prototype.toString.call(arg);
    } catch (_) {
      return '[object Object]';
    }
  }

  function patchConsoleMethod(name) {
    if (!window.console || typeof window.console[name] !== 'function') {
      return;
    }
    var original = window.console[name];
    try {
      Object.defineProperty(window.console, name, {
        configurable: true,
        enumerable: false,
        writable: true,
        value: function() {
          if (name === 'clear') {
            return;
          }
          var args = Array.prototype.slice.call(arguments).map(sanitizeConsoleArg);
          return original.apply(this, args);
        }
      });
    } catch (_) {}
  }

  function patchConsole() {
    [
      'log',
      'debug',
      'info',
      'warn',
      'error',
      'dir',
      'dirxml',
      'table',
      'trace',
      'clear'
    ].forEach(patchConsoleMethod);
  }

  function clearAutomationArtifacts() {
    var root = document.documentElement;
    if (root) {
      try {
        root.removeAttribute('webdriver');
        root.removeAttribute('driver');
        root.removeAttribute('selenium');
      } catch (_) {}
    }

    [
      '__selenium_evaluate',
      '__selenium_unwrapped',
      '__webdriver_script_fn',
      '__driver_evaluate',
      '__webdriver_evaluate',
      '__fxdriver_evaluate',
      '__driver_unwrapped',
      '__webdriver_unwrapped',
      '__fxdriver_unwrapped',
      '__webdriver_script_func'
    ].forEach(function(key) {
      tryDelete(document, key);
    });

    [
      '__nightmare',
      '_selenium',
      'callSelenium',
      '_Selenium_IDE_Recorder',
      'callPhantom',
      '_phantom',
      '__webdriver_capture',
      'webdriver'
    ].forEach(function(key) {
      tryDelete(window, key);
    });
  }

  function makeArrayLike(items, arrayProto, namedKey) {
    var list = Object.create(arrayProto || Object.prototype);
    for (var i = 0; i < items.length; i++) {
      defineValue(list, i, items[i]);
    }
    defineValue(list, 'length', items.length);
    defineValue(list, 'item', function(index) {
      index = Number(index) || 0;
      return items[index] || null;
    });
    defineValue(list, 'namedItem', function(name) {
      for (var i = 0; i < items.length; i++) {
        if (items[i] && items[i][namedKey] === name) {
          return items[i];
        }
      }
      return null;
    });
    defineValue(list, 'refresh', function() {});
    if (typeof Symbol !== 'undefined' && Symbol.iterator) {
      defineValue(list, Symbol.iterator, function* () {
        for (var i = 0; i < items.length; i++) {
          yield items[i];
        }
      });
    }
    return list;
  }

  function buildPluginData() {
    if (typeof PluginArray === 'undefined' ||
        typeof Plugin === 'undefined' ||
        typeof MimeTypeArray === 'undefined' ||
        typeof MimeType === 'undefined') {
      return null;
    }

    var mimeType = Object.create(MimeType.prototype);
    defineValue(mimeType, 'type', 'application/pdf');
    defineValue(mimeType, 'suffixes', 'pdf');
    defineValue(mimeType, 'description', 'Portable Document Format');

    var plugin = Object.create(Plugin.prototype);
    defineValue(plugin, 'name', 'Chrome PDF Viewer');
    defineValue(plugin, 'filename', 'internal-pdf-viewer');
    defineValue(plugin, 'description', 'Portable Document Format');
    defineValue(plugin, 'length', 1);
    defineValue(plugin, 0, mimeType);
    defineValue(plugin, 'item', function(index) {
      return Number(index) === 0 ? mimeType : null;
    });
    defineValue(plugin, 'namedItem', function(name) {
      return name === mimeType.type ? mimeType : null;
    });

    defineValue(mimeType, 'enabledPlugin', plugin);

    return {
      plugins: makeArrayLike([plugin], PluginArray.prototype, 'name'),
      mimeTypes: makeArrayLike([mimeType], MimeTypeArray.prototype, 'type')
    };
  }

  try {
    clearAutomationArtifacts();
    if (navigator.webdriver === true || window.webdriver === true) {
      overrideGetter(Navigator.prototype, 'webdriver', function() {
        return undefined;
      }) || overrideGetter(navigator, 'webdriver', function() {
        return undefined;
      });
      overrideGetter(window, 'webdriver', function() {
        return undefined;
      });
    }
  } catch (_) {}

  try {
    if (window.chrome == null) {
      Object.defineProperty(window, 'chrome', {
        configurable: true,
        enumerable: false,
        value: {}
      });
    } else if (window.chrome && window.chrome.runtime) {
      tryDelete(window.chrome, 'runtime');
    }
  } catch (_) {}

  try {
    if (!Array.isArray(navigator.languages) || navigator.languages.length === 0) {
      overrideGetter(Navigator.prototype, 'languages', function() {
        return ['zh-CN', 'zh', 'en-US', 'en'];
      }) || overrideGetter(navigator, 'languages', function() {
        return ['zh-CN', 'zh', 'en-US', 'en'];
      });
    }
  } catch (_) {}

  try {
    if (window.Notification == null) {
      var NotificationCtor = function Notification() {};
      defineValue(NotificationCtor, 'permission', 'default');
      defineValue(NotificationCtor, 'requestPermission', function(callback) {
        if (typeof callback === 'function') {
          callback('default');
        }
        return Promise.resolve('default');
      });
      defineValue(window, 'Notification', NotificationCtor);
    }
  } catch (_) {}

  try {
    if ((navigator.plugins && navigator.plugins.length === 0) ||
        (navigator.mimeTypes && navigator.mimeTypes.length === 0)) {
      var pluginData = buildPluginData();
      if (pluginData) {
        overrideGetter(Navigator.prototype, 'plugins', function() {
          return pluginData.plugins;
        }) || overrideGetter(navigator, 'plugins', function() {
          return pluginData.plugins;
        });
        overrideGetter(Navigator.prototype, 'mimeTypes', function() {
          return pluginData.mimeTypes;
        }) || overrideGetter(navigator, 'mimeTypes', function() {
          return pluginData.mimeTypes;
        });
      }
    }
  } catch (_) {}

  try {
    patchConsole();
  } catch (_) {}

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', clearAutomationArtifacts, {
      once: true
    });
  } else {
    clearAutomationArtifacts();
  }
})();
''';

  /// Third-party hosts that stall the `load` event without contributing
  /// anything the captcha or search flow needs.
  static const List<String> _blockedResourceHosts = [
    'polyfill-js\\.cn',
    'polyfill\\.io',
  ];

  /// URL substrings (path fragments) that identify beacon/telemetry endpoints
  /// served from otherwise-needed origins. These are safe to drop and would
  /// otherwise keep the load event pending.
  static const List<String> _blockedResourcePaths = [
    '/cdn-cgi/speculation',
    '/cdn-cgi/rum',
    '/cdn-cgi/trace',
  ];

  static List<ContentBlocker> _buildContentBlockers() {
    // flutter_inappwebview only implements content blockers on Android/iOS/macOS.
    // On Windows/Linux, ContentBlockerActionType.BLOCK's native value is null and
    // constructing it throws: type 'Null' is not a subtype of type 'String'.
    // Do not even touch ContentBlockerActionType on unsupported platforms.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
      default:
        return const [];
    }

    final blockers = <ContentBlocker>[];
    for (final host in _blockedResourceHosts) {
      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: '.*$host.*'),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      );
    }
    for (final path in _blockedResourcePaths) {
      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: '.*${RegExp.escape(path)}.*',
          ),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      );
    }
    return blockers;
  }

  late final CaptchaJobRunner _captchaRunner;
  late final VideoExtractionJobRunner _videoRunner;
  late final CaptchaJobRunnerSink _captchaSink;
  late final VideoExtractionJobSink _videoSink;

  InAppWebViewController? _webViewController;
  WebViewJob? _lastJob;
  WebViewJobKind? _lastAcceptedKind;

  void _debugWorkerMessage(String message) {
    final ownerTag = widget.stats?.sessionContext?.tag;
    final prefix = ownerTag == null ? '' : '$ownerTag ';
    debugPrint('$prefix[WebViewWorker] $message');
  }

  @override
  void initState() {
    super.initState();
    widget.stats?.onBrowserWorkerCreated('worker_${widget.workerId}');
    _captchaSink = CaptchaJobRunnerSink(
      onResult: (job, result) {
        widget.onCaptchaResult?.call(job, result);
      },
      onIdle: (workerId, job) {
        widget.onCaptchaIdle?.call(workerId, job);
      },
      onLog: (msg) {
        widget.onLog?.call('[captcha] $msg');
      },
    );
    _captchaRunner = CaptchaJobRunner(
      workerId: widget.workerId,
      sink: _captchaSink,
      stats: widget.stats,
      clearVisitedHostsOnDispose: false,
    );
    _videoSink = VideoExtractionJobSink(
      onResult: (job, result) {
        widget.onVideoResult?.call(job, result);
      },
      onIdle: (workerId, job) {
        widget.onVideoIdle?.call(workerId, job);
      },
      onLog: (msg) {
        widget.onLog?.call('[video] $msg');
      },
    );
    _videoRunner = VideoExtractionJobRunner(
      workerId: widget.workerId,
      sink: _videoSink,
      stats: widget.stats,
    );
    final job = widget.job;
    _lastJob = job;
    if (job != null) {
      _acceptJob(job);
    }
  }

  @override
  void didUpdateWidget(covariant ReusableBrowserWorker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameJob(oldWidget.job, widget.job)) return;
    final old = _lastJob;
    final next = widget.job;
    if (old == null && next == null) return;
    if (old != null && next == null) {
      _retireCurrentRunner(
        old,
        preserveCaptchaSession: widget.preserveCaptchaSessionOnIdle,
      );
      _lastJob = null;
      return;
    }
    if (old == null && next != null) {
      _acceptJob(next);
      _lastJob = next;
      return;
    }
    if (old != null && next != null) {
      if (old.kind == next.kind) {
        _acceptJob(next);
      } else {
        _retireCurrentRunner(old, next: next);
        _acceptJob(next);
      }
      _lastJob = next;
    }
  }

  bool _sameJob(WebViewJob? a, WebViewJob? b) {
    return sameWebViewJob(a, b);
  }

  void _acceptJob(WebViewJob job) {
    final previousKind = _lastAcceptedKind;
    if (previousKind != null && previousKind != job.kind) {
      widget.stats?.onBrowserWorkerSameWorkerCrossKindReuse(widget.workerId);
    }
    _lastAcceptedKind = job.kind;
    widget.stats?.onBrowserWorkerKindSwitched(widget.workerId, job.kind);
    final controller = _webViewController;
    if (controller != null) {
      _attachControllerToRunner(job.kind, controller);
    }
    switch (job) {
      case CaptchaJob(:final preflight):
        _captchaRunner.acceptJob(preflight);
      case VideoJob(:final extraction):
        _videoRunner.acceptJob(extraction);
    }
  }

  void _retireCurrentRunner(
    WebViewJob previous, {
    WebViewJob? next,
    bool preserveCaptchaSession = false,
  }) {
    final incomingSourceName = _sourceNameForJob(next);
    switch (previous) {
      case CaptchaJob():
        _captchaRunner.transitionToIdle(
          incomingSourceName: incomingSourceName,
          preserveSession: preserveCaptchaSession,
        );
      case VideoJob():
        _videoRunner.transitionToIdle();
    }
  }

  String? _sourceNameForJob(WebViewJob? job) {
    return switch (job) {
      CaptchaJob(:final preflight) => preflight.source.name,
      VideoJob(:final extraction) => extraction.sourceName,
      null => null,
    };
  }

  void _attachControllerToRunner(
    WebViewJobKind kind,
    InAppWebViewController controller,
  ) {
    switch (kind) {
      case WebViewJobKind.captcha:
        _captchaRunner.attachController(controller);
      case WebViewJobKind.video:
        _videoRunner.attachController(controller);
    }
  }

  void _attachControllerToAllRunners(InAppWebViewController controller) {
    _webViewController = controller;
    _captchaRunner.attachController(controller);
    _videoRunner.attachController(controller);
  }

  /// 调度器入口: 在不卸载 WebView 的前提下停止当前 job。
  void cancelCurrentJob() {
    final current = _lastJob;
    if (current == null) return;
    _retireCurrentRunner(current);
  }

  @override
  void dispose() {
    widget.stats?.onBrowserWorkerDisposed('worker_${widget.workerId}');
    _webViewController = null;
    _captchaRunner.dispose();
    _videoRunner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = _lastJob;

    String entryUrl = 'about:blank';
    Map<String, String> entryHeaders = const <String, String>{};
    String? userAgent;
    String? applicationName;

    if (job is CaptchaJob) {
      entryUrl = _captchaRunner.initialUrl ?? 'about:blank';
      if (entryUrl.isEmpty) entryUrl = 'about:blank';
      entryHeaders = _captchaRunner.buildNavigationHeaders();
      userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      applicationName = '';
    } else if (job is VideoJob) {
      final extraction = job.extraction;
      entryUrl = extraction.url;
      final merged = <String, String>{};
      if (extraction.headers != null) {
        for (final entry in extraction.headers!.entries) {
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
      if (extraction.cookies != null && extraction.cookies!.trim().isNotEmpty) {
        merged.putIfAbsent('Cookie', () => extraction.cookies!.trim());
      }
      if (!merged.containsKey('Referer')) {
        final uri = Uri.tryParse(extraction.url);
        if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
          merged['Referer'] = uri.origin.endsWith('/')
              ? uri.origin
              : '${uri.origin}/';
        }
      }
      entryHeaders = merged;
      userAgent =
          merged['User-Agent'] ??
          merged['userAgent'] ??
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }

    final webView = InAppWebView(
      // 固定 key: job 切换不重建 InAppWebView — 验证码后同源视频提取能
      // 真正复用同一浏览器实例。
      key: ValueKey('reusable_browser_webview_${widget.workerId}'),
      initialUrlRequest: URLRequest(
        url: WebUri(entryUrl),
        headers: entryHeaders.isEmpty ? null : entryHeaders,
      ),
      webViewEnvironment: webViewEnvironment,
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _minimalStealthScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: false,
        isFraudulentWebsiteWarningEnabled: false,
        useHybridComposition: true,
        useShouldInterceptRequest: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        userAgent: userAgent,
        applicationNameForUserAgent: applicationName,
        contentBlockers: _buildContentBlockers(),
      ),
      onWebViewCreated: (controller) {
        _attachControllerToAllRunners(controller);
      },
      onLoadStart: (controller, url) {
        final activeKind = _lastJob?.kind;
        if (activeKind == WebViewJobKind.video) {
          _videoRunner.onLoadStart(controller, url);
        } else if (activeKind == WebViewJobKind.captcha) {
          _captchaRunner.onLoadStart(url);
        }
      },
      onProgressChanged: (ctrl, progress) {
        final activeKind = _lastJob?.kind;
        if (activeKind == WebViewJobKind.captcha) {
          _captchaRunner.onProgressChanged(ctrl, progress);
        }
      },
      onLoadStop: (controller, url) async {
        final activeKind = _lastJob?.kind;
        if (activeKind == WebViewJobKind.video) {
          await _videoRunner.onLoadStop(controller, url);
        } else if (activeKind == WebViewJobKind.captcha) {
          await _captchaRunner.onLoadStop(controller, url);
        }
      },
      shouldInterceptRequest: (controller, request) async {
        final activeKind = _lastJob?.kind;
        if (activeKind == WebViewJobKind.video) {
          return _videoRunner.shouldInterceptRequest(request);
        }
        return null;
      },
      // Android's onLoadResource implementation injects a JavaScript
      // PerformanceObserver and sends one platform message per resource.
      // Video extraction already gets the same URLs from shouldInterceptRequest,
      // so keep this callback off Android to avoid flooding the Flutter UI
      // isolate during pages with many subresources.
      onLoadResource: defaultTargetPlatform == TargetPlatform.android
          ? null
          : (controller, resource) {
              final activeKind = _lastJob?.kind;
              if (activeKind == WebViewJobKind.video) {
                _videoRunner.onLoadResource(resource);
              }
            },
      onConsoleMessage: (controller, consoleMessage) {
        final activeKind = _lastJob?.kind;
        if (activeKind == WebViewJobKind.video) {
          _videoRunner.onConsoleMessage(consoleMessage);
        } else if (activeKind == WebViewJobKind.captcha) {
          _captchaRunner.onConsoleMessage(consoleMessage);
        }
      },
      onJsAlert: (_, request) async {
        _debugWorkerMessage('Suppressed JS alert: ${request.message}');
        return JsAlertResponse(
          handledByClient: true,
          action: JsAlertResponseAction.CONFIRM,
        );
      },
      onJsConfirm: (_, request) async {
        _debugWorkerMessage('Suppressed JS confirm: ${request.message}');
        return JsConfirmResponse(
          handledByClient: true,
          action: JsConfirmResponseAction.CANCEL,
        );
      },
      onJsPrompt: (_, request) async {
        _debugWorkerMessage('Suppressed JS prompt: ${request.message}');
        return JsPromptResponse(
          handledByClient: true,
          action: JsPromptResponseAction.CANCEL,
          value: '',
        );
      },
      onReceivedError: (controller, request, error) {
        final activeKind = _lastJob?.kind;
        if (activeKind == WebViewJobKind.video) {
          _videoRunner.onReceivedError(request, error);
        } else if (activeKind == WebViewJobKind.captcha) {
          _captchaRunner.onReceivedError(request, error);
        }
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        final activeKind = _lastJob?.kind;
        if (activeKind == WebViewJobKind.video) {
          _videoRunner.onReceivedHttpError(request, errorResponse);
        } else if (activeKind == WebViewJobKind.captcha) {
          _captchaRunner.onReceivedHttpError(request, errorResponse);
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
          final width = constraints.maxWidth < maxWidth
              ? availableWidth
              : maxWidth;
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
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(opacity: 0, child: webView),
    );
  }
}

/// 5B step 2: 联合 job 类型。两种 job 通过 sealed class 实现穷举匹配。
sealed class WebViewJob {
  const WebViewJob();

  /// 调度器记账 key (captcha 任务即 taskKey, 视频即 pageKey)。
  String get jobKey;

  /// 当前 job 类别, 决定 [ReusableBrowserWorker] 路由到 captcha 还是
  /// video runner。
  WebViewJobKind get kind;

  /// Generation of the surrounding source search. A task key such as
  /// `search:<source>` is intentionally stable across episodes for scheduler
  /// bookkeeping, but it must not make an EP1 captcha flow indistinguishable
  /// from a newly dispatched EP2 flow on the same warm WebView.
  int get generation;
}

enum WebViewJobKind { captcha, video }

class CaptchaJob extends WebViewJob {
  final CaptchaPreflightJob preflight;
  @override
  int get generation => preflight.generation;

  const CaptchaJob(this.preflight);

  @override
  String get jobKey => preflight.jobKey;

  @override
  WebViewJobKind get kind => WebViewJobKind.captcha;
}

class VideoJob extends WebViewJob {
  final VideoExtractionJob extraction;
  @override
  int get generation => extraction.generation;

  const VideoJob(this.extraction);

  @override
  String get jobKey => extraction.jobKey;

  @override
  WebViewJobKind get kind => WebViewJobKind.video;
}

/// Whether a retained browser worker can keep running [a] instead of retiring
/// it and accepting [b]. Kept as a pure helper so episode-switch identity is
/// testable without constructing an InAppWebView.
@visibleForTesting
bool sameWebViewJob(WebViewJob? a, WebViewJob? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return a.kind == b.kind &&
      a.jobKey == b.jobKey &&
      a.generation == b.generation;
}
