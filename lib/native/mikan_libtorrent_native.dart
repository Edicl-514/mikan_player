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

typedef _AddMagnetNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
    );
typedef _AddMagnetDart =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
    );

typedef _AddMagnetExNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Pointer<Utf8>,
      Int32,
    );
typedef _AddMagnetExDart =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
    );

typedef _SaveResumeDataNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _SaveResumeDataDart =
    int Function(Pointer<Void>, int, Pointer<Utf8>, Pointer<Utf8>, int);

typedef _WaitMetadataNative =
    Int32 Function(Pointer<Void>, Int32, Int32, Pointer<Utf8>, Int32);
typedef _WaitMetadataDart =
    int Function(Pointer<Void>, int, int, Pointer<Utf8>, int);

typedef _GetFilesCountNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32);
typedef _GetFilesCountDart =
    int Function(Pointer<Void>, int, Pointer<Utf8>, int);

typedef _GetFileInfoNative =
    Int32 Function(
      Pointer<Void>,
      Int32,
      Int32,
      Pointer<Utf8>,
      Int32,
      Pointer<Int64>,
      Pointer<Int32>,
      Pointer<Utf8>,
      Int32,
    );
typedef _GetFileInfoDart =
    int Function(
      Pointer<Void>,
      int,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Int64>,
      Pointer<Int32>,
      Pointer<Utf8>,
      int,
    );

typedef _SetFilePrioritiesNative =
    Int32 Function(
      Pointer<Void>,
      Int32,
      Pointer<Int32>,
      Int32,
      Pointer<Utf8>,
      Int32,
    );
typedef _SetFilePrioritiesDart =
    int Function(Pointer<Void>, int, Pointer<Int32>, int, Pointer<Utf8>, int);

typedef _PauseResumeNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32);
typedef _PauseResumeDart = int Function(Pointer<Void>, int, Pointer<Utf8>, int);

typedef _RemoveTorrentNative =
    Int32 Function(Pointer<Void>, Int32, Int32, Pointer<Utf8>, Int32);
typedef _RemoveTorrentDart =
    int Function(Pointer<Void>, int, int, Pointer<Utf8>, int);

typedef _GetStatsCountNative =
    Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef _GetStatsCountDart = int Function(Pointer<Void>, Pointer<Utf8>, int);

final class _TorrentStatsNative extends Struct {
  @Int32()
  external int torrentId;

  @Int32()
  external int state;

  @Int32()
  external int isPaused;

  @Int32()
  external int hasMetadata;

  @Int32()
  external int progressMilli;

  @Int64()
  external int totalWanted;

  @Int64()
  external int totalDone;

  @Int32()
  external int downloadRate;

  @Int32()
  external int uploadRate;

  @Int32()
  external int numPeers;

  @Int32()
  external int numSeeds;
}

typedef _GetStatsItemNative =
    Int32 Function(
      Pointer<Void>,
      Int32,
      Pointer<_TorrentStatsNative>,
      Pointer<Utf8>,
      Int32,
      Pointer<Utf8>,
      Int32,
      Pointer<Utf8>,
      Int32,
      Pointer<Utf8>,
      Int32,
    );
typedef _GetStatsItemDart =
    int Function(
      Pointer<Void>,
      int,
      Pointer<_TorrentStatsNative>,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
    );

typedef _ConfigureSessionNative =
    Int32 Function(
      Pointer<Void>,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Pointer<Utf8>,
      Int32,
    );
typedef _ConfigureSessionDart =
    int Function(
      Pointer<Void>,
      int,
      int,
      int,
      int,
      int,
      int,
      int,
      int,
      Pointer<Utf8>,
      int,
    );

typedef _StartStreamNative =
    Int32 Function(
      Pointer<Void>,
      Int32,
      Int32,
      Int32,
      Pointer<Utf8>,
      Int32,
      Pointer<Utf8>,
      Int32,
    );
typedef _StartStreamDart =
    int Function(
      Pointer<Void>,
      int,
      int,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
    );

typedef _StopStreamNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32);
typedef _StopStreamDart = int Function(Pointer<Void>, int, Pointer<Utf8>, int);

typedef _SetStreamCacheNative =
    Int32 Function(
      Pointer<Void>,
      Int32,
      Int32,
      Int32,
      Int32,
      Pointer<Utf8>,
      Int32,
    );
typedef _SetStreamCacheDart =
    int Function(Pointer<Void>, int, int, int, int, Pointer<Utf8>, int);

