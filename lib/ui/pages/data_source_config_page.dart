import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';

class DataSourceConfigPage extends StatefulWidget {
  final SourceState? source;

  const DataSourceConfigPage({super.key, this.source});

  @override
  State<DataSourceConfigPage> createState() => _DataSourceConfigPageState();
}

class _DataSourceConfigPageState extends State<DataSourceConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _jsonEncoder = const JsonEncoder.withIndent('  ');
  final List<TextEditingController> _controllers = [];

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

  static const _subjectFormats = <String, String>{
    'a': '单标签',
    'indexed': '多标签',
    'jsonpath-indexed': 'JsonPath',
  };

  static const _channelFormats = <String, String>{
    'index-grouped': '线路分组',
    'no-channel': '不区分线路',
  };

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
    if (!_subjectFormats.containsKey(_subjectFormatId)) {
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
    if (!_channelFormats.containsKey(_channelFormatId)) {
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
        await addSourceConfig(newConfig: update);
      } else {
        await updateSingleSourceConfig(update: update);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return '必填';
    return null;
  }

  String? _integer(String? value) {
    if (value == null || value.trim().isEmpty) return '必填';
    if (int.tryParse(value.trim()) == null) return '请输入整数';
    return null;
  }

  String? _optionalInteger(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (int.tryParse(value.trim()) == null) return '请输入整数';
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
            child: Text(item.isEmpty ? '不标记' : item),
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
      child: SingleChildScrollView(
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

  List<Widget> _buildGeneralSection(bool isWide) {
    return [
      _responsivePair(
        isWide,
        _textField(
          controller: _nameController,
          label: '名称',
          helper: '显示在数据源列表中的名称',
          validator: _required,
        ),
        _textField(
          controller: _tierController,
          label: '优先级',
          helper: '数字越小优先级越高',
          keyboardType: TextInputType.number,
          validator: _integer,
        ),
      ),
      _textField(
        controller: _iconUrlController,
        label: '图标链接',
        hint: 'https://...',
      ),
      _textField(controller: _descController, label: '描述', maxLines: 3),
    ];
  }

  List<Widget> _buildSearchSection(bool isWide) {
    return [
      _textField(
        controller: _searchUrlController,
        label: '搜索链接',
        hint: 'https://example.com/search?wd={keyword}',
        helper: '{keyword} 会替换为条目名称',
        maxLines: 2,
        validator: _required,
      ),
      _textField(
        controller: _rawBaseUrlController,
        label: 'Base URL',
        helper: '可选。用于拼接条目详情页链接，留空时通常从搜索链接推断',
      ),
      _switchTile(
        title: '仅使用第一个词',
        subtitle: '以空格分割条目名后只用第一个词搜索',
        value: _searchUseOnlyFirstWord,
        onChanged: (value) => _searchUseOnlyFirstWord = value,
      ),
      _switchTile(
        title: '去除特殊字符',
        subtitle: '清理符号和部分常见干扰词，提升搜索兼容性',
        value: _searchRemoveSpecial,
        onChanged: (value) => _searchRemoveSpecial = value,
      ),
      _responsivePair(
        isWide,
        _textField(
          controller: _searchUseSubjectNamesCountController,
          label: '尝试条目名称数量',
          helper: '留空使用默认值。1 表示仅使用主名称',
          keyboardType: TextInputType.number,
          validator: _optionalInteger,
        ),
        _textField(
          controller: _requestIntervalController,
          label: '请求间隔 (毫秒)',
          helper: '每次请求后的等待时间',
          keyboardType: TextInputType.number,
          validator: _optionalInteger,
        ),
      ),
    ];
  }

  List<Widget> _buildSubjectSection(bool isWide) {
    return [
      _segmentedSelector(
        value: _subjectFormatId,
        labels: _subjectFormats,
        onChanged: (value) => _subjectFormatId = value,
      ),
      if (_subjectFormatId == 'a') ...[
        _textField(
          controller: _subjectASelectListsController,
          label: '条目链接选择器',
          helper: '从搜索结果页选择条目详情链接',
          validator: _required,
        ),
        _switchTile(
          title: '优先匹配较短名称',
          value: _preferSubjectAShorterName,
          onChanged: (value) => _preferSubjectAShorterName = value,
        ),
      ] else if (_subjectFormatId == 'jsonpath-indexed') ...[
        _responsivePair(
          isWide,
          _textField(
            controller: _subjectJsonPathSelectNamesController,
            label: '名称 JsonPath',
            validator: _required,
          ),
          _textField(
            controller: _subjectJsonPathSelectLinksController,
            label: '链接 JsonPath',
            validator: _required,
          ),
        ),
        _switchTile(
          title: '优先匹配较短名称',
          value: _preferSubjectJsonPathShorterName,
          onChanged: (value) => _preferSubjectJsonPathShorterName = value,
        ),
      ] else ...[
        _responsivePair(
          isWide,
          _textField(
            controller: _subjectIndexedSelectNamesController,
            label: '条目名称选择器',
            validator: _required,
          ),
          _textField(
            controller: _subjectIndexedSelectLinksController,
            label: '条目链接选择器',
            validator: _required,
          ),
        ),
        _switchTile(
          title: '优先匹配较短名称',
          value: _preferSubjectIndexedShorterName,
          onChanged: (value) => _preferSubjectIndexedShorterName = value,
        ),
      ],
    ];
  }

  List<Widget> _buildChannelSection(bool isWide) {
    return [
      _segmentedSelector(
        value: _channelFormatId,
        labels: _channelFormats,
        onChanged: (value) => _channelFormatId = value,
      ),
      if (_channelFormatId == 'index-grouped') ...[
        _responsivePair(
          isWide,
          _textField(
            controller: _channelNamesController,
            label: '线路名称选择器',
            helper: '例如线路、字幕组、播放源 tab',
          ),
          _textField(
            controller: _channelNameRegexController,
            label: '线路名称正则',
            helper: r'可用 (?<ch>...) 捕获最终名称',
          ),
        ),
        _textField(
          controller: _episodeListsController,
          label: '剧集列表选择器',
          validator: _required,
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _episodesFromListController,
            label: '列表内剧集选择器',
            validator: _required,
          ),
          _textField(
            controller: _episodeLinksFromListController,
            label: '列表内链接选择器',
            helper: '留空时使用剧集元素自身 href',
          ),
        ),
        _textField(
          controller: _episodeSortRegexController,
          label: '剧集序号正则',
          helper: r'建议使用 (?<ep>...) 捕获集数',
        ),
      ] else ...[
        _textField(
          controller: _noChannelEpisodesController,
          label: '剧集选择器',
          validator: _required,
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _noChannelEpisodeLinksController,
            label: '剧集链接选择器',
            helper: '留空时使用剧集元素自身 href',
          ),
          _textField(
            controller: _noChannelEpisodeSortRegexController,
            label: '剧集序号正则',
            helper: r'建议使用 (?<ep>...) 捕获集数',
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildFilterAndPlayerSection(bool isWide) {
    return [
      _responsivePair(
        isWide,
        _dropdownTextField(
          controller: _resolutionController,
          label: '标记分辨率',
          helper: '用于播放器内偏好和过滤',
          options: _resolutionOptions,
        ),
        _dropdownTextField(
          controller: _subtitleController,
          label: '标记字幕语言',
          helper: '用于播放器内偏好和过滤',
          options: _subtitleOptions,
        ),
      ),
      _switchTile(
        title: '使用条目名称过滤',
        subtitle: '要求资源标题包含条目名称',
        value: _filterBySubjectName,
        onChanged: (value) => _filterBySubjectName = value,
      ),
      _switchTile(
        title: '使用剧集序号过滤',
        subtitle: '要求资源标题包含剧集序号，通常建议开启',
        value: _filterByEpisodeSort,
        onChanged: (value) => _filterByEpisodeSort = value,
      ),
      _switchTile(
        title: '区分条目名称',
        subtitle: '关闭后，不同搜索结果中同名剧集会被去重',
        value: _distinguishSubjectName,
        onChanged: (value) => _distinguishSubjectName = value,
      ),
      _switchTile(
        title: '区分线路名称',
        subtitle: '关闭后，不同线路中的同名剧集会被去重',
        value: _distinguishChannelName,
        onChanged: (value) => _distinguishChannelName = value,
      ),
    ];
  }

  List<Widget> _buildVideoSection(bool isWide) {
    return [
      _textField(
        controller: _matchVideoUrlController,
        label: '视频 URL 正则',
        helper: r'可用 (?<v>...) 捕获最终播放地址',
        maxLines: 4,
        validator: _required,
      ),
      _switchTile(
        title: '启用嵌套 URL 匹配',
        subtitle: '先从播放器页找到内层播放页，再匹配视频地址',
        value: _enableNestedUrl,
        onChanged: (value) => _enableNestedUrl = value,
      ),
      _textField(
        controller: _matchNestedUrlController,
        label: '嵌套 URL 正则',
        maxLines: 3,
      ),
      _textField(
        controller: _cookiesController,
        label: 'Cookie',
        helper: '播放视频请求携带的 Cookie，可留空',
        maxLines: 2,
      ),
      _responsivePair(
        isWide,
        _textField(
          controller: _refererController,
          label: 'Referer',
          helper: '播放视频请求的 Referer',
        ),
        _textField(
          controller: _userAgentController,
          label: 'User-Agent',
          helper: '播放视频请求的 User-Agent',
          maxLines: 2,
        ),
      ),
    ];
  }

  List<Widget> _buildCaptchaSection(bool isWide) {
    return [
      _switchTile(
        title: '启用验证码处理',
        subtitle: '需要绕过详情页验证码时开启',
        value: _captchaEnable,
        onChanged: (value) => _captchaEnable = value,
      ),
      if (_captchaEnable || _hadCaptchaConfig) ...[
        _responsivePair(
          isWide,
          _textField(controller: _captchaTypeController, label: '类型'),
          _textField(
            controller: _captchaInitialDelayController,
            label: '初始等待 (毫秒)',
            keyboardType: TextInputType.number,
            validator: _optionalInteger,
          ),
        ),
        _switchTile(
          title: '详情页使用 WebView',
          value: _captchaUseWebViewForDetail,
          onChanged: (value) => _captchaUseWebViewForDetail = value,
        ),
        _textField(
          controller: _captchaDetectSelectorController,
          label: '验证码检测选择器',
          maxLines: 2,
        ),
        _textField(
          controller: _captchaSuccessSelectorController,
          label: '成功页面选择器',
          maxLines: 2,
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _captchaImageSelectorController,
            label: '验证码图片选择器',
          ),
          _textField(
            controller: _captchaRefreshSelectorController,
            label: '刷新图片选择器',
          ),
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _captchaInputSelectorController,
            label: '输入框选择器',
          ),
          _textField(
            controller: _captchaSubmitSelectorController,
            label: '提交按钮选择器',
          ),
        ),
        _responsivePair(
          isWide,
          _textField(
            controller: _captchaExpectedLengthController,
            label: '验证码长度',
            keyboardType: TextInputType.number,
            validator: _optionalInteger,
          ),
          _textField(controller: _captchaAllowedCharsController, label: '允许字符'),
        ),
      ],
    ];
  }

  Widget _buildPreviewSection() {
    final searchJson = _jsonEncoder.convert(_buildSearchConfig());
    final captchaJson = _buildCaptchaConfigJson();
    return _section(
      title: '生成的 JSON',
      subtitle: '用于核对保存内容',
      initiallyExpanded: false,
      children: [
        Text('searchConfig', style: Theme.of(context).textTheme.titleSmall),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: SelectableText(searchJson),
        ),
        Text('captchaConfig', style: Theme.of(context).textTheme.titleSmall),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: SelectableText(captchaJson ?? '未配置'),
        ),
      ],
    );
  }

  Widget _buildFormContent(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(title: '基本信息', children: _buildGeneralSection(isWide)),
        _section(
          title: '步骤 1：搜索条目',
          subtitle: '配置搜索链接和搜索词处理规则',
          children: _buildSearchSection(isWide),
        ),
        _section(
          title: '步骤 1：解析搜索结果',
          subtitle: '从搜索结果中提取条目名称和详情页链接',
          children: _buildSubjectSection(isWide),
        ),
        _section(
          title: '步骤 2：解析线路和剧集',
          subtitle: '从详情页提取线路、剧集和播放页链接',
          children: _buildChannelSection(isWide),
        ),
        _section(
          title: '过滤和播放器选择',
          children: _buildFilterAndPlayerSection(isWide),
        ),
        _section(
          title: '步骤 3：匹配视频',
          subtitle: '从播放页提取最终视频地址和请求头',
          children: _buildVideoSection(isWide),
        ),
        _section(
          title: '验证码',
          subtitle: '可选。仅数据源存在验证码时需要配置',
          children: _buildCaptchaSection(isWide),
          initiallyExpanded: _hadCaptchaConfig,
        ),
        _buildPreviewSection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPc = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.source == null ? '新建数据源' : '配置: ${widget.source!.name}',
        ),
        actions: [
          IconButton(
            tooltip: '保存',
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPc ? 960 : double.infinity,
                ),
                child: _buildFormContent(isWide),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
