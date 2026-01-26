import 'package:flutter/material.dart';
import 'package:mikan_player/ui/screens/mobile/mobile_home_layout.dart';
import 'package:mikan_player/ui/screens/pc/pc_home_layout.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return const PcHomeLayout();
        } else {
          return const MobileHomeLayout();
        }
      },
    );
  }
}
