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
  late TextEditingController _nameController;
  late TextEditingController _tierController;
  late TextEditingController _subtitleController;
  late TextEditingController _resolutionController;
  late TextEditingController _searchUrlController;
  late TextEditingController _iconUrlController;
  late TextEditingController _descController;
  late TextEditingController _searchConfigJsonController;
  bool _isSaving = false;
  bool _useAdvancedMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.source != null) {
      _nameController = TextEditingController(text: widget.source!.name);
      _tierController = TextEditingController(
        text: widget.source!.tier.toString(),
      );
      _subtitleController = TextEditingController(
        text: widget.source!.defaultSubtitleLanguage,
      );
      _resolutionController = TextEditingController(
        text: widget.source!.defaultResolution,
      );
      _searchUrlController = TextEditingController(
        text: widget.source!.searchUrl,
      );
      _iconUrlController = TextEditingController(text: widget.source!.iconUrl);
      _descController = TextEditingController(text: widget.source!.description);
      _searchConfigJsonController = TextEditingController(
        text: widget.source!.searchConfigJson,
      );
    } else {
      _nameController = TextEditingController();
      _tierController = TextEditingController(text: '0');
      _subtitleController = TextEditingController();
      _resolutionController = TextEditingController();
      _searchUrlController = TextEditingController();
      _iconUrlController = TextEditingController();
      _descController = TextEditingController();
      _searchConfigJsonController = TextEditingController(
        text: const JsonEncoder.withIndent('  ').convert({
          "searchUrl": "https://example.com/api/search?q={keyword}",
          "defaultSubtitleLanguage": "{{defaultSubtitleLanguage}}",
          "defaultResolution": "{{defaultResolution}}",
          "subjectFormatId": "{{subjectFormatId}}",
          "selectorSubjectFormatA": {
            "selectLists": "{{selectSubjectALists}}",
            "preferShorterName": "{{preferShorterName}}",
          },
          "selectorSubjectFormatIndexed": {
            "selectNames": "{{selectSubjectIndexedNames}}",
            "selectLinks": "{{selectSubjectIndexedLinks}}",
            "preferShorterName": "{{preferShorterName}}",
          },
          "channelFormatId": "{{channelFormatId}}",
          "selectorChannelFormatFlattened": {
            "selectChannelNames": "{{selectChannelNames}}",
            "matchChannelName": "{{matchChannelNameRegex}}",
            "selectEpisodeLists": "{{selectEpisodeLists}}",
            "selectEpisodesFromList": "{{selectEpisodesFromList}}",
            "selectEpisodeLinksFromList": "{{selectEpisodeLinksFromList}}",
            "matchEpisodeSortFromName": "{{matchEpisodeSortRegex}}",
          },
          "selectorChannelFormatNoChannel": {
            "selectEpisodes": "{{selectEpisodes}}",
            "selectEpisodeLinks": "{{selectEpisodeLinks}}",
            "matchEpisodeSortFromName": "{{matchEpisodeSortRegexNoChannel}}",
          },
          "matchVideo": {
            "matchVideoUrl": "{{matchVideoUrlRegex}}",
            "enableNestedUrl": "{{enableNestedUrl}}",
            "matchNestedUrl": "{{matchNestedUrl}}",
            "cookies": "{{cookies}}",
            "addHeadersToVideo": {
              "userAgent": "{{userAgent}}",
              "referer": "{{referer}}",
            },
          },
        }),
      );
      // Default to advanced mode for new sources as it is safer/more explicit
      _useAdvancedMode = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tierController.dispose();
    _subtitleController.dispose();
    _resolutionController.dispose();
    _searchUrlController.dispose();
    _iconUrlController.dispose();
    _descController.dispose();
    _searchConfigJsonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final update = SourceConfigUpdate(
        name: widget.source?.name ?? _nameController.text,
        newName:
            widget.source != null && _nameController.text != widget.source!.name
            ? _nameController.text
            : null,
        tier: int.tryParse(_tierController.text),
        defaultSubtitleLanguage: _subtitleController.text,
        defaultResolution: _resolutionController.text,
        searchUrl: _searchUrlController.text,
        iconUrl: _iconUrlController.text,
        description: _descController.text,
        searchConfigJson: _useAdvancedMode
            ? _searchConfigJsonController.text
            : null,
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
        Navigator.pop(context, true); // Return true to indicate refresh needed
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
    int maxLines = 1,
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

  Widget _buildFormContent(bool isPc) {
    // Common fields
    final commonFields = [
      if (isPc)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: _nameController,
                label: '源名称 (Name)',
                helper: '修改名称可能会影响某些依赖名称的逻辑',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _tierController,
                label: '优先级 (Tier)',
                helper: '数字越小优先级越高 (0 > 1)',
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return '请输入优先级';
                  if (int.tryParse(val) == null) return '请输入有效的整数';
                  return null;
                },
              ),
            ),
          ],
        )
      else ...[
        _buildTextField(controller: _nameController, label: '源名称 (Name)'),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _tierController,
          label: '优先级 (Tier)',
          helper: '数字越小优先级越高',
          keyboardType: TextInputType.number,
        ),
      ],
      const SizedBox(height: 16),
      _buildTextField(
        controller: _iconUrlController,
        label: '图标 URL',
        hint: isPc ? 'https://...' : null,
      ),
      const SizedBox(height: 16),
      _buildTextField(controller: _descController, label: '描述', maxLines: 3),
    ];

    // Search Config Section
    final searchConfigSection = [
      const SizedBox(height: 16),
      Row(
        children: [
          const Text(
            '搜索配置 (Search Config)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          const Text('高级模式 (JSON)'),
          Switch(
            value: _useAdvancedMode,
            onChanged: (val) {
              setState(() {
                _useAdvancedMode = val;
                if (!val) {
                  // JSON -> Fields
                  try {
                    final json = jsonDecode(_searchConfigJsonController.text);
                    if (json is Map) {
                      if (json['defaultSubtitleLanguage'] != null) {
                        _subtitleController.text =
                            json['defaultSubtitleLanguage'];
                      }
                      if (json['defaultResolution'] != null) {
                        _resolutionController.text = json['defaultResolution'];
                      }
                      if (json['searchUrl'] != null) {
                        _searchUrlController.text = json['searchUrl'];
                      }
                    }
                  } catch (e) {
                    debugPrint('Sync failed: $e');
                  }
                } else {
                  // Fields -> JSON
                  try {
                    final json = jsonDecode(_searchConfigJsonController.text);
                    if (json is Map) {
                      json['defaultSubtitleLanguage'] =
                          _subtitleController.text;
                      json['defaultResolution'] = _resolutionController.text;
                      json['searchUrl'] = _searchUrlController.text;
                      _searchConfigJsonController.text =
                          const JsonEncoder.withIndent('  ').convert(json);
                    }
                  } catch (e) {
                    debugPrint('Sync failed: $e');
                  }
                }
              });
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_useAdvancedMode)
        _buildTextField(
          controller: _searchConfigJsonController,
          label: 'Search Config JSON',
          maxLines: 20,
          validator: (val) {
            if (val == null || val.isEmpty) return '请输入 JSON 配置';
            try {
              jsonDecode(val);
            } catch (e) {
              return '无效的 JSON 格式';
            }
            return null;
          },
        )
      else ...[
        if (isPc)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _subtitleController,
                  label: '默认字幕语言',
                  hint: '如: 简中, 繁中',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _resolutionController,
                  label: '默认分辨率',
                  hint: '如: 1080P, 4K',
                ),
              ),
            ],
          )
        else ...[
          _buildTextField(controller: _subtitleController, label: '默认字幕语言'),
          const SizedBox(height: 16),
          _buildTextField(controller: _resolutionController, label: '默认分辨率'),
        ],
        const SizedBox(height: 16),
        _buildTextField(
          controller: _searchUrlController,
          label: '搜索 URL',
          hint: '使用 {keyword} 作为占位符',
          maxLines: 3,
          validator: (val) {
            if (val == null || val.isEmpty) return '请输入搜索 URL';
            return null;
          },
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...commonFields, ...searchConfigSection],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPc = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.source == null ? '新建数据源' : '配置: ${widget.source!.name}',
        ),
        actions: [
          IconButton(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: isPc
                ? const BoxConstraints(maxWidth: 800)
                : const BoxConstraints(),
            child: Form(key: _formKey, child: _buildFormContent(isPc)),
          ),
        ),
      ),
    );
  }
}
