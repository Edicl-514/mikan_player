// Narrow libtorrent HTTP-streaming capability (Phase 3 follow-up).
//
// Core torrent ops live on [BtBackend]. Streaming has its own lifecycle
// (active/inactive playback windows, piece-priority recovery around the read
// cursor) that is orthogonal to add/pause/resume/remove. This interface
// captures only the backend-owned half of that lifecycle so [DownloadManager]
// can:
//   - reattach / stop a stream without removing the torrent
//   - re-prioritize the selected file after playback ends
//   - merge file-size into stats
//
// Playback *policy* stays on the manager:
//   - `_activeStreamHashes` / [DownloadManager.setActiveStream]
//   - delayed restore orchestration and pause/remove guards
//   - task.streamUrl / notifyListeners / persistence fan-out
//
// Production: [LibtorrentBackend] implements this interface.
// Tests: inject [LibtorrentBackend] with a fake [LibtorrentSessionPort], or a
// dedicated fake that implements only this surface.

import 'package:mikan_player/services/download/bt_backend.dart';

/// Backend-owned libtorrent HTTP streaming ops.
///
/// Does **not** own playback policy (which streams are "active" for the UI /
/// player). Callers pass lowercased info-hashes; implementations may normalize
/// case themselves.
abstract interface class BtStreamCapability {
  /// Tracked native stream id for [infoHash], or null if no stream is live.
  int? streamIdForHash(String infoHash);

  /// Selected file index for [infoHash], or null if unknown.
  int? fileIdxForHash(String infoHash);

  /// Selected file size for progress math, or null if unknown.
  int? fileSizeForHash(String infoHash);

  /// Stop the HTTP stream for [infoHash] without removing the torrent.
  ///
  /// Clears any internal stream-id map entry. No-op when no stream is tracked.
  void stopStreamForHash(String infoHash);

  /// Re-prioritize the selected file and resume after playback ends.
  ///
  /// Returns a handle with the selected file metadata when the torrent is
  /// already tracked; `null` if the torrent is not in the session (caller
  /// should re-[BtBackend.addTorrent] with `startStream: false` instead).
  ///
  /// Live in-memory file selection takes precedence over [preferredFileIdx]
  /// (which may be a stale persisted preference).
  Future<BtTorrentHandle?> restoreBackgroundDownload(
    String infoHash, {
    int? preferredFileIdx,
  });
}
