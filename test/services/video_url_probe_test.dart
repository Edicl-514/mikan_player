import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/video_url_probe.dart';

import '../support/local_http_server.dart';

void main() {
  group('VideoUrlProbeService', () {
    late LocalHttpServer server;
    late VideoUrlProbeService service;

    setUp(() async {
      server = await startLocalHttpServer();
      service = VideoUrlProbeService();
    });

    String url(String path) => server.baseUri.replace(path: path).toString();

    test(
      'accepts video content and sends range, user-agent, and cookies',
      () async {
        server.setRoute(
          '/video',
          (_) => const LocalHttpServerResponse(
            body: <int>[0, 1, 2, 3],
            headers: <String, String>{'content-type': 'video/mp4'},
          ),
        );

        final result = await service.probe(
          url('/video'),
          headers: const {'X-Token': 'abc'},
          cookies: ' sid=123 ',
        );

        expect(result.playable, isTrue);
        expect(result.statusCode, HttpStatus.ok);
        expect(result.contentType, 'video/mp4');
        expect(result.error, isNull);
        final request = server.recordedRequests.single;
        expect(request.headers['range'], 'bytes=0-1023');
        expect(request.headers['x-token'], 'abc');
        expect(request.headers['cookie'], 'sid=123');
        expect(request.headers['user-agent'], isNotEmpty);
      },
    );

    test(
      'explicit Cookie header is not overwritten by cookie argument',
      () async {
        server.setRoute(
          '/cookie',
          (_) => const LocalHttpServerResponse(
            body: <int>[1],
            headers: <String, String>{'content-type': 'video/mp4'},
          ),
        );

        await service.probe(
          url('/cookie'),
          headers: const {'Cookie': 'explicit=1'},
          cookies: 'fallback=2',
        );

        expect(server.recordedRequests.single.headers['cookie'], 'explicit=1');
      },
    );

    test('accepts HLS playlist even when served as text', () async {
      server.setRoute(
        '/playlist',
        (_) => LocalHttpServerResponse.text('#EXTM3U\n#EXT-X-VERSION:3'),
      );

      final result = await service.probe(url('/playlist'));

      expect(result.playable, isTrue);
    });

    test('follows a redirect to playable media', () async {
      server.setRoute(
        '/redirect',
        (_) => LocalHttpServerResponse(
          status: HttpStatus.found,
          headers: {'location': url('/target')},
        ),
      );
      server.setRoute(
        '/target',
        (_) => const LocalHttpServerResponse(
          body: <int>[1, 2],
          headers: <String, String>{'content-type': 'video/mp2t'},
        ),
      );

      final result = await service.probe(url('/redirect'));

      expect(result.playable, isTrue);
      expect(result.statusCode, HttpStatus.ok);
      expect(server.recordedRequests.map((r) => r.path), [
        '/redirect',
        '/target',
      ]);
    });

    test('rejects HTML error pages returned with status 200', () async {
      server.setRoute(
        '/captcha',
        (_) => LocalHttpServerResponse.text(
          '<html><body>Access denied: captcha</body></html>',
          headers: const {'content-type': 'text/html; charset=utf-8'},
        ),
      );

      final result = await service.probe(url('/captcha'));

      expect(result.playable, isFalse);
      expect(result.error, 'Returned an HTML error page');
    });

    test('rejects image and JSON responses', () async {
      server.setRoute(
        '/image',
        (_) => const LocalHttpServerResponse(
          body: <int>[1],
          headers: <String, String>{'content-type': 'image/png'},
        ),
      );
      server.setRoute(
        '/json',
        (_) => LocalHttpServerResponse.json({'ok': true}),
      );

      final image = await service.probe(url('/image'));
      final json = await service.probe(url('/json'));

      expect(image.playable, isFalse);
      expect(image.error, 'Returned a non-media response');
      expect(json.playable, isFalse);
      expect(json.error, 'Response did not look playable');
    });

    test(
      'reports HTTP errors without waiting for an unbounded error body',
      () async {
        final rawServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() => rawServer.close(force: true));
        rawServer.listen((request) async {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.text;
          request.response.write('x');
          await request.response.flush();
          // Intentionally leave the response body open. Status alone is enough
          // for the probe to reject the URL.
        });

        final stopwatch = Stopwatch()..start();
        final result = await service.probe(
          'http://${rawServer.address.host}:${rawServer.port}/hang',
          timeout: const Duration(seconds: 2),
        );
        stopwatch.stop();

        expect(result.playable, isFalse);
        expect(result.statusCode, HttpStatus.internalServerError);
        expect(result.error, 'HTTP 500');
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      },
    );

    test('returns timeout and parse errors as non-playable results', () async {
      final timeoutServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => timeoutServer.close(force: true));
      timeoutServer.listen((request) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        await request.response.close();
      });

      final timedOut = await service.probe(
        'http://${timeoutServer.address.host}:${timeoutServer.port}/slow',
        timeout: const Duration(milliseconds: 40),
      );
      final malformed = await service.probe('not a valid url');

      expect(timedOut.playable, isFalse);
      expect(timedOut.error, 'Probe timed out');
      expect(malformed.playable, isFalse);
      expect(malformed.error, isNotEmpty);
    });
  });
}
