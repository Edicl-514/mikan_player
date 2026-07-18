// Local `dart:io` HTTP server for Dart-side service tests.
//
// Several Dart services (`video_url_probe.dart`, `header_injection_proxy.dart`,
// `image_cache_service.dart`) use `dart:io.HttpClient` directly. Rather than
// mock the concrete `HttpClient` (which is hostile to subclassing) the
// canonical pattern in this repo is to point the production code at the local
// loopback HTTP server and exercise real request/response serialization.
//
// Use [startLocalHttpServer] from `setUp`; cleanup is registered via
// [addTearDown]. Define per-path handlers with [LocalHttpServer.setRoute] so
// each test owns the responses it expects.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Function handed a [LocalHttpServerRequest] on the loopback server. Tests
/// return a [LocalHttpServerResponse] describing the bytes the server should
/// write back and the status code it should set.
///
/// Handlers never see the raw `HttpRequest` directly — the server drains the
/// request body once into the [LocalHttpServerRequest] snapshot so a single
/// buffer can be shared between the handler and the [recordedRequests] ledger.
typedef LocalHttpHandler =
    FutureOr<LocalHttpServerResponse> Function(LocalHttpServerRequest request);

/// A tiny immutable response descriptor returned by [LocalHttpHandler]s.
class LocalHttpServerResponse {
  const LocalHttpServerResponse({
    this.status = HttpStatus.ok,
    this.body = const <int>[],
    this.headers = const <String, String>{},
  });

  final int status;
  final List<int> body;
  final Map<String, String> headers;

  /// Builds a plain-text response with `content-type: text/plain;
  /// charset=utf-8` by default. [headers] (when provided) override the default.
  static LocalHttpServerResponse text(
    String body, {
    int status = HttpStatus.ok,
    Map<String, String>? headers,
  }) {
    final merged = <String, String>{
      'content-type': 'text/plain; charset=utf-8',
    };
    if (headers != null) merged.addAll(headers);
    return LocalHttpServerResponse(
      status: status,
      body: utf8.encode(body),
      headers: merged,
    );
  }

  /// Builds a JSON response with `content-type: application/json; charset=utf-8`
  /// by default. The supplied [body] is JSON-encoded via [jsonEncode].
  static LocalHttpServerResponse json(
    Object? body, {
    int status = HttpStatus.ok,
    Map<String, String>? headers,
  }) {
    final merged = <String, String>{
      'content-type': 'application/json; charset=utf-8',
    };
    if (headers != null) merged.addAll(headers);
    final bytes = utf8.encode(jsonEncode(body));
    return LocalHttpServerResponse(
      status: status,
      body: bytes,
      headers: merged,
    );
  }
}

