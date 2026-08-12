import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/favorite_status_selector.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';

enum BangumiCollectionEditorAction { save, remove }

class BangumiCollectionEditorResult {
  const BangumiCollectionEditorResult({
    required this.action,
    required this.type,
    required this.rate,
    required this.comment,
    required this.tags,
    required this.private,
  });

  final BangumiCollectionEditorAction action;
  final int type;
  final int rate;
  final String comment;
  final List<String> tags;
  final bool private;
}

class BangumiCollectionEditorPanel extends StatefulWidget {
  const BangumiCollectionEditorPanel({
    super.key,
    required this.initialType,
    required this.initialRate,
    required this.initialComment,
    required this.initialTags,
    required this.initialPrivate,
    required this.suggestedTags,
    required this.canRemove,
  });

  final int initialType;
  final int initialRate;
  final String initialComment;
  final List<String> initialTags;
  final bool initialPrivate;
  final List<String> suggestedTags;
  final bool canRemove;

  @override
  State<BangumiCollectionEditorPanel> createState() =>
      _BangumiCollectionEditorPanelState();
}

class _BangumiCollectionEditorPanelState
    extends State<BangumiCollectionEditorPanel> {
  final ScrollController _scrollController = createPlatformScrollController();
  late int _type;
  late int _rate;
  late bool _private;
  late final TextEditingController _commentController;
  late final TextEditingController _tagController;
  late final List<String> _tags;
  String? _tagError;

  @override
  void initState() {
    super.initState();
    _type = LocalFavoriteType.isValid(widget.initialType)
        ? widget.initialType
        : LocalFavoriteType.wish;
    _rate = widget.initialRate.clamp(0, 10);
    _private = widget.initialPrivate;
    _commentController = TextEditingController(text: widget.initialComment);
    _tagController = TextEditingController();
    _tags = widget.initialTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tagController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addPendingTags([String? rawValue]) {
    final raw = rawValue ?? _tagController.text;
    if (raw.trim().isEmpty) return;
    final candidates = raw.split(RegExp(r'[,，]'));
    try {
      final normalized = normalizeBangumiTags(candidates);
      setState(() {
        for (final tag in normalized) {
          if (!_tags.contains(tag)) _tags.add(tag);
        }
        _tagController.clear();
        _tagError = null;
      });
    } on FormatException {
      final invalid = candidates.firstWhere(
        (tag) => tag.trim().contains(RegExp(r'\s')),
        orElse: () => raw,
      );
      setState(() {
        _tagError = AppLocalizations.of(
          context,
        ).bangumiCollectionInvalidTag(invalid.trim());
      });
    }
  }

  void _submit() {
    if (_tagController.text.trim().isNotEmpty) {
      _addPendingTags();
      if (_tagError != null) return;
    }
    Navigator.of(context).pop(
      BangumiCollectionEditorResult(
        action: BangumiCollectionEditorAction.save,
        type: _type,
        rate: _rate,
        comment: _commentController.text,
        tags: List<String>.unmodifiable(_tags),
        private: _private,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availableSuggestions = widget.suggestedTags
        .where((tag) => !_tags.contains(tag))
        .toList(growable: false);

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surfaceTint,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.bookmark_outline_rounded, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.bangumiCollectionEditorTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                      icon: Icons.bookmark_outline_rounded,
                      label: l10n.bangumiCollectionStatus,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in LocalFavoriteType.values)
                          ChoiceChip(
                            key: ValueKey('collection-status-$type'),
                            label: Text(bangumiFavoriteStatusLabel(l10n, type)),
                            selected: _type == type,
                            showCheckmark: true,
                            onSelected: (_) => setState(() => _type = type),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _SectionLabel(
                            icon: Icons.star_outline_rounded,
                            label: l10n.bangumiCollectionRating,
                          ),
                        ),
                        Text(
                          _rate == 0
                              ? l10n.bangumiCollectionNotRated
                              : l10n.bangumiCollectionRatingValue(_rate),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _rate == 0
                                ? colors.onSurfaceVariant
                                : colors.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      key: const ValueKey('collection-rating-slider'),
                      value: _rate.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: _rate == 0
                          ? l10n.bangumiCollectionNotRated
                          : l10n.bangumiCollectionRatingValue(_rate),
                      onChanged: (value) =>
                          setState(() => _rate = value.round()),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: l10n.bangumiCollectionComment,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('collection-comment-field'),
                      controller: _commentController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 400,
                      decoration: InputDecoration(
                        hintText: l10n.bangumiCollectionCommentHint,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(
                      icon: Icons.sell_outlined,
                      label: l10n.bangumiCollectionTags,
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        key: const ValueKey('collection-selected-tags'),
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in _tags)
                            InputChip(
                              label: Text(tag),
                              onDeleted: () =>
                                  setState(() => _tags.remove(tag)),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('collection-tag-field'),
                      controller: _tagController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _addPendingTags,
                      decoration: InputDecoration(
                        hintText: l10n.bangumiCollectionTagInputHint,
                        errorText: _tagError,
                        suffixIcon: IconButton(
                          tooltip: l10n.bangumiCollectionAddTag,
                          onPressed: _addPendingTags,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ),
                    ),
                    if (availableSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.bangumiCollectionSuggestedTags,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        key: const ValueKey('collection-suggested-tags'),
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in availableSuggestions)
                            ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 16),
                              label: Text(tag),
                              onPressed: () => _addPendingTags(tag),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SwitchListTile(
                      key: const ValueKey('collection-private-switch'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.lock_outline_rounded),
                      title: Text(l10n.bangumiCollectionPrivate),
                      subtitle: Text(l10n.bangumiCollectionPrivateDescription),
                      value: _private,
                      onChanged: (value) => setState(() => _private = value),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final removeButton = widget.canRemove
                      ? TextButton.icon(
                          key: const ValueKey('collection-remove-button'),
                          onPressed: () => Navigator.of(context).pop(
                            BangumiCollectionEditorResult(
                              action: BangumiCollectionEditorAction.remove,
                              type: _type,
                              rate: _rate,
                              comment: _commentController.text,
                              tags: List<String>.unmodifiable(_tags),
                              private: _private,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(l10n.bangumiCollectionRemove),
                        )
                      : null;
                  final actions = Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        key: const ValueKey('collection-save-button'),
                        onPressed: _submit,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(l10n.bangumiCollectionSave),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 430 && removeButton != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: removeButton,
                        ),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    children: [?removeButton, const Spacer(), actions],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 19, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
