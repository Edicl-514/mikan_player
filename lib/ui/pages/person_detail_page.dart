import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'bangumi_details_page.dart';
import 'character_detail_page.dart';

class PersonDetailPage extends StatefulWidget {
  final int personId;
  final String? personName;
  final String? heroImageUrl;
  final bool enableHeroAnimation;

  const PersonDetailPage({
    super.key,
    required this.personId,
    this.personName,
    this.heroImageUrl,
    this.enableHeroAnimation = true,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

/// Grouped character: one character voiced in potentially many subjects
class _GroupedCharacter {
  final int charId;
  final String name;
  final BangumiImages? images;
  final List<PersonCharacter> appearances; // one entry per subject

  _GroupedCharacter({
    required this.charId,
    required this.name,
    required this.images,
    required this.appearances,
  });
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  PersonDetails? _details;
  List<PersonSubject> _subjects = [];
  List<_GroupedCharacter> _groupedCharacters = [];
  bool _isLoadingDetails = true;
  bool _isLoadingSubjects = true;
  bool _isLoadingCharacters = true;
  String? _error;

  // Tracks which grouped character cards are expanded
  final Set<int> _expandedCharIds = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchDetails(), _fetchSubjects(), _fetchCharacters()]);
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await fetchPersonDetails(personId: widget.personId);
      if (mounted) {
        setState(() {
          _details = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching person details: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load person details';
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _fetchSubjects() async {
    try {
      final subjects = await fetchPersonSubjects(personId: widget.personId);
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _isLoadingSubjects = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching person subjects: $e');
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  Future<void> _fetchCharacters() async {
    try {
      final chars = await fetchPersonCharacters(personId: widget.personId);
      if (mounted) {
        setState(() {
          _groupedCharacters = _groupCharacters(chars);
          _isLoadingCharacters = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching person characters: $e');
      if (mounted) setState(() => _isLoadingCharacters = false);
    }
  }

  List<_GroupedCharacter> _groupCharacters(List<PersonCharacter> chars) {
    final map = <int, _GroupedCharacter>{};
    for (final c in chars) {
      final id = c.id.toInt();
      if (map.containsKey(id)) {
        map[id]!.appearances.add(c);
      } else {
        map[id] = _GroupedCharacter(
          charId: id,
          name: c.name,
          images: c.images,
          appearances: [c],
        );
      }
    }
    // Sort: characters with more appearances (main roles) first
    final list = map.values.toList();
    list.sort((a, b) => b.appearances.length.compareTo(a.appearances.length));
    return list;
  }

  void _openBangumiPage(
    int subjectId,
    String name,
    String image, {
    String? heroTag,
  }) {
    final tag = heroTag ?? 'person_${widget.personId}_subj_$subjectId';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BangumiDetailsPage(
          anime: AnimeInfo(
            title: name,
            bangumiId: subjectId.toString(),
            coverUrl: image,
            tags: const [],
          ),
          heroTag: tag,
          enableCharacterHero: false,
        ),
      ),
    );
  }

  void _openCharacterPage(int characterId, String name, String? imageUrl) {
    final heroTag = 'person_${widget.personId}_char_$characterId';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterDetailPage(
          characterId: characterId,
          characterName: name,
          heroImageUrl: imageUrl,
          enableHeroAnimation: true,
          heroTag: heroTag,
        ),
      ),
    );
  }

  bool get _isSeiyu =>
      _details?.career.contains('seiyu') == true ||
      _details?.career.contains('voice_actor') == true;

  String _careerLabel(String career) {
    const map = {
      'seiyu': '声优',
      'voice_actor': '声优',
      'producer': '制作人',
      'mangaka': '漫画家',
      'artist': '音乐人',
      'writer': '作者',
      'illustrator': '插画家',
    };
    return map[career] ?? career;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (_error != null && _details == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF16161E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchData, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF16161E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: isMobile
          ? _buildMobileLayout(context)
          : _buildDesktopLayout(context),
    );
  }

  // ── Backgrounds ──────────────────────────────────────────────────────────

  Widget _buildBlurredBackground(BuildContext context) {
    final imgUrl = _details?.img ?? widget.heroImageUrl;
    if (imgUrl == null || imgUrl.isEmpty) {
      return Container(color: const Color(0xFF16161E));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF16161E).withValues(alpha: 0.3),
                  const Color(0xFF16161E).withValues(alpha: 0.7),
                  const Color(0xFF16161E),
                ],
                stops: const [0.0, 0.4, 0.8],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildMobileHeader(context)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSummarySection(context),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildInfoBoxSection(context),
          ),
        ),
        if (_isSeiyu)
          ..._buildCharactersSlivers(
            context,
            padding: const EdgeInsets.all(16),
          ),
        ..._buildSubjectsSlivers(context, padding: const EdgeInsets.all(16)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildBlurredBackground(context)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left panel
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      32,
                      kToolbarHeight + 32,
                      32,
                      32,
                    ),
                    child: Column(
                      children: [
                        _buildPoster(context, radius: 16),
                        const SizedBox(height: 24),
                        _buildStatCard(context),
                        const SizedBox(height: 24),
                        _buildInfoBoxSection(context),
                      ],
                    ),
                  ),
                ),
                // Right panel
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      32,
                      kToolbarHeight + 32,
                      32,
                      32,
                    ),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildTitleSection(context)),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        SliverToBoxAdapter(
                          child: _buildSummarySection(context),
                        ),
                        if (_isSeiyu) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                          ..._buildCharactersSlivers(context),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ..._buildSubjectsSlivers(context),
                        const SliverToBoxAdapter(child: SizedBox(height: 50)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Header (mobile) ───────────────────────────────────────────────────────

  Widget _buildMobileHeader(BuildContext context) {
    final imgUrl = _details?.img ?? widget.heroImageUrl;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF16161E).withValues(alpha: 0.5),
            const Color(0xFF16161E),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatarWidget(imgUrl, width: 160, height: 200, radius: 12),
              const SizedBox(height: 20),
              if (_isLoadingDetails)
                _shimmer(width: 140, height: 28, radius: 6)
              else
                Text(
                  _details?.name ?? widget.personName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              if (!_isLoadingDetails && _details != null)
                _buildCareerChips(_details!.career),
              const SizedBox(height: 8),
              if (_isLoadingDetails)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shimmer(width: 72, height: 28, radius: 14),
                    const SizedBox(width: 12),
                    _shimmer(width: 72, height: 28, radius: 14),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(
                      Icons.comment_outlined,
                      '${_details?.stat.comments ?? 0} 评论',
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Icons.favorite_outline,
                      '${_details?.stat.collects ?? 0} 收藏',
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Poster (desktop left panel) ───────────────────────────────────────────

  Widget _buildPoster(BuildContext context, {required double radius}) {
    final imgUrl = _details?.img ?? widget.heroImageUrl;
    return widget.enableHeroAnimation
        ? Hero(
            tag: 'person_${widget.personId}',
            child: _posterContainer(imgUrl, radius),
          )
        : _posterContainer(imgUrl, radius);
  }

  Widget _posterContainer(String? imgUrl, double radius) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: imgUrl != null && imgUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                )
              : Container(
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.white54,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(
    String? imgUrl, {
    required double width,
    required double height,
    required double radius,
  }) {
    return widget.enableHeroAnimation
        ? Hero(
            tag: 'person_${widget.personId}',
            child: _avatarContainer(imgUrl, width, height, radius),
          )
        : _avatarContainer(imgUrl, width, height, radius);
  }

  Widget _avatarContainer(
    String? imgUrl,
    double width,
    double height,
    double radius,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imgUrl != null && imgUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imgUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              )
            : Container(
                color: Colors.grey[800],
                child: const Icon(
                  Icons.person,
                  size: 64,
                  color: Colors.white54,
                ),
              ),
      ),
    );
  }

  // ── Stat card (desktop) ────────────────────────────────────────────────────

  Widget _buildStatCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatColumn(
            Icons.comment_outlined,
            '${_details?.stat.comments ?? 0}',
            '评论',
          ),
          Container(width: 1, height: 40, color: Colors.white10),
          _buildStatColumn(
            Icons.favorite_outline,
            '${_details?.stat.collects ?? 0}',
            '收藏',
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.amber, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // ── Title section (desktop right panel) ──────────────────────────────────

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _details?.name ?? widget.personName ?? 'Unknown',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_details != null) _buildCareerChips(_details!.career),
      ],
    );
  }

  Widget _buildCareerChips(List<String> careers) {
    if (careers.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: careers.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
          ),
          child: Text(
            _careerLabel(c),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.tealAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Summary section ───────────────────────────────────────────────────────

  Widget _buildSummarySection(BuildContext context) {
    if (_isLoadingDetails) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(width: 60, height: 20, radius: 4),
          const SizedBox(height: 12),
          _shimmer(width: double.infinity, height: 14, radius: 4),
          const SizedBox(height: 8),
          _shimmer(width: double.infinity, height: 14, radius: 4),
          const SizedBox(height: 8),
          _shimmer(width: 200, height: 14, radius: 4),
        ],
      );
    }
    final summary = _details?.summary ?? '';
    if (summary.isEmpty) return const SizedBox.shrink();
    final processed = summary
        .replaceAll('\r\n', '<br>')
        .replaceAll('\n', '<br>');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, '简介'),
        const SizedBox(height: 12),
        HtmlWidget(
          processed,
          textStyle: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // ── Infobox section ───────────────────────────────────────────────────────

  Widget _buildInfoBoxSection(BuildContext context) {
    final infobox = _details?.infobox ?? [];
    if (infobox.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, '资料'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: infobox.map((item) {
              final isAlias = item.key == '别名';
              Widget valueWidget = isAlias
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: item.value
                          .split(RegExp(r'[、,;；，]'))
                          .map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                a.trim(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        item.key,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(child: valueWidget),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCharactersSlivers(
    BuildContext context, {
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    if (_isLoadingCharacters) {
      return [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, '配音角色'),
                const SizedBox(height: 12),
                const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    if (_groupedCharacters.isEmpty) return const [];

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          padding.top,
          padding.right,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, '配音角色'),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          0,
          padding.right,
          padding.bottom,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildCharacterCard(context, _groupedCharacters[index]),
            childCount: _groupedCharacters.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildCharacterCard(BuildContext context, _GroupedCharacter group) {
    final imgUrl =
        group.images?.large ??
        group.images?.medium ??
        group.images?.small ??
        '';
    final charHeroTag = 'person_${widget.personId}_char_${group.charId}';
    final hasMultiple = group.appearances.length > 1;
    // Auto-expand single-appearance groups; multi-appearance groups toggle manually
    final isExpanded = !hasMultiple || _expandedCharIds.contains(group.charId);

    // Dedupe appearances within this group by subjectId to keep hero tags unique
    final seenSubjectIds = <int>{};
    final uniqueAppearances = group.appearances
        .where((a) => seenSubjectIds.add(a.subjectId.toInt()))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // ── Character header row ──────────────────────────────────────
          InkWell(
            onTap: hasMultiple
                ? () {
                    setState(() {
                      if (_expandedCharIds.contains(group.charId)) {
                        _expandedCharIds.remove(group.charId);
                      } else {
                        _expandedCharIds.add(group.charId);
                      }
                    });
                  }
                : () => _openCharacterPage(
                    group.charId,
                    group.name,
                    imgUrl.isEmpty ? null : imgUrl,
                  ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Character thumbnail — always navigates to character page (Hero)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openCharacterPage(
                        group.charId,
                        group.name,
                        imgUrl.isEmpty ? null : imgUrl,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Hero(
                        tag: charHeroTag,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 72,
                            child: imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white38,
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Character name (original)
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Appearance count
                        Text(
                          '${uniqueAppearances.length} 部作品',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasMultiple)
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white38,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),

          // ── Subject grid (expanded appearances) ───────────────────────
          if (isExpanded && uniqueAppearances.isNotEmpty) ...[
            Divider(
              color: Colors.white10,
              height: 1,
              indent: 12,
              endIndent: 12,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: _buildCharacterSubjectGrid(
                uniqueAppearances,
                group.charId,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacterSubjectGrid(
    List<PersonCharacter> appearances,
    int charId,
  ) {
    // Map subject id -> cover image, sourced from the person's subjects list
    // Fallback to the direct image API if not found
    final subjectImageMap = <int, String>{
      for (final s in _subjects) s.id.toInt(): s.image,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 14,
        crossAxisSpacing: 10,
        childAspectRatio: 0.58,
      ),
      itemCount: appearances.length,
      itemBuilder: (_, i) {
        final a = appearances[i];
        final subjectId = a.subjectId.toInt();
        final title = a.subjectNameCn.isNotEmpty
            ? a.subjectNameCn
            : a.subjectName;
        final coverUrl =
            subjectImageMap[subjectId] ??
            'https://api.bgm.tv/v0/subjects/$subjectId/image?type=common';
        final heroTag =
            'person_${widget.personId}_char_${charId}_subj_$subjectId';
        return _buildCharacterSubjectTile(
          subjectId: subjectId,
          title: title,
          coverUrl: coverUrl,
          staff: a.staff,
          heroTag: heroTag,
        );
      },
    );
  }

  Widget _buildCharacterSubjectTile({
    required int subjectId,
    required String title,
    required String coverUrl,
    required String staff,
    required String heroTag,
  }) {
    final isMain = staff.contains('主角');
    final badgeColor = isMain ? Colors.amber : Colors.blue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            _openBangumiPage(subjectId, title, coverUrl, heroTag: heroTag),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Hero(
                  tag: heroTag,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white38,
                              ),
                            ),
                    ),
                  ),
                ),
                if (staff.isNotEmpty)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        staff,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Subjects section ──────────────────────────────────────────────────────

  List<PersonSubject> _uniqueSubjects() {
    final seen = <int>{};
    return _subjects.where((s) => seen.add(s.id.toInt())).toList();
  }

  List<Widget> _buildSubjectsSlivers(
    BuildContext context, {
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final sectionLabel = _isSeiyu ? '出演作品' : '相关作品';

    if (_isLoadingSubjects) {
      return [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, sectionLabel),
                const SizedBox(height: 12),
                const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    if (_subjects.isEmpty) return const [];

    final uniqueSubjects = _uniqueSubjects();

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          padding.top,
          padding.right,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, sectionLabel),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          0,
          padding.right,
          padding.bottom,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildSubjectCard(context, uniqueSubjects[index]),
            childCount: uniqueSubjects.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildSubjectCard(BuildContext context, PersonSubject subject) {
    final title = subject.nameCn.isNotEmpty ? subject.nameCn : subject.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _openBangumiPage(subject.id.toInt(), title, subject.image),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'person_${widget.personId}_subj_${subject.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 70,
                      height: 95,
                      child: subject.image.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: subject.image,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[700],
                              child: const Icon(
                                Icons.movie,
                                color: Colors.white54,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subject.staff.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.teal.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            subject.staff,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (subject.eps.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            subject.eps,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subject.name != title && subject.name.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subject.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white30,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _shimmer({
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
