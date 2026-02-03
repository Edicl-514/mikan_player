import 'dart:io';
import 'package:flutter/foundation.dart';

/// A simple HTTP proxy server that adds custom headers to requests
/// This is used to work around media_kit/libmpv not properly forwarding HTTP headers on Windows
class HeaderInjectionProxy {
  HttpServer? _server;
  int? _port;
  final Map<String, Map<String, String>> _urlHeaders = {};

  static final HeaderInjectionProxy _instance =
      HeaderInjectionProxy._internal();
  factory HeaderInjectionProxy() => _instance;
  HeaderInjectionProxy._internal();

  /// Start the proxy server
  Future<void> start() async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('[HeaderProxy] Started on port $_port');

      _server!.listen((HttpRequest request) async {
        try {
          await _handleRequest(request);
        } catch (e) {
          debugPrint('[HeaderProxy] Error handling request: $e');
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('[HeaderProxy] Failed to start: $e');
    }
  }

  /// Stop the proxy server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
    _port = null;
    _urlHeaders.clear();
    debugPrint('[HeaderProxy] Stopped');
  }

  /// Register a URL with custom headers
  /// Returns the proxied URL that should be used for playback
  String registerUrl(String originalUrl, Map<String, String> headers) {
    if (_port == null) {
      debugPrint(
        '[HeaderProxy] Warning: Server not started, returning original URL',
      );
      return originalUrl;
    }

    final key = originalUrl;
    _urlHeaders[key] = Map.from(headers);

    // Create proxy URL: http://localhost:PORT/proxy?url=ENCODED_URL
    final encodedUrl = Uri.encodeComponent(originalUrl);
    final proxyUrl = 'http://127.0.0.1:$_port/proxy?url=$encodedUrl';

    debugPrint('[HeaderProxy] Registered: $originalUrl');
    debugPrint('[HeaderProxy] Proxy URL: $proxyUrl');
    debugPrint('[HeaderProxy] Headers: $headers');

    return proxyUrl;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      // Extract original URL from query parameter
      final urlParam = request.uri.queryParameters['url'];
      if (urlParam == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing url parameter');
        await request.response.close();
        return;
      }

      final originalUrl = Uri.decodeComponent(urlParam);
      final customHeaders = _urlHeaders[originalUrl] ?? {};

      debugPrint('[HeaderProxy] Proxying: $originalUrl');
      debugPrint('[HeaderProxy] Custom headers: $customHeaders');

      // Create HTTP client
      final client = HttpClient();

      try {
        // Forward the request to the original URL
        final uri = Uri.parse(originalUrl);
        final clientRequest = await client.getUrl(uri);

        // Add custom headers
        customHeaders.forEach((key, value) {
          clientRequest.headers.set(key, value);
        });

        // Forward original request headers (except Host)
        request.headers.forEach((name, values) {
          if (name.toLowerCase() != 'host') {
            for (var value in values) {
              clientRequest.headers.add(name, value);
            }
          }
        });

        // Send request and get response
        final clientResponse = await clientRequest.close();

        // Forward response status and headers
        request.response.statusCode = clientResponse.statusCode;
        clientResponse.headers.forEach((name, values) {
          for (var value in values) {
            request.response.headers.add(name, value);
          }
        });

        // Stream response body
        await clientResponse.pipe(request.response);
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[HeaderProxy] Error proxying request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Proxy error: $e');
      await request.response.close();
    }
  }
}
