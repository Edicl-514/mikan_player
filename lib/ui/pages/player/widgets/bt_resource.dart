/// Immutable display view-model for a single BT resource card.
///
/// Lives in its own file so display widgets (e.g. `BtResourceList`) can import
/// the type without pulling in the generated `mikan.dart` / `dmhy.dart`
/// bindings through `player_source_helpers.dart`. The page-side adapter
/// functions `toBtResource` / `toBtResourceViewModels` (in
/// `player_source_helpers.dart`) construct instances of this class from
/// `MikanEpisodeResource` / `DmhyResource` dispatch results.
class BtResource {
  final String title;
  final String magnet;
  final String size;
  final String time;
  final int? episode;

  const BtResource({
    required this.title,
    required this.magnet,
    required this.size,
    required this.time,
    this.episode,
  });
}
