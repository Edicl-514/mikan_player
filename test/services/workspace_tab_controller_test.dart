import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';

void main() {
  test('supports 20 tabs, activation, reorder and closing the last tab', () {
    final controller = WorkspaceTabController();
    final ids = <WorkspaceTabId>[controller.activeTabId];
    for (var i = 0; i < 19; i++) {
      ids.add(controller.create(activate: false));
    }

    expect(controller.tabs, hasLength(20));
    controller.activate(ids[10]);
    expect(controller.activeTabId, ids[10]);
    controller.reorder(10, 0);
    expect(controller.tabs.first.id, ids[10]);

    for (final id in [...ids]..remove(ids[10])) {
      controller.close(id);
    }
    expect(controller.tabs, hasLength(1));
    expect(controller.activeTabId, ids[10]);

    controller.close(ids[10]);
    expect(controller.tabs, hasLength(1));
    expect(controller.activeTab.title, 'Home');
    expect(controller.activeTab.id, isNot(ids[10]));
  });

  test('keeps independent back and forward destination history', () {
    final controller = WorkspaceTabController();
    final id = controller.activeTabId;
    controller.navigate(
      id,
      WorkspaceDestination(
        routeId: WorkspaceRouteId.allocate(),
        kind: 'one',
        title: 'One',
      ),
    );
    controller.navigate(
      id,
      WorkspaceDestination(
        routeId: WorkspaceRouteId.allocate(),
        kind: 'two',
        title: 'Two',
      ),
    );

    expect(controller.activeTab.title, 'Two');
    expect(controller.back(), isTrue);
    expect(controller.activeTab.title, 'One');
    expect(controller.activeTab.canGoForward, isTrue);
    expect(controller.forward(), isTrue);
    expect(controller.activeTab.title, 'Two');
    expect(controller.back(), isTrue);
    controller.navigate(
      id,
      WorkspaceDestination(
        routeId: WorkspaceRouteId.allocate(),
        kind: 'three',
        title: 'Three',
      ),
    );
    expect(controller.activeTab.canGoForward, isFalse);
  });

  test('close is idempotent for missing and already closing ids', () {
    final controller = WorkspaceTabController();
    const unknown = WorkspaceTabId('unknown');
    expect(controller.beginClose(unknown), isFalse);
    final id = controller.activeTabId;
    expect(controller.beginClose(id), isTrue);
    expect(controller.beginClose(id), isFalse);
    controller.completeClose(id);
    expect(controller.tabs, hasLength(1));
  });

  test('close others keeps and activates the selected tab', () {
    final controller = WorkspaceTabController();
    final keep = controller.create(activate: false);
    controller.create();

    controller.closeOthers(keep);

    expect(controller.tabs.map((tab) => tab.id), [keep]);
    expect(controller.activeTabId, keep);
  });
}