typedef _PreloadStreamNative =
    Int32 Function(Pointer<Void>, Int32, Int64, Pointer<Utf8>, Int32);
typedef _PreloadStreamDart =
    int Function(Pointer<Void>, int, int, Pointer<Utf8>, int);

const int _kErrorBufferLen = 4096;
const int _kTextBufferLen = 4096;

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

  late final _AddMagnetDart _addMagnet = _library
      .lookupFunction<_AddMagnetNative, _AddMagnetDart>('mikan_lt_add_magnet');

  late final _AddMagnetExDart _addMagnetEx = _library
      .lookupFunction<_AddMagnetExNative, _AddMagnetExDart>(
        'mikan_lt_add_magnet_ex',
      );

  late final _SaveResumeDataDart _saveResumeData = _library
      .lookupFunction<_SaveResumeDataNative, _SaveResumeDataDart>(
        'mikan_lt_save_resume_data',
      );

  late final _WaitMetadataDart _waitMetadata = _library
      .lookupFunction<_WaitMetadataNative, _WaitMetadataDart>(
        'mikan_lt_wait_metadata',
      );

  late final _GetFilesCountDart _getFilesCount = _library
      .lookupFunction<_GetFilesCountNative, _GetFilesCountDart>(
        'mikan_lt_get_files_count',
      );

  late final _GetFileInfoDart _getFileInfo = _library
      .lookupFunction<_GetFileInfoNative, _GetFileInfoDart>(
        'mikan_lt_get_file_info',
      );

  late final _SetFilePrioritiesDart _setFilePriorities = _library
      .lookupFunction<_SetFilePrioritiesNative, _SetFilePrioritiesDart>(
        'mikan_lt_set_file_priorities',
      );

  late final _PauseResumeDart _pauseTorrent = _library
      .lookupFunction<_PauseResumeNative, _PauseResumeDart>(
        'mikan_lt_pause_torrent',
      );

  late final _PauseResumeDart _resumeTorrent = _library
      .lookupFunction<_PauseResumeNative, _PauseResumeDart>(
        'mikan_lt_resume_torrent',
      );

  late final _RemoveTorrentDart _removeTorrent = _library
      .lookupFunction<_RemoveTorrentNative, _RemoveTorrentDart>(
        'mikan_lt_remove_torrent',
      );

  late final _GetStatsCountDart _getTorrentStatsCount = _library
      .lookupFunction<_GetStatsCountNative, _GetStatsCountDart>(
        'mikan_lt_get_torrent_stats_count',
      );

  late final _GetStatsItemDart _getTorrentStatsItem = _library
      .lookupFunction<_GetStatsItemNative, _GetStatsItemDart>(
        'mikan_lt_get_torrent_stats_item',
      );

  late final _ConfigureSessionDart _configureSession = _library
      .lookupFunction<_ConfigureSessionNative, _ConfigureSessionDart>(
        'mikan_lt_configure_session',
      );

  late final _StartStreamDart _startStream = _library
      .lookupFunction<_StartStreamNative, _StartStreamDart>(
        'mikan_lt_start_stream',
      );

  late final _StopStreamDart _stopStream = _library
      .lookupFunction<_StopStreamNative, _StopStreamDart>(
        'mikan_lt_stop_stream',
      );

  late final _SetStreamCacheDart _setStreamCache = _library
      .lookupFunction<_SetStreamCacheNative, _SetStreamCacheDart>(
        'mikan_lt_set_stream_cache',
      );

  late final _PreloadStreamDart _preloadStream = _library
      .lookupFunction<_PreloadStreamNative, _PreloadStreamDart>(
        'mikan_lt_preload_stream',
      );

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

  int addMagnet(String magnet, {String? savePath}) {
    final magnetPtr = magnet.toNativeUtf8();
    final savePathPtr = (savePath ?? '').toNativeUtf8();
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final torrentId = _owner._addMagnet(
        handle,
        magnetPtr,
        savePathPtr,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (torrentId < 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
      return torrentId;
    } finally {
      calloc.free(magnetPtr);
      calloc.free(savePathPtr);
      calloc.free(errorPtr);
    }
  }

  int addMagnetEx(
    String magnet, {
    String? savePath,
    String? resumePath,
    bool seedMode = false,
  }) {
    final magnetPtr = magnet.toNativeUtf8();
    final savePathPtr = (savePath ?? '').toNativeUtf8();
    final resumePathPtr = (resumePath ?? '').toNativeUtf8();
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final torrentId = _owner._addMagnetEx(
        handle,
        magnetPtr,
        savePathPtr,
        resumePathPtr,
        seedMode ? 1 : 0,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (torrentId < 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
      return torrentId;
    } finally {
      calloc.free(magnetPtr);
      calloc.free(savePathPtr);
      calloc.free(resumePathPtr);
      calloc.free(errorPtr);
    }
  }

  void saveResumeData(int torrentId, {required String resumePath}) {
    final resumePathPtr = resumePath.toNativeUtf8();
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = _owner._saveResumeData(
        handle,
        torrentId,
        resumePathPtr,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(resumePathPtr);
      calloc.free(errorPtr);
    }
  }

  void waitMetadata(
    int torrentId, {
    Duration timeout = const Duration(seconds: 90),
  }) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = _owner._waitMetadata(
        handle,
        torrentId,
        timeout.inMilliseconds,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
    }
  }

  List<MikanLtFileInfo> getFiles(int torrentId) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final count = _owner._getFilesCount(
        handle,
        torrentId,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (count < 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
      final result = <MikanLtFileInfo>[];
      final namePtr = calloc<Uint8>(_kTextBufferLen);
      final sizePtr = calloc<Int64>();
      final streamablePtr = calloc<Int32>();
      try {
        for (var i = 0; i < count; i++) {
          final ok = _owner._getFileInfo(
            handle,
            torrentId,
            i,
            namePtr.cast(),
            _kTextBufferLen,
            sizePtr,
            streamablePtr,
            errorPtr.cast(),
            _kErrorBufferLen,
          );
          if (ok == 0) {
            throw MikanLibtorrentException(_readError(errorPtr));
          }
          result.add(
            MikanLtFileInfo(
              index: i,
              path: namePtr.cast<Utf8>().toDartString(),
              size: sizePtr.value,
              isStreamable: streamablePtr.value != 0,
            ),
          );
        }
      } finally {
        calloc.free(namePtr);
        calloc.free(sizePtr);
        calloc.free(streamablePtr);
      }
      return result;
    } finally {
      calloc.free(errorPtr);
    }
  }

  void setFilePriorities(int torrentId, List<int> priorities) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    final prioritiesPtr = calloc<Int32>(priorities.length);
    try {
      for (var i = 0; i < priorities.length; i++) {
        prioritiesPtr[i] = priorities[i];
      }
      final ok = _owner._setFilePriorities(
        handle,
        torrentId,
        prioritiesPtr,
        priorities.length,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
      calloc.free(prioritiesPtr);
    }
  }

  void pauseTorrent(int torrentId) {
    _runSimpleTorrentOp(_owner._pauseTorrent, torrentId);
  }

  void resumeTorrent(int torrentId) {
    _runSimpleTorrentOp(_owner._resumeTorrent, torrentId);
  }

  void removeTorrent(int torrentId, {bool deleteFiles = false}) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = _owner._removeTorrent(
        handle,
        torrentId,
        deleteFiles ? 1 : 0,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
    }
  }

  List<MikanLtTorrentStats> getTorrentStats() {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final count = _owner._getTorrentStatsCount(
        handle,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (count < 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }

      final items = <MikanLtTorrentStats>[];
      final statsPtr = calloc<_TorrentStatsNative>();
      final namePtr = calloc<Uint8>(_kTextBufferLen);
      final hashPtr = calloc<Uint8>(128);
      final statErrorPtr = calloc<Uint8>(_kTextBufferLen);
      try {
        for (var i = 0; i < count; i++) {
          final ok = _owner._getTorrentStatsItem(
            handle,
            i,
            statsPtr,
            namePtr.cast(),
            _kTextBufferLen,
            hashPtr.cast(),
            128,
            statErrorPtr.cast(),
            _kTextBufferLen,
            errorPtr.cast(),
            _kErrorBufferLen,
          );
          if (ok == 0) {
            throw MikanLibtorrentException(_readError(errorPtr));
          }
          final native = statsPtr.ref;
          items.add(
            MikanLtTorrentStats(
              torrentId: native.torrentId,
              name: namePtr.cast<Utf8>().toDartString(),
              infoHash: hashPtr.cast<Utf8>().toDartString(),
              errorMessage: statErrorPtr.cast<Utf8>().toDartString(),
              state: native.state,
              isPaused: native.isPaused != 0,
              hasMetadata: native.hasMetadata != 0,
              progress: native.progressMilli / 1000.0,
              totalWanted: native.totalWanted,
              totalDone: native.totalDone,
              downloadRate: native.downloadRate,
              uploadRate: native.uploadRate,
              numPeers: native.numPeers,
              numSeeds: native.numSeeds,
            ),
          );
        }
      } finally {
        calloc.free(statsPtr);
        calloc.free(namePtr);
        calloc.free(hashPtr);
        calloc.free(statErrorPtr);
      }
      return items;
    } finally {
      calloc.free(errorPtr);
    }
  }

  void configureSession({
    int downloadLimitBytesPerSecond = -1,
    int uploadLimitBytesPerSecond = -1,
    int connectionsLimit = -1,
    bool? enableDht,
    bool? enableLsd,
    bool? enableUpnp,
    bool? enableNatPmp,
    int alertQueueSize = -1,
  }) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = _owner._configureSession(
        handle,
        downloadLimitBytesPerSecond,
        uploadLimitBytesPerSecond,
        connectionsLimit,
        _boolToNativeTriState(enableDht),
        _boolToNativeTriState(enableLsd),
        _boolToNativeTriState(enableUpnp),
        _boolToNativeTriState(enableNatPmp),
        alertQueueSize,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
    }
  }

  MikanLtStreamInfo startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = 512 * 1024 * 1024,
  }) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    final urlPtr = calloc<Uint8>(_kTextBufferLen);
    try {
      final streamId = _owner._startStream(
        handle,
        torrentId,
        fileIndex,
        maxCacheBytes,
        urlPtr.cast(),
        _kTextBufferLen,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (streamId < 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
      return MikanLtStreamInfo(
        id: streamId,
        url: urlPtr.cast<Utf8>().toDartString(),
      );
    } finally {
      calloc.free(errorPtr);
      calloc.free(urlPtr);
    }
  }

  void stopStream(int streamId) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = _owner._stopStream(
        handle,
        streamId,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
    }
  }

  void setStreamCache(
    int streamId, {
    required int capacity,
    required int readAheadPct,
    required int connectionsLimit,
  }) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = _owner._setStreamCache(
        handle,
        streamId,
        capacity,
        readAheadPct,
        connectionsLimit,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
    }
  }

  void preloadStream(int streamId, {required int preloadBytes}) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = _owner._preloadStream(
        handle,
        streamId,
        preloadBytes,
        errorPtr.cast(),
        _kErrorBufferLen,
      );
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
    }
  }

  void _runSimpleTorrentOp(_PauseResumeDart fn, int torrentId) {
    final errorPtr = calloc<Uint8>(_kErrorBufferLen);
    try {
      final ok = fn(handle, torrentId, errorPtr.cast(), _kErrorBufferLen);
      if (ok == 0) {
        throw MikanLibtorrentException(_readError(errorPtr));
      }
    } finally {
      calloc.free(errorPtr);
    }
  }

  String _readError(Pointer<Uint8> errorPtr) {
    final message = errorPtr.cast<Utf8>().toDartString();
    return message.isEmpty ? 'native libtorrent call failed' : message;
  }

  int _boolToNativeTriState(bool? value) {
    if (value == null) return -1;
    return value ? 1 : 0;
  }
}

