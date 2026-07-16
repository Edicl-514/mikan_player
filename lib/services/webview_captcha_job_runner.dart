import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:mikan_player/services/captcha_ocr_service.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/services/webview_cookie_janitor.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_policy.dart';

/// Pure controller for a long-lived WebView captcha preflight slot.
///
/// Round 7 / 5B step 1 extraction: takes a shared
/// [InAppWebViewController] (managed by the host widget) and drives one
/// [CaptchaPreflightJob] at a time. Job state — the running flow stage, the
/// job token, the load event token, the per-job visited hosts set, the
/// eagerly started token, the captcha retry count, etc. — lives here, not in
/// any widget State, so the host widget can be rebuilt (or replaced with a
/// unified [ReusableBrowserWorker]) without disturbing the in-flight job's
/// bookkeeping.
///
/// Lifecycle:
/// 1. Host widget creates the runner once (alongside the long-lived
///    [InAppWebView]).
/// 2. The host calls [attachController] from `onWebViewCreated` and
///    [acceptJob] whenever the scheduler dispatches a new job.
/// 3. The host forwards `InAppWebView` events to the matching
///    [onLoadStart] / [onProgressChanged] / [onLoadStop] /
///    [onReceivedError] / [onReceivedHttpError] / [onConsoleMessage] hooks.
/// 4. The runner emits exactly one [CaptchaJobRunnerSink.onResult] and one
///    [CaptchaJobRunnerSink.onIdle] per job (success / failure / timeout /
///    cancel), then waits for the next [acceptJob].
/// 5. The host calls [dispose] when the worker is being torn down for good
///    (idle slot removed or worker unhealthy rebuilt).
class CaptchaJobRunner {
  CaptchaJobRunner({
    required this.workerId,
    required this.sink,
    required this.stats,
    this.clearVisitedHostsOnDispose = true,
  });

  final int workerId;
  final CaptchaJobRunnerSink sink;
  final WebViewSchedulerStats? stats;

  /// One-shot captcha widgets should clear their session when they leave the
  /// tree. Long-lived pooled workers opt out because a transient tree rebuild
  /// during an episode switch must not erase the browser challenge session
  /// needed by the replacement worker.
  final bool clearVisitedHostsOnDispose;

  static const int _maxCaptchaRetries = 3;
  static const int _matchScoreThreshold = 36;
  static const int _eagerProgressThreshold = 10;
  static const Duration _eagerPollInterval = Duration(milliseconds: 350);

  InAppWebViewController? _webViewController;
  CaptchaPreflightJob? _currentJob;
  int _currentJobToken = 0;
  bool _isCompleted = false;
  bool _isCaptchaFlowRunning = false;
  int _captchaRetryCount = 0;
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
  String? _lastJobSourceName;

  Timer? _timeoutTimer;

  CaptchaPreflightJob? get currentJob => _currentJob;
  String? get initialUrl => _initialUrl;
  String? get initialReferer => _initialReferer;
  Duration get jobTimeout =>
      _currentJob?.timeout ?? const Duration(seconds: 45);

  // --------------------- Lifecycle hooks ---------------------

  void attachController(InAppWebViewController controller) {
    _webViewController = controller;
    final job = _currentJob;
    if (job != null && _initialUrl != null && _initialUrl!.isNotEmpty) {
      _log('WebView created, awaiting initialUrlRequest load: $_initialUrl');
    } else {
      _log('WebView created, worker idle');
    }
  }

  void acceptJob(CaptchaPreflightJob job) {
    final incomingSource = job.source.name;
    _maybeTransitionHostsAcrossSource(
      incomingSource: incomingSource,
      navigateControllerToBlank: true,
    );
    _currentJob = job;
    _resetJobState(advanceToken: true);
    _initialUrl = _resolveInitialUrl();
    _initialReferer = job.referer?.trim();
    _isSearchEntryFlow = job.initialUrl?.trim().isEmpty ?? true;
    _lastJobSourceName = incomingSource;
    _log('Worker $workerId accept job ${job.jobKey}');

    final entryUrl = _initialUrl;
    if (entryUrl == null || entryUrl.isEmpty) {
      _complete(
        _currentJobToken,
        CaptchaBypassResult(
          sourceName: job.source.name,
          success: false,
          error:
              'Captcha bypass requires initialUrl or a non-empty searchKeyword',
        ),
      );
      return;
    }

    _startTimeout(_currentJobToken);
    final controller = _webViewController;
    if (controller != null) {
      _loadJobUrl(controller, job, _currentJobToken);
    }
  }

