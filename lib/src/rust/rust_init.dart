import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:mikan_player/src/rust/frb_generated.dart';

Future<void> initRustLib() async {
  final externalLibrary = _createRustExternalLibrary();
  await RustLib.init(externalLibrary: externalLibrary);
}

ExternalLibrary? _createRustExternalLibrary() {
  if (kIsWeb || !Platform.isWindows) {
    return null;
  }

  // Let Windows resolve the DLL from the application directory so `flutter run`
  // does not accidentally load a stale copy from `rust/target/release`.
  return ExternalLibrary.open('rust.dll');
}
