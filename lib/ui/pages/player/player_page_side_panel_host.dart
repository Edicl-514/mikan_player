part of '../player_page.dart';

extension _PlayerPageSidePanelHost on _PlayerPageState {
  Future<void> _loadComments() async {
    if (_episodeController.currentEpisode.id == 0) return;

    _updateState(() {
      _sidePanelLoader.beginCommentsLoad();
    });

    try {
      final comments = await fetchBangumiEpisodeComments(
        episodeId: _episodeController.currentEpisode.id,
      );
      if (mounted) {
        _updateState(() {
          _sidePanelLoader.setComments(comments);
        });
      }
    } catch (e) {
      debugPrint("Error loading comments: $e");
      if (mounted) {
        _updateState(() {
          _sidePanelLoader.setCommentsError(e.toString());
        });
      }
    }
  }

  Future<void> _loadOnairSites() async {
    try {
      final bangumiId = widget.anime.bangumiId;
      final mikanId = widget.anime.mikanId;
      List<BangumiDataSiteEntry> sites = [];
      if (bangumiId != null && bangumiId.isNotEmpty) {
        sites = await BangumiDataService.getSites(bangumiId);
      }
      if (sites.isEmpty && mikanId != null && mikanId.isNotEmpty) {
        sites = await BangumiDataService.getSitesByMikan(mikanId);
      }
      final onair = filterOnairSites(sites);
      if (mounted && onair.isNotEmpty) {
        _updateState(() {
          _sidePanelLoader.setOnairSites(onair);
        });
      }
    } catch (e) {
      debugPrint('Failed to load onair sites: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    _updateState(() {
      _sidePanelLoader.beginRecommendationsLoad();
    });

    try {
      final List<RankingAnime> results = [];
      final Set<String> addedIds = {};
      final isLegacyMode =
          BangumiRequestModeService.notifier.value == BangumiRequestMode.legacy;
      debugPrint(
        '[Recommendations] Start loading for '
        '${widget.anime.bangumiId ?? "unknown"} / ${widget.anime.title}, '
        'mode=${BangumiRequestModeService.notifier.value.value}, '
        'tagSort=${isLegacyMode ? "collects" : "trends"}',
      );

      // 0. Add current anime ID to exclude list
      if (widget.anime.bangumiId != null) {
        addedIds.add(widget.anime.bangumiId!);
      }

      // 1. Fetch Relations (Sequel/Prequel)
      if (widget.anime.bangumiId != null) {
        final id = int.tryParse(widget.anime.bangumiId!);
        if (id != null) {
          try {
            final relations = await fetchBangumiRelations(subjectId: id);
            // i18n-ignore: Bangumi API relation tokens used for filtering;
            // the actual display names come from `r.name` and are already
            // server-provided. The display label keys `playerSidePanelPrequel`
            // / `playerSidePanelSequel` are used by the badge widget below.
            final pres = relations
                .where(
                  // i18n-ignore: see Bangumi API relation filter above
                  (r) =>
                      r.relation == '前传' || // i18n-ignore
                      r.relation == '续集', // i18n-ignore
                )
                .toList();
            final others = relations
                .where(
                  // i18n-ignore: see Bangumi API relation filter above
                  (r) =>
                      r.relation != '前传' && // i18n-ignore
                      r.relation != '续集', // i18n-ignore
                )
                .toList();
            debugPrint(
              '[Recommendations] Relations fetched for $id: total=${relations.length}, '
              'priority=${pres.length}, others=${others.length}',
            );
            appendRelationRecommendations(
              relations: relations,
              results: results,
              addedIds: addedIds,
            );
          } catch (e) {
            debugPrint("[Recommendations] Error fetching relations: $e");
          }
        }
      }

      // 2. Tag-based Search
      final validTags = await _resolveRecommendationTags();
      debugPrint(
        '[Recommendations] Resolved tags for '
        '${widget.anime.bangumiId ?? widget.anime.title}: count=${validTags.length}, tags=$validTags',
      );

      if (validTags.isNotEmpty) {
        final limitPerTag = recommendationLimitPerTag(validTags.length);

        // Take max 5 tags to search
        final searchTags = validTags.take(5).toList();
        debugPrint(
          '[Recommendations] Searching tags: $searchTags, limitPerTag=$limitPerTag',
        );

        // Fetch in parallel
        final futures = searchTags.map((tag) async {
          try {
            final items = await fetchBangumiBrowser(
              sortType: isLegacyMode ? 'collects' : 'trends',
              year: '',
              tags: [tag],
              page: 1,
            );
            debugPrint(
              '[Recommendations] Tag "$tag" returned ${items.length} items',
            );
            return items;
          } catch (e) {
            debugPrint('[Recommendations] Tag "$tag" search failed: $e');
            return <RankingAnime>[];
          }
        });

        final tagGroups = await Future.wait(futures);
        appendTagRecommendations(
          tagGroups: tagGroups,
          limitPerTag: limitPerTag,
          results: results,
          addedIds: addedIds,
        );
      } else {
        debugPrint(
          '[Recommendations] Skip tag search because resolved tags are empty',
        );
      }

      if (mounted) {
        _updateState(() {
          _sidePanelLoader.setRecommendations(results);
        });
      }
      debugPrint(
        '[Recommendations] Finished loading for '
        '${widget.anime.bangumiId ?? widget.anime.title}: total=${results.length}',
      );
    } catch (e) {
      debugPrint("[Recommendations] Error loading recommendations: $e");
      if (mounted) {
        _updateState(() {
          _sidePanelLoader.markRecommendationsLoadFailed();
        });
      }
    }
  }

