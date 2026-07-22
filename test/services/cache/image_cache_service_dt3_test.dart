import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/cache/image_cache_service.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

import '../../support/local_http_server.dart';

void main() {
  group('ImageCacheService network boundary', () {
    late Directory tempDir;
    late ImageCacheService service;
    late LocalHttpServer server;

    setUp(() async {
      BangumiUrlRewriter.setEnabled(false);
      tempDir = await Directory.systemTemp.createTemp('mikan_image_cache_dt3_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      server = await startLocalHttpServer();
      service = ImageCacheService.forTesting(cacheDirectory: tempDir);
      addTearDown(service.debugCloseForTest);
      await service.initialize();
    });

    String url(String path) => server.baseUri.replace(path: path).toString();

    test(
      'downloads bytes with image headers and reuses the disk cache',
      () async {
        server.setRoute(
          '/cover.png',
          (_) => const LocalHttpServerResponse(
            body: <int>[1, 2, 3, 4],
            headers: <String, String>{'content-type': 'image/png'},
          ),
        );

        final first = await service.cacheImage(url('/cover.png'));
        final second = await service.cacheImage(url('/cover.png'));

        expect(first, isNotNull);
        expect(second, first);
        expect(await File(first!).readAsBytes(), [1, 2, 3, 4]);
        expect(first, endsWith('.png'));
        expect(server.recordedRequests, hasLength(1));
        expect(
          server.recordedRequests.single.headers['referer'],
          '${server.baseUri}/',
        );
        expect(
          server.recordedRequests.single.headers['user-agent'],
          isNotEmpty,
        );
        expect(service.getCachedPathSync(url('/cover.png')), first);
      },
    );

    test('coalesces concurrent downloads for the same canonical URL', () async {
      server.setRoute('/same.jpg', (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return const LocalHttpServerResponse(body: <int>[9, 8, 7]);
      });

      final results = await Future.wait(
        List.generate(8, (_) => service.cacheImage(url('/same.jpg'))),
      );

      expect(results.toSet(), hasLength(1));
      expect(results.first, isNotNull);
      expect(server.recordedRequests, hasLength(1));
    });

    test(
      'does not create a cache file for non-200 or empty responses',
      () async {
        server.setRoute(
          '/missing.jpg',
          (_) => const LocalHttpServerResponse(status: HttpStatus.notFound),
        );
        server.setRoute('/empty.jpg', (_) => const LocalHttpServerResponse());

        expect(await service.cacheImage(url('/missing.jpg')), isNull);
        expect(await service.cacheImage(url('/empty.jpg')), isNull);
        expect(await service.getCacheCount(), 0);
        expect(await service.getCacheSize(), 0);
      },
    );

    test(
      'delete and clear evict both disk and synchronous memory entries',
      () async {
        server.setRoute(
          '/one.jpg',
          (_) => const LocalHttpServerResponse(body: [1]),
        );
        server.setRoute(
          '/two.jpg',
          (_) => const LocalHttpServerResponse(body: [2]),
        );
        final first = await service.cacheImage(url('/one.jpg'));
        final second = await service.cacheImage(url('/two.jpg'));

        expect(await service.deleteImage(url('/one.jpg')), isTrue);
        expect(service.getCachedPathSync(url('/one.jpg')), isNull);
        expect(await File(first!).exists(), isFalse);

        await service.clearAll();
        expect(service.getCachedPathSync(url('/two.jpg')), isNull);
        expect(await File(second!).exists(), isFalse);
        expect(await service.getCacheCount(), 0);
      },
    );

    test('an in-flight download cannot repopulate a cleared cache', () async {
      final response = Completer<LocalHttpServerResponse>();
      server.setRoute('/slow.jpg', (_) => response.future);

      final download = service.cacheImage(url('/slow.jpg'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.clearAll();
      response.complete(const LocalHttpServerResponse(body: [1, 2, 3]));

      expect(await download, isNull);
      expect(await service.getCacheCount(), 0);
      expect(await service.isCached(url('/slow.jpg')), isFalse);
    });

    test('age cleanup evicts stale synchronous memory paths', () async {
      server.setRoute(
        '/old.jpg',
        (_) => const LocalHttpServerResponse(body: [3]),
      );
      final path = await service.cacheImage(url('/old.jpg'));
      final old = DateTime.now().subtract(const Duration(days: 10));
      await File(path!).setLastModified(old);
      expect(service.getCachedPathSync(url('/old.jpg')), path);

      await service.cleanupOldCache(maxAgeDays: 1);

      expect(await File(path).exists(), isFalse);
      expect(service.getCachedPathSync(url('/old.jpg')), isNull);
    });

    test('size cleanup removes oldest files until under the limit', () async {
      server.setRoute(
        '/old.jpg',
        (_) => const LocalHttpServerResponse(body: [1, 1, 1]),
      );
      server.setRoute(
        '/new.jpg',
        (_) => const LocalHttpServerResponse(body: [2, 2, 2]),
      );
      final oldPath = await service.cacheImage(url('/old.jpg'));
      final newPath = await service.cacheImage(url('/new.jpg'));
      await File(
        oldPath!,
      ).setLastModified(DateTime.now().subtract(const Duration(days: 1)));

      await service.cleanupOldCache(maxAgeDays: 30, maxSizeBytes: 3);

      expect(await File(oldPath).exists(), isFalse);
      expect(await File(newPath!).exists(), isTrue);
      expect(service.getCachedPathSync(url('/old.jpg')), isNull);
      expect(await service.getCacheSize(), 3);
    });

    test(
      'legacy cache migration merges files and removes the old directory',
      () async {
        final legacy = Directory(
          '${tempDir.path}${Platform.pathSeparator}legacy',
        );
        final target = Directory(
          '${tempDir.path}${Platform.pathSeparator}target',
        );
        await legacy.create();
        await target.create();
        await File(
          '${legacy.path}${Platform.pathSeparator}old.jpg',
        ).writeAsBytes([1, 2, 3]);
        await File(
          '${legacy.path}${Platform.pathSeparator}same.jpg',
        ).writeAsBytes([1]);
        await File(
          '${target.path}${Platform.pathSeparator}same.jpg',
        ).writeAsBytes([9]);

        await ImageCacheService.migrateCacheDirectory(
          legacy: legacy,
          target: target,
        );

        expect(await legacy.exists(), isFalse);
        expect(
          await File(
            '${target.path}${Platform.pathSeparator}old.jpg',
          ).readAsBytes(),
          [1, 2, 3],
        );
        expect(
          await File(
            '${target.path}${Platform.pathSeparator}same.jpg',
          ).readAsBytes(),
          [9],
        );
      },
    );

    test(
      'batch caching preserves each input key and canonical mirror paths match',
      () async {
        server.setRoute(
          '/a.webp',
          (_) => const LocalHttpServerResponse(body: [1]),
        );
        server.setRoute(
          '/b.gif',
          (_) => const LocalHttpServerResponse(body: [2]),
        );
        final inputs = [url('/a.webp'), url('/b.gif')];

        final results = await service.cacheImages(inputs);

        expect(results.keys, inputs);
        expect(results[inputs[0]], endsWith('.webp'));
        expect(results[inputs[1]], endsWith('.gif'));
        expect(
          service.getLocalPath('https://api.bgm.tv/v0/subjects/1/image'),
          service.getLocalPath('https://api.bangumi.lol/v0/subjects/1/image'),
        );
      },
    );
  });
}
