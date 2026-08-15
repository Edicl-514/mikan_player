import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';
import 'package:mikan_player/services/bangumi_reverse_proxy_service.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/workspace_chrome_tint.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_section.dart';

typedef PersonDetailsLoader = Future<PersonDetails> Function(int id);
typedef PersonSubjectsLoader = Future<List<PersonSubject>> Function(int id);
typedef PersonCharactersLoader = Future<List<PersonCharacter>> Function(int id);
typedef PersonCommentsLoader =
    Future<List<BangumiEpisodeComment>> Function(int id);

class PersonDetailPage extends StatefulWidget {
  final int personId;
  final String? personName;
  final String? heroImageUrl;
  final bool enableHeroAnimation;
  final String? heroTag;
  final PersonDetailsLoader? loadDetails;
  final PersonSubjectsLoader? loadSubjects;
  final PersonCharactersLoader? loadCharacters;
  final PersonCommentsLoader? loadComments;

  const PersonDetailPage({
    super.key,
    required this.personId,
    this.personName,
    this.heroImageUrl,
    this.enableHeroAnimation = true,
    this.heroTag,
    this.loadDetails,
    this.loadSubjects,
    this.loadCharacters,
    this.loadComments,
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

class _PersonDetailPageState extends State<PersonDetailPage>
    with SingleTickerProviderStateMixin {
  late final EntityDetailsController<
    int,
    PersonDetails,
    PersonSubject,
    PersonCharacter
  >
  _controller;

  PersonDetails? get _details => _controller.details;
  List<PersonSubject> get _subjects => _controller.subjects;
  List<_GroupedCharacter> get _groupedCharacters =>
      _groupCharacters(_controller.related);
  bool get _isLoadingDetails => _controller.isLoadingDetails;
  bool get _isLoadingSubjects => _controller.isLoadingSubjects;
  bool get _isLoadingCharacters => _controller.isLoadingRelated;

  List<BangumiEpisodeComment>? _comments;
  bool _isLoadingComments = false;
  bool _commentsFailed = false;
  // Whether comments have been requested for the current person. Controls
  // lazy loading: we never fetch comments until the user opens the comments
  // tab, so the default "subjects" tab doesn't pay for an unused request.
  bool _commentsLoaded = false;
  final RequestGenerationGuard _commentsGuard = RequestGenerationGuard();

  late final TabController _mobileTabController;

  /// Cached api host used to assemble the `/v0/subjects/{id}/image?type=common`
  /// fallback URL when the per-subject image isn't already known. Refreshed on
  /// every page rebuild so users flipping the reverse-proxy switch see the
  /// change immediately.
  late String _apiHost;

  // Tracks which grouped character cards are expanded
  final Set<int> _expandedCharIds = {};

  final ScrollController _mobileScrollController =
      createPlatformScrollController();
  final ScrollController _desktopLeftScrollController =
      createPlatformScrollController();
  final ScrollController _desktopRightScrollController =
      createPlatformScrollController();

  @override
  void initState() {
    super.initState();
    _controller =
        EntityDetailsController<
            int,
            PersonDetails,
            PersonSubject,
            PersonCharacter
          >(
            fetchDetails:
                widget.loadDetails ?? (id) => fetchPersonDetails(personId: id),
            fetchSubjects:
                widget.loadSubjects ??
                (id) => fetchPersonSubjects(personId: id),
            fetchRelated:
                widget.loadCharacters ??
                (id) => fetchPersonCharacters(personId: id),
          )
          ..addListener(_onControllerChanged);
    // The cached value is read synchronously to avoid an `await` inside the
    // synchronous GridView builder. When the user toggles reverse-proxy mode
    // the page rebuilds and we pick up the new value.
    _apiHost = BangumiUrlRewriter.enabled == true
        ? 'api.bangumi.lol'
        : 'api.bgm.tv';
    // React to runtime changes (the user might toggle reverse-proxy mode while
    // this page is on the navigation stack).
    BangumiReverseProxyService.notifier.addListener(_onReverseProxyChanged);
    _mobileTabController = TabController(length: 2, vsync: this);
    _mobileTabController.addListener(_onMobileTabChanged);
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant PersonDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId) {
      _commentsGuard.invalidate();
      _expandedCharIds.clear();
      _selectedDesktopTabIndex = 0;
      _mobileTabController.index = 0;
      setState(() {
        _commentsLoaded = false;
        _comments = null;
        _isLoadingComments = false;
        _commentsFailed = false;
      });
      _fetchData();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onReverseProxyChanged() {
    final newHost = BangumiReverseProxyService.notifier.value
        ? 'api.bangumi.lol'
        : 'api.bgm.tv';
    if (newHost != _apiHost) {
      setState(() {
        _apiHost = newHost;
      });
    }
  }

  void _onMobileTabChanged() {
    if (_mobileTabController.index == 1) {
      _ensureCommentsLoaded();
    }
  }

  @override
  void dispose() {
    _commentsGuard.dispose();
    _controller.dispose();
    BangumiReverseProxyService.notifier.removeListener(_onReverseProxyChanged);
    _mobileTabController.dispose();
    _mobileScrollController.dispose();
    _desktopLeftScrollController.dispose();
    _desktopRightScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await _controller.load(widget.personId);
  }

  /// Fetch comments once per person, only when the comments tab is first
  /// opened. Subsequent tab switches reuse the cached result; the retry button
  /// calls [_loadComments] directly rather than going through this gate.
  void _ensureCommentsLoaded() {
    if (_commentsLoaded) return;
    _commentsLoaded = true;
    _loadComments();
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    final generation = _commentsGuard.begin();
    final personId = widget.personId;
    setState(() {
      _isLoadingComments = true;
      _commentsFailed = false;
    });
    try {
      final loader =
          widget.loadComments ??
          (id) => fetchBangumiPersonComments(personId: id);
      final comments = await loader(personId);
      if (!mounted || !_commentsGuard.isCurrent(generation)) return;
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (e) {
      if (!mounted || !_commentsGuard.isCurrent(generation)) return;
      setState(() {
        _commentsFailed = true;
        _isLoadingComments = false;
      });
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
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.bangumiDetails(
        anime: AnimeInfo(
          title: name,
          bangumiId: subjectId.toString(),
          coverUrl: image,
          tags: const [],
        ),
        heroTag: tag,
        enableCharacterHero: false,
      ),
    );
  }

  void _openCharacterPage(int characterId, String name, String? imageUrl) {
    final heroTag = 'person_${widget.personId}_char_$characterId';
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.character(
        characterId: characterId,
        characterName: name,
        heroImageUrl: imageUrl,
        enableHeroAnimation: true,
        heroTag: heroTag,
      ),
    );
  }

  bool get _isSeiyu =>
      // i18n-ignore: upstream Bangumi career token used for matching
      _details?.career.contains('seiyu') == true ||
      // i18n-ignore: upstream Bangumi career token used for matching
      _details?.career.contains('voice_actor') == true;

  String _careerLabel(BuildContext context, String career) {
    final l10n = AppLocalizations.of(context);
    switch (career) {
      // i18n-ignore: upstream Bangumi career token used for matching
      case 'seiyu':
      // i18n-ignore: upstream Bangumi career token used for matching
      case 'voice_actor':
        return l10n.personCareerSeiyu;
      // i18n-ignore: upstream Bangumi career token used for matching
      case 'producer':
        return l10n.personCareerProducer;
      // i18n-ignore: upstream Bangumi career token used for matching
      case 'mangaka':
        return l10n.personCareerMangaka;
      // i18n-ignore: upstream Bangumi career token used for matching
      case 'artist':
        return l10n.personCareerArtist;
      // i18n-ignore: upstream Bangumi career token used for matching
      case 'writer':
        return l10n.personCareerWriter;
      // i18n-ignore: upstream Bangumi career token used for matching
      case 'illustrator':
        return l10n.personCareerIllustrator;
      default:
        return career;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final hostsChrome = DesktopPageChromeScope.hostsNavigation(context);
    final l10n = AppLocalizations.of(context);

    final displayTitle = _details?.name.isNotEmpty == true
        ? _details!.name
        : (widget.personName?.isNotEmpty == true
              ? widget.personName!
              : '#${widget.personId}');

    if (_controller.detailsError != null && _details == null) {
      final errorPage = Scaffold(
        backgroundColor: const Color(0xFF16161E),
        appBar: hostsChrome
            ? null
            : AppBar(
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
              Text(
                l10n.personDetailsLoadFailed,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                child: Text(l10n.pageRetry),
              ),
            ],
          ),
        ),
      );
      return WorkspaceRouteTitle(title: displayTitle, child: errorPage);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF16161E)
        : Theme.of(context).scaffoldBackgroundColor;

    final page = Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: !hostsChrome,
      appBar: hostsChrome
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(
                color: isDark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
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
          ? _buildMobileLayout(context, isDark: isDark)
          : _buildDesktopLayout(context),
    );

    return WorkspaceRouteTitle(title: displayTitle, child: page);
  }

  // ── Backgrounds ──────────────────────────────────────────────────────────

  Widget _buildBlurredBackground(BuildContext context) {
    final imgUrl = _details?.img ?? widget.heroImageUrl;
    if (imgUrl == null || imgUrl.isEmpty) {
      return Container(color: const Color(0xFF16161E));
    }
    return WorkspaceChromeTintPublisher(
      imageUrl: imgUrl,
      child: Stack(
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
      ),
    );
  }

  int _selectedDesktopTabIndex = 0;

  Widget _buildMobileLayout(BuildContext context, {required bool isDark}) {
    final l10n = AppLocalizations.of(context);
    final bgColor = isDark
        ? const Color(0xFF16161E)
        : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        controller: _mobileScrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildMobileHeader(context, isDark: isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSummarySection(context, isDarkBg: isDark),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildInfoBoxSection(context, isDarkBg: isDark),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PersonSliverTabBarDelegate(
                TabBar(
                  controller: _mobileTabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: isDark
                      ? Colors.white70
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: [
                    Tab(text: l10n.personTabSubjects),
                    Tab(text: l10n.personTabComments),
                  ],
                ),
                backgroundColor: bgColor,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _mobileTabController,
          children: [
            CustomScrollView(
              slivers: [
                if (_isSeiyu)
                  ..._buildCharactersSlivers(
                    context,
                    padding: const EdgeInsets.all(16),
                    isDarkBg: isDark,
                  ),
                ..._buildSubjectsSlivers(
                  context,
                  padding: const EdgeInsets.all(16),
                  isDarkBg: isDark,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
            BangumiCommentSection(
              isLoading: _isLoadingComments,
              failed: _commentsFailed,
              comments: _comments ?? const [],
              isDarkBg: isDark,
              emptyMessage: l10n.personCommentsPlaceholder,
              errorMessage: l10n.personCommentsLoadFailed,
              retryLabel: l10n.pageRetry,
              onRetry: _loadComments,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topInset =
        DesktopPageMetrics.navigationTopInsetFor(
          context,
          reserved: kToolbarHeight,
        ) +
        32;
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
                    controller: _desktopLeftScrollController,
                    padding: EdgeInsets.fromLTRB(32, topInset, 32, 32),
                    child: Column(
                      children: [
                        _buildPoster(context, radius: 16),
                        const SizedBox(height: 24),
                        _buildStatCard(context),
                        const SizedBox(height: 24),
                        _buildInfoBoxSection(context, isDarkBg: true),
                      ],
                    ),
                  ),
                ),
                // Right panel
                Expanded(
                  child: CustomScrollView(
                    controller: _desktopRightScrollController,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(32, topInset, 32, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildTitleSection(context),
                            const SizedBox(height: 32),
                            _buildSummarySection(context, isDarkBg: true),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<int>(
                                style: SegmentedButton.styleFrom(
                                  selectedForegroundColor: Colors.white,
                                  selectedBackgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.35),
                                  foregroundColor: Colors.white70,
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.25,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                segments: [
                                  ButtonSegment<int>(
                                    value: 0,
                                    label: Text(l10n.personTabSubjects),
                                    icon: const Icon(Icons.work_outline),
                                  ),
                                  ButtonSegment<int>(
                                    value: 1,
                                    label: Text(l10n.personTabComments),
                                    icon: const Icon(Icons.comment_outlined),
                                  ),
                                ],
                                selected: {_selectedDesktopTabIndex},
                                onSelectionChanged: (newSelection) {
                                  setState(() {
                                    _selectedDesktopTabIndex =
                                        newSelection.first;
                                  });
                                  if (newSelection.first == 1) {
                                    _ensureCommentsLoaded();
                                  }
                                },
                              ),
                            ),
                          ]),
                        ),
                      ),
                      if (_selectedDesktopTabIndex == 0) ...[
                        if (_isSeiyu) ...[
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            sliver: SliverToBoxAdapter(
                              child: const SizedBox(height: 16),
                            ),
                          ),
                          ..._buildCharactersSlivers(
                            context,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            isDarkBg: true,
                          ),
                        ],
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          sliver: SliverToBoxAdapter(
                            child: const SizedBox(height: 16),
                          ),
                        ),
                        ..._buildSubjectsSlivers(
                          context,
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          isDarkBg: true,
                        ),
                      ] else ...[
                        BangumiCommentSection(
                          isLoading: _isLoadingComments,
                          failed: _commentsFailed,
                          comments: _comments ?? const [],
                          isDarkBg: true,
                          useSliver: true,
                          sliverPadding: const EdgeInsets.symmetric(
                            horizontal: 32,
                          ),
                          emptyMessage: l10n.personCommentsPlaceholder,
                          errorMessage: l10n.personCommentsLoadFailed,
                          retryLabel: l10n.pageRetry,
                          onRetry: _loadComments,
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 50)),
                    ],
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

  Widget _buildMobileHeader(BuildContext context, {required bool isDark}) {
    final imgUrl = _details?.img ?? widget.heroImageUrl;
    final bgColor = isDark
        ? const Color(0xFF16161E)
        : Theme.of(context).scaffoldBackgroundColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, bgColor.withValues(alpha: 0.5), bgColor],
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
                _shimmer(width: 140, height: 28, radius: 6, isDarkBg: isDark)
              else
                Text(
                  _details?.name ?? widget.personName ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : Theme.of(context).textTheme.titleLarge?.color,
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
                    _shimmer(
                      width: 72,
                      height: 28,
                      radius: 14,
                      isDarkBg: isDark,
                    ),
                    const SizedBox(width: 12),
                    _shimmer(
                      width: 72,
                      height: 28,
                      radius: 14,
                      isDarkBg: isDark,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(
                      Icons.comment_outlined,
                      AppLocalizations.of(
                        context,
                      ).detailsCommentsCount(_details?.stat.comments ?? 0),
                      isDarkBg: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Icons.favorite_outline,
                      AppLocalizations.of(
                        context,
                      ).detailsCollectsCount(_details?.stat.collects ?? 0),
                      isDarkBg: isDark,
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
            tag: widget.heroTag ?? 'person_${widget.personId}',
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
            tag: widget.heroTag ?? 'person_${widget.personId}',
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
            AppLocalizations.of(context).detailsCommentsLabel,
          ),
          Container(width: 1, height: 40, color: Colors.white10),
          _buildStatColumn(
            Icons.favorite_outline,
            '${_details?.stat.collects ?? 0}',
            AppLocalizations.of(context).detailsCollectsLabel,
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
            _careerLabel(context, c),
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

  Widget _buildSummarySection(BuildContext context, {bool isDarkBg = true}) {
    if (_isLoadingDetails) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(width: 60, height: 20, radius: 4, isDarkBg: isDarkBg),
          const SizedBox(height: 12),
          _shimmer(
            width: double.infinity,
            height: 14,
            radius: 4,
            isDarkBg: isDarkBg,
          ),
          const SizedBox(height: 8),
          _shimmer(
            width: double.infinity,
            height: 14,
            radius: 4,
            isDarkBg: isDarkBg,
          ),
          const SizedBox(height: 8),
          _shimmer(width: 200, height: 14, radius: 4, isDarkBg: isDarkBg),
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
        _sectionTitle(
          context,
          AppLocalizations.of(context).detailsSectionSummary,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        HtmlWidget(
          processed,
          textStyle: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: isDarkBg
                ? Colors.white.withValues(alpha: 0.8)
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  // ── Infobox section ───────────────────────────────────────────────────────

  Widget _buildInfoBoxSection(BuildContext context, {bool isDarkBg = true}) {
    final infobox = _details?.infobox ?? [];
    if (infobox.isEmpty) return const SizedBox.shrink();
    final textColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.9)
        : Theme.of(context).textTheme.bodyMedium?.color;
    final keyColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.grey;
    final bgColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.withValues(alpha: 0.1);
    final borderColor = isDarkBg
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          AppLocalizations.of(context).detailsSectionInfo,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: infobox.map((item) {
              // i18n-ignore: upstream Bangumi infobox key token used for matching
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
                                  color: textColor,
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
                        color: textColor,
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
                        style: TextStyle(fontSize: 13, color: keyColor),
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
    bool isDarkBg = true,
  }) {
    if (_isLoadingCharacters) {
      return [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  context,
                  AppLocalizations.of(context).detailsSectionVoiceRoles,
                  isDarkBg: isDarkBg,
                ),
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
              _sectionTitle(
                context,
                AppLocalizations.of(context).detailsSectionVoiceRoles,
                isDarkBg: isDarkBg,
              ),
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
            (context, index) => _buildCharacterCard(
              context,
              _groupedCharacters[index],
              isDarkBg: isDarkBg,
            ),
            childCount: _groupedCharacters.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildCharacterCard(
    BuildContext context,
    _GroupedCharacter group, {
    bool isDarkBg = true,
  }) {
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
        color: isDarkBg
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkBg ? Colors.white10 : Colors.grey.withValues(alpha: 0.3),
        ),
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
                          style: TextStyle(
                            fontSize: 15,
                            color: isDarkBg
                                ? Colors.cyanAccent
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Appearance count
                        Text(
                          AppLocalizations.of(
                            context,
                          ).detailsWorksCount(uniqueAppearances.length),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkBg
                                ? Colors.white.withValues(alpha: 0.55)
                                : Colors.grey,
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
            'https://$_apiHost/v0/subjects/$subjectId/image?type=common';
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
    // i18n-ignore: upstream Bangumi role token used for matching
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
    bool isDarkBg = true,
  }) {
    final l10n = AppLocalizations.of(context);
    final sectionLabel = _isSeiyu
        ? l10n.detailsSectionAppearances
        : l10n.detailsSectionRelatedWorks;

    if (_isLoadingSubjects) {
      return [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, sectionLabel, isDarkBg: isDarkBg),
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
              _sectionTitle(context, sectionLabel, isDarkBg: isDarkBg),
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
            (context, index) => _buildSubjectCard(
              context,
              uniqueSubjects[index],
              isDarkBg: isDarkBg,
            ),
            childCount: uniqueSubjects.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildSubjectCard(
    BuildContext context,
    PersonSubject subject, {
    bool isDarkBg = true,
  }) {
    final title = subject.nameCn.isNotEmpty ? subject.nameCn : subject.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkBg
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkBg ? Colors.white10 : Colors.grey.withValues(alpha: 0.3),
        ),
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
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkBg
                              ? Colors.white
                              : Theme.of(context).textTheme.titleSmall?.color,
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
                              color: isDarkBg
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.grey,
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

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    bool isDarkBg = true,
  }) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: isDarkBg
                ? Colors.amber
                : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkBg
                ? Colors.white
                : Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
      ],
    );
  }

  Widget _shimmer({
    required double width,
    required double height,
    required double radius,
    bool isDarkBg = true,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDarkBg
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, {bool isDarkBg = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkBg
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDarkBg ? Colors.white70 : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkBg ? Colors.white70 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _PersonSliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_PersonSliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
