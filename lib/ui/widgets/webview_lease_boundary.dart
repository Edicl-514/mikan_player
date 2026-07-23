import 'package:flutter/widgets.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/webview_resource_coordinator.dart';

/// Releases a WebView worker lease only after its widget subtree is disposed.
class WebViewLeaseBoundary extends StatefulWidget {
  const WebViewLeaseBoundary({
    super.key,
    required this.leaseId,
    required this.child,
    this.coordinator,
  });

  final WebViewWorkerLeaseId leaseId;
  final Widget child;
  final WebViewResourceCoordinator? coordinator;

  @override
  State<WebViewLeaseBoundary> createState() => _WebViewLeaseBoundaryState();
}

class _WebViewLeaseBoundaryState extends State<WebViewLeaseBoundary> {
  WebViewResourceCoordinator get _coordinator =>
      widget.coordinator ?? WebViewResourceCoordinator.instance;

  @override
  void didUpdateWidget(covariant WebViewLeaseBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leaseId != widget.leaseId) {
      (oldWidget.coordinator ?? WebViewResourceCoordinator.instance)
          .releaseLease(oldWidget.leaseId);
    }
  }

  @override
  void dispose() {
    _coordinator.releaseLease(widget.leaseId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