/// A snapshot of a received request, safe to read after the response was
/// closed and shared between the [LocalHttpHandler] and [recordedRequests].
class LocalHttpServerRequest {
  LocalHttpServerRequest._({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  /// Builds a snapshot from the live [request]. The on-the-wire body is
  /// always drained. With [captureBody] `false`, its bytes are discarded
  /// rather than retained in the handler/ledger snapshot.
  static Future<LocalHttpServerRequest> from(
    HttpRequest request, {
    bool captureBody = true,
  }) async {
    final body = captureBody
        ? await _drainBody(request)
        : await _discardBody(request);
    return LocalHttpServerRequest._(
      method: request.method,
      path: request.uri.path,
      query: request.uri.queryParameters,
      headers: _captureHeaders(request.headers),
      body: body,
    );
  }

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String?> headers;
  final List<int> body;

  String get bodyAsString => utf8.decode(body, allowMalformed: true);

  @override
  String toString() => '$method $path query=$query';

  static Future<List<int>> _drainBody(HttpRequest request) async {
    // `HttpRequest` is itself a `Stream<List<int>>`. We fold the chunks into
    // a single buffer so both the handler and [recordedRequests] see the same
    // copy rather than racing for the stream.
    final builder = BytesBuilder();
    await for (final chunk in request) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static Future<List<int>> _discardBody(HttpRequest request) async {
    await for (final _ in request) {
      // Drain the stream without retaining upload bytes in test memory.
    }
    return const <int>[];
  }

  /// [HttpHeaders] lacks a public `keys` getter, so we walk it with its
  /// `forEach` API and pick the first value for each header name. Tests that
  /// care about multi-valued headers should iterate [headers.keys] themselves
  /// and re-issue the request via [LocalHttpServer.setRoute].
  static Map<String, String?> _captureHeaders(HttpHeaders headers) {
    final out = <String, String?>{};
    headers.forEach((name, values) {
      out[name] = values.isEmpty ? null : values.first;
    });
    return out;
  }
}

class LocalHttpServer {
  LocalHttpServer._(this._server);

  final HttpServer _server;
  final Map<String, LocalHttpHandler> _routes = <String, LocalHttpHandler>{};
  final List<LocalHttpServerRequest> _records = <LocalHttpServerRequest>[];
  LocalHttpHandler? _defaultHandler;

  /// Host string suitable for `http://$host:$port` (typically `127.0.0.1`).
  String get host => _server.address.host;

  /// Bound port. The OS picks an ephemeral port when [start]/[startLocalHttpServer]
  /// is called with port `0`.
  int get port => _server.port;

  /// Base URI (`http://127.0.0.1:PORT`) for building request URLs in tests.
  Uri get baseUri => Uri(scheme: 'http', host: host, port: port);

  /// Unmodifiable snapshot of the requests received so far.
  List<LocalHttpServerRequest> get recordedRequests =>
      List.unmodifiable(_records);

  /// Routes [path] (matched verbatim against `request.uri.path`) to [handler].
  /// Re-registering the same path replaces the previous handler.
  void setRoute(String path, LocalHttpHandler handler) {
    _routes[path] = handler;
  }

  /// Replaces the fallback handler invoked when no exact route matches.
  /// Default behavior is to return `404` with an empty body.
  void setDefault(LocalHttpHandler? handler) {
    _defaultHandler = handler;
  }

  /// Starts the server bound to IPv4 loopback on an ephemeral port. The
  /// request body is always drained. Pass [ignoreBody] to discard it without
  /// buffering, so the handler and ledger both receive an empty body. This
  /// mimics a peer that streams large uploads and drops their contents.
  static Future<LocalHttpServer> start({
    LocalHttpHandler? defaultHandler,
    bool ignoreBody = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = LocalHttpServer._(server);
    instance._defaultHandler = defaultHandler;
    instance._ignoreBody = ignoreBody;
    instance._serveLoop();
    return instance;
  }

  bool _ignoreBody = false;

  /// Stops the server. When [force] is `true` ongoing connections are
  /// dropped; tests should pass `force: true` (the default) so a hung client
  /// cannot keep the test running.
  Future<void> close({bool force = true}) async {
    await _server.close(force: force);
  }

  void _serveLoop() {
    _server.listen((HttpRequest request) {
      Future<void>(() async {
        final record = await LocalHttpServerRequest.from(
          request,
          captureBody: !_ignoreBody,
        );
        _records.add(record);
        final handler =
            _routes[record.path] ?? _defaultHandler ?? _defaultNotFoundHandler;
        LocalHttpServerResponse response;
        try {
          response = await handler(record);
        } catch (e, st) {
          response = LocalHttpServerResponse.text(
            'LocalHttpServer handler threw: $e\n$st',
            status: HttpStatus.internalServerError,
          );
        }
        final res = request.response;
        res.statusCode = response.status;
        response.headers.forEach((name, value) => res.headers.set(name, value));
        res.add(response.body);
        await res.close();
      }).catchError((Object error) {
        try {
          request.response.close();
        } catch (_) {
          // Best-effort — the test failure surface is the assertion, not the
          // server's error path.
        }
      });
    });
  }

  static const LocalHttpServerResponse _defaultNotFound =
      LocalHttpServerResponse(status: HttpStatus.notFound, body: <int>[]);

  static LocalHttpServerResponse _defaultNotFoundHandler(
    LocalHttpServerRequest request,
  ) => _defaultNotFound;
}

/// Starts a [LocalHttpServer] and registers `close(force: true)` on
/// [addTearDown] so the bound port is released even when a test throws.
///
/// Prefer this entry point over [LocalHttpServer.start] from test bodies to
/// keep cleanup centralized in [addTearDown].
Future<LocalHttpServer> startLocalHttpServer({
  LocalHttpHandler? defaultHandler,
  bool ignoreBody = false,
}) async {
  final server = await LocalHttpServer.start(
    defaultHandler: defaultHandler,
    ignoreBody: ignoreBody,
  );
  addTearDown(() async {
    await server.close(force: true);
  });
  return server;
}