  void transitionToIdle({
    String? incomingSourceName,
    bool preserveSession = false,
  }) {
    if (_currentJob == null) return;
    if (!_isCompleted) {
      final sameIncomingSource =
          incomingSourceName != null &&
          incomingSourceName == _lastJobSourceName;
      _cancelCurrentJob(preserveSession: preserveSession || sameIncomingSource);
      return;
    }
    _timeoutTimer?.cancel();
    if (!preserveSession && incomingSourceName != null) {
      _maybeTransitionHostsAcrossSource(
        incomingSource: incomingSourceName,
        navigateControllerToBlank: true,
      );
    }
    _currentJob = null;
    _resetJobState(advanceToken: true);
  }

  void cancelCurrentJob() {
    _cancelCurrentJob();
  }

  void dispose() {
    _timeoutTimer?.cancel();
    final controller = _webViewController;
    _webViewController = null;
    if (controller != null) {
      unawaited(_teardownWebView(controller));
    }
    if (clearVisitedHostsOnDispose && _visitedHosts.isNotEmpty) {
      final janitor = WebViewCookieJanitor();
      for (final host in _visitedHosts) {
        janitor.requestHostCleanup(host: host);
      }
      _visitedHosts.clear();
    }
    _currentJob = null;
    _isCompleted = true;
  }

  // --------------------- InAppWebView hooks ---------------------

  void onLoadStart(WebUri? url) {
    if (_currentJob == null || _isCompleted) return;
    _log('Page load started: $url');
  }

  void onProgressChanged(InAppWebViewController ctrl, int progress) {
    if (_currentJob == null || _isCompleted) return;
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
  }

