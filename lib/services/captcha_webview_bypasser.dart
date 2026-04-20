import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;
import 'package:mikan_player/services/captcha_ocr_service.dart';
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
  final int initialDelayMs;
  final OcrConstraints? ocrConstraints;

  const CaptchaConfig({
    required this.enable,
    this.type,
    this.detectSelector,
    this.successSelector,
    this.imageSelector,
    this.inputSelector,
    this.submitSelector,
    this.initialDelayMs = 1000,
    this.ocrConstraints,
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
      initialDelayMs: json['initialDelayMs'] as int? ?? 1000,
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
}

class CaptchaBypassResult {
  final String sourceName;
  final bool success;
  final String? error;
  final String? cookies;
  final String? pageHtml;
  final String? pageUrl;

  const CaptchaBypassResult({
    required this.sourceName,
    required this.success,
    this.error,
    this.cookies,
    this.pageHtml,
    this.pageUrl,
  });
}

class CaptchaWebViewBypassWidget extends StatefulWidget {
  final SourceState source;
  final String searchKeyword;
  final CaptchaConfig captchaConfig;
  final Duration timeout;
  final void Function(CaptchaBypassResult result) onResult;
  final void Function(String message)? onLog;
  final bool showWebView;

  const CaptchaWebViewBypassWidget({
    super.key,
    required this.source,
    required this.searchKeyword,
    required this.captchaConfig,
    this.timeout = const Duration(seconds: 45),
    required this.onResult,
    this.onLog,
    this.showWebView = false,
  });

  @override
  State<CaptchaWebViewBypassWidget> createState() =>
      _CaptchaWebViewBypassWidgetState();
}

class _CaptchaWebViewBypassWidgetState
    extends State<CaptchaWebViewBypassWidget> {
  Timer? _timeoutTimer;
  bool _isCompleted = false;
  int _captchaRetryCount = 0;
  static const _maxCaptchaRetries = 3;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(widget.timeout, () {
      if (_isCompleted) return;
      _log('Captcha preflight timed out');
      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: false,
          error: 'Captcha preflight timed out after ${widget.timeout.inSeconds}s',
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
    _log('Completed: success=${result.success}, error=${result.error}');
    widget.onResult(result);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchUrl = widget.source.searchUrl.replaceAll(
      '{keyword}',
      widget.searchKeyword,
    );

    final webView = InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(searchUrl)),
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        useHybridComposition: true,
      ),
      onWebViewCreated: (_) {
        _log('WebView created, loading search: $searchUrl');
      },
      onLoadStop: (ctrl, url) async {
        _log('Page loaded: $url');

        await Future.delayed(
          Duration(milliseconds: widget.captchaConfig.initialDelayMs),
        );

        if (_isCompleted) return;

        final hasCaptcha = await _detectCaptcha(ctrl, widget.captchaConfig);
        if (hasCaptcha) {
          await _handleCaptcha(ctrl);
          return;
        }

        await _completeSuccess(ctrl, url?.toString());
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame ?? false) {
          _log('Page error: ${error.description}');
        }
      },
    );

    if (widget.showWebView) {
      return Container(
        height: 300,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: webView,
      );
    }

    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(opacity: 0, child: webView),
    );
  }

  Future<void> _handleCaptcha(InAppWebViewController ctrl) async {
    if (!widget.captchaConfig.isImageOcr) {
      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: false,
          error:
              'Captcha type "${widget.captchaConfig.type}" not supported',
        ),
      );
      return;
    }

    if (_captchaRetryCount >= _maxCaptchaRetries) {
      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: false,
          error: 'Captcha bypass failed after $_maxCaptchaRetries retries',
        ),
      );
      return;
    }

    _captchaRetryCount++;
    _log(
      'Captcha detected (attempt $_captchaRetryCount/$_maxCaptchaRetries)',
    );

    final ocrResult = await _solveImageOcrCaptcha(ctrl, widget.captchaConfig);
    if (ocrResult == null) {
      _log('OCR failed');
      if (_captchaRetryCount >= _maxCaptchaRetries) {
        _complete(
          CaptchaBypassResult(
            sourceName: widget.source.name,
            success: false,
            error: 'OCR failed to solve captcha',
          ),
        );
      }
      return;
    }

    _log('OCR result: $ocrResult, submitting...');
    await _fillInputAndSubmit(ctrl, widget.captchaConfig, ocrResult);
    await Future.delayed(const Duration(milliseconds: 2000));

    if (_isCompleted) return;

    final success = await _checkSuccess(ctrl, widget.captchaConfig);
    if (!success) {
      _log('Captcha still present after submit');
      if (_captchaRetryCount >= _maxCaptchaRetries) {
        _complete(
          CaptchaBypassResult(
            sourceName: widget.source.name,
            success: false,
            error: 'Captcha verification failed',
          ),
        );
      }
      return;
    }

    _log('Captcha bypassed');
    final currentUrl = (await ctrl.getUrl())?.toString();
    await _completeSuccess(ctrl, currentUrl);
  }

  Future<void> _completeSuccess(
    InAppWebViewController ctrl,
    String? currentUrl,
  ) async {
    try {
      final pageHtml = await ctrl.evaluateJavascript(
        source:
            '(function(){ return document.documentElement ? document.documentElement.outerHTML : null; })()',
      );

      final cookies = await _getCookiesForUrl(
        currentUrl ??
            widget.source.searchUrl.replaceAll('{keyword}', widget.searchKeyword),
      );

      _complete(
        CaptchaBypassResult(
          sourceName: widget.source.name,
          success: true,
          cookies: cookies,
          pageHtml: pageHtml?.toString(),
          pageUrl: currentUrl,
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
      try {
        final exists = await ctrl.evaluateJavascript(
          source:
              '(function(){ return document.querySelector("${_esc(selector)}") !== null; })()',
        );
        if (exists == true) return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<bool> _checkSuccess(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    final selector = config.successSelector;
    if (selector == null || selector.isEmpty) return true;
    try {
      final exists = await ctrl.evaluateJavascript(
        source:
            '(function(){ return document.querySelector("${_esc(selector)}") !== null; })()',
      );
      return exists == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _solveImageOcrCaptcha(
    InAppWebViewController ctrl,
    CaptchaConfig config,
  ) async {
    final imageSelector = config.imageSelector;
    if (imageSelector == null || imageSelector.isEmpty) return null;

    try {
      final imageSrc = await ctrl.evaluateJavascript(source: '''
(function(){
  var img = document.querySelector("${_esc(imageSelector)}");
  if(!img) return null;
  var c = document.createElement("canvas");
  c.width = img.naturalWidth || img.width;
  c.height = img.naturalHeight || img.height;
  c.getContext("2d").drawImage(img, 0, 0);
  return c.toDataURL("image/png");
})()
''');

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

  static Future<void> _fillInputAndSubmit(
    InAppWebViewController ctrl,
    CaptchaConfig config,
    String ocrResult,
  ) async {
    final inputSelector = config.inputSelector;
    final submitSelector = config.submitSelector;

    if (inputSelector != null && inputSelector.isNotEmpty) {
      await ctrl.evaluateJavascript(source: '''
(function(){
  var input = document.querySelector("${_esc(inputSelector)}");
  if(input){
    input.value = "${_esc(ocrResult)}";
    input.dispatchEvent(new Event("input", {bubbles: true}));
    input.dispatchEvent(new Event("change", {bubbles: true}));
  }
})()
''');
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (submitSelector != null && submitSelector.isNotEmpty) {
      await ctrl.evaluateJavascript(source: '''
(function(){
  var btn = document.querySelector("${_esc(submitSelector)}");
  if(btn) btn.click();
})()
''');
    }
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
