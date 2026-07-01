class SourceChannelKey {
  final String sourceName;
  final BigInt? channelIndex;

  const SourceChannelKey({
    required this.sourceName,
    this.channelIndex,
  });

  static const int _nullChannelIndex = -1;

  static SourceChannelKey fromPageKey(String pageKey) {
    final separator = '\x00';
    if (!pageKey.contains(separator)) {
      final parts = pageKey.split('_');
      if (parts.length <= 1) {
        return SourceChannelKey(sourceName: pageKey);
      }
      final sourceName = parts.sublist(0, parts.length - 1).join('_');
      final channelStr = parts.last;
      final channelIndex = channelStr == _nullChannelIndex.toString()
          ? null
          : BigInt.tryParse(channelStr);
      return SourceChannelKey(
        sourceName: sourceName,
        channelIndex: channelIndex,
      );
    }
    final idx = pageKey.indexOf(separator);
    return SourceChannelKey(
      sourceName: pageKey.substring(0, idx),
      channelIndex: _parseChannelIndex(pageKey.substring(idx + 1)),
    );
  }

  static BigInt? _parseChannelIndex(String s) {
    if (s == _nullChannelIndex.toString()) return null;
    return BigInt.tryParse(s);
  }

  String toPageKey() {
    return '$sourceName\x00${channelIndex ?? BigInt.from(_nullChannelIndex)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceChannelKey &&
          sourceName == other.sourceName &&
          channelIndex == other.channelIndex;

  @override
  int get hashCode => Object.hash(sourceName, channelIndex);

  @override
  String toString() => 'SourceChannelKey($sourceName, $channelIndex)';
}
