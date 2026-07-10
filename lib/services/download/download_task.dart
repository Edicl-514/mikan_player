// Download task data model and JSON persistence.
//
// Persisted JSON keys are part of the on-disk format and MUST NOT change.
// Adding new keys is fine; renaming or removing keys breaks user data.
//
// This file is intentionally Flutter-free so it can be unit-tested as pure
// Dart. It depends only on `dart:core` and `dart:convert` (for callers that
// need it).
library;

enum DownloadTaskType { bt, http }

enum DownloadTaskStatus {
  pending,
  downloading,
  seeding,
  paused,
  completed,
  error,
  metadata, // Fetching torrent metadata (DHT/peers)
  checking, // Verifying existing files (checking_files / checking_resume_data)
  queued, // Waiting for an available download slot
}

enum BtBackendKind { rqbit, libtorrent }

extension BtBackendKindX on BtBackendKind {
  String get storageValue => switch (this) {
    BtBackendKind.rqbit => 'rqbit',
    BtBackendKind.libtorrent => 'libtorrent',
  };

  String get label => switch (this) {
    BtBackendKind.rqbit => 'rqbit',
    BtBackendKind.libtorrent => 'libtorrent',
  };

  static BtBackendKind fromStorage(String? value) {
    return switch (value) {
      'libtorrent' => BtBackendKind.libtorrent,
      _ => BtBackendKind.rqbit,
    };
  }
}

/// Represents a download task.
class DownloadTask {
  String id;
  final String name;
  final String magnet;
  final String? animeName;
  final int? episodeNumber;
  final DateTime startTime;

  DownloadTaskType taskType;
  DownloadTaskStatus status;
  double progress;
  double downloadSpeed; // bytes per second
  double uploadSpeed; // bytes per second
  BigInt downloaded;
  BigInt totalSize;
  int peers;
  String? streamUrl;
  int? largestFileIdx; // Persisted so streamUrl can be recreated after restart.
  String? largestFilePath;
  BtBackendKind backend;
  String? errorMessage;
  String? downloadDir;

  // HTTP-specific fields
  String? videoUrl;
  Map<String, String>? headers;
  String? cookies;
  String? localFilePath;

  DownloadTask({
    required this.id,
    required this.name,
    this.magnet = '',
    this.animeName,
    this.episodeNumber,
    required this.startTime,
    this.taskType = DownloadTaskType.bt,
    this.status = DownloadTaskStatus.pending,
    this.progress = 0.0,
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    BigInt? downloaded,
    BigInt? totalSize,
    this.peers = 0,
    this.streamUrl,
    this.largestFileIdx,
    this.largestFilePath,
    this.backend = BtBackendKind.rqbit,
    this.errorMessage,
    this.downloadDir,
    this.videoUrl,
    this.headers,
    this.cookies,
    this.localFilePath,
  }) : downloaded = downloaded ?? BigInt.zero,
       totalSize = totalSize ?? BigInt.zero;

  /// Create from JSON (for persistence).
  ///
  /// Preserves backward compatibility:
  /// - Old records without `taskType` default to `bt`.
  /// - Old records with an unknown status index default to `pending`.
  /// - `streamUrl`, `downloadSpeed`, `uploadSpeed`, `peers`, `errorMessage`
  ///   are intentionally reset; they are process-local.
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final statusIndex = json['status'] as int;
    final largestFileIdx = (json['largestFileIdx'] as num?)?.toInt();
    final backend = BtBackendKindX.fromStorage(json['backend'] as String?);
    // Backward compatibility: old data without taskType defaults to bt
    final taskTypeStr = json['taskType'] as String?;
    final taskType = switch (taskTypeStr) {
      'http' => DownloadTaskType.http,
      _ => DownloadTaskType.bt,
    };

    // Parse headers map
    Map<String, String>? headers;
    final headersJson = json['headers'] as Map<String, dynamic>?;
    if (headersJson != null) {
      headers = headersJson.map((k, v) => MapEntry(k, v.toString()));
    }