  Future<void> onLoadStop(InAppWebViewController ctrl, WebUri? url) async {
    final jobToken = _currentJobToken;
    if (_currentJob == null || _isCompleted) return;
    if (url?.toString() == 'about:blank') return;
    _log('Page loaded: $url');
    if (url != null) {
      final host = Uri.tryParse(url.toString())?.host;
      if (host != null && host.isNotEmpty) {
        _visitedHosts.add(host);
      }
    }
    if (_isCompleted) return;
    if (_isCaptchaFlowRunning) {
      _log(
        'Page loaded while captcha flow is active, skipping duplicate handler',
      );
      return;
    }

    final loadEventToken = ++_loadEventToken;
    _refreshTimeout(token: jobToken);

    await _logEnvironmentSnapshot(ctrl);

    if (_isCompleted || loadEventToken != _loadEventToken) return;

    final config = _currentJob?.captchaConfig;
    if (config == null) return;
    final shouldGateForChallenge =
        config.successSelector?.trim().isNotEmpty ?? false;

    _CaptchaPageSignal? preDelaySignal;
    if (shouldGateForChallenge) {
      _log(
        'Waiting for captcha/success selector before starting initial delay...',
      );
      preDelaySignal = await _waitForCaptchaOrSuccessSignal(
        ctrl,
        config,
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

    if (preDelaySignal == _CaptchaPageSignal.success) {
      _log('Success detected by readiness gate, completing without delay');
      final currentUrl = (await ctrl.getUrl())?.toString() ?? url?.toString();
      await _completeSuccess(ctrl, currentUrl, token: jobToken);
      return;
    }

    if (preDelaySignal == _CaptchaPageSignal.captcha) {
      _log(
        'Captcha detected by readiness gate, pacing submit by '
        '${_effectiveInitialDelayMs}ms before solving',
      );
      await Future.delayed(Duration(milliseconds: _effectiveInitialDelayMs));
      if (_isCompleted || loadEventToken != _loadEventToken) return;
      await _handleCaptcha(ctrl, token: jobToken);
      return;
    }

    _log(
      'Starting initial delay (${_effectiveInitialDelayMs}ms) after readiness gate',
    );

    await Future.delayed(Duration(milliseconds: _effectiveInitialDelayMs));

    if (_isCompleted || loadEventToken != _loadEventToken) return;

    final hasCaptcha = await _detectCaptcha(ctrl, config);

    if (_isCompleted || loadEventToken != _loadEventToken) return;

    if (hasCaptcha) {
      await _handleCaptcha(ctrl, token: jobToken);
      return;
    }

    var hasSuccess = await _checkSuccess(
      ctrl,
      config,
      allowEmptySelector: !shouldGateForChallenge,
    );

    if (_isCompleted || loadEventToken != _loadEventToken) return;

    if (!hasSuccess && shouldGateForChallenge) {
      _log(
        'Success selector not found after delay, waiting for post-challenge render...',
      );
      final postDelaySignal = await _waitForCaptchaOrSuccessSignal(
        ctrl,
        config,
        loadEventToken: loadEventToken,
        stageLabel: 'post-delay',
        timeout: const Duration(seconds: 12),
      );

      if (postDelaySignal == _CaptchaPageSignal.cancelled ||
          postDelaySignal == _CaptchaPageSignal.superseded) {
        return;
      }

      if (postDelaySignal == _CaptchaPageSignal.captcha) {
        await _handleCaptcha(ctrl, token: jobToken);
        return;
      }

      hasSuccess = postDelaySignal == _CaptchaPageSignal.success;
    }

    if (_isCompleted || loadEventToken != _loadEventToken) return;

    if (hasSuccess) {
      final currentUrl = (await ctrl.getUrl())?.toString() ?? url?.toString();
      await _completeSuccess(ctrl, currentUrl, token: jobToken);
      return;
    }

    await _completeSuccess(ctrl, url?.toString(), token: jobToken);
  }

  void onReceivedError(WebResourceRequest request, WebResourceError error) {
    if (_currentJob == null || _isCompleted) return;
    if (request.isForMainFrame ?? false) {
      _log('Page error: ${error.description}');
    }
  }

  void onReceivedHttpError(
    WebResourceRequest request,
    WebResourceResponse errorResponse,
  ) {
    if (_currentJob == null || _isCompleted) return;
    if (request.isForMainFrame ?? false) {
      _log(
        'Page HTTP error: ${errorResponse.statusCode} ${errorResponse.reasonPhrase}',
      );
    }
  }

  void onConsoleMessage(ConsoleMessage consoleMessage) {
    if (_currentJob == null || _isCompleted) return;
    final message = consoleMessage.message.trim();
    if (message.isEmpty) return;
    if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR ||
        consoleMessage.messageLevel == ConsoleMessageLevel.WARNING ||
        message.contains('sl-') ||
        message.contains('challenge') ||
        message.contains('captcha')) {
      _log('Console[${consoleMessage.messageLevel.toString()}]: $message');
    }
  }

  /// Build-phase helper: returns the navigation headers for the *current*
  /// job's entry URL. Used by the host widget to drive
  /// [InAppWebView.initialUrlRequest] on first build.
  Map<String, String> buildNavigationHeaders() {
    final entryUrl = _initialUrl;
    if (entryUrl == null || entryUrl.isEmpty) {
      return const <String, String>{};
    }
    return _buildNavigationHeaders(entryUrl, referer: _initialReferer);
  }

  // --------------------- Internal helpers ---------------------

  int get _effectiveInitialDelayMs {
    final configured = _currentJob?.captchaConfig.initialDelayMs ?? 1000;
    if (_flowStage == _WebViewFlowStage.detail) {
      return math.min(configured, 500);
    }
    return configured;
  }

  void _log(String message) {
    final sourceName = _currentJob?.source.name ?? 'idle';
    debugPrint('[CaptchaBypass][$sourceName] $message');
    sink.onLog?.call(message);
  }

  void _resetJobState({required bool advanceToken}) {
    if (advanceToken) {
      _currentJobToken++;
    }
    _timeoutTimer?.cancel();
    _isCompleted = false;
    _isCaptchaFlowRunning = false;
    _captchaRetryCount = 0;
    _loadEventToken++;
    _flowStage = _WebViewFlowStage.search;
    _initialUrl = null;
    _initialReferer = null;
    _isSearchEntryFlow = true;
    _searchPageHtml = null;
    _searchPageUrl = null;
    _eagerStartedForToken = null;
    _eagerPollActive = false;
  }

  void _startTimeout(int token) => _refreshTimeout(token: token);

  void _refreshTimeout({int? token}) {
    final jobToken = token ?? _currentJobToken;
    if (_isCompleted) return;
    final job = _currentJob;
    if (job == null) return;
    _timeoutTimer?.cancel();
    final budget = job.timeout;
    _timeoutTimer = Timer(budget, () {
      if (jobToken != _currentJobToken) return;
      if (_isCompleted) return;
      _log('Captcha preflight timed out');
      _complete(
        jobToken,
        CaptchaBypassResult(
          sourceName: job.source.name,
          success: false,
          error: 'Captcha preflight timed out after ${budget.inSeconds}s',
          timedOut: true,
        ),
      );
    });
  }

  void _complete(int token, CaptchaBypassResult result) {
    if (token != _currentJobToken) return;
    if (_isCompleted) return;
    final job = _currentJob;
    if (job == null) return;
    _isCompleted = true;
    _timeoutTimer?.cancel();
    _log('Completed: success=${result.success}, error=${result.error}');
    sink.onResult?.call(job.jobKey, result);
    sink.onIdle?.call(workerId);
  }

  void _cancelCurrentJob({bool preserveSession = false}) {
    final job = _currentJob;
    if (job == null) return;
    final controller = _webViewController;
    _isCompleted = true;
    _timeoutTimer?.cancel();
    _currentJobToken++;
    _loadEventToken++;
    if (controller != null) {
      try {
        unawaited(controller.stopLoading());
      } catch (_) {}
    }
    _log('Worker $workerId cancelled job ${job.jobKey}');
    if (!preserveSession) {
      _maybeTransitionHostsAcrossSource(
        incomingSource: null,
        navigateControllerToBlank: true,
      );
    }
    _currentJob = null;
    _resetJobState(advanceToken: false);
    sink.onIdle?.call(workerId);
  }

  void _maybeTransitionHostsAcrossSource({
    required String? incomingSource,
    required bool navigateControllerToBlank,
  }) {
    final lastSource = _lastJobSourceName;
    if (lastSource == null || lastSource.isEmpty) {
      return;
    }
    final sameSource = incomingSource != null && incomingSource == lastSource;
    if (sameSource) {
      return;
    }
    if (_visitedHosts.isNotEmpty) {
      final janitor = WebViewCookieJanitor();
      for (final host in _visitedHosts) {
        janitor.requestHostCleanup(host: host);
      }
      _log(
        'Cross-source host/cookie cleanup: $lastSource -> '
        '${incomingSource ?? '(idle)'} hosts=${_visitedHosts.length}',
      );
      _visitedHosts.clear();
    }
    final controller = _webViewController;
    if (controller != null && navigateControllerToBlank) {
      try {
        unawaited(controller.stopLoading());
      } catch (_) {}
      try {
        unawaited(
          controller.loadUrl(
            urlRequest: URLRequest(url: WebUri('about:blank')),
          ),
        );
      } catch (_) {}
    }
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

  void _loadJobUrl(
    InAppWebViewController controller,
    CaptchaPreflightJob job,
    int token,
  ) {
    if (token != _currentJobToken) return;
    final entryUrl = _initialUrl;
    if (entryUrl == null || entryUrl.isEmpty) return;
    final navigationHeaders = _buildNavigationHeaders(
      entryUrl,
      referer: _initialReferer,
    );
    try {
      unawaited(
        controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(entryUrl),
            headers: navigationHeaders.isEmpty ? null : navigationHeaders,
          ),
        ),
      );
    } catch (e) {
      _log('Failed to load captcha job URL: $e');
    }
  }

