import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/workspace_chrome_tint.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_section.dart';

typedef CharacterDetailsLoader = Future<CharacterDetails> Function(int id);
typedef CharacterSubjectsLoader =
    Future<List<CharacterSubject>> Function(int id);
typedef CharacterCommentsLoader =
    Future<List<BangumiEpisodeComment>> Function(int id);

class CharacterDetailPage extends StatefulWidget {
  final int characterId;
  final String? characterName;
  final String? heroImageUrl;
  final bool enableHeroAnimation;
  final String? heroTag;
  final CharacterDetailsLoader? loadDetails;
  final CharacterSubjectsLoader? loadSubjects;
  final CharacterCommentsLoader? loadComments;

  const CharacterDetailPage({
    super.key,
    required this.characterId,
    this.characterName,
    this.heroImageUrl,
    this.enableHeroAnimation = true,
    this.heroTag,
    this.loadDetails,
    this.loadSubjects,
    this.loadComments,
  });

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage>
    with SingleTickerProviderStateMixin {
  late final EntityDetailsController<
    int,
    CharacterDetails,
    CharacterSubject,
    Object
  >
  _controller;

  CharacterDetails? get _characterDetails => _controller.details;
  List<CharacterSubject> get _subjects => _controller.subjects;
  bool get _isLoadingDetails => _controller.isLoadingDetails;
  bool get _isLoadingSubjects => _controller.isLoadingSubjects;

  List<BangumiEpisodeComment>? _comments;
  bool _isLoadingComments = false;
  bool _commentsFailed = false;
  // Whether comments have been requested for the current character. Controls
  // lazy loading: we never fetch comments until the user opens the comments
  // tab, so the default "subjects" tab doesn't pay for an unused request.
  bool _commentsLoaded = false;
  final RequestGenerationGuard _commentsGuard = RequestGenerationGuard();

  late final TabController _mobileTabController;

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
            CharacterDetails,
            CharacterSubject,
            Object
          >(
            fetchDetails:
                widget.loadDetails ??
                (id) => fetchCharacterDetails(characterId: id),
            fetchSubjects:
                widget.loadSubjects ??
                (id) => fetchCharacterSubjects(characterId: id),
          )
          ..addListener(_onControllerChanged);
    _mobileTabController = TabController(length: 2, vsync: this);
    _mobileTabController.addListener(_onMobileTabChanged);
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant CharacterDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characterId != widget.characterId) {
      _commentsGuard.invalidate();
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

  void _onMobileTabChanged() {
    if (_mobileTabController.index == 1) {
      _ensureCommentsLoaded();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _commentsGuard.dispose();
    _controller.dispose();
    _mobileTabController.dispose();
    _mobileScrollController.dispose();
    _desktopLeftScrollController.dispose();
    _desktopRightScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await _controller.load(widget.characterId);
  }

  /// Fetch comments once per character, only when the comments tab is first
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
    final characterId = widget.characterId;
    setState(() {
      _isLoadingComments = true;
      _commentsFailed = false;
    });
    try {
      final loader =
          widget.loadComments ??
          (id) => fetchBangumiCharacterComments(characterId: id);
      final comments = await loader(characterId);
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

  void _openBangumiPage(int subjectId) {
    final subject = _subjects.firstWhere((s) => s.id.toInt() == subjectId);
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.bangumiDetails(
        anime: AnimeInfo(
          title: subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
          bangumiId: subjectId.toString(),
          coverUrl: subject.image,
          tags: const [],
        ),
        heroTag: 'bangumi_$subjectId',
        enableCharacterHero: false,
      ),
    );
  }

  void _openPersonPage(
    int personId,
    int subjectId,
    String personName,
    String? imageUrl,
  ) {
    final heroTag =
        'character_${widget.characterId}_subject_${subjectId}_person_$personId';
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.person(
        personId: personId,
        personName: personName,
        heroImageUrl: imageUrl,
        heroTag: heroTag,
      ),
    );
  }

  String? _getDisplayBirthday(AppLocalizations l10n) {
    if (_characterDetails == null) return null;
    final year = _characterDetails!.birthYear;
    final month = _characterDetails!.birthMon;
    final day = _characterDetails!.birthDay;

    if (year == null && month == null && day == null) return null;

    final parts = <String>[];
    if (year != null) parts.add(l10n.detailsBirthdayYear(year));
    if (month != null) parts.add(l10n.detailsBirthdayMonth(month));
    if (day != null) parts.add(l10n.detailsBirthdayDay(day));

    return parts.join(l10n.detailsBirthdaySeparator);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final hostsChrome = DesktopPageChromeScope.hostsNavigation(context);
    final l10n = AppLocalizations.of(context);

    final displayTitle = _characterDetails?.name.isNotEmpty == true
        ? _characterDetails!.name
        : (widget.characterName?.isNotEmpty == true
              ? widget.characterName!
              : '#${widget.characterId}');

    if (_controller.detailsError != null && _characterDetails == null) {
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
                l10n.characterDetailsLoadFailed,
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
              delegate: _CharacterSliverTabBarDelegate(
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
                    Tab(text: l10n.characterTabSubjects),
                    Tab(text: l10n.characterTabComments),
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
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildSubjectsSection(context, isDarkBg: isDark),
            ),
            BangumiCommentSection(
              isLoading: _isLoadingComments,
              failed: _commentsFailed,
              comments: _comments ?? const [],
              isDarkBg: isDark,
              emptyMessage: l10n.characterCommentsPlaceholder,
              errorMessage: l10n.characterCommentsLoadFailed,
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
                // Left Panel
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
                // Right Panel
                Expanded(
                  child: CustomScrollView(
                    controller: _desktopRightScrollController,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(32, topInset, 32, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildTitleSection(context, isDarkBg: true),
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
                                    label: Text(l10n.characterTabSubjects),
                                    icon: const Icon(Icons.movie_outlined),
                                  ),
                                  ButtonSegment<int>(
                                    value: 1,
                                    label: Text(l10n.characterTabComments),
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
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          sliver: SliverToBoxAdapter(
                            child: _buildSubjectsSection(
                              context,
                              isDarkBg: true,
                            ),
                          ),
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
                          emptyMessage: l10n.characterCommentsPlaceholder,
                          errorMessage: l10n.characterCommentsLoadFailed,
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

  Widget _buildBlurredBackground(BuildContext context) {
    final imgUrl =
        _characterDetails?.images?.large ??
        _characterDetails?.images?.medium ??
        widget.heroImageUrl;

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

  Widget _buildMobileHeader(BuildContext context, {required bool isDark}) {
    final imgUrl =
        _characterDetails?.images?.large ??
        _characterDetails?.images?.medium ??
        widget.heroImageUrl;
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
              // Character Image
              widget.enableHeroAnimation
                  ? Hero(
                      tag: widget.heroTag ?? 'character_${widget.characterId}',
                      child: Container(
                        width: 160,
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
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
                      ),
                    )
                  : Container(
                      width: 160,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                    ),
              const SizedBox(height: 20),
              // Character Name
              if (_isLoadingDetails)
                _buildShimmerBox(
                  width: 140,
                  height: 28,
                  radius: 6,
                  isDark: isDark,
                )
              else
                Text(
                  _characterDetails?.name ?? widget.characterName ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              // Gender badge
              if (_isLoadingDetails)
                _buildShimmerBox(
                  width: 60,
                  height: 24,
                  radius: 12,
                  isDark: isDark,
                )
              else if (_characterDetails?.gender != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getGenderColor(
                      _characterDetails!.gender!,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getGenderColor(
                        _characterDetails!.gender!,
                      ).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _getGenderText(context, _characterDetails!.gender!),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getGenderColor(_characterDetails!.gender!),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Birthday
              if (_isLoadingDetails)
                _buildShimmerBox(
                  width: 100,
                  height: 18,
                  radius: 4,
                  isDark: isDark,
                )
              else if (_getDisplayBirthday(AppLocalizations.of(context)) !=
                  null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      size: 16,
                      color: (isDark ? Colors.white : Colors.black87)
                          .withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getDisplayBirthday(AppLocalizations.of(context))!,
                      style: TextStyle(
                        fontSize: 14,
                        color: (isDark ? Colors.white : Colors.black87)
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              // Stats
              if (_isLoadingDetails)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildShimmerBox(
                      width: 72,
                      height: 28,
                      radius: 14,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildShimmerBox(
                      width: 72,
                      height: 28,
                      radius: 14,
                      isDark: isDark,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(
                      Icons.comment_outlined,
                      AppLocalizations.of(context).detailsCommentsCount(
                        _characterDetails?.stat.comments ?? 0,
                      ),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Icons.favorite_outline,
                      AppLocalizations.of(context).detailsCollectsCount(
                        _characterDetails?.stat.collects ?? 0,
                      ),
                      isDark: isDark,
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

  Widget _buildPoster(BuildContext context, {required double radius}) {
    final imgUrl =
        _characterDetails?.images?.large ??
        _characterDetails?.images?.medium ??
        widget.heroImageUrl;

    return widget.enableHeroAnimation
        ? Hero(
            tag: widget.heroTag ?? 'character_${widget.characterId}',
            child: Container(
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
            ),
          )
        : Container(
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
            '${_characterDetails?.stat.comments ?? 0}',
            AppLocalizations.of(context).detailsCommentsLabel,
          ),
          Container(width: 1, height: 40, color: Colors.white10),
          _buildStatColumn(
            Icons.favorite_outline,
            '${_characterDetails?.stat.collects ?? 0}',
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

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required double radius,
    bool isDark = true,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, {bool isDark = true}) {
    final textColor = isDark ? Colors.white70 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context, {required bool isDarkBg}) {
    final textColor = isDarkBg ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _characterDetails?.name ?? widget.characterName ?? 'Unknown',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_characterDetails?.gender != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getGenderColor(
                    _characterDetails!.gender!,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getGenderColor(
                      _characterDetails!.gender!,
                    ).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  _getGenderText(context, _characterDetails!.gender!),
                  style: TextStyle(
                    fontSize: 14,
                    color: _getGenderColor(_characterDetails!.gender!),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (_characterDetails?.gender != null &&
                _getDisplayBirthday(AppLocalizations.of(context)) != null)
              const SizedBox(width: 12),
            if (_getDisplayBirthday(AppLocalizations.of(context)) != null)
              Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    size: 16,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getDisplayBirthday(AppLocalizations.of(context))!,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context, {required bool isDarkBg}) {
    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final summary = _characterDetails?.summary ?? '';

    if (_isLoadingDetails) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBox(width: 60, height: 20, radius: 4, isDark: isDarkBg),
          const SizedBox(height: 12),
          _buildShimmerBox(
            width: double.infinity,
            height: 14,
            radius: 4,
            isDark: isDarkBg,
          ),
          const SizedBox(height: 8),
          _buildShimmerBox(
            width: double.infinity,
            height: 14,
            radius: 4,
            isDark: isDarkBg,
          ),
          const SizedBox(height: 8),
          _buildShimmerBox(width: 200, height: 14, radius: 4, isDark: isDarkBg),
        ],
      );
    }

    if (summary.isEmpty) {
      return const SizedBox.shrink();
    }

    // Replace \r\n with <br> for proper rendering
    final processedSummary = summary
        .replaceAll('\r\n', '<br>')
        .replaceAll('\n', '<br>');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).detailsSectionSummary,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        HtmlWidget(
          processedSummary,
          textStyle: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBoxSection(BuildContext context, {required bool isDarkBg}) {
    final infobox = _characterDetails?.infobox ?? [];
    if (infobox.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).detailsSectionInfo,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkBg
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: isDarkBg ? Border.all(color: Colors.white10) : null,
          ),
          child: Column(
            children: infobox.map((item) {
              // Handle aliases specially - display one per line
              // i18n-ignore: upstream Bangumi infobox key token used for matching
              final isAlias = item.key == '别名';
              final valueWidget = isAlias
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: item.value
                          .split(RegExp(r'[、,;；，]'))
                          .map(
                            (alias) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                alias.trim(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withValues(alpha: 0.9),
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
                        color: textColor.withValues(alpha: 0.9),
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
                          color: textColor.withValues(alpha: 0.5),
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

  Widget _buildSubjectsSection(BuildContext context, {required bool isDarkBg}) {
    if (_isLoadingSubjects) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            context,
            AppLocalizations.of(context).detailsSectionAppearances,
            isDarkBg: isDarkBg,
          ),
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator(color: Colors.amber)),
        ],
      );
    }

    if (_subjects.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDarkBg ? Colors.white10 : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).detailsSectionAppearances,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        ..._subjects.map((subject) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openBangumiPage(subject.id.toInt()),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Cover Image
                      Hero(
                        tag: 'bangumi_${subject.id}',
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
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Staff badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                // i18n-ignore: upstream Bangumi role token used for matching
                                color: subject.staff.contains('主角')
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subject.staff,
                                style: TextStyle(
                                  fontSize: 11,
                                  // i18n-ignore: upstream Bangumi role token used for matching
                                  color: subject.staff.contains('主角')
                                      ? Colors.amber[300]
                                      : Colors.blue[300],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Subject name
                            Text(
                              subject.nameCn.isNotEmpty
                                  ? subject.nameCn
                                  : subject.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColor.withValues(alpha: 0.95),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subject.nameCn.isNotEmpty &&
                                subject.name != subject.nameCn)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subject.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 8),
                            // Voice actors
                            if (subject.persons.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: subject.persons.map((person) {
                                  final personImageUrl =
                                      person.images?.small ?? '';
                                  final personHeroTag =
                                      'character_${widget.characterId}_subject_${subject.id.toInt()}_person_${person.id.toInt()}';
                                  return GestureDetector(
                                    onTap: () => _openPersonPage(
                                      person.id.toInt(),
                                      subject.id.toInt(),
                                      person.name,
                                      personImageUrl.isEmpty
                                          ? null
                                          : personImageUrl,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (personImageUrl.isNotEmpty)
                                            Hero(
                                              tag: personHeroTag,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CachedNetworkImage(
                                                    imageUrl: personImageUrl,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (personImageUrl.isNotEmpty)
                                            const SizedBox(width: 4),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            ).detailsCvName(person.name),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textColor.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    required bool isDarkBg,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: isDarkBg ? Colors.amber : Colors.deepPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkBg ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
      // i18n-ignore: upstream Bangumi gender token used for matching
      case '男':
        return Colors.blue;
      case 'female':
      // i18n-ignore: upstream Bangumi gender token used for matching
      case '女':
        return Colors.pink;
      default:
        return Colors.purple;
    }
  }

  String _getGenderText(BuildContext context, String gender) {
    final l10n = AppLocalizations.of(context);
    switch (gender.toLowerCase()) {
      case 'male':
      // i18n-ignore: upstream Bangumi gender token used for matching
      case '男':
        return l10n.detailsGenderMale;
      case 'female':
      // i18n-ignore: upstream Bangumi gender token used for matching
      case '女':
        return l10n.detailsGenderFemale;
      default:
        return gender;
    }
  }
}

class _CharacterSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _CharacterSliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

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
  bool shouldRebuild(_CharacterSliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
