import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/home_pc_page.dart';
import 'package:mikan_player/ui/pages/index_page.dart';
import 'package:mikan_player/ui/pages/my_page.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/ui/widgets/network_avatar.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';

class PcHomeLayout extends StatefulWidget {
  const PcHomeLayout({super.key});

  @override
  State<PcHomeLayout> createState() => _PcHomeLayoutState();
}

class _PcHomeLayoutState extends State<PcHomeLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [HomePcPage(), IndexPage(), MyPage()];

  List<String> _titles(BuildContext context) => [
    AppLocalizations.of(context).navHome,
    AppLocalizations.of(context).navIndex,
    AppLocalizations.of(context).navMy,
  ];

  final UserManager _userManager = UserManager();

  @override
  void initState() {
    super.initState();
    _userManager.addListener(_onUserUpdate);
  }

  @override
  void dispose() {
    _userManager.removeListener(_onUserUpdate);
    super.dispose();
  }

  void _onUserUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.play_arrow, color: Colors.white),
              ),
            ),
            groupAlignment: -0.9,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: Text(AppLocalizations.of(context).navHome),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.category_outlined),
                selectedIcon: const Icon(Icons.category),
                label: Text(AppLocalizations.of(context).navIndex),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: Text(AppLocalizations.of(context).navMy),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                // Custom Top Bar for Search and Title
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    children: [
                      Text(
                        _titles(context)[_selectedIndex],
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      // Search Icon
                      IconButton(
                        onPressed: () => WorkspaceNavigation.open<void>(
                          context,
                          WorkspaceDestinations.search(context),
                        ),
                        icon: const Icon(Icons.search),
                        tooltip: AppLocalizations.of(context).searchHint,
                      ),
                      const SizedBox(width: 8),
                      // User Avatar
                      NetworkAvatar(
                        imageUrl: _userManager.isLoggedIn
                            ? _userManager.user!.avatar.medium
                            : null,
                        radius: 16,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        fallback: const Icon(Icons.person, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: _pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
