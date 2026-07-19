import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/captcha_ocr_service.dart';
import 'package:mikan_player/src/rust/api/captcha.dart' as rust_captcha;

void main() {
  late Directory tempDir;
  late FakeCaptchaOcrBackend backend;
  late List<String> assetRequests;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mikan_ocr_dt3_');
    backend = FakeCaptchaOcrBackend();
    assetRequests = <String>[];
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CaptchaOcrService makeService({CaptchaAssetLoader? assetLoader}) {
    return CaptchaOcrService.forTesting(
      backend: backend,
      appSupportDirectory: () async => tempDir,
      assetLoader:
          assetLoader ??
          (path) async {
            assetRequests.add(path);
            return Uint8List.fromList(path.endsWith('.onnx') ? [1, 2] : [3, 4]);
          },
    );
  }

  test('constraint options map every field to the Rust DTO', () {
    const options = CaptchaConstraintOptions(
      allowedChars: 'ABC123',
      expectedLength: 6,
      enableLookalikeMapping: false,
    );

    final rust = options.toRust();

    expect(rust.allowedChars, 'ABC123');
    expect(rust.expectedLength, 6);
    expect(rust.enableLookalikeMapping, isFalse);
  });

  test('already initialized backend skips directory and asset work', () async {
    backend.initialized = true;
    var directoryCalls = 0;
    final service = CaptchaOcrService.forTesting(
      backend: backend,
      appSupportDirectory: () async {
        directoryCalls++;
        return tempDir;
      },
      assetLoader: (path) async {
        assetRequests.add(path);
        return Uint8List(0);
      },
    );

    await service.ensureInitialized();

    expect(backend.isInitializedCalls, 1);
    expect(backend.initializeCalls, 0);
    expect(directoryCalls, 0);
    expect(assetRequests, isEmpty);
  });

  test(
    'concurrent initialization shares one backend check and future',
    () async {
      final checked = Completer<bool>();
      backend.onIsInitialized = () => checked.future;
      final service = makeService();

      final first = service.ensureInitialized();
      final second = service.ensureInitialized();
      expect(identical(first, second), isTrue);
      expect(backend.isInitializedCalls, 1);
      checked.complete(true);
      await Future.wait([first, second]);

      expect(backend.initializeCalls, 0);
    },
  );

  test(
    'copies missing assets and initializes with stable file paths',
    () async {
      final service = makeService();

      await service.ensureInitialized();

      final ocrDir = Directory('${tempDir.path}${Platform.pathSeparator}ocr');
      final model = File('${ocrDir.path}${Platform.pathSeparator}common.onnx');
      final charset = File(
        '${ocrDir.path}${Platform.pathSeparator}common_beta_charset.json',
      );
      expect(await model.readAsBytes(), [1, 2]);
      expect(await charset.readAsBytes(), [3, 4]);
      expect(assetRequests, [
        'assets/ocr/common.onnx',
        'assets/ocr/common_beta_charset.json',
      ]);
      expect(backend.initializePaths.single, (model.path, charset.path));
      expect(backend.modelInfoCalls, 1);
    },
  );

  test(
    'existing model files are preserved without loading bundled assets',
    () async {
      final ocrDir = Directory('${tempDir.path}${Platform.pathSeparator}ocr');
      await ocrDir.create(recursive: true);
      final model = File('${ocrDir.path}${Platform.pathSeparator}common.onnx');
      final charset = File(
        '${ocrDir.path}${Platform.pathSeparator}common_beta_charset.json',
      );
      await model.writeAsBytes([9]);
      await charset.writeAsBytes([8]);

      await makeService().ensureInitialized();

      expect(await model.readAsBytes(), [9]);
      expect(await charset.readAsBytes(), [8]);
      expect(assetRequests, isEmpty);
    },
  );

  test(
    'failed initialization is cleared so a later attempt can retry',
    () async {
      backend.initializeErrors.add(StateError('first init failed'));
      final service = makeService();

      await expectLater(service.ensureInitialized(), throwsStateError);
      await service.ensureInitialized();

      expect(backend.isInitializedCalls, 2);
      expect(backend.initializeCalls, 2);
      expect(assetRequests, hasLength(2));
    },
  );

  test(
    'recognize bytes selects unconstrained and constrained backend paths',
    () async {
      backend.initialized = true;
      backend.recognizeResult = 'plain';
      backend.constrainedResult = 'fixed';
      final service = makeService();
      final bytes = Uint8List.fromList([1, 2, 3]);

      expect(await service.recognizeBytes(bytes, pngFix: true), 'plain');
      expect(
        await service.recognizeBytes(
          bytes,
          constraints: const CaptchaConstraintOptions(
            allowedChars: 'AB',
            expectedLength: 2,
          ),
        ),
        'fixed',
      );

      expect(backend.recognizeCalls.single, (bytes, true));
      final constrained = backend.constrainedCalls.single;
      expect(constrained.$1, bytes);
      expect(constrained.$2, isFalse);
      expect(constrained.$3.allowedChars, 'AB');
      expect(constrained.$3.expectedLength, 2);
    },
  );

  test(
    'recognizeFile reads bytes and fixed digits supplies numeric constraints',
    () async {
      backend.initialized = true;
      backend.recognizeResult = 'file';
      backend.constrainedResult = '12345';
      final service = makeService();
      final file = File('${tempDir.path}${Platform.pathSeparator}captcha.png');
      await file.writeAsBytes([7, 8, 9]);

      expect(await service.recognizeFile(file.path), 'file');
      expect(
        await service.recognizeFixedDigits(
          Uint8List.fromList([4]),
          length: 5,
          pngFix: true,
        ),
        '12345',
      );

      expect(backend.recognizeCalls.single.$1, [7, 8, 9]);
      final options = backend.constrainedCalls.single.$3;
      expect(options.allowedChars, '0123456789');
      expect(options.expectedLength, 5);
      expect(options.enableLookalikeMapping, isTrue);
      expect(backend.constrainedCalls.single.$2, isTrue);
    },
  );
}

class FakeCaptchaOcrBackend implements CaptchaOcrBackend {
  bool initialized = false;
  Future<bool> Function()? onIsInitialized;
  int isInitializedCalls = 0;
  int initializeCalls = 0;
  final initializePaths = <(String, String)>[];
  final initializeErrors = <Object>[];
  String recognizeResult = '';
  String constrainedResult = '';
  final recognizeCalls = <(Uint8List, bool)>[];
  final constrainedCalls =
      <(Uint8List, bool, rust_captcha.CaptchaConstraintOptions)>[];
  int modelInfoCalls = 0;

  @override
  Future<bool> isInitialized() {
    isInitializedCalls++;
    return onIsInitialized?.call() ?? Future.value(initialized);
  }

  @override
  Future<void> initialize({
    required String modelPath,
    required String charsetPath,
  }) async {
    initializeCalls++;
    initializePaths.add((modelPath, charsetPath));
    if (initializeErrors.isNotEmpty) throw initializeErrors.removeAt(0);
    initialized = true;
  }

  @override
  Future<String> recognize(Uint8List imageBytes, {required bool pngFix}) async {
    recognizeCalls.add((imageBytes, pngFix));
    return recognizeResult;
  }

  @override
  Future<String> recognizeWithConstraints(
    Uint8List imageBytes, {
    required bool pngFix,
    required rust_captcha.CaptchaConstraintOptions options,
  }) async {
    constrainedCalls.add((imageBytes, pngFix, options));
    return constrainedResult;
  }

  @override
  Future<String> getModelInfo() async {
    modelInfoCalls++;
    return 'fake model';
  }
}
