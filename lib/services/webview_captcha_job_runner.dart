import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/services/cookie_usage_registry.dart';

import 'package:mikan_player/services/captcha_ocr_service.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/services/webview_cookie_janitor.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_policy.dart';

import 'package:mikan_player/services/captcha/captcha_job_runner_sink.dart';

export 'package:mikan_player/services/captcha/captcha_job_runner_sink.dart'
    show CaptchaJobRunnerSink;

part 'captcha/captcha_job_types.dart';
part 'captcha/captcha_page_signal.dart';
part 'captcha/captcha_search_flow.dart';
part 'captcha/captcha_detail_flow.dart';

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
  CookieHostLeaseId? _cookieHostLeaseId;

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
    _ensureCookieHostLease(job);
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
        janitor.requestHostCleanup(
          host: host,
          sessionId: stats?.sessionContext?.sessionId,
          generation:
              stats?.sessionContext?.generation ?? _currentJob?.generation,
          ownerTag: stats?.sessionContext?.tag,
        );
      }
      _visitedHosts.clear();
    }
    _releaseCookieHostLease();
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
        final lease = _cookieHostLeaseId;
        if (lease != null) {
          CookieUsageRegistry.instance.acquireHost(lease, host);
        }
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
    sink.onResult?.call(job, result);
    sink.onIdle?.call(workerId, job);
  }

  void _cancelCurrentJob({bool preserveSession = false}) {
    final job = _currentJob;
    if (job == null) return;
    // A result/timeout may complete synchronously before the host rebuilds
    // with a null job. A concurrent explicit cancel must only retire that
    // already-settled job; emitting onIdle again would settle one dispatch
    // twice and can trigger duplicate slot release / pool pumps.
    if (_isCompleted) {
      _currentJob = null;
      _resetJobState(advanceToken: true);
      return;
    }
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
    sink.onIdle?.call(workerId, job);
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
        janitor.requestHostCleanup(
          host: host,
          sessionId: stats?.sessionContext?.sessionId,
          generation: _currentJob?.generation,
          ownerTag: stats?.sessionContext?.tag,
        );
      }
      _log(
        'Cross-source host/cookie cleanup: $lastSource -> '
        '${incomingSource ?? '(idle)'} hosts=${_visitedHosts.length}',
      );
      _visitedHosts.clear();
      _releaseCookieHostLease();
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

  void _ensureCookieHostLease(CaptchaPreflightJob job) {
    final sessionId = stats?.sessionContext?.sessionId;
    if (sessionId == null) return;
    final lease = _cookieHostLeaseId ??= CookieHostLeaseId(
      sessionId: sessionId,
      resourceKey: 'captcha:$workerId:${identityHashCode(this)}',
    );
    final url = _initialUrl?.trim() ?? job.initialUrl?.trim();
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) {
      CookieUsageRegistry.instance.acquireHost(lease, uri.host);
    }
    for (final host in _visitedHosts) {
      CookieUsageRegistry.instance.acquireHost(lease, host);
    }
  }

  void _releaseCookieHostLease() {
    final lease = _cookieHostLeaseId;
    if (lease == null) return;
    CookieUsageRegistry.instance.releaseLease(lease);
    _cookieHostLeaseId = null;
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

      if (await _maybeAdvanceToDetailStage(
        ctrl,
        token: token,
        effectiveUrl: effectiveUrl,
        finalHtml: finalHtml,
      )) {
        return;
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

  static Map<String, String> _buildNavigationHeaders(
    String url, {
    String? referer,
  }) {
    try {
      final uri = Uri.parse(url);
      final origin = uri.origin;
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
