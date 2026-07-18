import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/section_title.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Classification of a character's role in the cast. Drives both badge color
/// and the localized label, so badge chrome never compares display strings.
enum _CharacterRole { main, supporting, minor }

/// Upstream Bangumi role tokens used for matching. Display strings go through
/// [AppLocalizations]; these protocol tokens must stay stable for sorting and
/// badge color decisions.
// i18n-ignore: upstream Bangumi role token used for matching
const bangumiRoleTokenMain = '主角';
// i18n-ignore: upstream Bangumi role token used for matching
const bangumiRoleTokenSupporting = '配角';

_CharacterRole? _characterRoleOf(BangumiCharacter character) {
  final roleName = character.roleName;
  if (roleName.isEmpty) return null;
  // i18n-ignore: upstream Bangumi role token used for matching
  if (roleName.contains(bangumiRoleTokenMain)) return _CharacterRole.main;
  // i18n-ignore: upstream Bangumi role token used for matching
  if (roleName.contains(bangumiRoleTokenSupporting)) {
    return _CharacterRole.supporting;
  }
  return _CharacterRole.minor;
}

String _characterRoleLabel(_CharacterRole role, AppLocalizations l10n) {
  switch (role) {
    case _CharacterRole.main:
      return l10n.bangumiDetailsRoleMain;
    case _CharacterRole.supporting:
      return l10n.bangumiDetailsRoleSupporting;
    case _CharacterRole.minor:
      return l10n.bangumiDetailsRoleMinor;
  }
}

/// Horizontal-scrolling list of characters for the Bangumi details page.
///
/// Stateless presentational widget extracted from `_buildCharactersSection`
/// in `bangumi_details_page.dart`. The host owns the scroll controller, the
/// loading/empty state flags, and provides `onCharacterTap` /
/// `onPersonTap` callbacks for navigation. CV names that appear in
/// `personIdMap` are rendered as tappable links.
class CharactersSection extends StatelessWidget {
  final List<BangumiCharacter> characters;
  final bool isLoading;
  final bool isDarkBg;
  final bool enableCharacterHero;
  final ScrollController scrollController;
  final void Function(int characterId, {String? characterName, String? heroImageUrl}) onCharacterTap;
  final void Function(int personId) onPersonTap;
  final Map<String, int> personIdMap;
  final WidgetBuilder loadingPlaceholder;
  final String sectionTitle;

  const CharactersSection({
    super.key,
    required this.characters,
    required this.isLoading,
    required this.isDarkBg,
    required this.enableCharacterHero,
    required this.scrollController,
    required this.onCharacterTap,
    required this.onPersonTap,
    required this.personIdMap,
    required this.loadingPlaceholder,
    required this.sectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingPlaceholder(context);
    }

    if (characters.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: sectionTitle, isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < characters.take(10).length; index++) ...[
                      if (index > 0) const SizedBox(width: 16),
                      Builder(
                        builder: (context) {
                          final char = characters[index];
                          final imageUrl =
                              char.images?.large ?? char.images?.medium ?? '';
                          final cvName = char.actors.isNotEmpty
                              ? char.actors.first.name
                              : '';
                          final canOpenCharacterPage = char.id != 0;
                          final role = _characterRoleOf(char);

                          return SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _CharacterImage(
                                  imageUrl: imageUrl,
                                  canOpenCharacterPage: canOpenCharacterPage,
                                  enableHero: enableCharacterHero,
                                  heroTag: 'character_${char.id.toInt()}',
                                  role: role,
                                  cardColor: cardColor,
                                  isDarkBg: isDarkBg,
                                  onTap: canOpenCharacterPage
                                      ? () => onCharacterTap(
                                            char.id.toInt(),
                                            characterName: char.name,
                                            heroImageUrl: imageUrl,
                                          )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                _CharacterName(
                                  name: char.name,
                                  canOpenCharacterPage: canOpenCharacterPage,
                                  textColor: textColor,
                                  isDarkBg: isDarkBg,
                                  onTap: canOpenCharacterPage
                                      ? () => onCharacterTap(
                                            char.id.toInt(),
                                            characterName: char.name,
                                            heroImageUrl: imageUrl,
                                          )
                                      : null,
                                ),
                                if (cvName.isNotEmpty)
                                  _CharacterCvName(
                                    cvName: cvName,
                                    hasPersonLink: personIdMap.containsKey(cvName),
                                    textColor: textColor,
                                    isDarkBg: isDarkBg,
                                    onPersonTap: () =>
                                        onPersonTap(personIdMap[cvName]!),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CharacterImage extends StatelessWidget {
  final String imageUrl;
  final bool canOpenCharacterPage;
  final bool enableHero;
  final String heroTag;
  final _CharacterRole? role;
  final Color? cardColor;
  final bool isDarkBg;
  final VoidCallback? onTap;

  const _CharacterImage({
    required this.imageUrl,
    required this.canOpenCharacterPage,
    required this.enableHero,
    required this.heroTag,
    required this.role,
    required this.cardColor,
    required this.isDarkBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          height: 140,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkBg ? Colors.white10 : Colors.grey[300]!,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? (enableHero
                          ? Hero(
                              tag: heroTag,
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                deferOffscreenLoad: false,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              deferOffscreenLoad: false,
                            ))
                    : Center(
                        child: Icon(
                          Icons.person,
                          color: isDarkBg ? Colors.white24 : Colors.grey[400],
                          size: 40,
                        ),
                      ),
                if (role != null)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _CharacterRoleBadge(
                      role: role!,
                      isDarkBg: isDarkBg,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterName extends StatelessWidget {
  final String name;
  final bool canOpenCharacterPage;
  final Color textColor;
  final bool isDarkBg;
  final VoidCallback? onTap;

  const _CharacterName({
    required this.name,
    required this.canOpenCharacterPage,
    required this.textColor,
    required this.isDarkBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (canOpenCharacterPage) {
      return GestureDetector(
        onTap: onTap,
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: isDarkBg ? Colors.cyanAccent : Colors.blue.shade800,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: isDarkBg ? Colors.cyanAccent : Colors.blue.shade800,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Text(
      name,
      style: TextStyle(
        fontSize: 12,
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CharacterCvName extends StatelessWidget {
  final String cvName;
  final bool hasPersonLink;
  final Color textColor;
  final bool isDarkBg;
  final VoidCallback? onPersonTap;

  const _CharacterCvName({
    required this.cvName,
    required this.hasPersonLink,
    required this.textColor,
    required this.isDarkBg,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final linkColor = isDarkBg ? Colors.cyanAccent : Colors.blue.shade800;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l10n.bangumiDetailsCvPrefix,
          style: TextStyle(
            fontSize: 10,
            color: textColor.withValues(alpha: 0.5),
          ),
        ),
        Expanded(
          child: hasPersonLink
              ? GestureDetector(
                  onTap: onPersonTap,
                  child: Text(
                    cvName,
                    style: TextStyle(
                      fontSize: 10,
                      color: linkColor,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(
                  cvName,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }
}

class _CharacterRoleBadge extends StatelessWidget {
  final _CharacterRole role;
  final bool isDarkBg;

  const _CharacterRoleBadge({required this.role, required this.isDarkBg});

  static const _colors = {
    _CharacterRole.main: Colors.amber,
    _CharacterRole.supporting: Colors.blue,
    _CharacterRole.minor: Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final badgeColor = _colors[role]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        _characterRoleLabel(role, l10n),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