    return DownloadTask(
      id: id,
      name: json['name'] as String,
      magnet: json['magnet'] as String? ?? '',
      animeName: json['animeName'] as String?,
      episodeNumber: json['episodeNumber'] as int?,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      taskType: taskType,
      status: statusIndex >= 0 && statusIndex < DownloadTaskStatus.values.length
          ? DownloadTaskStatus.values[statusIndex]
          : DownloadTaskStatus.pending,
      progress: (json['progress'] as num).toDouble(),
      downloadSpeed: 0.0, // Reset speed on load
      uploadSpeed: 0.0,
      downloaded: BigInt.parse(json['downloaded'] as String? ?? '0'),
      totalSize: BigInt.parse(json['totalSize'] as String? ?? '0'),
      peers: 0,
      // streamUrl is intentionally not restored. The local streaming endpoint
      // only works after the torrent has been re-attached to this process.
      streamUrl: null,
      largestFileIdx: largestFileIdx,
      largestFilePath: json['largestFilePath'] as String?,
      backend: backend,
      errorMessage: null,
      downloadDir: json['downloadDir'] as String?,
      videoUrl: json['videoUrl'] as String?,
      headers: headers,
      cookies: json['cookies'] as String?,
      localFilePath: json['localFilePath'] as String?,
    );
  }

  /// Convert to JSON (for persistence).
  ///
  /// Persisted keys: id, name, magnet, animeName, episodeNumber, startTime,
  /// taskType, status, progress, downloaded, totalSize, largestFileIdx,
  /// largestFilePath, backend, downloadDir, videoUrl, headers, cookies,
  /// localFilePath.
  ///
  /// `streamUrl` is intentionally omitted — it is process-local and rebuilt
  /// on demand.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'magnet': magnet,
      'animeName': animeName,
      'episodeNumber': episodeNumber,
      'startTime': startTime.millisecondsSinceEpoch,
      'taskType': taskType.name,
      'status': status.index,
      'progress': progress,
      'downloaded': downloaded.toString(),
      'totalSize': totalSize.toString(),
      'largestFileIdx': largestFileIdx,
      'largestFilePath': largestFilePath,
      'backend': backend.storageValue,
      // streamUrl intentionally omitted — it is process-local and rebuilt on demand.
      'downloadDir': downloadDir,
      'videoUrl': videoUrl,
      'headers': headers,
      'cookies': cookies,
      'localFilePath': localFilePath,
    };
  }

  String get formattedSpeed {
    if (downloadSpeed < 1024) {
      return '${downloadSpeed.toStringAsFixed(1)} B/s';
    } else if (downloadSpeed < 1024 * 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(downloadSpeed / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
  }

  String get formattedUploadSpeed {
    if (uploadSpeed < 1024) {
      return '${uploadSpeed.toStringAsFixed(1)} B/s';
    } else if (uploadSpeed < 1024 * 1024) {
      return '${(uploadSpeed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(uploadSpeed / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
  }

  String get formattedSize {
    final total = totalSize.toInt();
    if (total < 1024) {
      return '$total B';
    } else if (total < 1024 * 1024) {
      return '${(total / 1024).toStringAsFixed(1)} KB';
    } else if (total < 1024 * 1024 * 1024) {
      return '${(total / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(total / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  String get formattedDownloaded {
    final dl = downloaded.toInt();
    if (dl < 1024) {
      return '$dl B';
    } else if (dl < 1024 * 1024) {
      return '${(dl / 1024).toStringAsFixed(1)} KB';
    } else if (dl < 1024 * 1024 * 1024) {
      return '${(dl / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(dl / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  /// Check if this task is completed (100% progress)
  bool get isCompleted => progress >= 100.0;

  /// Check if this task is actively downloading or seeding
  bool get isPlayable =>
      status == DownloadTaskStatus.downloading ||
      status == DownloadTaskStatus.seeding ||
      status == DownloadTaskStatus.completed ||
      status == DownloadTaskStatus.paused ||
      status == DownloadTaskStatus.metadata ||
      status == DownloadTaskStatus.checking;
}
