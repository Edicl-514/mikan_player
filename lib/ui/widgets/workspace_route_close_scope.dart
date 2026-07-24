import 'dart:async';

import 'package:flutter/material.dart';

/// Defers a route pop until its asynchronous owner cleanup has completed.
class WorkspaceRouteCloseScope<T> extends StatefulWidget {
  const WorkspaceRouteCloseScope({
    super.key,
    required this.prepareToClose,
    required this.child,
  });

  final FutureOr<void> Function() prepareToClose;
  final Widget child;

  @override
  State<WorkspaceRouteCloseScope<T>> createState() =>
      _WorkspaceRouteCloseScopeState<T>();
}

class _WorkspaceRouteCloseScopeState<T>
    extends State<WorkspaceRouteCloseScope<T>> {
  bool _allowPop = false;
  bool _preparing = false;

  @override
  Widget build(BuildContext context) {
    return PopScope<T>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _preparing) return;
        final navigator = Navigator.of(context);
        _preparing = true;
        await widget.prepareToClose();
        if (!mounted || !navigator.mounted) return;
        setState(() => _allowPop = true);
        navigator.pop<T>(result);
      },
      child: widget.child,
    );
  }
}
