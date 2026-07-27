enum BangumiAccountMode {
  public('public'),
  sync('sync');

  const BangumiAccountMode(this.storageValue);

  final String storageValue;

  static BangumiAccountMode? fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageValue == value) return mode;
    }
    return null;
  }
}
