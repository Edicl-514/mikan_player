import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/cache/platform_cache_service.dart';

void main() {
  test(
    'directorySize includes nested files and ignores missing directories',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'mikan_platform_cache_stats_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final nested = Directory('${root.path}${Platform.pathSeparator}nested');
      await nested.create();
      await File(
        '${root.path}${Platform.pathSeparator}one.bin',
      ).writeAsBytes([1, 2]);
      await File(
        '${nested.path}${Platform.pathSeparator}two.bin',
      ).writeAsBytes([3, 4, 5]);

      expect(await PlatformCacheService.directorySize(root), 5);
      expect(
        await PlatformCacheService.directorySize(
          Directory('${root.path}${Platform.pathSeparator}missing'),
        ),
        0,
      );
    },
  );
}
