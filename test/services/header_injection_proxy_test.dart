import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/header_injection_proxy.dart';

import '../support/local_http_server.dart';

void main() {
  group('HeaderInjectionProxy', () {
    late HeaderInjectionProxy proxy;
    late LocalHttpServer upstream;

    setUp(() async {
      proxy = HeaderInjectionProxy();
      await proxy.stop();
      await proxy.start();
      upstream = await startLocalHttpServer();
    });

    tearDown(() => proxy.stop());

    test('returns original URL before the server is started', () async {
      await proxy.stop();
      expect(
        proxy.registerUrl('https://example.test/video', const {'X-A': '1'}),
        'https://example.test/video',
      );
    });

    test(
      'forwards status, body, response headers, and injected headers',
      () async {
        upstream.setRoute(
          '/video',
          (request) => LocalHttpServerResponse.text(
            '${request.headers['x-token']}|${request.headers['range']}',
            status: HttpStatus.partialContent,
            headers: const {'content-type': 'video/mp4', 'x-upstream': 'yes'},
          ),
        );
        final original = upstream.baseUri.replace(path: '/video').toString();
        final proxied = proxy.registerUrl(original, const {
          'X-Token': 'injected',
        });

        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final request = await client.getUrl(Uri.parse(proxied));
        request.headers.set('Range', 'bytes=0-99');
        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();

        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.headers.value('x-upstream'), 'yes');
        expect(body, 'injected|bytes=0-99');
      },
    );

    test('injected headers override conflicting client headers', () async {
      upstream.setRoute(
        '/override',
        (request) => LocalHttpServerResponse.text(
          request.headers['authorization'] ?? '',
        ),
      );
      final original = upstream.baseUri.replace(path: '/override').toString();
      final proxied = proxy.registerUrl(original, const {
        'Authorization': 'Bearer registered',
      });

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(Uri.parse(proxied));
      request.headers.set('Authorization', 'Bearer caller');
      final response = await request.close();

      expect(await utf8.decoder.bind(response).join(), 'Bearer registered');
    });

    test(
      'preserves percent-encoded data in the original URL exactly once',
      () async {
        upstream.setRoute(
          '/encoded',
          (request) =>
              LocalHttpServerResponse.text(request.query['token'] ?? ''),
        );
        final original = upstream.baseUri
            .replace(path: '/encoded', queryParameters: const {'token': '%2F'})
            .toString();
        final proxied = proxy.registerUrl(original, const {});

        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final response = await (await client.getUrl(
          Uri.parse(proxied),
        )).close();

        expect(await utf8.decoder.bind(response).join(), '%2F');
      },
    );

    test('missing URL parameter returns 400', () async {
      final registered = proxy.registerUrl(
        upstream.baseUri.replace(path: '/unused').toString(),
        const {},
      );
      final uri = Uri.parse(registered).replace(query: '');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final response = await (await client.getUrl(uri)).close();

      expect(response.statusCode, HttpStatus.badRequest);
      expect(await utf8.decoder.bind(response).join(), 'Missing url parameter');
    });
  });
}
