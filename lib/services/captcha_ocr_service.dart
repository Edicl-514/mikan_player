import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/src/rust/api/captcha.dart' as rust_captcha;
import 'package:mikan_player/utils/app_directories.dart';

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
  CaptchaOcrService._();

  static final CaptchaOcrService instance = CaptchaOcrService._();

  static const _modelAssetPath = 'assets/ocr/common.onnx';
  static const _charsetAssetPath = 'assets/ocr/common_beta_charset.json';

  Future<void>? _initializing;

  Future<void> ensureInitialized() {
    return _initializing ??= _initialize();
  }

  Future<String> recognizeBytes(
    Uint8List imageBytes, {
    bool pngFix = false,
    CaptchaConstraintOptions? constraints,
  }) async {
    await ensureInitialized();
    if (constraints != null) {
      return rust_captcha.recognizeCaptchaWithConstraints(
        imageBytes: imageBytes,
        pngFix: pngFix,
        options: constraints.toRust(),
      );
    }
    return rust_captcha.recognizeCaptcha(
      imageBytes: imageBytes,
      pngFix: pngFix,
    );
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
    if (await rust_captcha.isCaptchaOcrInitialized()) {
      return;
    }

    final appSupportDir = await AppDirectories.getUnifiedAppDataDirectory();
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

    await rust_captcha.initializeCaptchaOcr(
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

    final asset = await rootBundle.load(assetPath);
    await targetFile.writeAsBytes(asset.buffer.asUint8List(), flush: true);
  }

  Future<String> _debugModelInfo() async {
    return rust_captcha.getCaptchaOcrModelInfo();
  }
}
