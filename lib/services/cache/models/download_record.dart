import 'package:isar/isar.dart';

part 'download_record.g.dart';

/// BT 下载记录模型
/// 用于持久化保存下载任务信息，防止应用重启丢失进度或元数据
@collection
class DownloadRecord {
  Id id = Isar.autoIncrement;

  /// Info Hash
  @Index(unique: true, replace: true)
  late String infoHash;

  /// Magnet Link
  late String magnet;

  /// Video/File Name
  String? name;

  /// Anime Name
  String? animeName;

  /// Bangumi ID (for linking back to anime)
  String? bangumiId;

  /// Episode Number
  int? episodeNumber;

  /// Download Status
  /// 0: pending/downloading
  /// 1: completed/seeding
  /// 2: paused
  /// 3: error
  int status = 0;

  /// File Path (if completed)
  String? filePath;

  /// Total Size (bytes)
  int totalSize = 0;

  /// Downloaded Bytes
  int downloaded = 0;

  /// Created Time
  late int createdAt;

  /// Updated Time
  late int updatedAt;

  DownloadRecord();

  static DownloadRecord create({
    required String infoHash,
    required String magnet,
    String? name,
    String? animeName,
    String? bangumiId,
    int? episodeNumber,
    int status = 0,
    String? filePath,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DownloadRecord()
      ..infoHash = infoHash
      ..magnet = magnet
      ..name = name
      ..animeName = animeName
      ..bangumiId = bangumiId
      ..episodeNumber = episodeNumber
      ..status = status
      ..filePath = filePath
      ..createdAt = now
      ..updatedAt = now;
  }
}
