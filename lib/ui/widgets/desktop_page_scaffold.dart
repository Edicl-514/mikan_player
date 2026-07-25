import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';

/// A page scaffold that drops its own header where the desktop shell draws one.
///
/// Mobile keeps the exact `Scaffold` + `AppBar` it had before. On a hosted
/// desktop page the `AppBar` is gone and the header's remaining business
/// content moves into the body: [desktopActionRow] when the page supplies one,
/// otherwise [actions] wrapped in a default [DesktopPageActionRow], followed by
/// [appBarBottom] (a `TabBar` and friends), then [body].
///
/// Pages that need the row pinned inside their own scroll view should pass
/// `desktopActionRow: null` and place a [DesktopPagePinnedActionRow] sliver
/// themselves.
class DesktopPageScaffold extends StatelessWidget {
  const DesktopPageScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.appBarBottom,
    this.desktopActionRow,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  /// Mobile `AppBar` title. Desktop takes the title from the tab metadata.
  final Widget? title;

  /// Mobile `AppBar` actions, reused as the default desktop action row.
  final List<Widget>? actions;

  /// Header content below the title on both platforms (`TabBar`, filters).
  final PreferredSizeWidget? appBarBottom;

  /// Desktop replacement for the header's business actions.
  final Widget? desktopActionRow;

  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    if (!DesktopPageChromeScope.hostsPageHeader(context)) {
      return Scaffold(
        appBar: AppBar(title: title, actions: actions, bottom: appBarBottom),
        body: body,
        floatingActionButton: floatingActionButton,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      );
    }

    final actionRow =
        desktopActionRow ??
        (actions == null || actions!.isEmpty
            ? null
            : DesktopPageActionRow(children: actions!));

    return Scaffold(
      body: Column(
        children: [
          ?actionRow,
          ?appBarBottom,
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// The first row of a desktop page's content, carrying the actions its former
/// `AppBar` owned.
///
/// Keeping them here instead of in the shell's toolbar leaves the tab title
/// room to breathe and keeps each control next to what it acts on.
class DesktopPageActionRow extends StatelessWidget {
  const DesktopPageActionRow({
    super.key,
    required this.children,
    this.leading,
    this.padding = DesktopPageMetrics.actionRowPadding,
    this.showDivider = true,
  });

  /// Trailing controls, laid out end-aligned.
  final List<Widget> children;

  /// Optional start-aligned content (a search field, a segmented control).
  final Widget? leading;

  final EdgeInsetsGeometry padding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              )
            : null,
      ),
      // The row's own padding counts toward its height, so a page that swaps a
      // plain row for a taller one changes the content offset by exactly the
      // difference and nothing else.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: DesktopPageMetrics.actionRowHeight,
        ),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null)
                Expanded(child: leading!)
              else
                const Spacer(),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A [DesktopPageActionRow] that stays visible while a scroll view moves under
/// it.
///
/// Use inside `CustomScrollView.slivers` for pages whose action row must not
/// scroll away (search input, date tabs, save buttons).
class DesktopPagePinnedActionRow extends StatelessWidget {
  const DesktopPagePinnedActionRow({
    super.key,
    required this.child,
    this.height = DesktopPageMetrics.actionRowHeight,
  });

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _PinnedActionRowDelegate(height: height, child: child),
  );
}

class _PinnedActionRowDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedActionRowDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SizedBox(height: height, child: child),
  );

  @override
  bool shouldRebuild(_PinnedActionRowDelegate oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}
