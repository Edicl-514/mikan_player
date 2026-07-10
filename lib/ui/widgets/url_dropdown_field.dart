import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/base_url_list_service.dart';

/// A base-URL picker backed by a dropdown of builtin + custom URLs.
///
/// The trailing "manage" button opens a dialog where the user can add new
/// URLs and remove custom ones. Builtin URLs (from [BaseUrlListService]) are
/// always present and cannot be deleted.
///
/// [trailing] is an optional widget rendered to the right of the dropdown
/// (e.g. an "auto-select fastest" button).
class UrlDropdownField extends StatelessWidget {
  const UrlDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.kind,
    required this.allUrls,
    required this.selectedUrl,
    required this.onSelected,
    required this.onUrlsChanged,
    this.trailing,
  });

  final String label;
  final String hint;
  final BaseUrlKind kind;
  final List<String> allUrls;
  final String selectedUrl;
  final ValueChanged<String> onSelected;
  final VoidCallback onUrlsChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final effectiveSelected = allUrls.contains(selectedUrl)
        ? selectedUrl
        : (allUrls.isNotEmpty ? allUrls.first : selectedUrl);

    final dropdown = DropdownButtonFormField<String>(
      key: ValueKey(effectiveSelected),
      initialValue: allUrls.contains(effectiveSelected)
          ? effectiveSelected
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.playlist_add),
          tooltip: AppLocalizations.of(context).manageUrls,
          onPressed: () async {
            await _showManageDialog(context);
            onUrlsChanged();
          },
        ),
      ),
      items: allUrls
          .map(
            (url) => DropdownMenuItem<String>(
              value: url,
              child: Text(url, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null && value != effectiveSelected) {
          onSelected(value);
        }
      },
    );

    if (trailing == null) {
      return dropdown;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: dropdown),
        const SizedBox(width: 8),
        Padding(padding: const EdgeInsets.only(top: 4), child: trailing),
      ],
    );
  }

  Future<void> _showManageDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _UrlManageDialog(
        kind: kind,
        initialUrls: allUrls,
        selectedUrl: selectedUrl,
      ),
    );
  }
}

class _UrlManageDialog extends StatefulWidget {
  const _UrlManageDialog({
    required this.kind,
    required this.initialUrls,
    required this.selectedUrl,
  });

  final BaseUrlKind kind;
  final List<String> initialUrls;
  final String selectedUrl;

  @override
  State<_UrlManageDialog> createState() => _UrlManageDialogState();
}

class _UrlManageDialogState extends State<_UrlManageDialog> {
  late List<String> _urls;
  late final TextEditingController _addController;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.initialUrls);
    _addController = TextEditingController();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addUrl() async {
    final raw = _addController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (raw.isEmpty) return;
    final cleaned = BaseUrlListService.normalize(raw);
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.invalidUrl)));
      }
      return;
    }
    final alreadyExists = _urls.any(
      (u) => BaseUrlListService.normalize(u) == cleaned,
    );
    if (alreadyExists) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.urlAlreadyExists)));
      }
      return;
    }
    setState(() => _isBusy = true);
    try {
      final updated = await BaseUrlListService.addCustomUrl(
        widget.kind,
        cleaned,
      );
      if (mounted) {
        setState(() {
          _urls = updated;
          _addController.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _removeUrl(String url) async {
    if (BaseUrlListService.isBuiltin(widget.kind, url)) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.builtinUrlCannotRemove)));
      return;
    }
    setState(() => _isBusy = true);
    try {
      final updated = await BaseUrlListService.removeCustomUrl(
        widget.kind,
        url,
      );
      if (mounted) {
        setState(() => _urls = updated);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.manageUrlsTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _urls.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final url = _urls[index];
                  final builtin = BaseUrlListService.isBuiltin(
                    widget.kind,
                    url,
                  );
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      url,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: builtin
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.builtinUrl,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : IconButton(
                            tooltip: l10n.removeUrl,
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: _isBusy ? null : () => _removeUrl(url),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addController,
              enabled: !_isBusy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.addUrlHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.add_link),
              ),
              onSubmitted: (_) => _addUrl(),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.addUrl),
          onPressed: _isBusy ? null : _addUrl,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
