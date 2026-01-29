import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  final String proxy;

  MyHttpOverrides(this.proxy);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final cleanProxy = proxy.replaceFirst(RegExp(r'^https?://'), '');
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        return "PROXY $cleanProxy; DIRECT";
      }
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
