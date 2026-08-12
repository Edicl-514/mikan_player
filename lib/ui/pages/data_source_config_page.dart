import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';

typedef SourceConfigPersistCallback =
    Future<void> Function(SourceConfigUpdate update);

class DataSourceConfigPage extends StatefulWidget {
  final SourceState? source;
  final SourceConfigPersistCallback? onCreateSourceConfig;
  final SourceConfigPersistCallback? onUpdateSourceConfig;

  const DataSourceConfigPage({
    super.key,
    this.source,
    this.onCreateSourceConfig,
    this.onUpdateSourceConfig,
  });

  @override
  State<DataSourceConfigPage> createState() => _DataSourceConfigPageState();
}

class _DataSourceConfigPageState extends State<DataSourceConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _jsonEncoder = const JsonEncoder.withIndent('  ');
  final List<TextEditingController> _controllers = [];
  final ScrollController _scrollController = createPlatformScrollController();

  late final TextEditingController _nameController;
  late final TextEditingController _tierController;
  late final TextEditingController _iconUrlController;
  late final TextEditingController _descController;
  late final TextEditingController _searchUrlController;
  late final TextEditingController _rawBaseUrlController;
  late final TextEditingController _searchUseSubjectNamesCountController;
  late final TextEditingController _requestIntervalController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _resolutionController;
  late final TextEditingController _subjectASelectListsController;
  late final TextEditingController _subjectIndexedSelectNamesController;
  late final TextEditingController _subjectIndexedSelectLinksController;
  late final TextEditingController _subjectJsonPathSelectNamesController;
  late final TextEditingController _subjectJsonPathSelectLinksController;
  late final TextEditingController _channelNamesController;
  late final TextEditingController _channelNameRegexController;
  late final TextEditingController _episodeListsController;
  late final TextEditingController _episodesFromListController;
  late final TextEditingController _episodeLinksFromListController;
  late final TextEditingController _episodeSortRegexController;
  late final TextEditingController _noChannelEpisodesController;
  late final TextEditingController _noChannelEpisodeLinksController;
  late final TextEditingController _noChannelEpisodeSortRegexController;
  late final TextEditingController _matchVideoUrlController;
  late final TextEditingController _matchNestedUrlController;
  late final TextEditingController _cookiesController;
  late final TextEditingController _refererController;
  late final TextEditingController _userAgentController;
  late final TextEditingController _captchaTypeController;
  late final TextEditingController _captchaDetectSelectorController;
  late final TextEditingController _captchaSuccessSelectorController;
  late final TextEditingController _captchaImageSelectorController;
  late final TextEditingController _captchaRefreshSelectorController;
  late final TextEditingController _captchaInputSelectorController;
  late final TextEditingController _captchaSubmitSelectorController;
  late final TextEditingController _captchaInitialDelayController;
  late final TextEditingController _captchaExpectedLengthController;
  late final TextEditingController _captchaAllowedCharsController;

  late Map<String, dynamic> _searchConfig;
  late Map<String, dynamic> _captchaConfig;
  bool _hadCaptchaConfig = false;
  bool _isSaving = false;
  bool _searchUseOnlyFirstWord = false;
  bool _searchRemoveSpecial = false;
  bool _preferSubjectAShorterName = true;
  bool _preferSubjectIndexedShorterName = true;
  bool _preferSubjectJsonPathShorterName = true;
  bool _filterBySubjectName = true;
  bool _filterByEpisodeSort = true;
  bool _distinguishSubjectName = true;
  bool _distinguishChannelName = true;
  bool _enableNestedUrl = true;
  bool _captchaEnable = false;
  bool _captchaUseWebViewForDetail = false;
  String _subjectFormatId = 'indexed';
  String _channelFormatId = 'index-grouped';

  static const _subjectFormatKeys = <String>{
    'a',
    'indexed',
    'jsonpath-indexed',
  };

  static const _channelFormatKeys = <String>{'index-grouped', 'no-channel'};

  Map<String, String> _subjectFormats(AppLocalizations l10n) {
    return <String, String>{
      'a': l10n.dataSourceConfigSubjectFormatA,
      'indexed': l10n.dataSourceConfigSubjectFormatIndexed,
      'jsonpath-indexed': l10n.dataSourceConfigSubjectFormatJsonPath,
    };
  }

  Map<String, String> _channelFormats(AppLocalizations l10n) {
    return <String, String>{
      'index-grouped': l10n.dataSourceConfigChannelFormatIndexGrouped,
      'no-channel': l10n.dataSourceConfigChannelFormatNoChannel,
    };
  }

  static const _resolutionOptions = <String>[
    '',
    '2160P',
    '1440P',
    '1080P',
    '720P',
    '480P',
  ];

  static const _subtitleOptions = <String>['', 'CHS', 'CHT', 'CHS&CHT', 'JPN'];

  @override
  void initState() {
    super.initState();

    final source = widget.source;
    _searchConfig = source == null
        ? _defaultSearchConfig()
        : _decodeObject(
            source.searchConfigJson,
            fallback: _defaultSearchConfig(),
          );
    _captchaConfig = _decodeObject(source?.captchaConfigJson);
    _hadCaptchaConfig = _captchaConfig.isNotEmpty;

    final subjectA = _objectAt(_searchConfig, 'selectorSubjectFormatA');
    final subjectIndexed = _objectAt(
      _searchConfig,
      'selectorSubjectFormatIndexed',
    );
    final subjectJsonPath = _objectAt(
      _searchConfig,
      'selectorSubjectFormatJsonPathIndexed',
    );
    final channelGrouped = _objectAt(
      _searchConfig,
      'selectorChannelFormatFlattened',
    );
    final channelNoChannel = _objectAt(
      _searchConfig,
      'selectorChannelFormatNoChannel',
    );
    final matchVideo = _objectAt(_searchConfig, 'matchVideo');
    final videoHeaders = _objectAt(matchVideo, 'addHeadersToVideo');
    final selectMedia = _objectAt(_searchConfig, 'selectMedia');
    final ocrConstraints = _objectAt(_captchaConfig, 'ocrConstraints');

    _nameController = _controller(source?.name ?? '');
    _tierController = _controller((source?.tier ?? 0).toString());
    _iconUrlController = _controller(source?.iconUrl ?? '');
    _descController = _controller(source?.description ?? '');
    _searchUrlController = _controller(
      _stringAt(_searchConfig, 'searchUrl', source?.searchUrl ?? ''),
    );
    _rawBaseUrlController = _controller(_stringAt(_searchConfig, 'rawBaseUrl'));
    _searchUseSubjectNamesCountController = _controller(
      _stringAt(_searchConfig, 'searchUseSubjectNamesCount'),
    );
    _requestIntervalController = _controller(
      _stringAt(_searchConfig, 'requestInterval'),
    );
    _subtitleController = _controller(
      _stringAt(
        _searchConfig,
        'defaultSubtitleLanguage',
        source?.defaultSubtitleLanguage ?? 'CHS',
      ),
    );
    _resolutionController = _controller(
      _stringAt(
        _searchConfig,
        'defaultResolution',
        source?.defaultResolution ?? '1080P',
      ),
    );

    _subjectFormatId = _stringAt(_searchConfig, 'subjectFormatId', 'indexed');
    if (!_subjectFormatKeys.contains(_subjectFormatId)) {
      _subjectFormatId = 'indexed';
    }
    _subjectASelectListsController = _controller(
      _stringAt(subjectA, 'selectLists'),
    );
    _subjectIndexedSelectNamesController = _controller(
      _stringAt(subjectIndexed, 'selectNames'),
    );
    _subjectIndexedSelectLinksController = _controller(
      _stringAt(subjectIndexed, 'selectLinks'),
    );
    _subjectJsonPathSelectNamesController = _controller(
      _stringAt(subjectJsonPath, 'selectNames', r"$[*]['title','name']"),
    );
    _subjectJsonPathSelectLinksController = _controller(
      _stringAt(subjectJsonPath, 'selectLinks', r"$[*]['url', 'link']"),
    );
    _preferSubjectAShorterName = _boolAt(
      subjectA,
      'preferShorterName',
      defaultValue: true,
    );
    _preferSubjectIndexedShorterName = _boolAt(
      subjectIndexed,
      'preferShorterName',
      defaultValue: true,
    );
    _preferSubjectJsonPathShorterName = _boolAt(
      subjectJsonPath,
      'preferShorterName',
      defaultValue: true,
    );

    _channelFormatId = _stringAt(
      _searchConfig,
      'channelFormatId',
      'index-grouped',
    );
    if (!_channelFormatKeys.contains(_channelFormatId)) {
      _channelFormatId = 'index-grouped';
    }
    _channelNamesController = _controller(
      _stringAt(channelGrouped, 'selectChannelNames'),
    );
    _channelNameRegexController = _controller(
      _stringAt(channelGrouped, 'matchChannelName'),
    );
    _episodeListsController = _controller(
      _stringAt(channelGrouped, 'selectEpisodeLists'),
    );
    _episodesFromListController = _controller(
      _stringAt(channelGrouped, 'selectEpisodesFromList'),
    );
    _episodeLinksFromListController = _controller(
      _stringAt(channelGrouped, 'selectEpisodeLinksFromList'),
    );
    _episodeSortRegexController = _controller(
      _stringAt(
        channelGrouped,
        'matchEpisodeSortFromName',
        r'第\s*(?<ep>.+)\s*[话集]',
      ),
    );
    _noChannelEpisodesController = _controller(
      _stringAt(channelNoChannel, 'selectEpisodes'),
    );
    _noChannelEpisodeLinksController = _controller(
      _stringAt(channelNoChannel, 'selectEpisodeLinks'),
    );
    _noChannelEpisodeSortRegexController = _controller(
      _stringAt(
        channelNoChannel,
        'matchEpisodeSortFromName',
        r'第\s*(?<ep>.+)\s*[话集]',
      ),
    );

    _matchVideoUrlController = _controller(
      _stringAt(matchVideo, 'matchVideoUrl'),
    );
    _matchNestedUrlController = _controller(
      _stringAt(matchVideo, 'matchNestedUrl', r'$^'),
    );
    _cookiesController = _controller(_stringAt(matchVideo, 'cookies'));
    _refererController = _controller(_stringAt(videoHeaders, 'referer'));
    _userAgentController = _controller(_stringAt(videoHeaders, 'userAgent'));

    _searchUseOnlyFirstWord = _boolAt(_searchConfig, 'searchUseOnlyFirstWord');
    _searchRemoveSpecial = _boolAt(_searchConfig, 'searchRemoveSpecial');
    _filterBySubjectName = _boolAt(
      _searchConfig,
      'filterBySubjectName',
      defaultValue: true,
    );
    _filterByEpisodeSort = _boolAt(
      _searchConfig,
      'filterByEpisodeSort',
      defaultValue: true,
    );
    _distinguishSubjectName = _boolAt(
      selectMedia,
      'distinguishSubjectName',
      defaultValue: true,
    );
    _distinguishChannelName = _boolAt(
      selectMedia,
      'distinguishChannelName',
      defaultValue: true,
    );
    _enableNestedUrl = _boolAt(
      matchVideo,
      'enableNestedUrl',
      defaultValue: true,
    );

    _captchaEnable = _boolAt(_captchaConfig, 'enable');
    _captchaUseWebViewForDetail = _boolAt(
      _captchaConfig,
      'useWebViewForDetail',
    );
    _captchaTypeController = _controller(
      _stringAt(_captchaConfig, 'type', 'image_ocr'),
    );
    _captchaDetectSelectorController = _controller(
      _stringAt(_captchaConfig, 'detectSelector'),
    );
    _captchaSuccessSelectorController = _controller(
      _stringAt(_captchaConfig, 'successSelector'),
    );
    _captchaImageSelectorController = _controller(
      _stringAt(_captchaConfig, 'imageSelector'),
    );
    _captchaRefreshSelectorController = _controller(
      _stringAt(_captchaConfig, 'refreshSelector'),
    );
    _captchaInputSelectorController = _controller(
      _stringAt(_captchaConfig, 'inputSelector'),
    );
    _captchaSubmitSelectorController = _controller(
      _stringAt(_captchaConfig, 'submitSelector'),
    );
    _captchaInitialDelayController = _controller(
      _stringAt(_captchaConfig, 'initialDelayMs'),
    );
    _captchaExpectedLengthController = _controller(
      _stringAt(ocrConstraints, 'expectedLength'),
    );
    _captchaAllowedCharsController = _controller(
      _stringAt(ocrConstraints, 'allowedChars', '0123456789'),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  TextEditingController _controller([String text = '']) {
    final controller = TextEditingController(text: text);
    _controllers.add(controller);
    return controller;
  }

  static Map<String, dynamic> _defaultSearchConfig() => {
    'searchUrl': '',
    'searchUseOnlyFirstWord': false,
    'searchRemoveSpecial': false,
    'rawBaseUrl': '',
    'subjectFormatId': 'indexed',
    'selectorSubjectFormatA': {'selectLists': '', 'preferShorterName': true},
    'selectorSubjectFormatIndexed': {
      'selectNames': '',
      'selectLinks': '',
      'preferShorterName': true,
    },
    'selectorSubjectFormatJsonPathIndexed': {
      'selectNames': r"$[*]['title','name']",
      'selectLinks': r"$[*]['url', 'link']",
      'preferShorterName': true,
    },
    'channelFormatId': 'index-grouped',
    'selectorChannelFormatFlattened': {
      'selectChannelNames': '',
      'matchChannelName': r'^(?<ch>.+?)(\d+)?$',
      'selectEpisodeLists': '',
      'selectEpisodesFromList': '',
      'selectEpisodeLinksFromList': '',
      'matchEpisodeSortFromName': r'第\s*(?<ep>.+)\s*[话集]',
    },
    'selectorChannelFormatNoChannel': {
      'selectEpisodes': '',
      'selectEpisodeLinks': '',
      'matchEpisodeSortFromName': r'第\s*(?<ep>.+)\s*[话集]',
    },
    'defaultResolution': '1080P',
    'defaultSubtitleLanguage': 'CHS',
    'filterByEpisodeSort': true,
    'filterBySubjectName': true,
    'selectMedia': {
      'distinguishSubjectName': true,
      'distinguishChannelName': true,
    },
    'matchVideo': {
      'matchVideoUrl': '',
      'enableNestedUrl': true,
      'matchNestedUrl': r'$^',
      'cookies': '',
      'addHeadersToVideo': {
        'referer': '',
        'userAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
      },
    },
  };

  static Map<String, dynamic> _decodeObject(
    String? raw, {
    Map<String, dynamic>? fallback,
  }) {
    if (raw == null || raw.trim().isEmpty) return fallback ?? {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Invalid legacy JSON is surfaced again when the user saves.
    }
    return fallback ?? {};
  }

  static Map<String, dynamic> _objectAt(
    Map<String, dynamic> object,
    String key,
  ) {
    final value = object[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static String _stringAt(
    Map<String, dynamic> object,
    String key, [
    String fallback = '',
  ]) {
    final value = object[key];
    if (value == null) return fallback;
    return value.toString();
  }

  static bool _boolAt(
    Map<String, dynamic> object,
    String key, {
    bool defaultValue = false,
  }) {
    final value = object[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return defaultValue;
  }

  int? _intFromController(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _putString(Map<String, dynamic> target, String key, String value) {
    target[key] = value.trim();
  }

  void _putOptionalInt(
    Map<String, dynamic> target,
    String key,
    TextEditingController controller,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      target.remove(key);
      return;
    }
    target[key] = int.tryParse(text) ?? text;
  }

  Map<String, dynamic> _buildSearchConfig() {
    final config = Map<String, dynamic>.from(_searchConfig);
    _putString(config, 'searchUrl', _searchUrlController.text);
    _putString(config, 'rawBaseUrl', _rawBaseUrlController.text);
    _putString(config, 'defaultSubtitleLanguage', _subtitleController.text);
    _putString(config, 'defaultResolution', _resolutionController.text);
    config['searchUseOnlyFirstWord'] = _searchUseOnlyFirstWord;
    config['searchRemoveSpecial'] = _searchRemoveSpecial;
    _putOptionalInt(
      config,
      'searchUseSubjectNamesCount',
      _searchUseSubjectNamesCountController,
    );
    _putOptionalInt(config, 'requestInterval', _requestIntervalController);
    config['subjectFormatId'] = _subjectFormatId;
    config['channelFormatId'] = _channelFormatId;
    config['filterBySubjectName'] = _filterBySubjectName;
    config['filterByEpisodeSort'] = _filterByEpisodeSort;

    config['selectorSubjectFormatA'] = {
      ..._objectAt(config, 'selectorSubjectFormatA'),
      'selectLists': _subjectASelectListsController.text.trim(),
      'preferShorterName': _preferSubjectAShorterName,
    };
    config['selectorSubjectFormatIndexed'] = {
      ..._objectAt(config, 'selectorSubjectFormatIndexed'),
      'selectNames': _subjectIndexedSelectNamesController.text.trim(),
      'selectLinks': _subjectIndexedSelectLinksController.text.trim(),
      'preferShorterName': _preferSubjectIndexedShorterName,
    };
    config['selectorSubjectFormatJsonPathIndexed'] = {
      ..._objectAt(config, 'selectorSubjectFormatJsonPathIndexed'),
      'selectNames': _subjectJsonPathSelectNamesController.text.trim(),
      'selectLinks': _subjectJsonPathSelectLinksController.text.trim(),
      'preferShorterName': _preferSubjectJsonPathShorterName,
    };
    config['selectorChannelFormatFlattened'] = {
      ..._objectAt(config, 'selectorChannelFormatFlattened'),
      'selectChannelNames': _channelNamesController.text.trim(),
      'matchChannelName': _channelNameRegexController.text.trim(),
      'selectEpisodeLists': _episodeListsController.text.trim(),
      'selectEpisodesFromList': _episodesFromListController.text.trim(),
      'selectEpisodeLinksFromList': _episodeLinksFromListController.text.trim(),
      'matchEpisodeSortFromName': _episodeSortRegexController.text.trim(),
    };
    config['selectorChannelFormatNoChannel'] = {
      ..._objectAt(config, 'selectorChannelFormatNoChannel'),
      'selectEpisodes': _noChannelEpisodesController.text.trim(),
      'selectEpisodeLinks': _noChannelEpisodeLinksController.text.trim(),
      'matchEpisodeSortFromName': _noChannelEpisodeSortRegexController.text
          .trim(),
    };
    config['selectMedia'] = {
      ..._objectAt(config, 'selectMedia'),
      'distinguishSubjectName': _distinguishSubjectName,
      'distinguishChannelName': _distinguishChannelName,
    };

    final matchVideo = {
      ..._objectAt(config, 'matchVideo'),
      'matchVideoUrl': _matchVideoUrlController.text.trim(),
      'enableNestedUrl': _enableNestedUrl,
      'matchNestedUrl': _matchNestedUrlController.text.trim(),
      'cookies': _cookiesController.text.trim(),
    };
    matchVideo['addHeadersToVideo'] = {
      ..._objectAt(matchVideo, 'addHeadersToVideo'),
      'referer': _refererController.text.trim(),
      'userAgent': _userAgentController.text.trim(),
    };
    config['matchVideo'] = matchVideo;

    return config;
  }

  String? _buildCaptchaConfigJson() {
    final hasCaptchaFields =
        _captchaDetectSelectorController.text.trim().isNotEmpty ||
        _captchaSuccessSelectorController.text.trim().isNotEmpty ||
        _captchaImageSelectorController.text.trim().isNotEmpty ||
        _captchaInputSelectorController.text.trim().isNotEmpty ||
        _captchaSubmitSelectorController.text.trim().isNotEmpty;
    if (!_captchaEnable && !_hadCaptchaConfig && !hasCaptchaFields) {
      return null;
    }

    final config = Map<String, dynamic>.from(_captchaConfig);
    config['enable'] = _captchaEnable;
    _putString(config, 'type', _captchaTypeController.text);
    _putString(config, 'detectSelector', _captchaDetectSelectorController.text);
    _putString(
      config,
      'successSelector',
      _captchaSuccessSelectorController.text,
    );
    _putString(config, 'imageSelector', _captchaImageSelectorController.text);
    _putString(
      config,
      'refreshSelector',
      _captchaRefreshSelectorController.text,
    );
    _putString(config, 'inputSelector', _captchaInputSelectorController.text);
    _putString(config, 'submitSelector', _captchaSubmitSelectorController.text);
    _putOptionalInt(config, 'initialDelayMs', _captchaInitialDelayController);
    config['useWebViewForDetail'] = _captchaUseWebViewForDetail;

    final constraints = {
      ..._objectAt(config, 'ocrConstraints'),
      'allowedChars': _captchaAllowedCharsController.text.trim(),
    };
    final expectedLength = _intFromController(_captchaExpectedLengthController);
    if (expectedLength == null) {
      constraints.remove('expectedLength');
    } else {
      constraints['expectedLength'] = expectedLength;
    }
    config['ocrConstraints'] = constraints;

    return _jsonEncoder.convert(config);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Subscription sources are managed exclusively by refresh/auto-update.
    if (widget.source != null && !widget.source!.isManual) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.subscriptionSourceReadOnly)),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final searchConfig = _buildSearchConfig();
      final update = SourceConfigUpdate(
        name: widget.source?.name ?? _nameController.text.trim(),
        newName:
            widget.source != null &&
                _nameController.text.trim() != widget.source!.name
            ? _nameController.text.trim()
            : null,
        tier: int.tryParse(_tierController.text.trim()),
        defaultSubtitleLanguage: _subtitleController.text.trim(),
        defaultResolution: _resolutionController.text.trim(),
        searchUrl: _searchUrlController.text.trim(),
        iconUrl: _iconUrlController.text.trim(),
        description: _descController.text.trim(),
        searchConfigJson: _jsonEncoder.convert(searchConfig),
        captchaConfigJson: _buildCaptchaConfigJson(),
      );

      if (widget.source == null) {
        final create = widget.onCreateSourceConfig;
        if (create != null) {
          await create(update);
        } else {
          await addSourceConfig(newConfig: update);
        }
      } else {
        final updateExisting = widget.onUpdateSourceConfig;
        if (updateExisting != null) {
          await updateExisting(update);
        } else {
          await updateSingleSourceConfig(update: update);
        }
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dataSourceConfigSaved)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataSourceConfigSaveFailed(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _required(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.dataSourceConfigRequired;
    }
    return null;
  }

  String? _integer(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.dataSourceConfigRequired;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return l10n.dataSourceConfigIntegerRequired;
    }
    if (parsed < -2147483648 || parsed > 2147483647) {
      return l10n.dataSourceConfigIntegerRange(-2147483648, 2147483647);
    }
    return null;
  }

  String? _optionalInteger(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (int.tryParse(value.trim()) == null) {
      return l10n.dataSourceConfigIntegerRequired;
    }
    return null;
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        border: const OutlineInputBorder(),
        filled: true,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _dropdownTextField({
    required TextEditingController controller,
    required String label,
    required List<String> options,
    String? helper,
    String? emptyLabel,
  }) {
    final value = controller.text;
    final items = {
      ...options,
      if (value.isNotEmpty && !options.contains(value)) value,
    }.toList();
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : '',
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
        filled: true,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(item.isEmpty ? (emptyLabel ?? item) : item),
          ),
      ],
      onChanged: (value) {
        controller.text = value ?? '';
      },
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: (value) => setState(() => onChanged(value)),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
    String? subtitle,
    bool initiallyExpanded = true,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle == null ? null : Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [const SizedBox(height: 8), ..._spaced(children)],
      ),
    );
  }

  List<Widget> _spaced(List<Widget> children) {
    return [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ],
    ];
  }

  Widget _responsivePair(bool isWide, Widget first, Widget second) {
    if (!isWide) {
      return Column(children: _spaced([first, second]));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  Widget _segmentedSelector({
    required String value,
    required Map<String, String> labels,
    required ValueChanged<String> onChanged,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PlatformSmoothSingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: [
            for (final entry in labels.entries)
              ButtonSegment(value: entry.key, label: Text(entry.value)),
          ],
          selected: {value},
          onSelectionChanged: (selected) {
            setState(() => onChanged(selected.first));
          },
        ),
      ),
    );
  }

  List<Widget> _buildGeneralSection(AppLocalizations l10n, bool isWide) {
    return [
      _responsivePair(
        isWide,
        _textField(
          controller: _nameController,
          label: l10n.dataSourceConfigName,
          helper: l10n.dataSourceConfigNameHelper,
          validator: (value) => _required(l10n, value),
        ),
        _textField(
          controller: _tierController,
          label: l10n.dataSourceConfigTier,
          helper: l10n.dataSourceConfigTierHelper,
          keyboardType: TextInputType.number,
          validator: (value) => _integer(l10n, value),
        ),
      ),
      _textField(
        controller: _iconUrlController,
        label: l10n.dataSourceConfigIconUrl,
        hint: l10n.dataSourceConfigIconUrlHint,
      ),
      _textField(
        controller: _descController,
        label: l10n.dataSourceConfigDescription,
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildSearchSection(AppLocalizations l10n, bool isWide) {
    return [
      _textField(
        controller: _searchUrlController,
        label: l10n.dataSourceConfigSearchUrl,
        hint: l10n.dataSourceConfigSearchUrlHint('{keyword}'),
        helper: l10n.dataSourceConfigSearchUrlHelper('{keyword}'),
        maxLines: 2,
        validator: (value) => _required(l10n, value),
      ),
      _textField(
        controller: _rawBaseUrlController,
        label: l10n.dataSourceConfigUseRawBaseUrl,
        helper: l10n.dataSourceConfigUseRawBaseUrlHelper,
      ),
      _switchTile(
        title: l10n.dataSourceConfigSubjectUseFirstWord,
        subtitle: l10n.dataSourceConfigSubjectUseFirstWordSub,
        value: _searchUseOnlyFirstWord,
        onChanged: (value) => _searchUseOnlyFirstWord = value,
      ),
      _switchTile(
        title: l10n.dataSourceConfigSubjectRemoveSpecial,
        subtitle: l10n.dataSourceConfigSubjectRemoveSpecialSub,
        value: _searchRemoveSpecial,
        onChanged: (value) => _searchRemoveSpecial = value,
      ),
      _responsivePair(
        isWide,
        _textField(
          controller: _searchUseSubjectNamesCountController,
          label: l10n.dataSourceConfigSubjectUseNamesCount,
          helper: l10n.dataSourceConfigSubjectUseNamesCountHelper,
          keyboardType: TextInputType.number,
          validator: (value) => _optionalInteger(l10n, value),
        ),
        _textField(
          controller: _requestIntervalController,
          label: l10n.dataSourceConfigRequestInterval,
          helper: l10n.dataSourceConfigRequestIntervalHelper,
          keyboardType: TextInputType.number,
          validator: (value) => _optionalInteger(l10n, value),
        ),
      ),
    ];
  }

  List<Widget> _buildSubjectSection(AppLocalizations l10n, bool isWide) {
    return [
      _segmentedSelector(
        value: _subjectFormatId,
        labels: _subjectFormats(l10n),
        onChanged: (value) => _subjectFormatId = value,
      ),
      if (_subjectFormatId == 'a') ...[
        _textField(
          controller: _subjectASelectListsController,
          label: l10n.dataSourceConfigSubjectLinkSelector,
          helper: l10n.dataSourceConfigSubjectLinkSelectorHelper,
          validator: (value) => _required(l10n, value),
        ),
        _switchTile(
          title: l10n.dataSourceConfigPreferShorterName,
          value: _preferSubjectAShorterName,
          onChanged: (value) => _preferSubjectAShorterName = value,
        ),
      ] else if (_subjectFormatId == 'jsonpath-indexed') ...[
        _responsivePair(
          isWide,
          _textField(
            controller: _subjectJsonPathSelectNamesController,
            label: l10n.dataSourceConfigNameJsonPath,
            validator: (value) => _required(l10n, value),
          ),
          _textField(
            controller: _subjectJsonPathSelectLinksController,
            label: l10n.dataSourceConfigLinkJsonPath,
            validator: (value) => _required(l10n, value),
          ),
        ),
        _switchTile(
          title: l10n.dataSourceConfigPreferShorterName,
          value: _preferSubjectJsonPathShorterName,
          onChanged: (value) => _preferSubjectJsonPathShorterName = value,
        ),
      ] else ...[
        _responsivePair(
          isWide,
          _textField(
            controller: _subjectIndexedSelectNamesController,
            label: l10n.dataSourceConfigSubjectNameSelector,
            validator: (value) => _required(l10n, value),
          ),
          _textField(
            controller: _subjectIndexedSelectLinksController,
            label: l10n.dataSourceConfigSubjectLinkSelector,
            validator: (value) => _required(l10n, value),
          ),
        ),
        _switchTile(
          title: l10n.dataSourceConfigPreferShorterName,
          value: _preferSubjectIndexedShorterName,
          onChanged: (value) => _preferSubjectIndexedShorterName = value,
        ),
      ],
    ];
  }

  List<Widget> _buildChannelSection(AppLocalizations l10n, bool isWide) {
    return [
      _segmentedSelector(
        value: _channelFormatId,
        labels: _channelFormats(l10n),
        onChanged: (value) => _channelFormatId = value,
      ),
      if (_channelFormatId == 'index-grouped') ...[
        _responsivePair(
          isWide,
          _textField(
            controller: _channelNamesController,
            label: l10n.dataSourceConfigChannelNameSelector,
            helper: l10n.dataSourceConfigChannelNameSelectorHelper,
          ),
          _textField(
            controller: _channelNameRegexController,
            label: l10n.dataSourceConfigChannelNameRegex,
            helper: l10n.dataSourceConfigChannelNameRegexHelper,
          ),
        ),
        _textField(
          controller: _episodeListsController,
          label: l10n.dataSourceConfigEpisodeListSelector,
          validator: (value) => _required(l10n, value),
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _episodesFromListController,
            label: l10n.dataSourceConfigEpisodesFromListSelector,
            validator: (value) => _required(l10n, value),
          ),
          _textField(
            controller: _episodeLinksFromListController,
            label: l10n.dataSourceConfigEpisodeLinkSelector,
            helper: l10n.dataSourceConfigEpisodeLinkSelectorHelper,
          ),
        ),
        _textField(
          controller: _episodeSortRegexController,
          label: l10n.dataSourceConfigSortRegex,
          helper: l10n.dataSourceConfigSortRegexHelper,
        ),
      ] else ...[
        _textField(
          controller: _noChannelEpisodesController,
          label: l10n.dataSourceConfigEpisodeSelector,
          validator: (value) => _required(l10n, value),
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _noChannelEpisodeLinksController,
            label: l10n.dataSourceConfigFromListEpisodeLinkSelector,
            helper: l10n.dataSourceConfigFromListEpisodeLinkSelectorHelper,
          ),
          _textField(
            controller: _noChannelEpisodeSortRegexController,
            label: l10n.dataSourceConfigSortRegex,
            helper: l10n.dataSourceConfigSortRegexHelper,
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildFilterAndPlayerSection(
    AppLocalizations l10n,
    bool isWide,
  ) {
    return [
      _responsivePair(
        isWide,
        _dropdownTextField(
          controller: _resolutionController,
          label: l10n.dataSourceConfigResolutionLabel,
          helper: l10n.dataSourceConfigResolutionHelper,
          emptyLabel: l10n.dataSourceConfigNotMarked,
          options: _resolutionOptions,
        ),
        _dropdownTextField(
          controller: _subtitleController,
          label: l10n.dataSourceConfigSubtitleLabel,
          helper: l10n.dataSourceConfigSubtitleHelper,
          emptyLabel: l10n.dataSourceConfigNotMarked,
          options: _subtitleOptions,
        ),
      ),
      _switchTile(
        title: l10n.dataSourceConfigFilterBySubjectName,
        subtitle: l10n.dataSourceConfigFilterBySubjectNameSub,
        value: _filterBySubjectName,
        onChanged: (value) => _filterBySubjectName = value,
      ),
      _switchTile(
        title: l10n.dataSourceConfigFilterByEpisodeSort,
        subtitle: l10n.dataSourceConfigFilterByEpisodeSortSub,
        value: _filterByEpisodeSort,
        onChanged: (value) => _filterByEpisodeSort = value,
      ),
      _switchTile(
        title: l10n.dataSourceConfigDistinguishSubjectName,
        subtitle: l10n.dataSourceConfigDistinguishSubjectNameSub,
        value: _distinguishSubjectName,
        onChanged: (value) => _distinguishSubjectName = value,
      ),
      _switchTile(
        title: l10n.dataSourceConfigDistinguishChannelName,
        subtitle: l10n.dataSourceConfigDistinguishChannelNameSub,
        value: _distinguishChannelName,
        onChanged: (value) => _distinguishChannelName = value,
      ),
    ];
  }

  List<Widget> _buildVideoSection(AppLocalizations l10n, bool isWide) {
    return [
      _textField(
        controller: _matchVideoUrlController,
        label: l10n.dataSourceConfigMatchVideoUrl,
        helper: l10n.dataSourceConfigMatchVideoUrlHelper,
        maxLines: 4,
        validator: (value) => _required(l10n, value),
      ),
      _switchTile(
        title: l10n.dataSourceConfigEnableNestedUrl,
        subtitle: l10n.dataSourceConfigEnableNestedUrlSub,
        value: _enableNestedUrl,
        onChanged: (value) => _enableNestedUrl = value,
      ),
      _textField(
        controller: _matchNestedUrlController,
        label: l10n.dataSourceConfigNestedUrlRegex,
        maxLines: 3,
      ),
      _textField(
        controller: _cookiesController,
        label: l10n.dataSourceConfigCookie,
        helper: l10n.dataSourceConfigCookieHelper,
        maxLines: 2,
      ),
      _responsivePair(
        isWide,
        _textField(
          controller: _refererController,
          label: l10n.dataSourceConfigReferer,
          helper: l10n.dataSourceConfigRefererHelper,
        ),
        _textField(
          controller: _userAgentController,
          label: l10n.dataSourceConfigUserAgent,
          helper: l10n.dataSourceConfigUserAgentHelper,
          maxLines: 2,
        ),
      ),
    ];
  }

  List<Widget> _buildCaptchaSection(AppLocalizations l10n, bool isWide) {
    return [
      _switchTile(
        title: l10n.dataSourceConfigEnableCaptcha,
        subtitle: l10n.dataSourceConfigEnableCaptchaSub,
        value: _captchaEnable,
        onChanged: (value) => _captchaEnable = value,
      ),
      if (_captchaEnable || _hadCaptchaConfig) ...[
        _responsivePair(
          isWide,
          _textField(
            controller: _captchaTypeController,
            label: l10n.dataSourceConfigType,
          ),
          _textField(
            controller: _captchaInitialDelayController,
            label: l10n.dataSourceConfigCaptchaInitialDelay,
            keyboardType: TextInputType.number,
            validator: (value) => _optionalInteger(l10n, value),
          ),
        ),
        _switchTile(
          title: l10n.dataSourceConfigUseWebViewForCaptchaDetail,
          value: _captchaUseWebViewForDetail,
          onChanged: (value) => _captchaUseWebViewForDetail = value,
        ),
        _textField(
          controller: _captchaDetectSelectorController,
          label: l10n.dataSourceConfigDetectSelector,
          maxLines: 2,
        ),
        _textField(
          controller: _captchaSuccessSelectorController,
          label: l10n.dataSourceConfigSuccessSelector,
          maxLines: 2,
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _captchaImageSelectorController,
            label: l10n.dataSourceConfigImageSelector,
          ),
          _textField(
            controller: _captchaRefreshSelectorController,
            label: l10n.dataSourceConfigRefreshSelector,
          ),
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _captchaInputSelectorController,
            label: l10n.dataSourceConfigInputSelector,
          ),
          _textField(
            controller: _captchaSubmitSelectorController,
            label: l10n.dataSourceConfigSubmitSelector,
          ),
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _captchaExpectedLengthController,
            label: l10n.dataSourceConfigExpectedLength,
            keyboardType: TextInputType.number,
            validator: (value) => _optionalInteger(l10n, value),
          ),
          _textField(
            controller: _captchaAllowedCharsController,
            label: l10n.dataSourceConfigAllowedChars,
          ),
        ),
      ],
    ];
  }

  Widget _buildPreviewSection(AppLocalizations l10n) {
    final searchJson = _jsonEncoder.convert(_buildSearchConfig());
    final captchaJson = _buildCaptchaConfigJson();
    return _section(
      title: l10n.dataSourceConfigJsonPreviewTitle,
      subtitle: l10n.dataSourceConfigJsonPreviewSub,
      initiallyExpanded: false,
      children: [
        Text(
          l10n.dataSourceConfigJsonSchemaSearch,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: SelectableText(searchJson),
        ),
        Text(
          l10n.dataSourceConfigJsonSchemaCaptcha,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: SelectableText(
            captchaJson ?? l10n.dataSourceConfigJsonSchemaNotConfigured,
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(AppLocalizations l10n, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          title: l10n.dataSourceConfigBasicInfo,
          children: _buildGeneralSection(l10n, isWide),
        ),
        _section(
          title: l10n.dataSourceConfigStep1Search,
          subtitle: l10n.dataSourceConfigStep1SearchSub,
          children: _buildSearchSection(l10n, isWide),
        ),
        _section(
          title: l10n.dataSourceConfigStep1ParseResults,
          subtitle: l10n.dataSourceConfigStep1ParseResultsSub,
          children: _buildSubjectSection(l10n, isWide),
        ),
        _section(
          title: l10n.dataSourceConfigStep2Channels,
          subtitle: l10n.dataSourceConfigStep2ChannelsSub,
          children: _buildChannelSection(l10n, isWide),
        ),
        _section(
          title: l10n.dataSourceConfigFilterAndPlayer,
          children: _buildFilterAndPlayerSection(l10n, isWide),
        ),
        _section(
          title: l10n.dataSourceConfigStep3MatchVideo,
          subtitle: l10n.dataSourceConfigStep3MatchVideoSub,
          children: _buildVideoSection(l10n, isWide),
        ),
        _section(
          title: l10n.dataSourceConfigCaptcha,
          subtitle: l10n.dataSourceConfigCaptchaSub,
          children: _buildCaptchaSection(l10n, isWide),
          initiallyExpanded: _hadCaptchaConfig,
        ),
        _buildPreviewSection(l10n),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPc = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final isReadOnly = widget.source != null && !widget.source!.isManual;
    final isHosted = DesktopPageChromeScope.hostsPageHeader(context);
    final title = widget.source == null
        ? l10n.dataSourceConfigNew
        : l10n.dataSourceConfigEditing(widget.source!.name);

    final page = DesktopPageScaffold(
      title: Text(title),
      actions: [
        if (!isReadOnly)
          IconButton(
            tooltip: l10n.dataSourceConfigSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
      ],
      desktopActionRow: isReadOnly ? const SizedBox.shrink() : null,
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            if (isReadOnly) ...[
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.subscriptionSourceReadOnly),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPc ? 960 : double.infinity,
                ),
                child: IgnorePointer(
                  ignoring: isReadOnly,
                  child: Opacity(
                    opacity: isReadOnly ? 0.7 : 1,
                    child: _buildFormContent(l10n, isWide),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return isHosted ? WorkspaceRouteTitle(title: title, child: page) : page;
  }
}
