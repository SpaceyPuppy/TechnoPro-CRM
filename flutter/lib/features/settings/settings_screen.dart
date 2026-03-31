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
            leading: Icon(Icons.business_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Business & Tax'),
            subtitle: const Text('Business details, ABN, GST rate'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/business'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.phone_android_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Device Models'),
            subtitle: const Text('Manage phone and tablet model lookup list'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/device-models'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Offline & Sync'),
            subtitle: const Text('Connection status, sync, and offline mode'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/offline-sync'),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
