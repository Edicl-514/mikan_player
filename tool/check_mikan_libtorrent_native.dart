// ignore_for_file: avoid_print

import 'package:mikan_player/native/mikan_libtorrent_native.dart';

void main(List<String> args) {
  final native = MikanLibtorrentNative.open(args.isEmpty ? null : args.first);
  final session = native.createSession(listenInterfaces: '127.0.0.1:0');
  try {
    print('libtorrent ${native.version}');
    print('session ok');
  } finally {
    session.dispose();
  }
}
