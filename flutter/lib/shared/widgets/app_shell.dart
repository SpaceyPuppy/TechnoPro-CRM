import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/layout_provider.dart';

// ── Destination definitions ──────────────────────────────────────────────────

typedef _Dest = ({IconData icon, IconData activeIcon, String label, String path});

const _railDestinations = <_Dest>[
  (icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard,            label: 'Dashboard',  path: '/dashboard'),
  (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number,  label: 'Tickets',    path: '/tickets'),
  (icon: Icons.people_outline,              activeIcon: Icons.people,               label: 'Customers',  path: '/customers'),
  (icon: Icons.inventory_2_outlined,        activeIcon: Icons.inventory_2,          label: 'Inventory',  path: '/inventory'),
  (icon: Icons.receipt_outlined,            activeIcon: Icons.receipt,              label: 'Invoices',   path: '/invoices'),
  (icon: Icons.settings_outlined,           activeIcon: Icons.settings,             label: 'Settings',   path: '/settings'),
];

const _phoneDestinations = <_Dest>[
  (icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard,            label: 'Dashboard',  path: '/dashboard'),
  (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number,  label: 'Tickets',    path: '/tickets'),
  (icon: Icons.people_outline,              activeIcon: Icons.people,               label: 'Customers',  path: '/customers'),
  (icon: Icons.receipt_outlined,            activeIcon: Icons.receipt,              label: 'Invoices',   path: '/invoices'),
];

const _moreItems = <_Dest>[
  (icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Inventory', path: '/inventory'),
  (icon: Icons.settings_outlined,    activeIcon: Icons.settings,    label: 'Settings',  path: '/settings'),
];

// ── Dark sidebar colour constants ────────────────────────────────────────────

const _sidebarBg        = Color(0xFF0F172A);
const _sidebarBorder    = Color(0xFF1E293B);
const _sidebarActive    = Color(0xFF1E3A8A);
const _sidebarActiveIcon = Color(0xFF93C5FD);
const _sidebarInactiveIcon = Color(0x99FFFFFF); // white 60%
const _sidebarText      = Color(0xFFFFFFFF);
const _sidebarTextDim   = Color(0x8AFFFFFF); // white 54%

// ── AppShell ─────────────────────────────────────────────────────────────────

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _railIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tickets'))   return 1;
    if (loc.startsWith('/customers')) return 2;
    if (loc.startsWith('/inventory')) return 3;
    if (loc.startsWith('/invoices'))  return 4;
    if (loc.startsWith('/settings'))  return 5;
    return 0;
  }

  int _phoneIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tickets'))   return 1;
    if (loc.startsWith('/customers')) return 2;
    if (loc.startsWith('/invoices'))  return 4;
    // inventory / settings → highlight "More" (index 4)
    if (loc.startsWith('/inventory') || loc.startsWith('/settings')) return 4;
    return 0;
  }

  Widget _wrapWithBanner(Widget content, bool isReachable) => Column(
        children: [
          if (!isReachable) const _OfflineBanner(),
          Expanded(child: content),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isTouch = ref.watch(touchModeProvider);
    final width = MediaQuery.sizeOf(context).width;
    final tier = layoutTier(width, isTouch);
    final isReachable = ref.watch(serverReachableProvider);

    return switch (tier) {
      LayoutTier.desktop => _buildDesktop(context, ref, _railIndex(context), user, isReachable),
      LayoutTier.tablet  => _buildTablet(context, ref, _railIndex(context), user, isReachable),
      LayoutTier.phone   => _buildPhone(context, ref, _phoneIndex(context), user, isReachable),
    };
  }

  // ── Desktop: extended dark sidebar ─────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            selectedIndex: selectedIndex,
            user: user,
            onDestinationSelected: (i) => context.go(_railDestinations[i].path),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: _sidebarBorder),
          Expanded(child: _wrapWithBanner(child, isReachable)),
        ],
      ),
    );
  }

  // ── Tablet: compact dark rail ───────────────────────────────────────────────

  Widget _buildTablet(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable) {
    return Scaffold(
      body: Row(
        children: [
          _TabletRail(
            selectedIndex: selectedIndex,
            user: user,
            onDestinationSelected: (i) => context.go(_railDestinations[i].path),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: _sidebarBorder),
          Expanded(child: _wrapWithBanner(child, isReachable)),
        ],
      ),
    );
  }

  // ── Phone: bottom nav + "More" bottom sheet ──────────────────────────────────

  Widget _buildPhone(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable) {
    final colorScheme = Theme.of(context).colorScheme;
    // Clamp to 0-3 for the 4 real destinations; 4 = More (not a real tab)
    final navIndex = selectedIndex > 3 ? 3 : selectedIndex;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/image/logo.png', height: 28, fit: BoxFit.contain),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: _wrapWithBanner(child, isReachable),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) {
          if (i < _phoneDestinations.length) {
            context.go(_phoneDestinations[i].path);
          } else {
            showMoreSheet(context);
          }
        },
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        destinations: [
          ..._phoneDestinations.map((d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.activeIcon),
                label: d.label,
              )),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            label: 'More',
            selectedIcon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
    );
  }
}

