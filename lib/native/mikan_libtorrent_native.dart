import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

typedef _SessionCreateNative =
    Pointer<Void> Function(Pointer<Utf8>, Int32, Int32, Pointer<Utf8>, Int32);
typedef _SessionCreateDart =
    Pointer<Void> Function(Pointer<Utf8>, int, int, Pointer<Utf8>, int);

typedef _SessionDestroyNative = Void Function(Pointer<Void>);
typedef _SessionDestroyDart = void Function(Pointer<Void>);

final class MikanLibtorrentNative {
  MikanLibtorrentNative._(this._library);

  factory MikanLibtorrentNative.open([String? path]) {
    return MikanLibtorrentNative._(_openLibrary(path));
  }

  static final MikanLibtorrentNative instance = MikanLibtorrentNative.open();

  final DynamicLibrary _library;

  late final _VersionDart _version = _library
      .lookupFunction<_VersionNative, _VersionDart>('mikan_lt_version');

  late final _SessionCreateDart _sessionCreate = _library
      .lookupFunction<_SessionCreateNative, _SessionCreateDart>(
        'mikan_lt_session_create',
      );

  late final Pointer<NativeFunction<_SessionDestroyNative>>
  _sessionDestroyPointer = _library
      .lookup<NativeFunction<_SessionDestroyNative>>(
        'mikan_lt_session_destroy',
      );

  late final _SessionDestroyDart _sessionDestroy = _sessionDestroyPointer
      .asFunction<_SessionDestroyDart>();

  late final NativeFinalizer _sessionFinalizer = NativeFinalizer(
    _sessionDestroyPointer.cast(),
  );

  String get version => _version().toDartString();

  MikanLibtorrentSession createSession({
    String listenInterfaces = '0.0.0.0:6881',
    int downloadLimitBytesPerSecond = 0,
    int uploadLimitBytesPerSecond = 0,
  }) {
    final listenInterfacesPtr = listenInterfaces.toNativeUtf8();
    final errorPtr = calloc<Uint8>(4096);
    try {
      final handle = _sessionCreate(
        listenInterfacesPtr,
        downloadLimitBytesPerSecond,
        uploadLimitBytesPerSecond,
        errorPtr.cast(),
        4096,
      );
      if (handle == nullptr) {
        final message = errorPtr.cast<Utf8>().toDartString();
        throw MikanLibtorrentException(
          message.isEmpty ? 'failed to create libtorrent session' : message,
        );
      }
      return MikanLibtorrentSession._(this, handle);
    } finally {
      calloc.free(listenInterfacesPtr);
      calloc.free(errorPtr);
    }
  }

  static DynamicLibrary _openLibrary(String? path) {
    if (path != null && path.isNotEmpty) {
      return DynamicLibrary.open(path);
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('mikan_libtorrent.dll');
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.open('libmikan_libtorrent.dylib');
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libmikan_libtorrent.so');
    }
    return DynamicLibrary.process();
  }
}

final class MikanLibtorrentSession implements Finalizable {
  MikanLibtorrentSession._(this._owner, Pointer<Void> handle)
    : _handle = handle {
    _owner._sessionFinalizer.attach(this, handle, detach: this);
  }

  final MikanLibtorrentNative _owner;
  Pointer<Void>? _handle;

  bool get isDisposed => _handle == null;

  Pointer<Void> get handle {
    final current = _handle;
    if (current == null) {
      throw StateError('libtorrent session has been disposed');
    }
    return current;
  }

  void dispose() {
    final current = _handle;
    if (current == null) {
      return;
    }
    _owner._sessionFinalizer.detach(this);
    _owner._sessionDestroy(current);
    _handle = null;
  }
}

final class MikanLibtorrentException implements Exception {
  const MikanLibtorrentException(this.message);

  final String message;

  @override
  String toString() => 'MikanLibtorrentException: $message';
}
