import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/layout_provider.dart';
import '../../core/sync/offline_mode_provider.dart' show OfflineMode, offlineModeProvider;
import '../models/enums.dart' show UserRolePermissions;

// ── Destination definitions ──────────────────────────────────────────────────

typedef _Dest = ({IconData icon, IconData activeIcon, String label, String path});

const _railDestinations = <_Dest>[
  (icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard,            label: 'Dashboard',  path: '/dashboard'),
  (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number,  label: 'Tickets',    path: '/tickets'),
  (icon: Icons.people_outline,              activeIcon: Icons.people,               label: 'Customers',  path: '/customers'),
  (icon: Icons.inventory_2_outlined,        activeIcon: Icons.inventory_2,          label: 'Inventory',  path: '/inventory'),
  (icon: Icons.local_shipping_outlined,     activeIcon: Icons.local_shipping,       label: 'Procurement',path: '/procurement'),
  (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Finance', path: '/finance'),
  (icon: Icons.settings_outlined,           activeIcon: Icons.settings,             label: 'Settings',   path: '/settings'),
];

const _phoneDestinations = <_Dest>[
  (icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard,            label: 'Dashboard',  path: '/dashboard'),
  (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number,  label: 'Tickets',    path: '/tickets'),
  (icon: Icons.people_outline,              activeIcon: Icons.people,               label: 'Customers',  path: '/customers'),
  (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Finance', path: '/finance'),
];

const _moreItems = <_Dest>[
  (icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Inventory', path: '/inventory'),
  (icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Procurement', path: '/procurement'),
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

  String _moreLabel(int selectedIndex) {
    if (selectedIndex >= 5 && selectedIndex < 5 + _moreItems.length) {
      return _moreItems[selectedIndex - 5].label;
    }
    return 'More';
  }

  IconData _moreIcon(int selectedIndex) {
    if (selectedIndex >= 5 && selectedIndex < 5 + _moreItems.length) {
      return _moreItems[selectedIndex - 5].activeIcon;
    }
    return Icons.more_horiz;
  }

  int _railIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tickets'))   return 1;
    if (loc.startsWith('/customers')) return 2;
    if (loc.startsWith('/inventory')) return 3;
    if (loc.startsWith('/procurement')) return 4;
    if (loc.startsWith('/finance') || loc.startsWith('/invoices')) return 5;
    if (loc.startsWith('/settings'))  return 6;
    return 0;
  }

  int _phoneIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tickets'))   return 1;
    if (loc.startsWith('/customers')) return 2;
    if (loc.startsWith('/finance') || loc.startsWith('/invoices')) return 3;
    // more items mapping
    if (loc.startsWith('/inventory')) return 5;
    if (loc.startsWith('/procurement')) return 6;
    if (loc.startsWith('/settings'))  return 7;
    return 0;
  }

  Widget _wrapWithBanner(Widget content, bool isReachable, WidgetRef ref) {
    final offlineMode = ref.watch(offlineModeProvider);
    final showBanner = !isReachable || offlineMode.isEnabled;
    return Column(
      children: [
        if (showBanner) _OfflineBanner(isReachable: isReachable, offlineMode: offlineMode),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isTouch = ref.watch(touchModeProvider);
    final width = MediaQuery.sizeOf(context).width;
    final tier = layoutTier(width, isTouch);
    final isReachable = ref.watch(serverReachableProvider);

    final canManage = user?.role.canManage ?? false;

    return switch (tier) {
      LayoutTier.desktop => _buildDesktop(context, ref, _railIndex(context), user, isReachable, canManage),
      LayoutTier.tablet  => _buildTablet(context, ref, _railIndex(context), user, isReachable, canManage),
      LayoutTier.phone   => _buildPhone(context, ref, _phoneIndex(context), user, isReachable, canManage),
    };
  }

  // ── Desktop: extended dark sidebar ─────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable, bool canManage) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            selectedIndex: selectedIndex,
            user: user,
            canManage: canManage,
            onDestinationSelected: (i) => context.go(_railDestinations[i].path),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: _sidebarBorder),
          Expanded(child: _wrapWithBanner(child, isReachable, ref)),
        ],
      ),
    );
  }

  // ── Tablet: compact dark rail ───────────────────────────────────────────────

  Widget _buildTablet(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable, bool canManage) {
    return Scaffold(
      body: Row(
        children: [
          _TabletRail(
            selectedIndex: selectedIndex,
            user: user,
            canManage: canManage,
            onDestinationSelected: (i) => context.go(_railDestinations[i].path),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: _sidebarBorder),
          Expanded(child: _wrapWithBanner(child, isReachable, ref)),
        ],
      ),
    );
  }

  // ── Phone: bottom nav + "More" bottom sheet ──────────────────────────────────

  Widget _buildPhone(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable, bool canManage) {
    final colorScheme = Theme.of(context).colorScheme;
    // Map selectedIndex to navIndex for NavigationBar (0-4)
    // selectedIndex 5-6 (More items) → navIndex 4 (More button)
    final navIndex = selectedIndex > 4 ? 4 : selectedIndex;
    final moreLabel = _moreLabel(selectedIndex);
    final moreIcon = _moreIcon(selectedIndex);

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
      body: _wrapWithBanner(child, isReachable, ref),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) {
          if (i < _phoneDestinations.length) {
            context.go(_phoneDestinations[i].path);
          } else {
            showMoreSheet(context, canManage: canManage);
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
            icon: Icon(moreIcon),
            label: moreLabel,
            selectedIcon: Icon(moreIcon),
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
    required this.canManage,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final dynamic user;
  final bool canManage;
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _railDestinations.length,
              itemBuilder: (context, i) {
                // Hide Settings (last item) for non-managers
                if (i == _railDestinations.length - 1 && !canManage) {
                  return const SizedBox.shrink();
                }
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
    required this.canManage,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final dynamic user;
  final bool canManage;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Container(
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: _railDestinations.length,
              itemBuilder: (context, i) {
                if (i == _railDestinations.length - 1 && !canManage) {
                  return const SizedBox.shrink();
                }
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
      ),
    );
  }
}

// ── More bottom sheet ─────────────────────────────────────────────────────────

void showMoreSheet(BuildContext context, {bool canManage = false}) {
  final items = canManage ? _moreItems : _moreItems.where((d) => d.path != '/settings').toList();
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
          ...items.map((d) => ListTile(
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
  final bool isReachable;
  final OfflineMode offlineMode;

  const _OfflineBanner({
    required this.isReachable,
    required this.offlineMode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine banner color and message based on state
    final (bannerColor, bannerMessage, bannerIcon) = switch ((isReachable, offlineMode.isEnabled)) {
      (false, _) => (
        colorScheme.errorContainer,
        'Cannot reach server — check your connection',
        Icons.cloud_off_outlined,
      ),
      (true, true) => (
        const Color(0xFF1E40AF), // Dark blue
        '📌 Offline Mode Enabled — working from cache',
        Icons.cloud_done_outlined,
      ),
      _ => (colorScheme.errorContainer, '', Icons.check),
    };

    return Material(
      color: bannerColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(bannerIcon,
                  size: 16,
                  color: isReachable ? Colors.white : colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bannerMessage,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isReachable ? Colors.white : colorScheme.onErrorContainer,
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