// ── Desktop sidebar widget ────────────────────────────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.user,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final dynamic user;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      color: _sidebarBg,
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/image/logo.png',
                height: 38,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _railDestinations.length,
              itemBuilder: (context, i) {
                final d = _railDestinations[i];
                final isSelected = i == selectedIndex;
                return _SidebarItem(
                  icon: isSelected ? d.activeIcon : d.icon,
                  label: d.label,
                  isSelected: isSelected,
                  onTap: () => onDestinationSelected(i),
                );
              },
            ),
          ),
          // Footer: user + logout
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _sidebarBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) ...[
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: _sidebarText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.role.value,
                    style: const TextStyle(color: _sidebarTextDim, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                ],
                GestureDetector(
                  onTap: onLogout,
                  child: const Row(
                    children: [
                      Icon(Icons.logout, size: 15, color: _sidebarTextDim),
                      SizedBox(width: 8),
                      Text('Sign out',
                          style: TextStyle(color: _sidebarTextDim, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? _sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          splashColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? _sidebarActiveIcon : _sidebarInactiveIcon,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? _sidebarActiveIcon : _sidebarInactiveIcon,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tablet rail ───────────────────────────────────────────────────────────────

class _TabletRail extends StatelessWidget {
  const _TabletRail({
    required this.selectedIndex,
    required this.user,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final dynamic user;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _sidebarBg,
      child: Column(
        children: [
          // Small logo at top
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset('assets/image/logo.png', height: 28, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: _railDestinations.length,
              itemBuilder: (context, i) {
                final d = _railDestinations[i];
                final isSelected = i == selectedIndex;
                return Tooltip(
                  message: d.label,
                  preferBelow: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Material(
                      color: isSelected ? _sidebarActive : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => onDestinationSelected(i),
                        borderRadius: BorderRadius.circular(8),
                        hoverColor: Colors.white.withValues(alpha: 0.06),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            isSelected ? d.activeIcon : d.icon,
                            size: 22,
                            color: isSelected ? _sidebarActiveIcon : _sidebarInactiveIcon,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              icon: const Icon(Icons.logout, size: 18),
              tooltip: 'Sign out',
              color: _sidebarTextDim,
              onPressed: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

// ── More bottom sheet ─────────────────────────────────────────────────────────

void showMoreSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'More',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ..._moreItems.map((d) => ListTile(
                leading: Icon(d.icon, color: Theme.of(context).colorScheme.primary),
                title: Text(d.label),
                onTap: () {
                  Navigator.pop(context);
                  context.go(d.path);
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 16, color: colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot reach server — check your connection',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
