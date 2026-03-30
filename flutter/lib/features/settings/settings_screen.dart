import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.phone_android_outlined),
            title: const Text('Device Models'),
            subtitle: const Text('Manage phone and tablet model lookup list'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/device-models'),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
