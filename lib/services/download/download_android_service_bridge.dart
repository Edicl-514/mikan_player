part of '../download_manager.dart';

extension _DownloadAndroidServiceBridge on DownloadManager {
  bool get _shouldKeepAndroidDownloadServiceRunning =>
      !kIsWeb &&
      Platform.isAndroid &&
      _allowBackgroundDownload &&
      _tasks.values.any(
        (task) =>
            !_removedTaskIds.contains(task.id) &&
            (_isActiveStatus(task.status) ||
                (_keepSeedingInBackground &&
                    task.status == DownloadTaskStatus.seeding)),
      );

  void _syncAndroidDownloadService() {
    if (kIsWeb || !Platform.isAndroid) return;
    final shouldRun = _shouldKeepAndroidDownloadServiceRunning;
    if (shouldRun == _androidDownloadServiceRunning) return;

    _androidDownloadServiceRunning = shouldRun;
    unawaited(_setAndroidDownloadServiceRunning(shouldRun));
  }

  Future<void> _setAndroidDownloadServiceRunning(bool running) async {
    try {
      await DownloadManager._androidDownloadServiceChannel.invokeMethod<void>(
        running ? 'start' : 'stop',
      );
      debugPrint(
        '[DownloadManager] Android foreground download service '
        '${running ? 'started' : 'stopped'}',
      );
    } catch (e) {
      _androidDownloadServiceRunning = !running;
      debugPrint(
        '[DownloadManager] Failed to ${running ? 'start' : 'stop'} '
        'Android foreground download service: $e',
      );
    }
  }
}
