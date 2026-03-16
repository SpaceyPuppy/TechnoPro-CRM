import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/layout_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    (icon: Icons.confirmation_number_outlined, label: 'Tickets', path: '/tickets'),
    (icon: Icons.people_outline, label: 'Customers', path: '/customers'),
    (icon: Icons.inventory_2_outlined, label: 'Inventory', path: '/inventory'),
    (icon: Icons.receipt_outlined, label: 'Invoices', path: '/invoices'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/customers')) return 1;
    if (location.startsWith('/inventory')) return 2;
    if (location.startsWith('/invoices')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final selectedIndex = _selectedIndex(context);
    final width = MediaQuery.sizeOf(context).width;
    final isTouch = ref.watch(touchModeProvider);
    final tier = layoutTier(width, isTouch);

    return switch (tier) {
      LayoutTier.desktop => _buildDesktop(context, ref, selectedIndex, user),
      LayoutTier.tablet => _buildTablet(context, ref, selectedIndex, user),
      LayoutTier.phone => _buildPhone(context, ref, selectedIndex, user),
    };
  }

  // --- Desktop: extended NavigationRail (sidebar-style) ---

  Widget _buildDesktop(
      BuildContext context, WidgetRef ref, int selectedIndex, dynamic user) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => context.go(_destinations[i].path),
            minExtendedWidth: 220,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
                      children: [
                        TextSpan(
                            text: 'Techno',
                            style: TextStyle(color: colorScheme.primary)),
                        TextSpan(
                            text: 'Pro',
                            style: TextStyle(color: colorScheme.onSurface)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: colorScheme.outlineVariant),
                      const SizedBox(height: 4),
                      if (user != null) ...[
                        Text(user.name,
                            style: textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        Text(user.role.value,
                            style: textTheme.labelSmall
                                ?.copyWith(color: colorScheme.outline),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                      ],
                      InkWell(
                        onTap: () => ref.read(authProvider.notifier).logout(),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.logout,
                                  size: 15, color: colorScheme.outline),
                              const SizedBox(width: 8),
                              Text('Sign out',
                                  style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.outline)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          VerticalDivider(width: 1, color: colorScheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }

  // --- Tablet: icon+label NavigationRail ---

  Widget _buildTablet(
      BuildContext context, WidgetRef ref, int selectedIndex, dynamic user) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => context.go(_destinations[i].path),
            labelType: NavigationRailLabelType.all,
            leading: const SizedBox(height: 8),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            user.name,
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Sign out',
                        onPressed: () =>
                            ref.read(authProvider.notifier).logout(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          VerticalDivider(width: 1, color: colorScheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }

  // --- Phone: AppBar + BottomNavigationBar ---

  Widget _buildPhone(
      BuildContext context, WidgetRef ref, int selectedIndex, dynamic user) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: 'Techno',
                  style: TextStyle(color: colorScheme.primary)),
              TextSpan(text: 'Pro',
                  style: TextStyle(color: colorScheme.onSurface)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}
