import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

class BangumiCollectionConflictPanel extends StatelessWidget {
  const BangumiCollectionConflictPanel({
    super.key,
    required this.conflicts,
    required this.choices,
    required this.statusLabel,
    required this.onChoiceChanged,
    required this.onResolve,
    required this.isResolving,
  });

  final List<BangumiCollectionConflict> conflicts;
  final Map<int, BangumiCollectionConflictChoice> choices;
  final String Function(int type) statusLabel;
  final void Function(int subjectId, BangumiCollectionConflictChoice choice)
  onChoiceChanged;
  final VoidCallback? onResolve;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
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
                        l10n.collectionConflictDescription(conflicts.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: choices.length == conflicts.length && !isResolving
                      ? onResolve
                      : null,
                  icon: isResolving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(l10n.collectionResolveConflicts),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: conflicts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ConflictComparison(
                conflict: conflicts[index],
                choice: choices[conflicts[index].local.bangumiId],
                statusLabel: statusLabel,
                onChanged: (choice) =>
                    onChoiceChanged(conflicts[index].local.bangumiId, choice),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictComparison extends StatelessWidget {
  const _ConflictComparison({
    required this.conflict,
    required this.choice,
    required this.statusLabel,
    required this.onChanged,
  });

  final BangumiCollectionConflict conflict;
  final BangumiCollectionConflictChoice? choice;
  final String Function(int type) statusLabel;
  final ValueChanged<BangumiCollectionConflictChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subject = conflict.bangumi.subject;
    final title = subject.nameCn.isNotEmpty
        ? subject.nameCn
        : (subject.name.isNotEmpty ? subject.name : conflict.local.title);
    final cover = subject.images.large.isNotEmpty
        ? subject.images.large
        : conflict.local.coverUrl;
    final localDate = DateTime.fromMillisecondsSinceEpoch(
      conflict.local.createdAt,
    );
    final remoteDate = DateTime.tryParse(conflict.bangumi.date);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 44,
                    height: 60,
                    child: CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: const ColoredBox(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final local = _ChoicePane(
                  selected: choice == BangumiCollectionConflictChoice.local,
                  title: l10n.collectionKeepLocal,
                  source: l10n.collectionSourceLocal,
                  status: statusLabel(conflict.local.type),
                  updatedAt: _formatDate(localDate),
                  onTap: () => onChanged(BangumiCollectionConflictChoice.local),
                );
                final remote = _ChoicePane(
                  selected: choice == BangumiCollectionConflictChoice.bangumi,
                  title: l10n.collectionKeepBangumi,
                  source: 'Bangumi',
                  status: statusLabel(conflict.bangumi.type),
                  updatedAt: remoteDate == null ? '-' : _formatDate(remoteDate),
                  onTap: () =>
                      onChanged(BangumiCollectionConflictChoice.bangumi),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    children: [local, const SizedBox(height: 8), remote],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: local),
                    const SizedBox(width: 8),
                    Expanded(child: remote),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
}

class _ChoicePane extends StatelessWidget {
  const _ChoicePane({
    required this.selected,
    required this.title,
    required this.source,
    required this.status,
    required this.updatedAt,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String source;
  final String status;
  final String updatedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<bool>(
                groupValue: selected,
                onChanged: (_) => onTap(),
                child: const Radio<bool>(value: true),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(source),
                    Text('${l10n.collectionConflictStatus}: $status'),
                    Text('${l10n.collectionConflictUpdated}: $updatedAt'),
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
