part of '../webview_captcha_job_runner.dart';

// Page-signal helpers extracted from `webview_captcha_job_runner.dart`.
//
// Two stratifications: pure DOM-signal primitives live at file scope as
// library-private free functions (they take an [InAppWebViewController] and
// return a bool / parsed value), while poll loops that observe the runner's
// cancel / token flags live as private extension methods on
// [CaptchaJobRunner] so they can read `_isCompleted` / `_loadEventToken` /
// `_currentJobToken` / `_log`.
//
// All names keep the underscore prefix — they remain library-private.

// --------------------- Pure DOM-signal primitives ---------------------

String _buildSelectorExistsScript(String selector) {
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
Future<dynamic> _evalJs(
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

Future<bool> _detectCaptcha(
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

Future<bool> _checkSuccess(
  InAppWebViewController ctrl,
  CaptchaConfig config, {
  bool allowEmptySelector = true,
}) async {
  final selector = config.successSelector;
  if (selector == null || selector.isEmpty) return allowEmptySelector;
  final exists = await _evalJs(ctrl, _buildSelectorExistsScript(selector));
  return exists == true;
}

Future<bool> _isDocumentReady(InAppWebViewController ctrl) async {
  final ready = await _evalJs(
    ctrl,
    '(function(){ return document.readyState === "complete"; })()',
  );
  return ready == true;
}

Future<bool> _selectorExists(
  InAppWebViewController ctrl,
  String? selector,
) async {
  if (selector == null || selector.trim().isEmpty) return true;
  final exists = await _evalJs(ctrl, _buildSelectorExistsScript(selector));
  return exists == true;
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

/// Eager (mid-load) readiness probe. Pure over the DOM — uses no runner
/// state. The polling orchestration that consumes this value lives on the
/// runner (`_runEagerCaptchaPoll`).
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

// --------------------- Poll loops (state-touching) ---------------------

extension _CaptchaRunnerPageSignal on CaptchaJobRunner {
  /// Polls [ctrl] for either a captcha or a success marker, returning the
  /// first signal that lands. Returns [_CaptchaPageSignal.timedOut] when
  /// [timeout] elapses with neither; `cancelled` / `superseded` when the
  /// job has been cancelled or a newer load event has invalidated this poll.
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

  /// After a captcha refresh click / page reload the captcha node often
  /// disappears for a short window. Wait for either a real success marker
  /// or a ready captcha image before declaring the challenge solved.
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

  /// After submitting the captcha, wait for either the success marker or
  /// the page reload that consuming the captcha triggers. Returns `true`
  /// when the request has cleared.
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
}
