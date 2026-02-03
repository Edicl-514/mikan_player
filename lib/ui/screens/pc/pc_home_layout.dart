import 'package:flutter/material.dart';
import 'package:mikan_player/ui/pages/index_page.dart';
import 'package:mikan_player/ui/pages/my_page.dart';
import 'package:mikan_player/ui/pages/ranking_page.dart';
import 'package:mikan_player/ui/pages/timetable_page.dart';
import 'package:mikan_player/services/user_manager.dart';

class PcHomeLayout extends StatefulWidget {
  const PcHomeLayout({super.key});

  @override
  State<PcHomeLayout> createState() => _PcHomeLayoutState();
}

class _PcHomeLayoutState extends State<PcHomeLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    TimeTablePage(),
    RankingPage(),
    IndexPage(),
    MyPage(),
  ];

  final List<String> _titles = const [
    'TimeTable',
    'Ranking',
    'Index',
    'My Profile',
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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: Text('Schedule'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard),
                label: Text('Ranking'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Index'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('My'),
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
                        _titles[_selectedIndex],
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      // Search Icon
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.search),
                        tooltip: 'Search Anime',
                      ),
                      const SizedBox(width: 8),
                      // User Avatar
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: _userManager.isLoggedIn
                            ? NetworkImage(_userManager.user!.avatar.medium)
                            : null,
                        child: !_userManager.isLoggedIn
                            ? const Icon(Icons.person, size: 20)
                            : null,
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
