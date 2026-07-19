import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/src/rust/api/captcha.dart' as rust_captcha;
import 'package:mikan_player/utils/app_directories.dart';

abstract interface class CaptchaOcrBackend {
  Future<bool> isInitialized();
  Future<void> initialize({
    required String modelPath,
    required String charsetPath,
  });
  Future<String> recognize(Uint8List imageBytes, {required bool pngFix});
  Future<String> recognizeWithConstraints(
    Uint8List imageBytes, {
    required bool pngFix,
    required rust_captcha.CaptchaConstraintOptions options,
  });
  Future<String> getModelInfo();
}

class RustCaptchaOcrBackend implements CaptchaOcrBackend {
  const RustCaptchaOcrBackend();

  @override
  Future<bool> isInitialized() => rust_captcha.isCaptchaOcrInitialized();

  @override
  Future<void> initialize({
    required String modelPath,
    required String charsetPath,
  }) => rust_captcha.initializeCaptchaOcr(
    modelPath: modelPath,
    charsetPath: charsetPath,
  );

  @override
  Future<String> recognize(Uint8List imageBytes, {required bool pngFix}) =>
      rust_captcha.recognizeCaptcha(imageBytes: imageBytes, pngFix: pngFix);

  @override
  Future<String> recognizeWithConstraints(
    Uint8List imageBytes, {
    required bool pngFix,
    required rust_captcha.CaptchaConstraintOptions options,
  }) => rust_captcha.recognizeCaptchaWithConstraints(
    imageBytes: imageBytes,
    pngFix: pngFix,
    options: options,
  );

  @override
  Future<String> getModelInfo() => rust_captcha.getCaptchaOcrModelInfo();
}

typedef CaptchaAssetLoader = Future<Uint8List> Function(String assetPath);

class CaptchaConstraintOptions {
  const CaptchaConstraintOptions({
    this.allowedChars,
    this.expectedLength,
    this.enableLookalikeMapping = true,
  });

  final String? allowedChars;
  final int? expectedLength;
  final bool enableLookalikeMapping;

  rust_captcha.CaptchaConstraintOptions toRust() {
    return rust_captcha.CaptchaConstraintOptions(
      allowedChars: allowedChars,
      expectedLength: expectedLength,
      enableLookalikeMapping: enableLookalikeMapping,
    );
  }
}

class CaptchaOcrService {
  CaptchaOcrService._({
    CaptchaOcrBackend backend = const RustCaptchaOcrBackend(),
    Future<Directory> Function()? appSupportDirectory,
    CaptchaAssetLoader? assetLoader,
  }) : _backend = backend,
       _appSupportDirectory =
           appSupportDirectory ?? AppDirectories.getUnifiedAppDataDirectory,
       _assetLoader = assetLoader ?? _loadRootBundleAsset;

  static final CaptchaOcrService instance = CaptchaOcrService._();

  static const _modelAssetPath = 'assets/ocr/common.onnx';
  static const _charsetAssetPath = 'assets/ocr/common_beta_charset.json';

  final CaptchaOcrBackend _backend;
  final Future<Directory> Function() _appSupportDirectory;
  final CaptchaAssetLoader _assetLoader;

  Future<void>? _initializing;

  @visibleForTesting
  factory CaptchaOcrService.forTesting({
    required CaptchaOcrBackend backend,
    required Future<Directory> Function() appSupportDirectory,
    required CaptchaAssetLoader assetLoader,
  }) => CaptchaOcrService._(
    backend: backend,
    appSupportDirectory: appSupportDirectory,
    assetLoader: assetLoader,
  );

  Future<void> ensureInitialized() {
    final existing = _initializing;
    if (existing != null) return existing;

    final future = _initialize();
    _initializing = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          if (identical(_initializing, future)) {
            _initializing = null;
          }
        },
      ),
    );
    return future;
  }

  Future<String> recognizeBytes(
    Uint8List imageBytes, {
    bool pngFix = false,
    CaptchaConstraintOptions? constraints,
  }) async {
    await ensureInitialized();
    if (constraints != null) {
      return _backend.recognizeWithConstraints(
        imageBytes,
        pngFix: pngFix,
        options: constraints.toRust(),
      );
    }
    return _backend.recognize(imageBytes, pngFix: pngFix);
  }

  Future<String> recognizeFile(
    String imagePath, {
    bool pngFix = false,
    CaptchaConstraintOptions? constraints,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    return recognizeBytes(bytes, pngFix: pngFix, constraints: constraints);
  }

  Future<String> recognizeFixedDigits(
    Uint8List imageBytes, {
    int length = 4,
    bool pngFix = false,
  }) {
    return recognizeBytes(
      imageBytes,
      pngFix: pngFix,
      constraints: CaptchaConstraintOptions(
        allowedChars: '0123456789',
        expectedLength: length,
        enableLookalikeMapping: true,
      ),
    );
  }

  Future<void> _initialize() async {
    if (await _backend.isInitialized()) {
      return;
    }

    final appSupportDir = await _appSupportDirectory();
    final ocrDir = Directory(
      '${appSupportDir.path}${Platform.pathSeparator}ocr',
    );
    if (!await ocrDir.exists()) {
      await ocrDir.create(recursive: true);
    }

    final modelFile = File(
      '${ocrDir.path}${Platform.pathSeparator}common.onnx',
    );
    final charsetFile = File(
      '${ocrDir.path}${Platform.pathSeparator}common_beta_charset.json',
    );

    await _copyAssetIfMissing(_modelAssetPath, modelFile);
    await _copyAssetIfMissing(_charsetAssetPath, charsetFile);

    await _backend.initialize(
      modelPath: modelFile.path,
      charsetPath: charsetFile.path,
    );

    if (kDebugMode) {
      debugPrint(await _debugModelInfo());
    }
  }

  Future<void> _copyAssetIfMissing(String assetPath, File targetFile) async {
    if (await targetFile.exists()) {
      return;
    }

    final bytes = await _assetLoader(assetPath);
    await targetFile.writeAsBytes(bytes, flush: true);
  }

  Future<String> _debugModelInfo() async {
    return _backend.getModelInfo();
  }

  static Future<Uint8List> _loadRootBundleAsset(String assetPath) async {
    final asset = await rootBundle.load(assetPath);
    return asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
  }
}
