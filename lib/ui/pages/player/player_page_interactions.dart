part of '../player_page.dart';

extension _PlayerPageInteractions on _PlayerPageState {
  void _markUserInteraction() {
    _lastUserInteractionAt = DateTime.now();
  }

  void _temporarilyAllowPositionReset() {
    final now = DateTime.now();
    _allowPositionResetUntil = now.add(
      _PlayerPageState._positionResetGracePeriod,
    );
    _furthestObservedPosition = Duration.zero;
    _isRecoveringUnexpectedJump = false;
  }

  void _handleUnexpectedPositionJump(Duration position) {
    final furthestPosition = _furthestObservedPosition;
    final now = DateTime.now();
    final isWithinManualInteractionWindow =
        _lastUserInteractionAt != null &&
        now.difference(_lastUserInteractionAt!) <=
            _PlayerPageState._manualSeekGracePeriod;

    if (isWithinManualInteractionWindow) {
      final movedForward = position > furthestPosition;
      final movedBackward =
          furthestPosition > position &&
          furthestPosition - position >=
              _PlayerPageState._manualBackwardSeekMinimum;

      if (movedForward || movedBackward) {
        // 用户手动 seek 后，必须把异常跳转检测的基线切到用户选中的位置。
        // 只跳过短暂窗口不够：窗口结束后旧 furthest 仍会把进度拉回去。
        _furthestObservedPosition = position;
      }
      return;
    }

    if (position > _furthestObservedPosition) {
      _furthestObservedPosition = position;
    }

    if (_isRecoveringUnexpectedJump) {
      _isRecoveringUnexpectedJump = false;
      return;
    }

    if (_allowPositionResetUntil?.isAfter(now) ?? false) {
      return;
    }

    if (furthestPosition < _PlayerPageState._unexpectedJumpSourceMinimum) {
      return;
    }

    final droppedDuration = furthestPosition - position;
    if (droppedDuration < _PlayerPageState._unexpectedJumpMinimum) {
      return;
    }

    final recoverPosition =
        furthestPosition + _PlayerPageState._unexpectedJumpRecoveryOffset;
    final duration = _player.state.duration;
    final boundedRecoverPosition = duration > Duration.zero
        ? recoverPosition > duration
              ? duration
              : recoverPosition
        : recoverPosition;

    if (boundedRecoverPosition <= position) {
      return;
    }

    _temporarilyAllowPositionReset();
    _isRecoveringUnexpectedJump = true;
    unawaited(_player.seek(boundedRecoverPosition));
    debugPrint(
      '[AntiAd] Unexpected position jump detected: '
      '${furthestPosition.inSeconds}s -> ${position.inSeconds}s, '
      'recovering to ${boundedRecoverPosition.inSeconds}s',
    );
  }

  Future<void> _navigateToAnime(RankingAnime item) async {
    // Create AnimeInfo from RankingAnime
    final animeInfo = AnimeInfo(
      title: item.title,
      bangumiId: item.bangumiId,
      coverUrl: item.coverUrl,
      score: item.score,
      rank: item.rank,
      tags: [], // We don't have full tags yet
      fullJson: null,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BangumiDetailsPage(
          anime: animeInfo,
          heroTag: 'player_rec_${item.bangumiId}',
        ),
      ),
    );
  }
}
