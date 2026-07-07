import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;
import 'package:mikan_player/services/webview_captcha_job_runner.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';

class OcrConstraints {
  final int? expectedLength;
  final String? allowedChars;

  const OcrConstraints({this.expectedLength, this.allowedChars});

  factory OcrConstraints.fromJson(Map<String, dynamic> json) {
    return OcrConstraints(
      expectedLength: json['expectedLength'] as int?,
      allowedChars: json['allowedChars'] as String?,
    );
  }
}

class CaptchaConfig {
  final bool enable;
  final String? type;
  final String? detectSelector;
  final String? successSelector;
  final String? imageSelector;
  final String? inputSelector;
  final String? submitSelector;
  final String? refreshSelector;
  final int initialDelayMs;
  final OcrConstraints? ocrConstraints;
  final bool useWebViewForDetail;

  const CaptchaConfig({
    required this.enable,
    this.type,
    this.detectSelector,
    this.successSelector,
    this.imageSelector,
    this.inputSelector,
    this.submitSelector,
    this.refreshSelector,
    this.initialDelayMs = 1000,
    this.ocrConstraints,
    this.useWebViewForDetail = false,
  });

  factory CaptchaConfig.fromJson(Map<String, dynamic> json) {
    return CaptchaConfig(
      enable: json['enable'] as bool? ?? false,
      type: json['type'] as String?,
      detectSelector: json['detectSelector'] as String?,
      successSelector: json['successSelector'] as String?,
      imageSelector: json['imageSelector'] as String?,
      inputSelector: json['inputSelector'] as String?,
      submitSelector: json['submitSelector'] as String?,
      refreshSelector: json['refreshSelector'] as String?,
      initialDelayMs: json['initialDelayMs'] as int? ?? 1000,
      useWebViewForDetail: json['useWebViewForDetail'] as bool? ?? false,
      ocrConstraints: json['ocrConstraints'] != null
          ? OcrConstraints.fromJson(
              json['ocrConstraints'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static CaptchaConfig? tryParse(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final config = CaptchaConfig.fromJson(json);
      return config.enable ? config : null;
    } catch (_) {
      return null;
    }
  }

  bool get isImageOcr => type == 'image_ocr';
  bool get isSimpleClick => type == 'simple_click';
}

class CaptchaBypassResult {
  final String sourceName;
  final bool success;
  final String? error;
  final String? cookies;
  final String? finalHtml;
  final String? finalUrl;
  final String? searchPageHtml;
  final String? searchPageUrl;
  final String? detailPageHtml;
  final String? detailPageUrl;

  /// True when this result was produced by the captcha preflight timeout
  /// timer, so the scheduler can book it under the timed-out branch instead
  /// of the generic failed branch. Purely diagnostic, defaults to false and
  /// every legacy call site keeps its current semantics.
  final bool timedOut;

  const CaptchaBypassResult({
    required this.sourceName,
    required this.success,
    this.error,
    this.cookies,
    this.finalHtml,
    this.finalUrl,
    this.searchPageHtml,
    this.searchPageUrl,
    this.detailPageHtml,
    this.detailPageUrl,
    this.timedOut = false,
  });

  @Deprecated('Use searchPageHtml instead.')
  String? get pageHtml => searchPageHtml;

  @Deprecated('Use searchPageUrl instead.')
  String? get pageUrl => searchPageUrl;
}

class CaptchaPreflightJob {
  final String jobKey;
  final SourceState source;
  final String? searchKeyword;
  final String? initialUrl;
  final String? referer;
  final String? initialCookies;
  final CaptchaConfig captchaConfig;
  final Duration timeout;

  const CaptchaPreflightJob({
    required this.jobKey,
    required this.source,
    this.searchKeyword,
    this.initialUrl,
    this.referer,
    this.initialCookies,
    required this.captchaConfig,
    this.timeout = const Duration(seconds: 45),
  });
}

/// 可复用的 WebView 验证码预处理 worker（5B 之后的容器 widget）。
///
/// 与一次性 [CaptchaWebViewBypassWidget] 不同，本 worker 的 [InAppWebView]
/// 不会随 job 切换而销毁/重建：当 [job] 变化时通过 [didUpdateWidget] 触发
/// runner 的 [CaptchaJobRunner.acceptJob]，重置 job 级状态并通过
/// `controller.loadUrl()` 导航到新 URL。
///
/// 所有 job 级状态（job token、load event token、flow stage、visited hosts、
/// captcha retry count、跨源治理用的 lastJobSourceName 等）都委托给
/// [CaptchaJobRunner]，本 widget 本身只承担：
///
/// - 长期持有 [InAppWebView] 实例（key 固定为
///   `reusable_captcha_webview_$workerId`）。
/// - 在 `initState` 通知 runner stats 创建；在 `dispose` 调用
///   `runner.dispose`。
/// - 把 InAppWebView 的所有回调原样转发到 runner。
/// - 在 `didUpdateWidget` 把 widget.job 的变化通过
///   [CaptchaJobRunner.acceptJob] / `transitionToIdle` 派发下去。
///
/// 对外回调：
/// - [onResult]：每次 job 结束（成功/失败/超时）触发一次，附带 jobKey。
/// - [onIdle]：每次 job 结束（含被 [cancelCurrentJob] 取消）后触发一次，
///   让调度器重新分配本 worker 槽。
///
/// 调度器可通过持有 `GlobalKey<_ReusableCaptchaWebViewBypasserState>`
/// 调用 [cancelCurrentJob] 提前停止当前 job 而不卸载 WebView。
class ReusableCaptchaWebViewBypasser extends StatefulWidget {
  final int workerId;
  final CaptchaPreflightJob? job;
  final void Function(String taskKey, CaptchaBypassResult result)? onResult;
  final void Function(int workerId)? onIdle;
  final void Function(String message)? onLog;
  final bool showWebView;
  final WebViewSchedulerStats? stats;

  const ReusableCaptchaWebViewBypasser({
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
  State<ReusableCaptchaWebViewBypasser> createState() =>
      _ReusableCaptchaWebViewBypasserState();
}

/// 一次性兼容包装。
///
/// 旧调用方按字段风格调用一次性 captcha bypass；本 widget 在内部将字段打
/// 包成 [CaptchaPreflightJob] 委托给 [ReusableCaptchaWebViewBypasser]
///（workerId 固定为 -1）执行一次。行为与旧实现等价：job 完成后 worker
/// 不会自行卸载 WebView，widget 离开 widget 树后才会触发 `dispose()`。
///
/// 播放页调度应当迁移到 worker slot 池 + 长期 worker；本 widget 仅在调试
/// 页等一次性入口继续使用。
class CaptchaWebViewBypassWidget extends StatelessWidget {
  final SourceState source;
  final String? searchKeyword;
  final String? initialUrl;
  final String? referer;
  final String? initialCookies;
  final CaptchaConfig captchaConfig;
  final Duration timeout;
  final void Function(CaptchaBypassResult result) onResult;
  final void Function(String message)? onLog;
  final bool showWebView;

  /// Phase 0 调试埋点句柄，详见 [WebViewSchedulerStats]。传 null 时该 widget
  /// 不产生任何额外日志，行为与旧行为完全一致。
  final WebViewSchedulerStats? stats;

  /// 关联键（通常即 captcha taskKey），仅供 stats 日志对齐使用。
  final String? jobKey;

  const CaptchaWebViewBypassWidget({
    super.key,
    required this.source,
    this.searchKeyword,
    this.initialUrl,
    this.referer,
    this.initialCookies,
    required this.captchaConfig,
    this.timeout = const Duration(seconds: 45),
    required this.onResult,
    this.onLog,
    this.showWebView = false,
    this.stats,
    this.jobKey,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveJobKey = jobKey ?? 'captcha_once_${identityHashCode(this)}';
    return ReusableCaptchaWebViewBypasser(
      workerId: -1,
      job: CaptchaPreflightJob(
        jobKey: effectiveJobKey,
        source: source,
        searchKeyword: searchKeyword,
        initialUrl: initialUrl,
        referer: referer,
        initialCookies: initialCookies,
        captchaConfig: captchaConfig,
        timeout: timeout,
      ),
      onResult: (_, result) => onResult(result),
      onLog: onLog,
      showWebView: showWebView,
      stats: stats,
    );
  }
}

class _ReusableCaptchaWebViewBypasserState
    extends State<ReusableCaptchaWebViewBypasser> {
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
  ///
  /// The girigiri search page hangs for ~30s because it injects a script from
  /// `polyfill-js.cn`, which never responds (the HAR shows status 0 after 35s),
  /// and then waits on analytics/telemetry beacons. The captcha image, input,
  /// submit button and all search results live on the site's own origin, so the
  /// page is fully interactable long before `load` fires — but Android WebView
  /// refuses to run `evaluateJavascript` against a main frame that is still in
  /// the loading state, which is why the eager (抢跑) JS poll could never win the
  /// race: every probe during the stall returns nothing. Blocking these dead
  /// resources lets `load` fire in ~2s, after which the normal onLoadStop path
  /// detects and solves the captcha immediately.
  ///
  /// Only cross-site trackers/polyfills are listed. Nothing on the anime site's
  /// own origin (including Cloudflare's `cdn-cgi/challenge-platform`, which real
  /// captchas depend on) is blocked.
  static const List<String> _blockedResourceHosts = [
    'polyfill-js\\.cn',
    'polyfill\\.io',
    'googletagmanager\\.com',
    'google-analytics\\.com',
    'analytics\\.google\\.com',
    'static\\.cloudflareinsights\\.com',
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

  late final CaptchaJobRunner _runner;
  late final CaptchaJobRunnerSink _sink;

  @override
  void initState() {
    super.initState();
    widget.stats?.onCaptchaWidgetCreated('captcha_worker_${widget.workerId}');
    _sink = CaptchaJobRunnerSink(
      onResult: widget.onResult,
      onIdle: widget.onIdle,
      onLog: widget.onLog,
    );
    _runner = CaptchaJobRunner(
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
  void didUpdateWidget(covariant ReusableCaptchaWebViewBypasser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameJobConfig(oldWidget.job, widget.job)) return;
    if (widget.job == null) {
      _runner.transitionToIdle();
      return;
    }
    _runner.acceptJob(widget.job!);
  }

  bool _sameJobConfig(CaptchaPreflightJob? a, CaptchaPreflightJob? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.jobKey == b.jobKey &&
        a.source.name == b.source.name &&
        a.searchKeyword == b.searchKeyword &&
        a.initialUrl == b.initialUrl &&
        a.referer == b.referer &&
        a.initialCookies == b.initialCookies &&
        a.captchaConfig == b.captchaConfig &&
        a.timeout == b.timeout;
  }

  /// 调度器入口：在不卸载 WebView 的前提下停止当前 job。语义与旧的
  /// `_ReusableCaptchaWebViewBypasserState.cancelCurrentJob` 兼容。
  void cancelCurrentJob() {
    _runner.cancelCurrentJob();
  }

  @override
  void dispose() {
    widget.stats?.onCaptchaWidgetDisposed('captcha_worker_${widget.workerId}');
    _runner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryUrl = _runner.initialUrl;
    final navigationHeaders = _runner.buildNavigationHeaders();

    final webView = InAppWebView(
      key: ValueKey('reusable_captcha_webview_${widget.workerId}'),
      initialUrlRequest: URLRequest(
        url: WebUri(
          entryUrl == null || entryUrl.isEmpty ? 'about:blank' : entryUrl,
        ),
        headers: navigationHeaders.isEmpty ? null : navigationHeaders,
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
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        applicationNameForUserAgent: "", // remove InAppWebView info
        useHybridComposition: true,
        contentBlockers: _buildContentBlockers(),
      ),
      onWebViewCreated: (controller) {
        _runner.attachController(controller);
      },
      onLoadStart: (_, url) {
        _runner.onLoadStart(url);
      },
      onProgressChanged: (ctrl, progress) {
        _runner.onProgressChanged(ctrl, progress);
      },
      onLoadStop: (ctrl, url) async {
        await _runner.onLoadStop(ctrl, url);
      },
      onReceivedError: (_, request, error) {
        _runner.onReceivedError(request, error);
      },
      onReceivedHttpError: (_, request, response) {
        _runner.onReceivedHttpError(request, response);
      },
      onConsoleMessage: (_, consoleMessage) {
        _runner.onConsoleMessage(consoleMessage);
      },
      onJsAlert: (_, request) async {
        debugPrint('[CaptchaWebView] Suppressed JS alert: ${request.message}');
        return JsAlertResponse(
          handledByClient: true,
          action: JsAlertResponseAction.CONFIRM,
        );
      },
      onJsConfirm: (_, request) async {
        debugPrint(
          '[CaptchaWebView] Suppressed JS confirm: ${request.message}',
        );
        return JsConfirmResponse(
          handledByClient: true,
          action: JsConfirmResponseAction.CANCEL,
        );
      },
      onJsPrompt: (_, request) async {
        debugPrint('[CaptchaWebView] Suppressed JS prompt: ${request.message}');
        return JsPromptResponse(
          handledByClient: true,
          action: JsPromptResponseAction.CANCEL,
          value: '',
        );
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