  void _maybeStartEagerCaptcha(InAppWebViewController? ctrl) {
    if (ctrl == null) return;
    if (_isCompleted || _isCaptchaFlowRunning || _eagerPollActive) return;
    if (_eagerStartedForToken == _loadEventToken) return;
    _eagerStartedForToken = _loadEventToken;
    _eagerPollActive = true;
    final loadToken = _loadEventToken;
    final jobToken = _currentJobToken;
    _log(
      'Eager captcha detection armed at progress>=$_eagerProgressThreshold% '
      '(token=$loadToken), polling for essential elements before full load',
    );
    unawaited(
      _runEagerCaptchaPoll(ctrl, loadToken: loadToken, jobToken: jobToken),
    );
  }

  Future<void> _runEagerCaptchaPoll(
    InAppWebViewController ctrl, {
    required int loadToken,
    required int jobToken,
  }) async {
    final buffer = const Duration(seconds: 3);
    final eagerBudget = jobTimeout > buffer ? jobTimeout - buffer : jobTimeout;
    final deadline = DateTime.now().add(eagerBudget);
    var tick = 0;
    try {
      while (!_isCompleted &&
          !_isCaptchaFlowRunning &&
          loadToken == _loadEventToken &&
          jobToken == _currentJobToken &&
          _isControllerAlive(ctrl) &&
          DateTime.now().isBefore(deadline)) {
        final config = _currentJob?.captchaConfig;
        if (config == null) return;
        final readiness = await _checkEagerReadiness(ctrl, config);
        if (_isCompleted ||
            _isCaptchaFlowRunning ||
            loadToken != _loadEventToken ||
            jobToken != _currentJobToken ||
            !_isControllerAlive(ctrl)) {
          return;
        }
        if (readiness == _EagerReadiness.captchaReady) {
          await _startEagerCaptchaSolving(
            ctrl,
            loadToken: loadToken,
            jobToken: jobToken,
          );
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
                loadToken != _loadEventToken ||
                jobToken != _currentJobToken ||
                !_isControllerAlive(ctrl)) {
              return;
            }
            await _completeSuccess(ctrl, currentUrl, token: jobToken);
          } catch (e) {
            _log('Eager success completion failed: $e');
            if (!_isCompleted) {
              _complete(
                jobToken,
                CaptchaBypassResult(
                  sourceName: _currentJob?.source.name ?? '',
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
    required int loadToken,
    required int jobToken,
  }) async {
    _log(
      'Essential captcha elements ready before page fully loaded, '
      'pacing submit by initialDelayMs '
      '(${_effectiveInitialDelayMs}ms) to avoid anti-bot rejection',
    );

    _isCaptchaFlowRunning = true;
    _refreshTimeout(token: jobToken);
    try {
      await Future.delayed(Duration(milliseconds: _effectiveInitialDelayMs));
      if (_isCompleted ||
          loadToken != _loadEventToken ||
          jobToken != _currentJobToken ||
          !_isControllerAlive(ctrl)) {
        return;
      }
      await _runCaptchaSolving(ctrl, token: jobToken);
    } catch (e) {
      _log('Eager captcha solving failed: $e');
      if (!_isCompleted) {
        _complete(
          jobToken,
          CaptchaBypassResult(
            sourceName: _currentJob?.source.name ?? '',
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
    final script =
        '''
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

  Future<void> _handleCaptcha(
    InAppWebViewController ctrl, {
    required int token,
  }) async {
    if (token != _currentJobToken) return;
    if (_isCaptchaFlowRunning) {
      _log('Captcha flow is already running, ignoring duplicate trigger');
      return;
    }
    _isCaptchaFlowRunning = true;

    try {
      await _runCaptchaSolving(ctrl, token: token);
    } finally {
      _isCaptchaFlowRunning = false;
    }
  }

  Future<void> _runCaptchaSolving(
    InAppWebViewController ctrl, {
    required int token,
  }) async {
    if (token != _currentJobToken) return;
    final job = _currentJob;
    final config = job?.captchaConfig;
    if (job == null || config == null) return;

    if (!config.isImageOcr && !config.isSimpleClick) {
      _complete(
        token,
        CaptchaBypassResult(
          sourceName: job.source.name,
          success: false,
          error: 'Captcha type "${config.type}" not supported',
        ),
      );
      return;
    }

    if (config.isSimpleClick) {
      while (_captchaRetryCount < _maxCaptchaRetries &&
          !_isCompleted &&
          token == _currentJobToken) {
        _captchaRetryCount++;
        final currentAttempt = _captchaRetryCount;
        _log(
          'Simple click captcha detected (attempt $currentAttempt/$_maxCaptchaRetries)',
        );

        await Future.delayed(Duration(milliseconds: _effectiveInitialDelayMs));
        if (_isCompleted || token != _currentJobToken) return;

        await _fillInputAndSubmit(ctrl, config, '');

        final submitSuccess = await _waitForSubmitResult(ctrl, config);

        if (_isCompleted || token != _currentJobToken) return;

        if (submitSuccess) {
          _log('Simple click bypassed successfully');
          final currentUrl = (await ctrl.getUrl())?.toString();
          await _completeSuccess(ctrl, currentUrl, token: token);
          return;
        }

        _log(
          'Simple click failed, still present (attempt $currentAttempt/$_maxCaptchaRetries)',
        );
      }

      _complete(
        token,
        CaptchaBypassResult(
          sourceName: job.source.name,
          success: false,
          error:
              'Simple click bypass failed after $_maxCaptchaRetries retries.',
        ),
      );
      return;
    }

    while (_captchaRetryCount < _maxCaptchaRetries &&
        !_isCompleted &&
        token == _currentJobToken) {
      _captchaRetryCount++;
      final currentAttempt = _captchaRetryCount;
      _log('Captcha detected (attempt $currentAttempt/$_maxCaptchaRetries)');

      if (currentAttempt > 1) {
        _log('Refreshing captcha image before retry...');
        await _refreshCaptchaImage(ctrl, config);
        if (_isCompleted || token != _currentJobToken) return;

        await Future.delayed(Duration(milliseconds: _effectiveInitialDelayMs));
        if (_isCompleted || token != _currentJobToken) return;

        final stillHasCaptcha = await _detectCaptcha(ctrl, config);
        if (!stillHasCaptcha) {
          // The captcha image is often briefly detached from the DOM while a
          // refresh is loading. That is NOT the same as a solved challenge —
          // treating it as success produced empty search HTML and a UI error
          // of "未找到匹配的动画" even though the job reported success=true.
          // Policy: docs/player_search_session_design.md +
          // shouldTreatMissingCaptchaAfterRefreshAsSuccess.
          final hasSuccess = await _checkSuccess(
            ctrl,
            config,
            allowEmptySelector: false,
          );
          if (_isCompleted || token != _currentJobToken) return;
          if (shouldTreatMissingCaptchaAfterRefreshAsSuccess(
            captchaStillDetectable: stillHasCaptcha,
            successSelectorPresent: hasSuccess,
          )) {
            _log(
              'Captcha cleared after refresh and success selector is present',
            );
            final currentUrl = (await ctrl.getUrl())?.toString();
            await _completeSuccess(ctrl, currentUrl, token: token);
            return;
          }

          _log(
            'Captcha not detectable after refresh (likely mid-reload); '
            'waiting for image to reappear before next OCR attempt',
          );
          final reappeared = await _waitForCaptchaImageAfterRefresh(
            ctrl,
            config,
            token: token,
          );
          if (_isCompleted || token != _currentJobToken) return;
          if (reappeared == _CaptchaPageSignal.success) {
            final currentUrl = (await ctrl.getUrl())?.toString();
            await _completeSuccess(ctrl, currentUrl, token: token);
            return;
          }
          if (reappeared != _CaptchaPageSignal.captcha) {
            _log(
              'Captcha did not reappear after refresh '
              '(signal=$reappeared); retrying OCR path if attempts remain',
            );
            continue;
          }
        }
      }

      final ocrResult = await _solveImageOcrCaptcha(ctrl, config);
      if (token != _currentJobToken) return;
      if (ocrResult == null) {
        _log('OCR failed (attempt $currentAttempt/$_maxCaptchaRetries)');
        continue;
      }

      _log('OCR result: $ocrResult, submitting...');
      await _fillInputAndSubmit(ctrl, config, ocrResult);

      final submitSuccess = await _waitForSubmitResult(ctrl, config);

      if (_isCompleted || token != _currentJobToken) return;

      if (submitSuccess) {
        _log('Captcha bypassed');
        final currentUrl = (await ctrl.getUrl())?.toString();
        await _completeSuccess(ctrl, currentUrl, token: token);
        return;
      }

      _log(
        'Captcha still present after submit (attempt $currentAttempt/$_maxCaptchaRetries)',
      );
    }

    _complete(
      token,
      CaptchaBypassResult(
        sourceName: job.source.name,
        success: false,
        error: 'Captcha bypass failed after $_maxCaptchaRetries retries',
      ),
    );
  }

  Future<void> _completeSuccess(
    InAppWebViewController ctrl,
    String? currentUrl, {
    required int token,
  }) async {
    if (token != _currentJobToken) return;
    final job = _currentJob;
    final config = job?.captchaConfig;
    if (job == null || config == null) return;
    try {
      final effectiveUrl = currentUrl ?? (await ctrl.getUrl())?.toString();
      if (token != _currentJobToken) return;
      final pageHtml = await _captureCurrentHtml(ctrl);
      if (token != _currentJobToken) return;
      final finalHtml = pageHtml?.toString();

      final jarCookies = await _getCookiesForUrl(
        effectiveUrl ?? _initialUrl ?? job.source.searchUrl,
      );

      final initialCookies = job.initialCookies?.trim();
      final cookies = _mergeCookieStrings(initialCookies, jarCookies);

      if (_isSearchEntryFlow &&
          config.useWebViewForDetail &&
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
          _refreshTimeout(token: token);
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
        token,
        CaptchaBypassResult(
          sourceName: job.source.name,
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
        token,
        CaptchaBypassResult(
          sourceName: job.source.name,
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
    final job = _currentJob;
    if (job == null) return null;
    final config = _SearchExtractionConfig.tryParse(
      job.source.searchConfigJson,
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

    final query = _preprocessSearchKeyword(job.searchKeyword) ?? '';
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
    final job = _currentJob;
    if (job == null) return null;
    final customInitial = job.initialUrl?.trim();
    if (customInitial != null && customInitial.isNotEmpty) {
      return customInitial;
    }

    final searchTemplate = job.source.searchUrl.trim();
    if (searchTemplate.isEmpty) {
      return null;
    }

    final keyword = _preprocessSearchKeyword(job.searchKeyword);
    if (keyword != null && keyword.isNotEmpty) {
      return searchTemplate.replaceAll('{keyword}', keyword);
    }

    if (!searchTemplate.contains('{keyword}')) {
      return searchTemplate;
    }

    return null;
  }

  // --------------------- Static helpers (formerly top-level) ---------------------

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
      final exists = await _evalJs(ctrl, _buildSelectorExistsScript(selector));
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

  /// After a refresh click / page reload the captcha node often disappears for
  /// a short window. Wait for either a real success marker or a ready captcha
  /// image before deciding the challenge is solved.
  Future<_CaptchaPageSignal> _waitForCaptchaImageAfterRefresh(
    InAppWebViewController ctrl,
    CaptchaConfig config, {
    required int token,
  }) async {
    const interval = Duration(milliseconds: 350);
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (!_isCompleted &&
        token == _currentJobToken &&
        DateTime.now().isBefore(deadline)) {
      final hasSuccess = await _checkSuccess(
        ctrl,
        config,
        allowEmptySelector: false,
      );
      if (_isCompleted || token != _currentJobToken) {
        return _CaptchaPageSignal.cancelled;
      }
      if (hasSuccess) {
        _log('Success selector detected while waiting after captcha refresh');
        return _CaptchaPageSignal.success;
      }

      final hasCaptcha = await _detectCaptcha(ctrl, config);
      if (_isCompleted || token != _currentJobToken) {
        return _CaptchaPageSignal.cancelled;
      }
      if (hasCaptcha) {
        if (!config.isImageOcr || await _isCaptchaImageReady(ctrl, config)) {
          return _CaptchaPageSignal.captcha;
        }
      }
      await Future.delayed(interval);
    }
    if (_isCompleted || token != _currentJobToken) {
      return _CaptchaPageSignal.cancelled;
    }
    return _CaptchaPageSignal.timedOut;
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

/// External callbacks the runner emits. Decoupled from the host widget so the
/// runner is portable across the current [ReusableCaptchaWebViewBypasser] and
/// the future [ReusableBrowserWorker].
class CaptchaJobRunnerSink {
  CaptchaJobRunnerSink({this.onResult, this.onIdle, this.onLog});

  final void Function(String taskKey, CaptchaBypassResult result)? onResult;
  final void Function(int workerId)? onIdle;
  final void Function(String message)? onLog;
}

enum _WebViewFlowStage { search, detail }

enum _CaptchaPageSignal { captcha, success, timedOut, superseded, cancelled }

enum _EagerReadiness { loading, notReady, captchaReady, successReady }

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
