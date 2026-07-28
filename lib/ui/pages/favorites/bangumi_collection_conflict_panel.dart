import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/bangumi_collection_merge.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Field-level conflict resolution panel.
///
/// Shows one conflict at a time (paginated). For each conflicting field,
/// displays local/remote values and lets the user pick which side to keep.
class BangumiCollectionConflictPanel extends StatefulWidget {
  const BangumiCollectionConflictPanel({
    super.key,
    required this.conflicts,
    required this.statusLabel,
    required this.onResolve,
    required this.isResolving,
  });

  final List<BangumiCollectionConflict> conflicts;
  final String Function(int type) statusLabel;
  final Future<void> Function(Map<int, BangumiCollectionResolution>) onResolve;
  final bool isResolving;

  @override
  State<BangumiCollectionConflictPanel> createState() =>
      _BangumiCollectionConflictPanelState();
}

class _BangumiCollectionConflictPanelState
    extends State<BangumiCollectionConflictPanel> {
  final Map<int, BangumiCollectionResolution> _resolutions = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeDefaultResolutions();
  }

  void _initializeDefaultResolutions() {
    for (final conflict in widget.conflicts) {
      final fieldChoices = <BangumiCollectionField, MergeSide>{};
      for (final field in conflict.fields) {
        fieldChoices[field.field] = MergeSide.local;
      }
      _resolutions[conflict.subjectId] = BangumiCollectionResolution(
        fields: fieldChoices,
        remoteDeleted:
            conflict.isRemoteDeleted ? MergeSide.local : null,
      );
    }
  }

  void _setFieldChoice(
    int subjectId,
    BangumiCollectionField field,
    MergeSide side,
  ) {
    setState(() {
      final current = _resolutions[subjectId];
      if (current == null) return;
      final updated = Map<BangumiCollectionField, MergeSide>.from(
        current.fields,
      )
        ..[field] = side;
      _resolutions[subjectId] = BangumiCollectionResolution(
        fields: updated,
        remoteDeleted: current.remoteDeleted,
      );
    });
  }

  void _setRemoteDeletedChoice(int subjectId, MergeSide side) {
    setState(() {
      final current = _resolutions[subjectId];
      if (current == null) return;
      _resolutions[subjectId] = BangumiCollectionResolution(
        fields: current.fields,
        remoteDeleted: side,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final conflict = widget.conflicts[_currentIndex];

    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Icon(Icons.compare_arrows, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.collectionConflictTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.collectionConflictIndex(
                          _currentIndex + 1,
                          widget.conflicts.length,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _ConflictDetail(
                conflict: conflict,
                resolution: _resolutions[conflict.subjectId]!,
                statusLabel: widget.statusLabel,
                onFieldChoiceChanged: (field, side) =>
                    _setFieldChoice(conflict.subjectId, field, side),
                onRemoteDeletedChoiceChanged: (side) =>
                    _setRemoteDeletedChoice(conflict.subjectId, side),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  OutlinedButton.icon(
                    onPressed: widget.isResolving
                        ? null
                        : () => setState(() => _currentIndex--),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(l10n.collectionConflictResolvePrevious),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: widget.isResolving
                      ? null
                      : () {
                          if (_currentIndex < widget.conflicts.length - 1) {
                            setState(() => _currentIndex++);
                          } else {
                            widget.onResolve(_resolutions);
                          }
                        },
                  icon: widget.isResolving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _currentIndex < widget.conflicts.length - 1
                              ? Icons.chevron_right
                              : Icons.sync,
                        ),
                  label: Text(
                    _currentIndex < widget.conflicts.length - 1
                        ? l10n.collectionConflictResolveNext
                        : l10n.collectionResolveConflicts,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictDetail extends StatelessWidget {
  const _ConflictDetail({
    required this.conflict,
    required this.resolution,
    required this.statusLabel,
    required this.onFieldChoiceChanged,
    required this.onRemoteDeletedChoiceChanged,
  });

  final BangumiCollectionConflict conflict;
  final BangumiCollectionResolution resolution;
  final String Function(int type) statusLabel;
  final void Function(BangumiCollectionField, MergeSide) onFieldChoiceChanged;
  final void Function(MergeSide) onRemoteDeletedChoiceChanged;

  @override
  Widget build(BuildContext context) {
    final remoteEntry = conflict.bangumi;
    final subject = remoteEntry?.subject;
    final title = switch (subject) {
      null => conflict.local.title,
      final s when s.nameCn.isNotEmpty => s.nameCn,
      final s when s.name.isNotEmpty => s.name,
      _ => conflict.local.title,
    };
    final cover = subject != null && subject.images.large.isNotEmpty
        ? subject.images.large
        : conflict.local.coverUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 80,
                child: CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  errorWidget: const ColoredBox(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (conflict.isRemoteDeleted)
          _RemoteDeletedField(
            resolution: resolution,
            onChanged: onRemoteDeletedChoiceChanged,
          )
        else
          ...conflict.fields.map((fieldConflict) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _FieldRow(
                  conflict: conflict,
                  fieldConflict: fieldConflict,
                  choice: resolution.fields[fieldConflict.field]!,
                  statusLabel: statusLabel,
                  onChanged: (side) =>
                      onFieldChoiceChanged(fieldConflict.field, side),
                ),
              )),
      ],
    );
  }
}

class _RemoteDeletedField extends StatelessWidget {
  const _RemoteDeletedField({
    required this.resolution,
    required this.onChanged,
  });

  final BangumiCollectionResolution resolution;
  final ValueChanged<MergeSide> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final choice = resolution.remoteDeleted ?? MergeSide.local;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: colors.error),
                const SizedBox(width: 8),
                Text(
                  l10n.collectionConflictRemoteDeleted,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.error,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ChoiceRadio(
              selected: choice == MergeSide.local,
              label: l10n.collectionKeepLocal,
              subtitle: l10n.collectionConflictReupload,
              onTap: () => onChanged(MergeSide.local),
            ),
            const SizedBox(height: 8),
            _ChoiceRadio(
              selected: choice == MergeSide.remote,
              label: l10n.collectionKeepBangumi,
              subtitle: l10n.collectionConflictDeleteLocal,
              onTap: () => onChanged(MergeSide.remote),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.conflict,
    required this.fieldConflict,
    required this.choice,
    required this.statusLabel,
    required this.onChanged,
  });

  final BangumiCollectionConflict conflict;
  final BangumiCollectionFieldConflict fieldConflict;
  final MergeSide choice;
  final String Function(int type) statusLabel;
  final ValueChanged<MergeSide> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fieldLabel(l10n, fieldConflict.field),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _ChoiceRadio(
              selected: choice == MergeSide.local,
              label: l10n.collectionKeepLocal,
              subtitle: _formatFieldValue(
                l10n,
                fieldConflict.field,
                fieldConflict.localValue,
                statusLabel,
              ),
              onTap: () => onChanged(MergeSide.local),
            ),
            const SizedBox(height: 8),
            _ChoiceRadio(
              selected: choice == MergeSide.remote,
              label: l10n.collectionKeepBangumi,
              subtitle: _formatFieldValue(
                l10n,
                fieldConflict.field,
                fieldConflict.remoteValue,
                statusLabel,
              ),
              onTap: () => onChanged(MergeSide.remote),
            ),
          ],
        ),
      ),
    );
  }

  String _fieldLabel(AppLocalizations l10n, BangumiCollectionField field) {
    return switch (field) {
      BangumiCollectionField.status => l10n.collectionConflictFieldStatus,
      BangumiCollectionField.rate => l10n.collectionConflictFieldRate,
      BangumiCollectionField.comment => l10n.collectionConflictFieldComment,
      BangumiCollectionField.tags => l10n.collectionConflictFieldTags,
      BangumiCollectionField.private => l10n.collectionConflictFieldPrivate,
    };
  }

  String _formatFieldValue(
    AppLocalizations l10n,
    BangumiCollectionField field,
    Object? value,
    String Function(int) statusLabel,
  ) {
    return switch (field) {
      BangumiCollectionField.status => statusLabel(value as int),
      BangumiCollectionField.rate => _formatRate(l10n, value as int?),
      BangumiCollectionField.comment =>
        _formatComment(l10n, value as String?),
      BangumiCollectionField.tags => _formatTags(l10n, value as List<String>?),
      BangumiCollectionField.private => _formatPrivate(l10n, value as bool?),
    };
  }

  String _formatRate(AppLocalizations l10n, int? rate) {
    if (rate == null || rate == 0) return l10n.collectionConflictNotSet;
    return l10n.bangumiCollectionRatingValue(rate);
  }

  String _formatComment(AppLocalizations l10n, String? comment) {
    if (comment == null || comment.isEmpty) {
      return l10n.collectionConflictEmpty;
    }
    if (comment.length <= 60) return comment;
    return '${comment.substring(0, 60)}...';
  }

  String _formatTags(AppLocalizations l10n, List<String>? tags) {
    if (tags == null || tags.isEmpty) return l10n.collectionConflictEmpty;
    final joined = tags.join(', ');
    if (joined.length <= 60) return joined;
    return '${joined.substring(0, 60)}...';
  }

  String _formatPrivate(AppLocalizations l10n, bool? isPrivate) {
    if (isPrivate == null) return l10n.collectionConflictNotSet;
    return isPrivate
        ? l10n.collectionConflictPrivateYes
        : l10n.collectionConflictPrivateNo;
  }
}

class _ChoiceRadio extends StatelessWidget {
  const _ChoiceRadio({
    required this.selected,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
