import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'scanner finds literals nested inside interpolation expressions',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mikan-i18n-scanner-',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final source = File(
        '${tempDir.path}${Platform.pathSeparator}sample.dart',
      );
      await source.writeAsString(r'''
void buildMessage() {
  final probe = '${true ? '可播放' : '不可播放'}';
  final episode = '${true ? '第${1}集' : 'Episode 1'}';
  print('$probe $episode');
}
''');

      final dartArguments = <String>[
        'run',
        'tool/scan_hardcoded_ui_text.dart',
        '--fail-on-findings',
        source.path,
      ];
      final result = await Process.run(
        Platform.isWindows
            ? (Platform.environment['COMSPEC'] ?? 'cmd.exe')
            : 'dart',
        Platform.isWindows
            ? <String>['/d', '/c', 'dart', ...dartArguments]
            : dartArguments,
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 1);
      expect(result.stdout, contains('可播放'));
      expect(result.stdout, contains(r'第${1}集'));
    },
  );
}
