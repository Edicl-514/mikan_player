// Self-tests for the F-0 local HTTP server helper.
//
// These tests do exercise `dart:io`'s real `HttpClient` against the loopback
// test server, but the entire exchange happens locally without any physical
// network. The HTTP server is released via `addTearDown`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'local_http_server.dart';

void main() {
  group('LocalHttpServer', () {
    test('returns the configured route body for a GET request', () async {
      final server = await startLocalHttpServer();
      server.setRoute('/hello', (req) => LocalHttpServerResponse.text('world'));

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        server.baseUri.replace(path: '/hello'),
      );
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(utf8.decode(bytes), 'world');
      expect(server.recordedRequests, hasLength(1));
      expect(server.recordedRequests.first.method, 'GET');
      expect(server.recordedRequests.first.path, '/hello');
    });

    test('JSON convenience response serializes the payload', () async {
      final server = await startLocalHttpServer();
      server.setRoute(
        '/json',
        (req) => LocalHttpServerResponse.json(<String, Object>{
          'ok': true,
          'count': 7,
        }),
      );

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        server.baseUri.replace(path: '/json'),
      );
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      expect(response.statusCode, HttpStatus.ok);
      final body = utf8.decode(bytes);
      final decoded = jsonDecode(body) as Map<String, Object?>;
      expect(decoded['ok'], isTrue);
      expect(decoded['count'], 7);
    });

    test('falls back to the default handler for unmatched paths', () async {
      final server = await startLocalHttpServer(
        defaultHandler: (req) =>
            LocalHttpServerResponse.text('default', status: 201),
      );

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        server.baseUri.replace(path: '/nope'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.created);
    });

    test('uploads carry the request body in recordedRequests', () async {
      final server = await startLocalHttpServer();
      var capturedInHandler = const <int>[];
      server.setRoute('/ingest', (record) async {
        capturedInHandler = record.body;
        return const LocalHttpServerResponse(status: 204);
      });

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.post(
        server.baseUri.host,
        server.baseUri.port,
        '/ingest',
      );
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(r'{"ping":1}'));
      final response = await request.close();
      expect(response.statusCode, HttpStatus.noContent);

      // The handler-read bytes and the auto-captured bytes should agree.
      expect(capturedInHandler, <int>[...utf8.encode(r'{"ping":1}')]);
      expect(server.recordedRequests.first.body, isNotEmpty);
    });

    test('ignoreBody drains uploads without retaining them', () async {
      final server = await startLocalHttpServer(ignoreBody: true);
      var handlerBody = const <int>[];
      server.setRoute('/discard', (record) {
        handlerBody = record.body;
        return const LocalHttpServerResponse(status: HttpStatus.noContent);
      });

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.post(
        server.baseUri.host,
        server.baseUri.port,
        '/discard',
      );
      request.add(List<int>.filled(16 * 1024, 1));
      final response = await request.close();

      expect(response.statusCode, HttpStatus.noContent);
      expect(handlerBody, isEmpty);
      expect(server.recordedRequests.single.body, isEmpty);
    });

    test('a failing handler surfaces a 500 response', () async {
      final server = await startLocalHttpServer();
      server.setRoute(
        '/boom',
        (req) => Future<LocalHttpServerResponse>.delayed(
          Duration.zero,
          () => throw StateError('boom'),
        ),
      );

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        server.baseUri.replace(path: '/boom'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.internalServerError);
    });
  });
}
