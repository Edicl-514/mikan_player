import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;
import 'package:mikan_player/services/captcha_ocr_service.dart';
import 'package:mikan_player/services/webview_cookie_janitor.dart';
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

class _SearchCandidate {
  final String title;
  final String url;
  final int score;

  const _SearchCandidate({
    required this.title,
    required this.url,
    required this.score,
  });
}

class _ExtractedCandidate {
  final String title;
  final String url;

  const _ExtractedCandidate({required this.title, required this.url});
}

class _SearchExtractionConfig {
  final String formatId;
  final String? selectLists;
  final String? selectNames;
  final String? selectLinks;

  const _SearchExtractionConfig({
    required this.formatId,
    this.selectLists,
    this.selectNames,
    this.selectLinks,
  });

  static _SearchExtractionConfig? tryParse(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final root = jsonDecode(jsonStr) as Map<String, dynamic>;
      final formatId = (root['subjectFormatId'] as String?) ?? 'indexed';
      final formatA = root['selectorSubjectFormatA'] as Map<String, dynamic>?;
      final formatIndexed =
          root['selectorSubjectFormatIndexed'] as Map<String, dynamic>?;
      return _SearchExtractionConfig(
        formatId: formatId,
        selectLists: formatA?['selectLists'] as String?,
        selectNames: formatIndexed?['selectNames'] as String?,
        selectLinks: formatIndexed?['selectLinks'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String buildExtractScript({required String? baseUrl}) {
    final baseUrlLiteral = jsonEncode(baseUrl ?? '');
    if (formatId == 'a' &&
        selectLists != null &&
        selectLists!.trim().isNotEmpty) {
      final listSelectorLiteral = jsonEncode(selectLists);
      return '''
(function() {
  var baseUrl = $baseUrlLiteral;
  var selector = $listSelectorLiteral;
  try {
    var nodes = Array.prototype.slice.call(document.querySelectorAll(selector));
    var results = nodes.map(function(node) {
      var href = node.getAttribute('href') || '';
      try {
        if (href && baseUrl) {
          href = new URL(href, baseUrl).toString();
        }
      } catch (_) {}
      return {
        title: (node.textContent || '').trim(),
        url: href
      };
    }).filter(function(item) {
      return item.title && item.url;
    });
    return JSON.stringify(results);
  } catch (_) {
    return '[]';
  }
})()
''';
    }

    final nameSelectorLiteral = jsonEncode(selectNames ?? '');
    final linkSelectorLiteral = jsonEncode(selectLinks ?? '');
    return '''
(function() {
  var baseUrl = $baseUrlLiteral;
  var nameSelector = $nameSelectorLiteral;
  var linkSelector = $linkSelectorLiteral;
  try {
    var names = Array.prototype.slice.call(document.querySelectorAll(nameSelector));
    var links = Array.prototype.slice.call(document.querySelectorAll(linkSelector));
    var length = Math.min(names.length, links.length);
    var results = [];
    for (var i = 0; i < length; i++) {
      var href = links[i].getAttribute('href') || '';
      try {
        if (href && baseUrl) {
          href = new URL(href, baseUrl).toString();
        }
      } catch (_) {}
      results.push({
        title: (names[i].textContent || '').trim(),
        url: href
      });
    }
    return JSON.stringify(results.filter(function(item) {
      return item.title && item.url;
    }));
  } catch (_) {
    return '[]';
  }
})()
''';
  }
}

enum _WebViewFlowStage { search, detail }

enum _CaptchaPageSignal { captcha, success, timedOut, superseded, cancelled }

enum _EagerReadiness { loading, notReady, captchaReady, successReady }

class CaptchaWebViewBypassWidget extends StatefulWidget {
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
  State<CaptchaWebViewBypassWidget> createState() =>
      _CaptchaWebViewBypassWidgetState();
}

class _CaptchaWebViewBypassWidgetState
    extends State<CaptchaWebViewBypassWidget> {
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
          trigger: ContentBlockerTrigger(
            urlFilter: '.*$host.*',
          ),
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

  Timer? _timeoutTimer;
  InAppWebViewController? _webViewController;
  bool _isCompleted = false;
  bool _isCaptchaFlowRunning = false;
  int _captchaRetryCount = 0;
  static const _maxCaptchaRetries = 3;
  static const int _matchScoreThreshold = 36;
  int _loadEventToken = 0;
  _WebViewFlowStage _flowStage = _WebViewFlowStage.search;
  String? _initialUrl;
  String? _initialReferer;
  bool _isSearchEntryFlow = true;
  String? _searchPageHtml;
  String? _searchPageUrl;
  final Set<String> _visitedHosts = {};
  int? _eagerStartedForToken;
  bool _eagerPollActive = false;
  static const int _eagerProgressThreshold = 10;
  static const Duration _eagerPollInterval = Duration(milliseconds: 350);

  /// (C) Detail-stage loads reuse the anti-bot session and cookies established
  /// during the search stage, so they do not need the full initial pacing
  /// delay. Cap it low for the detail stage; the search stage keeps the
  /// configured value.
  int get _effectiveInitialDelayMs {
    final configured = widget.captchaConfig.initialDelayMs;
    if (_flowStage == _WebViewFlowStage.detail) {
      return math.min(configured, 500);
    }
    return configured;
  }

  @override
  void initState() {
    super.initState();
    widget.stats?.onCaptchaWidgetCreated(widget.jobKey);
    _initialUrl = _resolveInitialUrl();
    _initialReferer = widget.referer?.trim();
    _isSearchEntryFlow = widget.initialUrl?.trim().isEmpty ?? true;
    _startTimeout();
  }

  void _startTimeout() => _refreshTimeout();

  /// Restart the preflight timeout with a fresh budget.
  ///
  /// The timer started in [initState] bounds the initial page load. A page
  /// behind heavy anti-bot can burn most of that budget just reaching 100%
  /// (girigiri愛動漫 sat at 80% for ~37s and only fired its load event at
  /// ~43s). By the time the captcha is finally injected into the DOM, almost
  /// nothing was left of the original window, so even the 3s pacing delay
  /// never completed before the global timeout fired and the solve never ran.
  ///
  /// Calling this when the page has finished loading (or when an eager solve
  /// commits) gives the captcha-solving phase a budget that is independent of
  /// how long the page took to load.
  void _refreshTimeout() {
    if (_isCompleted) return;
    _timeoutTimer?.cancel();
    final budget = widget.timeout;
    _timeoutTimer = Timer(budget, () {
      if (_isCompleted) return;
      _log('Captcha preflight timed out');
      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: false,
          error: 'Captcha preflight timed out after ${budget.inSeconds}s',
          timedOut: true,
        ),
      );
    });
  }

  void _log(String message) {
    debugPrint('[CaptchaBypass][${widget.source.name}] $message');
    widget.onLog?.call(message);
  }

  void _complete(CaptchaBypassResult result) {
    if (_isCompleted) return;
    _isCompleted = true;
    _timeoutTimer?.cancel();
    final controller = _webViewController;
    _webViewController = null;
    if (controller != null) {
      unawaited(_teardownWebView(controller));
    }
    _log('Completed: success=${result.success}, error=${result.error}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        widget.onResult(result);
        return;
      }
      widget.onResult(result);
    });
  }

  Future<void> _teardownWebView(InAppWebViewController controller) async {
    try {
      await controller.stopLoading();
    } catch (_) {}
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.stats?.onCaptchaWidgetDisposed(widget.jobKey);
    _timeoutTimer?.cancel();
    final controller = _webViewController;
    _webViewController = null;
    if (controller != null) {
      unawaited(_teardownWebView(controller));
    }
    if (_visitedHosts.isNotEmpty) {
      final janitor = WebViewCookieJanitor();
      for (final host in _visitedHosts) {
        janitor.requestHostCleanup(host: host);
      }
      _visitedHosts.clear();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryUrl = _initialUrl;
    if (entryUrl == null || entryUrl.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isCompleted) return;
        _complete(
          CaptchaBypassResult(
            sourceName: widget.source.name,
            success: false,
            error:
                'Captcha bypass requires initialUrl or a non-empty searchKeyword',
          ),
        );
      });
      return const SizedBox.shrink();
    }

    final navigationHeaders = _buildNavigationHeaders(
      entryUrl,
      referer: _initialReferer,
    );

    final webView = InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(entryUrl),
        headers: navigationHeaders,
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
        _webViewController = controller;
        _log('WebView created, loading entry: $entryUrl');
        _log('Navigation headers: $navigationHeaders');
      },
      onLoadStart: (_, url) {
        _log('Page load started: $url');
      },
      onProgressChanged: (ctrl, progress) {
        if (progress == 10 ||
            progress == 30 ||
            progress == 50 ||
            progress == 80 ||
            progress == 100) {
          _log('Page progress: $progress%');
        }
        if (progress >= _eagerProgressThreshold) {
          _maybeStartEagerCaptcha(ctrl);
        }
      },
      onLoadStop: (ctrl, url) async {
        _log('Page loaded: $url');
        if (url != null) {
          final host = Uri.tryParse(url.toString())?.host;
          if (host != null && host.isNotEmpty) {
            _visitedHosts.add(host);
          }
        }
        if (_isCompleted) return;
        // (E) Guard BEFORE bumping the load token. A committed eager solve sets
        // this flag; if we incremented the token here we would invalidate its
        // token check while also skipping the handler below — leaving nobody to
        // finish the captcha until the 45s timeout. Skipping without touching
        // the token lets the eager path complete on its own.
        if (_isCaptchaFlowRunning) {
          _log(
            'Page loaded while captcha flow is active, skipping duplicate handler',
          );
          return;
        }

        final loadEventToken = ++_loadEventToken;

        // The page just finished loading. A slow load (girigiri reached 100%
        // only after ~43s) can consume nearly the whole original preflight
        // budget before the captcha is even in the DOM. Restart the timer so
        // the readiness gate + pacing + solving that follow get a full window
        // regardless of how long the load took.
        _refreshTimeout();

        await _logEnvironmentSnapshot(ctrl);

        if (_isCompleted || loadEventToken != _loadEventToken) return;

        final shouldGateForChallenge =
            widget.captchaConfig.successSelector?.trim().isNotEmpty ?? false;

        _CaptchaPageSignal? preDelaySignal;
        if (shouldGateForChallenge) {
          _log(
            'Waiting for captcha/success selector before starting initial delay...',
          );
          preDelaySignal = await _waitForCaptchaOrSuccessSignal(
            ctrl,
            widget.captchaConfig,
            loadEventToken: loadEventToken,
            stageLabel: 'pre-delay',
            timeout: const Duration(seconds: 20),
          );
          if (preDelaySignal == _CaptchaPageSignal.cancelled ||
              preDelaySignal == _CaptchaPageSignal.superseded) {
            return;
          }
          if (preDelaySignal == _CaptchaPageSignal.timedOut) {
            _log(
              'Readiness gate timed out before delay, falling back to legacy detection',
            );
          }
        }

        if (_isCompleted || loadEventToken != _loadEventToken) return;

        // (B) The readiness gate already told us the outcome — act on it
        // directly instead of blindly sleeping the full initial delay.
        if (preDelaySignal == _CaptchaPageSignal.success) {
          _log('Success detected by readiness gate, completing without delay');
          final currentUrl =
              (await ctrl.getUrl())?.toString() ?? url?.toString();
          await _completeSuccess(ctrl, currentUrl);
          return;
        }

        if (preDelaySignal == _CaptchaPageSignal.captcha) {
          _log(
            'Captcha detected by readiness gate, pacing submit by '
            '${_effectiveInitialDelayMs}ms before solving',
          );
          await Future.delayed(
            Duration(milliseconds: _effectiveInitialDelayMs),
          );
          if (_isCompleted || loadEventToken != _loadEventToken) return;
          await _handleCaptcha(ctrl);
          return;
        }

        _log(
          'Starting initial delay (${_effectiveInitialDelayMs}ms) after readiness gate',
        );

        await Future.delayed(
          Duration(milliseconds: _effectiveInitialDelayMs),
        );

        if (_isCompleted || loadEventToken != _loadEventToken) return;

        final hasCaptcha = await _detectCaptcha(ctrl, widget.captchaConfig);

        if (_isCompleted || loadEventToken != _loadEventToken) return;

        if (hasCaptcha) {
          await _handleCaptcha(ctrl);
          return;
        }

        var hasSuccess = await _checkSuccess(
          ctrl,
          widget.captchaConfig,
          allowEmptySelector: !shouldGateForChallenge,
        );

        if (_isCompleted || loadEventToken != _loadEventToken) return;

        if (!hasSuccess && shouldGateForChallenge) {
          _log(
            'Success selector not found after delay, waiting for post-challenge render...',
          );
          final postDelaySignal = await _waitForCaptchaOrSuccessSignal(
            ctrl,
            widget.captchaConfig,
            loadEventToken: loadEventToken,
            stageLabel: 'post-delay',
            timeout: const Duration(seconds: 12),
          );

          if (postDelaySignal == _CaptchaPageSignal.cancelled ||
              postDelaySignal == _CaptchaPageSignal.superseded) {
            return;
          }

          if (postDelaySignal == _CaptchaPageSignal.captcha) {
            await _handleCaptcha(ctrl);
            return;
          }

          hasSuccess = postDelaySignal == _CaptchaPageSignal.success;
        }

        if (_isCompleted || loadEventToken != _loadEventToken) return;

        if (hasSuccess) {
          final currentUrl =
              (await ctrl.getUrl())?.toString() ?? url?.toString();
          await _completeSuccess(ctrl, currentUrl);
          return;
        }

        await _completeSuccess(ctrl, url?.toString());
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame ?? false) {
          _log('Page error: ${error.description}');
        }
      },
      onReceivedHttpError: (_, request, response) {
        if (request.isForMainFrame ?? false) {
          _log(
            'Page HTTP error: ${response.statusCode} ${response.reasonPhrase}',
          );
        }
      },
      onConsoleMessage: (_, consoleMessage) {
        final message = consoleMessage.message.trim();
        if (message.isEmpty) return;
        if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR ||
            consoleMessage.messageLevel == ConsoleMessageLevel.WARNING ||
            message.contains('sl-') ||
            message.contains('challenge') ||
            message.contains('captcha')) {
          _log('Console[${consoleMessage.messageLevel.toString()}]: $message');
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

    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(opacity: 0, child: webView),
    );
  }

  void _maybeStartEagerCaptcha(InAppWebViewController? ctrl) {
    if (ctrl == null) return;
    if (_isCompleted || _isCaptchaFlowRunning || _eagerPollActive) return;
    if (_eagerStartedForToken == _loadEventToken) return;
    _eagerStartedForToken = _loadEventToken;
    _eagerPollActive = true;
    final token = _loadEventToken;
    _log(
      'Eager captcha detection armed at progress>=$_eagerProgressThreshold% '
      '(token=$token), polling for essential elements before full load',
    );
    unawaited(_runEagerCaptchaPoll(ctrl, token: token));
  }

  Future<void> _runEagerCaptchaPoll(
    InAppWebViewController ctrl, {
    required int token,
  }) async {
    // Align the eager deadline with the global timeout (minus a small buffer so
    // the eager path can still finish before the timeout timer fires) instead
    // of a shorter fixed window. A short fixed window made eager give up while
    // the page's load event was still stalled on a slow sub-resource, right
    // before onLoadStop would have fired — so eager never won the race it was
    // designed to win.
    final buffer = const Duration(seconds: 3);
    final eagerBudget = widget.timeout > buffer
        ? widget.timeout - buffer
        : widget.timeout;
    final deadline = DateTime.now().add(eagerBudget);
    var tick = 0;
    try {
      while (!_isCompleted &&
          !_isCaptchaFlowRunning &&
          token == _loadEventToken &&
          _isControllerAlive(ctrl) &&
          DateTime.now().isBefore(deadline)) {
        final readiness = await _checkEagerReadiness(ctrl, widget.captchaConfig);
        if (_isCompleted ||
            _isCaptchaFlowRunning ||
            token != _loadEventToken ||
            !_isControllerAlive(ctrl)) {
          return;
        }
        if (readiness == _EagerReadiness.captchaReady) {
          await _startEagerCaptchaSolving(ctrl, token: token);
          return;
        }
        if (readiness == _EagerReadiness.successReady) {
          _log(
            'Success marker detected before page fully loaded, '
            'completing early (no captcha, cookie likely reused)',
          );
          _isCaptchaFlowRunning = true;
          try {
            final currentUrl = (await ctrl.getUrl())?.toString();
            if (_isCompleted ||
                token != _loadEventToken ||
                !_isControllerAlive(ctrl)) {
              return;
            }
            await _completeSuccess(ctrl, currentUrl);
          } catch (e) {
            _log('Eager success completion failed: $e');
            if (!_isCompleted) {
              _complete(
                CaptchaBypassResult(
                  sourceName: widget.source.name,
                  success: false,
                  error: 'Eager success completion failed: $e',
                ),
              );
            }
          } finally {
            _isCaptchaFlowRunning = false;
          }
          return;
        }
        tick += 1;
        if (tick % 8 == 0) {
          _log('Eagerly waiting for captcha elements to be ready...');
        }
        await Future.delayed(_eagerPollInterval);
      }
    } catch (e) {
      _log('Eager captcha poll aborted: $e');
    } finally {
      _eagerPollActive = false;
    }
  }

  Future<void> _startEagerCaptchaSolving(
    InAppWebViewController ctrl, {
    required int token,
  }) async {
    _log(
      'Essential captcha elements ready before page fully loaded, '
      'pacing submit by initialDelayMs '
      '(${_effectiveInitialDelayMs}ms) to avoid anti-bot rejection',
    );

    _isCaptchaFlowRunning = true;
    _refreshTimeout();
    try {
      await Future.delayed(
        Duration(milliseconds: _effectiveInitialDelayMs),
      );
      if (_isCompleted ||
          token != _loadEventToken ||
          !_isControllerAlive(ctrl)) {
        return;
      }
      await _runCaptchaSolving(ctrl);
    } catch (e) {
      _log('Eager captcha solving failed: $e');
      if (!_isCompleted) {
        _complete(
          CaptchaBypassResult(
            sourceName: widget.source.name,
            success: false,
            error: 'Eager captcha solving failed: $e',
          ),
        );
      }
    } finally {
      _isCaptchaFlowRunning = false;
    }
  }

  bool _isControllerAlive(InAppWebViewController ctrl) {
    return identical(_webViewController, ctrl) && !_isCompleted;
  }

  Future<_EagerReadiness> _checkEagerReadiness(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    // Do NOT gate captcha detection on document.readyState. A page whose load
    // event is stalled on a slow sub-resource (tracker, cdn beacon, speculation
    // rules) can sit in "loading" for tens of seconds while the captcha DOM is
    // already fully rendered and interactable. Waiting for readyState here was
    // exactly why eager detection kept losing the race to onLoadStop. Probe the
    // captcha/success elements directly; their presence is the real signal.
    final readyState = await _evalJs(
      ctrl,
      '(function(){ try { return document.readyState; } catch (_) { return "loading"; } })()',
    );
    final readyStateResolved =
        readyState == 'interactive' || readyState == 'complete';

    final hasCaptcha = await _detectCaptcha(ctrl, config);
    if (!hasCaptcha) {
      final successSelector = config.successSelector;
      if (successSelector != null && successSelector.trim().isNotEmpty) {
        if (await _selectorExists(ctrl, successSelector)) {
          return _EagerReadiness.successReady;
        }
      }
      // Neither captcha nor success visible yet. If the document itself has not
      // reached interactive, report loading so the caller keeps polling quietly
      // rather than treating this as a settled "not ready" state.
      return readyStateResolved
          ? _EagerReadiness.notReady
          : _EagerReadiness.loading;
    }

    if (config.isImageOcr) {
      if (!await _isCaptchaImageReady(ctrl, config)) {
        return _EagerReadiness.notReady;
      }
      if (!await _selectorExists(ctrl, config.inputSelector)) {
        return _EagerReadiness.notReady;
      }
      if (!await _selectorExists(ctrl, config.submitSelector)) {
        return _EagerReadiness.notReady;
      }
    } else if (config.isSimpleClick) {
      if (!await _selectorExists(ctrl, config.submitSelector)) {
        return _EagerReadiness.notReady;
      }
    }

    return _EagerReadiness.captchaReady;
  }

  Future<bool> _isCaptchaImageReady(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    final imageSelector = config.imageSelector;
    if (imageSelector == null || imageSelector.trim().isEmpty) return true;
    final selectorLiteral = jsonEncode(imageSelector);
    final script = '''
(function() {
  try {
    var el = document.querySelector($selectorLiteral);
    if (!el) return false;
    if (el.tagName === 'IMG') {
      return !!(el.complete && el.naturalWidth && el.naturalWidth > 0);
    }
    return true;
  } catch (_) {
    return false;
  }
})()
''';
    final result = await _evalJs(ctrl, script);
    return result == true;
  }

  Future<bool> _selectorExists(
    InAppWebViewController ctrl,
    String? selector,
  ) async {
    if (selector == null || selector.trim().isEmpty) return true;
    final exists = await _evalJs(ctrl, _buildSelectorExistsScript(selector));
    return exists == true;
  }

  Future<void> _handleCaptcha(InAppWebViewController ctrl) async {
    if (_isCaptchaFlowRunning) {
      _log('Captcha flow is already running, ignoring duplicate trigger');
      return;
    }
    _isCaptchaFlowRunning = true;

    try {
      await _runCaptchaSolving(ctrl);
    } finally {
      _isCaptchaFlowRunning = false;
    }
  }

  Future<void> _runCaptchaSolving(InAppWebViewController ctrl) async {
    if (!widget.captchaConfig.isImageOcr &&
        !widget.captchaConfig.isSimpleClick) {
      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: false,
          error: 'Captcha type "${widget.captchaConfig.type}" not supported',
        ),
      );
      return;
    }

    if (widget.captchaConfig.isSimpleClick) {
      while (_captchaRetryCount < _maxCaptchaRetries && !_isCompleted) {
        _captchaRetryCount++;
        final currentAttempt = _captchaRetryCount;
        _log(
          'Simple click captcha detected (attempt $currentAttempt/$_maxCaptchaRetries)',
        );

        await Future.delayed(
          Duration(milliseconds: _effectiveInitialDelayMs),
        );
        if (_isCompleted) return;

        await _fillInputAndSubmit(ctrl, widget.captchaConfig, '');

        final submitSuccess = await _waitForSubmitResult(
          ctrl,
          widget.captchaConfig,
        );

        if (_isCompleted) return;

        if (submitSuccess) {
          _log('Simple click bypassed successfully');
          final currentUrl = (await ctrl.getUrl())?.toString();
          await _completeSuccess(ctrl, currentUrl);
          return;
        }

        _log(
          'Simple click failed, still present (attempt $currentAttempt/$_maxCaptchaRetries)',
        );
      }

      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: false,
          error:
              'Simple click bypass failed after $_maxCaptchaRetries retries.',
        ),
      );
      return;
    }

    while (_captchaRetryCount < _maxCaptchaRetries && !_isCompleted) {
      _captchaRetryCount++;
      final currentAttempt = _captchaRetryCount;
      _log('Captcha detected (attempt $currentAttempt/$_maxCaptchaRetries)');

      if (currentAttempt > 1) {
        _log('Refreshing captcha image before retry...');
        await _refreshCaptchaImage(ctrl, widget.captchaConfig);
        if (_isCompleted) return;

        await Future.delayed(
          Duration(milliseconds: _effectiveInitialDelayMs),
        );
        if (_isCompleted) return;

        final stillHasCaptcha = await _detectCaptcha(
          ctrl,
          widget.captchaConfig,
        );
        if (!stillHasCaptcha) {
          _log('Captcha no longer present after refresh, proceeding...');
          final currentUrl = (await ctrl.getUrl())?.toString();
          await _completeSuccess(ctrl, currentUrl);
          return;
        }
      }

      final ocrResult = await _solveImageOcrCaptcha(
        ctrl,
        widget.captchaConfig,
      );
      if (ocrResult == null) {
        _log('OCR failed (attempt $currentAttempt/$_maxCaptchaRetries)');
        continue;
      }

      _log('OCR result: $ocrResult, submitting...');
      await _fillInputAndSubmit(ctrl, widget.captchaConfig, ocrResult);

      final submitSuccess = await _waitForSubmitResult(
        ctrl,
        widget.captchaConfig,
      );

      if (_isCompleted) return;

      if (submitSuccess) {
        _log('Captcha bypassed');
        final currentUrl = (await ctrl.getUrl())?.toString();
        await _completeSuccess(ctrl, currentUrl);
        return;
      }

      _log(
        'Captcha still present after submit (attempt $currentAttempt/$_maxCaptchaRetries)',
      );
    }

    _complete(
      CaptchaBypassResult(
        sourceName: widget.source.name,
        success: false,
        error: 'Captcha bypass failed after $_maxCaptchaRetries retries',
      ),
    );
  }

  Future<void> _completeSuccess(
    InAppWebViewController ctrl,
    String? currentUrl,
  ) async {
    try {
      final effectiveUrl = currentUrl ?? (await ctrl.getUrl())?.toString();
      final pageHtml = await _captureCurrentHtml(ctrl);
      final finalHtml = pageHtml?.toString();

      final jarCookies = await _getCookiesForUrl(
        effectiveUrl ?? _initialUrl ?? widget.source.searchUrl,
      );

      final initialCookies = widget.initialCookies?.trim();
      final cookies = _mergeCookieStrings(initialCookies, jarCookies);

      if (_isSearchEntryFlow &&
          widget.captchaConfig.useWebViewForDetail &&
          _flowStage == _WebViewFlowStage.search) {
        _searchPageHtml = finalHtml;
        _searchPageUrl = effectiveUrl;

        final detailCandidate = await _selectBestSearchCandidate(
          ctrl,
          effectiveUrl,
        );
        if (detailCandidate != null) {
          _flowStage = _WebViewFlowStage.detail;
          _log(
            'Using WebView for detail page: "${detailCandidate.title}" '
            '(score=${detailCandidate.score}) -> ${detailCandidate.url}',
          );
          // The detail page is a fresh navigation that needs its own load
          // budget; restart the timer so a slow detail load does not bleed
          // into the search-solve window.
          _refreshTimeout();
          await ctrl.loadUrl(
            urlRequest: URLRequest(
              url: WebUri(detailCandidate.url),
              headers: _buildNavigationHeaders(
                detailCandidate.url,
                referer: effectiveUrl,
              ),
            ),
          );
          return;
        }

        _log('WebView detail mode enabled, but no detail candidate was found');
      }

      final detailPageHtml = _flowStage == _WebViewFlowStage.detail
          ? finalHtml
          : null;
      final detailPageUrl = _flowStage == _WebViewFlowStage.detail
          ? effectiveUrl
          : null;

      final searchPageHtml = _isSearchEntryFlow
          ? (_searchPageHtml ??
                (_flowStage == _WebViewFlowStage.search ? finalHtml : null))
          : null;
      final searchPageUrl = _isSearchEntryFlow
          ? (_searchPageUrl ??
                (_flowStage == _WebViewFlowStage.search ? effectiveUrl : null))
          : null;

      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: true,
          cookies: cookies,
          finalHtml: finalHtml,
          finalUrl: effectiveUrl,
          searchPageHtml: searchPageHtml,
          searchPageUrl: searchPageUrl,
          detailPageHtml: detailPageHtml,
          detailPageUrl: detailPageUrl,
        ),
      );
    } catch (e) {
      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: false,
          error: 'Failed to capture page context: $e',
        ),
      );
    }
  }

  Future<String?> _captureCurrentHtml(InAppWebViewController ctrl) async {
    final pageHtml = await ctrl.evaluateJavascript(
      source:
          '(function(){ return document.documentElement ? document.documentElement.outerHTML : null; })()',
    );
    return pageHtml?.toString();
  }

  Future<_SearchCandidate?> _selectBestSearchCandidate(
    InAppWebViewController ctrl,
    String? currentUrl,
  ) async {
    final config = _SearchExtractionConfig.tryParse(
      widget.source.searchConfigJson,
    );
    if (config == null) {
      _log('Unable to parse searchConfigJson for WebView detail mode');
      return null;
    }

    final candidates = await _extractSearchCandidates(
      ctrl,
      config: config,
      currentUrl: currentUrl,
    );
    if (candidates.isEmpty) {
      _log('No search candidates extracted from WebView search page');
      return null;
    }

    final query = _preprocessSearchKeyword(widget.searchKeyword) ?? '';
    if (query.isEmpty) {
      final first = candidates.first;
      return _SearchCandidate(title: first.title, url: first.url, score: 0);
    }
    final core = _extractCoreName(query);

    _SearchCandidate? best;
    for (final item in candidates) {
      final score = _calculateMatchScore(item.title, query, core);
      if (score >= _matchScoreThreshold &&
          (best == null || score > best.score)) {
        best = _SearchCandidate(title: item.title, url: item.url, score: score);
      }
    }

    if (best == null && candidates.isNotEmpty) {
      _log(
        'No candidate meets score≥$_matchScoreThreshold '
        '(best was ${candidates.map((c) => _calculateMatchScore(c.title, query, core)).reduce(math.max)})',
      );
    }

    return best;
  }

  String? _resolveInitialUrl() {
    final customInitial = widget.initialUrl?.trim();
    if (customInitial != null && customInitial.isNotEmpty) {
      return customInitial;
    }

    final searchTemplate = widget.source.searchUrl.trim();
    if (searchTemplate.isEmpty) {
      return null;
    }

    final keyword = _preprocessSearchKeyword(widget.searchKeyword);
    if (keyword != null && keyword.isNotEmpty) {
      return searchTemplate.replaceAll('{keyword}', keyword);
    }

    if (!searchTemplate.contains('{keyword}')) {
      return searchTemplate;
    }

    return null;
  }

  static String? _preprocessSearchKeyword(String? keyword) {
    final trimmed = keyword?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final core = _extractCoreName(trimmed);
    return core.isNotEmpty ? core : trimmed;
  }

  static Map<String, String> _buildNavigationHeaders(
    String url, {
    String? referer,
  }) {
    try {
      final uri = Uri.parse(url);
      final origin = '${uri.scheme}://${uri.host}';
      return {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-US;q=0.7',
        'Referer': referer ?? '$origin/',
        'Upgrade-Insecure-Requests': '1',
      };
    } catch (_) {
      return {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-US;q=0.7',
        if (referer != null && referer.isNotEmpty) 'Referer': referer,
        'Upgrade-Insecure-Requests': '1',
      };
    }
  }

  Future<List<_ExtractedCandidate>> _extractSearchCandidates(
    InAppWebViewController ctrl, {
    required _SearchExtractionConfig config,
    required String? currentUrl,
  }) async {
    final script = config.buildExtractScript(baseUrl: currentUrl);
    try {
      final raw = await ctrl.evaluateJavascript(source: script);
      if (raw is! String || raw.isEmpty) {
        return const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _ExtractedCandidate(
              title: (item['title'] ?? '').toString().trim(),
              url: (item['url'] ?? '').toString().trim(),
            ),
          )
          .where((item) => item.title.isNotEmpty && item.url.isNotEmpty)
          .toList();
    } catch (e) {
      _log('Failed to extract search candidates in WebView: $e');
      return const [];
    }
  }

  static String _extractCoreName(String name) {
    var value = name.trim();
    final seasonPatterns = [
      RegExp(r'第[一二三四五六七八九十\d]+\s*季', caseSensitive: false),
      RegExp(r'part\s*\d+', caseSensitive: false),
      RegExp(r'\bseason\s*\d+\b', caseSensitive: false),
      RegExp(r'\b\d+(st|nd|rd|th)\s*season\b', caseSensitive: false),
    ];
    for (final pattern in seasonPatterns) {
      value = value.replaceAll(pattern, ' ');
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int _calculateMatchScore(String title, String query, String core) {
    final titleNorm = _normalizeForMatch(title);
    final queryNorm = _normalizeForMatch(query);
    final coreNorm = _normalizeForMatch(core);
    final titleCoreNorm = _normalizeForMatch(_extractCoreName(title));

    if (titleNorm.isEmpty) return 0;
    if (queryNorm.isNotEmpty && titleNorm == queryNorm) return 100;
    if (coreNorm.isNotEmpty && titleCoreNorm == coreNorm) return 95;
    if (queryNorm.isNotEmpty && titleNorm.contains(queryNorm)) return 70;
    if (coreNorm.isNotEmpty && titleCoreNorm.contains(coreNorm)) return 57;
    return 0;
  }

  static String _normalizeForMatch(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
      '',
    );
  }

  static String _buildSelectorExistsScript(String selector) {
    final selectorLiteral = jsonEncode(selector);
    return '''
(function() {
  var selector = $selectorLiteral;

  function exists(sel) {
    var containsMatch = sel.match(/^(.*?):contains\\((["'])(.*)\\2\\)\$/);
    if (containsMatch) {
      var baseSelector = containsMatch[1].trim();
      var text = containsMatch[3];
      var nodes = document.querySelectorAll(baseSelector || '*');
      for (var i = 0; i < nodes.length; i++) {
        if ((nodes[i].textContent || '').indexOf(text) !== -1) {
          return true;
        }
      }
      return false;
    }
    return document.querySelector(sel) !== null;
  }

  try {
    return exists(selector);
  } catch (_) {
    return false;
  }
})()
''';
  }

  /// Run [source] against the page, but never block longer than [timeout].
  ///
  /// Android's WebView silently drops a pending `evaluateJavascript` callback
  /// when the document it was issued against is torn down by a navigation. The
  /// bridge future then never completes, and any `await` on it hangs forever.
  /// The eager poll issues these calls against a still-loading (and sometimes
  /// about-to-be-replaced) document, so an unbounded await there wedges the
  /// entire poll for the full preflight window — which is exactly the failure
  /// the eager path was built to avoid. Bounding each call lets the loop retry
  /// against the live document on the next tick instead of dying on a dead one.
  static Future<dynamic> _evalJs(
    InAppWebViewController ctrl,
    String source, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      return await ctrl
          .evaluateJavascript(source: source)
          .timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _detectCaptcha(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    final detectSelector = config.detectSelector;
    if (detectSelector == null || detectSelector.isEmpty) return false;

    final selectors = detectSelector
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    for (final selector in selectors) {
      final exists = await _evalJs(
        ctrl,
        _buildSelectorExistsScript(selector),
      );
      if (exists == true) return true;
    }
    return false;
  }

  static Future<bool> _checkSuccess(
    InAppWebViewController ctrl,
    CaptchaConfig config, {
    bool allowEmptySelector = true,
  }) async {
    final selector = config.successSelector;
    if (selector == null || selector.isEmpty) return allowEmptySelector;
    final exists = await _evalJs(ctrl, _buildSelectorExistsScript(selector));
    return exists == true;
  }

  Future<_CaptchaPageSignal> _waitForCaptchaOrSuccessSignal(
    InAppWebViewController ctrl,
    CaptchaConfig config, {
    required int loadEventToken,
    required String stageLabel,
    required Duration timeout,
  }) async {
    const interval = Duration(milliseconds: 350);
    final deadline = DateTime.now().add(timeout);
    var tick = 0;

    while (!_isCompleted &&
        loadEventToken == _loadEventToken &&
        DateTime.now().isBefore(deadline)) {
      final hasCaptcha = await _detectCaptcha(ctrl, config);
      if (hasCaptcha) {
        _log('[$stageLabel] Captcha selector detected');
        return _CaptchaPageSignal.captcha;
      }

      final hasSuccess = await _checkSuccess(
        ctrl,
        config,
        allowEmptySelector: false,
      );
      if (hasSuccess) {
        _log('[$stageLabel] Success selector detected');
        return _CaptchaPageSignal.success;
      }

      tick += 1;
      if (tick % 9 == 0) {
        _log('[$stageLabel] Waiting for challenge to finish...');
      }
      await Future.delayed(interval);
    }

    if (_isCompleted) return _CaptchaPageSignal.cancelled;
    if (loadEventToken != _loadEventToken) {
      return _CaptchaPageSignal.superseded;
    }
    return _CaptchaPageSignal.timedOut;
  }

  Future<bool> _waitForSubmitResult(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    const timeout = Duration(seconds: 8);
    const interval = Duration(milliseconds: 350);
    final deadline = DateTime.now().add(timeout);

    while (!_isCompleted && DateTime.now().isBefore(deadline)) {
      final success = await _checkSuccess(ctrl, config);
      if (success) return true;

      final hasCaptcha = await _detectCaptcha(ctrl, config);
      if (!hasCaptcha) {
        final isReady = await _isDocumentReady(ctrl);
        if (isReady) return true;
      }

      await Future.delayed(interval);
    }

    return false;
  }

  static Future<bool> _isDocumentReady(InAppWebViewController ctrl) async {
    final ready = await _evalJs(
      ctrl,
      '(function(){ return document.readyState === "complete"; })()',
    );
    return ready == true;
  }

  Future<void> _logEnvironmentSnapshot(InAppWebViewController ctrl) async {
    try {
      final snapshot = await ctrl.evaluateJavascript(
        source: '''
(function() {
  function hasOwn(target, key) {
    try {
      return !!target && Object.prototype.hasOwnProperty.call(target, key);
    } catch (_) {
      return false;
    }
  }

  return JSON.stringify({
    webdriver: {
      navigator: (function(){ try { return navigator.webdriver; } catch (_) { return 'error'; } })(),
      window: (function(){ try { return window.webdriver; } catch (_) { return 'error'; } })(),
      attr: (function(){ try { return document.documentElement && document.documentElement.getAttribute('webdriver'); } catch (_) { return 'error'; } })()
    },
    notification: typeof window.Notification,
    languages: (function(){ try { return navigator.languages; } catch (_) { return 'error'; } })(),
    platform: (function(){ try { return navigator.platform; } catch (_) { return 'error'; } })(),
    plugins: (function(){ try { return navigator.plugins ? navigator.plugins.length : null; } catch (_) { return 'error'; } })(),
    mimeTypes: (function(){ try { return navigator.mimeTypes ? navigator.mimeTypes.length : null; } catch (_) { return 'error'; } })(),
    chrome: {
      exists: typeof window.chrome !== 'undefined',
      runtime: (function(){ try { return !!(window.chrome && window.chrome.runtime); } catch (_) { return 'error'; } })(),
      loadTimes: (function(){ try { return !!(window.chrome && window.chrome.loadTimes); } catch (_) { return 'error'; } })()
    },
    suspiciousWindowKeys: (function() {
      var keys = [
        '__nightmare',
        '_selenium',
        'callSelenium',
        '_Selenium_IDE_Recorder',
        'callPhantom',
        '_phantom',
        '__webdriver_capture',
        'webdriver'
      ];
      return keys.filter(function(key) { return hasOwn(window, key); });
    })(),
    suspiciousDocumentKeys: (function() {
      var keys = [
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
      ];
      return keys.filter(function(key) { return hasOwn(document, key); });
    })()
  });
})()
''',
      );
      if (snapshot != null) {
        _log('Environment snapshot: $snapshot');
      }
    } catch (e) {
      _log('Failed to capture environment snapshot: $e');
    }
  }

  Future<String?> _solveImageOcrCaptcha(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    final imageSelector = config.imageSelector;
    if (imageSelector == null || imageSelector.isEmpty) return null;

    try {
      final imageSrc = await ctrl.evaluateJavascript(
        source:
            '''
(function(){
  var img = document.querySelector("${_esc(imageSelector)}");
  if(!img) return null;
  var c = document.createElement("canvas");
  c.width = img.naturalWidth || img.width;
  c.height = img.naturalHeight || img.height;
  c.getContext("2d").drawImage(img, 0, 0);
  return c.toDataURL("image/png");
})()
''',
      );

      if (imageSrc == null ||
          imageSrc is! String ||
          !imageSrc.startsWith('data:image/png;base64,')) {
        _log('Failed to extract captcha image');
        return null;
      }

      final base64 = imageSrc.substring('data:image/png;base64,'.length);
      final imageBytes = _base64Decode(base64);

      _log('Captcha image extracted, running OCR...');

      final constraints = config.ocrConstraints != null
          ? CaptchaConstraintOptions(
              expectedLength: config.ocrConstraints!.expectedLength,
              allowedChars: config.ocrConstraints!.allowedChars,
              enableLookalikeMapping: true,
            )
          : null;

      final result = await CaptchaOcrService.instance.recognizeBytes(
        Uint8List.fromList(imageBytes),
        pngFix: true,
        constraints: constraints,
      );

      _log('OCR result: "$result"');

      if (result.isEmpty) return null;

      if (config.ocrConstraints?.expectedLength != null &&
          result.length != config.ocrConstraints!.expectedLength) {
        _log(
          'OCR length mismatch: ${result.length} != ${config.ocrConstraints!.expectedLength}',
        );
        return null;
      }

      return result;
    } catch (e) {
      _log('OCR error: $e');
      return null;
    }
  }

  Future<void> _refreshCaptchaImage(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    final refreshSelector = config.refreshSelector;
    if (refreshSelector == null || refreshSelector.isEmpty) {
      _log('No refreshSelector configured, reloading page to refresh captcha');
      try {
        await ctrl.evaluateJavascript(source: 'location.reload()');
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    _log('Clicking captcha refresh button: $refreshSelector');
    try {
      await ctrl.evaluateJavascript(
        source:
            '''
(function(){
  var btn = document.querySelector("${_esc(refreshSelector)}");
  if(btn) btn.click();
})()
''',
      );
    } catch (e) {
      _log('Failed to click refresh button: $e');
    }
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  static Future<void> _fillInputAndSubmit(
    InAppWebViewController ctrl,
    CaptchaConfig config,
    String ocrResult,
  ) async {
    final inputSelector = config.inputSelector;
    final submitSelector = config.submitSelector;

    if (inputSelector != null && inputSelector.isNotEmpty) {
      await ctrl.evaluateJavascript(
        source:
            '''
(function(){
  var input = document.querySelector("${_esc(inputSelector)}");
  if(input){
    input.value = "${_esc(ocrResult)}";
    input.dispatchEvent(new Event("input", {bubbles: true}));
    input.dispatchEvent(new Event("change", {bubbles: true}));
  }
})()
''',
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (submitSelector != null && submitSelector.isNotEmpty) {
      await ctrl.evaluateJavascript(
        source:
            '''
(function(){
  var btn = document.querySelector("${_esc(submitSelector)}");
  if(btn) btn.click();
})()
''',
      );
    }
  }

  static String? _mergeCookieStrings(String? a, String? b) {
    final aTrimmed = a?.trim();
    final bTrimmed = b?.trim();
    if (aTrimmed == null || aTrimmed.isEmpty) return bTrimmed;
    if (bTrimmed == null || bTrimmed.isEmpty) return aTrimmed;

    final map = <String, String>{};
    for (final part in '$aTrimmed; $bTrimmed'.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq < 0) continue;
      final name = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      if (name.isNotEmpty) map[name] = value;
    }
    if (map.isEmpty) return null;
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static Future<String?> _getCookiesForUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final cookieManager = CookieManager();
      final cookies = await cookieManager.getCookies(
        url: WebUri('${uri.scheme}://${uri.host}'),
      );
      if (cookies.isEmpty) return null;
      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (_) {
      return null;
    }
  }

  static List<int> _base64Decode(String base64Str) {
    final lookup = <int, int>{};
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    for (var i = 0; i < chars.length; i++) {
      lookup[chars.codeUnitAt(i)] = i;
    }
    final source = base64Str.replaceAll(RegExp(r'\s'), '');
    final result = <int>[];
    int buffer = 0;
    int bits = 0;
    for (final charCode in source.runes) {
      final val = lookup[charCode] ?? 0;
      buffer = (buffer << 6) | val;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        result.add((buffer >> bits) & 0xFF);
      }
    }
    return result;
  }

  static String _esc(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }
}