final class MikanLtFileInfo {
  const MikanLtFileInfo({
    required this.index,
    required this.path,
    required this.size,
    required this.isStreamable,
  });

  final int index;
  final String path;
  final int size;
  final bool isStreamable;
}

final class MikanLtTorrentStats {
  const MikanLtTorrentStats({
    required this.torrentId,
    required this.name,
    required this.infoHash,
    required this.errorMessage,
    required this.state,
    required this.isPaused,
    required this.hasMetadata,
    required this.progress,
    required this.totalWanted,
    required this.totalDone,
    required this.downloadRate,
    required this.uploadRate,
    required this.numPeers,
    required this.numSeeds,
  });

  final int torrentId;
  final String name;
  final String infoHash;
  final String errorMessage;
  final int state;
  final bool isPaused;
  final bool hasMetadata;
  final double progress;
  final int totalWanted;
  final int totalDone;
  final int downloadRate;
  final int uploadRate;
  final int numPeers;
  final int numSeeds;
}

final class MikanLtStreamInfo {
  const MikanLtStreamInfo({required this.id, required this.url});

  final int id;
  final String url;
}

final class MikanLibtorrentException implements Exception {
  const MikanLibtorrentException(this.message);

  final String message;

  @override
  String toString() => 'MikanLibtorrentException: $message';
}