  bool _isCurrentMikanSourceRequest(int requestToken) =>
      mounted && _sourceController.isMikanRequestCurrent(requestToken);

  bool _isCurrentDmhySourceRequest(int requestToken) =>
      mounted && _sourceController.isDmhyRequestCurrent(requestToken);

  PlayerBtSourceLoadSink get _btSourceLoadSink => PlayerBtSourceLoadSink(
    isMikanCurrent: _isCurrentMikanSourceRequest,
    isDmhyCurrent: _isCurrentDmhySourceRequest,
    apply: (mutation) {
      if (!mounted) return;
      _updateState(mutation);
    },
  );

  Future<void> _loadDmhySource() => loadDmhySource(
    controller: _sourceController,
    sink: _btSourceLoadSink,
    subjectId: widget.anime.bangumiId,
    targetEpisode: _episodeController.currentEpisode.sort.toInt(),
  );

  Future<void> _loadMikanSource() => loadMikanSource(
    controller: _sourceController,
    sink: _btSourceLoadSink,
    animeTitle: widget.anime.title,
    animeMikanId: widget.anime.mikanId,
    animeBangumiId: widget.anime.bangumiId,
    episodeId: _episodeController.currentEpisode.id,
    targetEpisode: _episodeController.currentEpisode.sort.toInt(),
  );

  String _buildSearchNameForSources() => buildSearchNameForSources(
    title: widget.anime.title,
    subTitle: widget.anime.subTitle,
    fullJson: widget.anime.fullJson,
  );

  String _buildCaptchaPreflightKeyword() => buildCaptchaPreflightKeyword(
    title: widget.anime.title,
    subTitle: widget.anime.subTitle,
    fullJson: widget.anime.fullJson,
  );

  Future<List<String>> _resolveRecommendationTags() async {
    final directTags = normalizeRecommendationTags(widget.anime.tags);
    if (directTags.isNotEmpty) {
      debugPrint(
        '[Recommendations] Using widget tags for ${widget.anime.bangumiId ?? widget.anime.title}: $directTags',
      );
      return directTags;
    }

    final jsonTags = normalizeRecommendationTags(
      extractRecommendationTagsFromBangumiJson(widget.anime.fullJson),
    );
    if (jsonTags.isNotEmpty) {
      debugPrint(
        '[Recommendations] Using fullJson tags for ${widget.anime.bangumiId ?? widget.anime.title}: $jsonTags',
      );
      return jsonTags;
    }

    final subjectId = int.tryParse(widget.anime.bangumiId ?? '');
    if (subjectId == null) {
      debugPrint(
        '[Recommendations] No bangumiId and no local tags for ${widget.anime.title}',
      );
      return const [];
    }

    try {
      final detail = await fetchLightSubjectDetails(subjectId: subjectId);
      final resolvedTags = normalizeRecommendationTags([
        ...detail.tags,
        ...extractRecommendationTagsFromBangumiJson(detail.fullJson),
      ]);
      debugPrint(
        '[Recommendations] Using fetched detail tags for $subjectId: $resolvedTags',
      );
      return resolvedTags;
    } catch (e) {
      debugPrint('[Recommendations] Error resolving tags for $subjectId: $e');
      return const [];
    }
  }
}
