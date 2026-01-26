import 'package:flutter/material.dart';
import 'package:mikan_player/ui/pages/index_page.dart';
import 'package:mikan_player/ui/pages/my_page.dart';
import 'package:mikan_player/ui/pages/ranking_page.dart';
import 'package:mikan_player/ui/pages/timetable_page.dart';

class MobileHomeLayout extends StatefulWidget {
  const MobileHomeLayout({super.key});

  @override
  State<MobileHomeLayout> createState() => _MobileHomeLayoutState();
}

class _MobileHomeLayoutState extends State<MobileHomeLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    TimeTablePage(),
    RankingPage(),
    IndexPage(),
    MyPage(),
  ];

  final List<String> _titles = const [
    'Schedule',
    'Ranking',
    'Anime Index',
    'My Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Index',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'My',
          ),
        ],
      ),
    );
  }
}
