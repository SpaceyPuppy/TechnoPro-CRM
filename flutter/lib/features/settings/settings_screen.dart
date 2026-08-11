import 'package:flutter/material.dart';
import '../../shared/widgets/prism_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/models/enums.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authProvider).user?.role == UserRole.admin;
    return Scaffold(
      appBar: const PrismAppBar(title: Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          PrismSectionLabel(
            title: 'Workspace',
            subtitle: 'Configure the way your operation runs',
          ),
          PrismSurface(
            radius: 26,
            child: Column(children: [
          ListTile(
            leading: Icon(Icons.business_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Business & Tax'),
            subtitle: const Text('Business details, ABN, GST rate'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/business'),
          ),
          const Divider(height: 1),
          if (isAdmin) ...[
            ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Staff Administration'),
              subtitle: const Text('Accounts, roles, passwords and access'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/staff'),
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: Icon(Icons.phone_android_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Device Models'),
            subtitle: const Text('Manage phone and tablet model lookup list'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/device-models'),
          ),
          const Divider(height: 1),
            ]),
          ),
        ],
      ),
    );
  }
}
