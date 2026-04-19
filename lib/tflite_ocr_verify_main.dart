import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/services/captcha_ocr_service.dart';
import 'package:mikan_player/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const CaptchaOcrVerifyApp());
}

class CaptchaOcrVerifyApp extends StatelessWidget {
  const CaptchaOcrVerifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Captcha OCR Verify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CaptchaOcrVerifyPage(),
    );
  }
}

class CaptchaOcrVerifyPage extends StatefulWidget {
  const CaptchaOcrVerifyPage({super.key});

  @override
  State<CaptchaOcrVerifyPage> createState() => _CaptchaOcrVerifyPageState();
}

class _CaptchaOcrVerifyPageState extends State<CaptchaOcrVerifyPage> {
  final _pathController = TextEditingController();
  final _allowedCharsController = TextEditingController(text: '0123456789');
  final _expectedLengthController = TextEditingController(text: '4');
  bool _pngFix = false;
  bool _isRunning = false;
  bool _useConstraints = true;
  bool _digitsOnlyPreset = true;
  bool _enableLookalikeMapping = true;
  String _result = '';

  @override
  void dispose() {
    _pathController.dispose();
    _allowedCharsController.dispose();
    _expectedLengthController.dispose();
    super.dispose();
  }

  Future<void> _runRecognition() async {
    final imagePath = _pathController.text.trim();
    if (imagePath.isEmpty) {
      setState(() {
        _result = 'Please enter an image path.';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _result = 'Running OCR...';
    });

    try {
      final constraints = _buildConstraints();
      final text = await CaptchaOcrService.instance.recognizeFile(
        imagePath,
        pngFix: _pngFix,
        constraints: constraints,
      );
      setState(() {
        _result = text;
      });
    } catch (error) {
      setState(() {
        _result = 'OCR failed: $error';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  CaptchaConstraintOptions? _buildConstraints() {
    if (!_useConstraints) {
      return null;
    }

    final allowedChars = _allowedCharsController.text.trim();
    final expectedLengthText = _expectedLengthController.text.trim();
    final expectedLength = int.tryParse(expectedLengthText);

    return CaptchaConstraintOptions(
      allowedChars: allowedChars.isEmpty ? null : allowedChars,
      expectedLength: expectedLength,
      enableLookalikeMapping: _enableLookalikeMapping,
    );
  }

  void _applyDigitsOnlyPreset(bool enabled) {
    setState(() {
      _digitsOnlyPreset = enabled;
      if (enabled) {
        _allowedCharsController.text = '0123456789';
        _expectedLengthController.text = '4';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Captcha OCR Verify')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Captcha image path',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _pngFix,
              onChanged: (value) {
                setState(() {
                  _pngFix = value;
                });
              },
              title: const Text('Enable PNG white background fix'),
            ),
            SwitchListTile(
              value: _useConstraints,
              onChanged: (value) {
                setState(() {
                  _useConstraints = value;
                });
              },
              title: const Text('Enable constraints'),
            ),
            SwitchListTile(
              value: _digitsOnlyPreset,
              onChanged: _useConstraints ? _applyDigitsOnlyPreset : null,
              title: const Text('Use 4-digit numeric preset'),
            ),
            TextField(
              controller: _allowedCharsController,
              enabled: _useConstraints,
              decoration: const InputDecoration(
                labelText: 'Allowed chars',
                hintText: 'Example: 0123456789',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expectedLengthController,
              enabled: _useConstraints,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Expected length',
                hintText: 'Example: 4',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _enableLookalikeMapping,
              onChanged: _useConstraints
                  ? (value) {
                      setState(() {
                        _enableLookalikeMapping = value;
                      });
                    }
                  : null,
              title: const Text('Enable lookalike mapping'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isRunning ? null : _runRecognition,
              child: Text(_isRunning ? 'Recognizing...' : 'Run OCR'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Result',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(_result),
          ],
        ),
      ),
    );
  }
}
