import 'package:flutter/material.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Header
        UserAccountsDrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          accountName: Text(
            "Otaku User",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          accountEmail: Text(
            "user@example.com",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          currentAccountPicture: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 40),
          ),
        ),
        const SizedBox(height: 16),
        _buildTile(
          context,
          Icons.download,
          'Downloads',
          'Manage cached episodes',
        ),
        _buildTile(context, Icons.history, 'History', 'Continue watching'),
        _buildTile(
          context,
          Icons.favorite,
          'Favorites',
          'Your collected anime',
        ),
        const Divider(),
        _buildTile(context, Icons.settings, 'Settings', 'App configuration'),
        _buildTile(context, Icons.info, 'About', 'Version 1.0.0'),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
