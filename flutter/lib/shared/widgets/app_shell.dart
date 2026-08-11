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
  (icon: Icons.timer_outlined,              activeIcon: Icons.timer,                label: 'Current work', path: '/current-work'),
  (icon: Icons.people_outline,              activeIcon: Icons.people,               label: 'Customers',  path: '/customers'),
  (icon: Icons.inventory_2_outlined,        activeIcon: Icons.inventory_2,          label: 'Inventory',  path: '/inventory'),
  (icon: Icons.local_shipping_outlined,      activeIcon: Icons.local_shipping,        label: 'Procurement', path: '/procurement'),
  (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Finance', path: '/finance'),
  (icon: Icons.settings_outlined,           activeIcon: Icons.settings,             label: 'Settings',   path: '/settings'),
];

const _phoneDestinations = <_Dest>[
  (icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard,            label: 'Dashboard',  path: '/dashboard'),
  (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number,  label: 'Tickets',    path: '/tickets'),
  (icon: Icons.inventory_2_outlined,        activeIcon: Icons.inventory_2,          label: 'Stock',      path: '/inventory'),
];

const _moreItems = <_Dest>[
  (icon: Icons.timer_outlined,        activeIcon: Icons.timer,        label: 'Current work', path: '/current-work'),
  (icon: Icons.people_outline,       activeIcon: Icons.people,       label: 'Customers', path: '/customers'),
  (icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Procurement', path: '/procurement'),
  (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Finance', path: '/finance'),
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
    return 'More';
  }

  IconData _moreIcon(int selectedIndex) {
    return Icons.more_horiz;
  }

  int _railIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tickets'))   return 1;
    if (loc.startsWith('/current-work')) return 2;
    if (loc.startsWith('/customers')) return 3;
    if (loc.startsWith('/inventory')) return 4;
    if (loc.startsWith('/procurement')) return 5;
    if (loc.startsWith('/finance') || loc.startsWith('/invoices')) return 6;
    if (loc.startsWith('/settings'))  return 7;
    return 0;
  }

  int _phoneIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tickets'))   return 1;
    if (loc.startsWith('/inventory')) return 3;
    // more items mapping
    if (loc.startsWith('/current-work')) return 4;
    if (loc.startsWith('/finance') || loc.startsWith('/invoices')) return 4;
    if (loc.startsWith('/customers')) return 4;
    if (loc.startsWith('/procurement')) return 4;
    if (loc.startsWith('/settings'))  return 4;
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
    final canCounter = user?.role.canCounter ?? false;

    return switch (tier) {
      LayoutTier.desktop => _buildDesktop(context, ref, _railIndex(context), user, isReachable, canManage, canCounter),
      LayoutTier.tablet  => _buildTablet(context, ref, _railIndex(context), user, isReachable, canManage, canCounter),
      LayoutTier.phone   => _buildPhone(context, ref, _phoneIndex(context), user, isReachable, canManage, canCounter),
    };
  }

  // ── Desktop: extended dark sidebar ─────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable, bool canManage, bool canCounter) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            selectedIndex: selectedIndex,
            user: user,
            canManage: canManage,
            canCounter: canCounter,
            onDestinationSelected: (i) => context.go(_railDestinations[i].path),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: _sidebarBorder),
          Expanded(child: _wrapWithBanner(_RouteLineage(child: child), isReachable, ref)),
        ],
      ),
    );
  }

  // ── Tablet: compact dark rail ───────────────────────────────────────────────

  Widget _buildTablet(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable, bool canManage, bool canCounter) {
    return Scaffold(
      body: Row(
        children: [
          _TabletRail(
            selectedIndex: selectedIndex,
            user: user,
            canManage: canManage,
            canCounter: canCounter,
            onDestinationSelected: (i) => context.go(_railDestinations[i].path),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: _sidebarBorder),
          Expanded(child: _wrapWithBanner(_RouteLineage(child: child), isReachable, ref)),
        ],
      ),
    );
  }

  // ── Phone: bottom nav + "More" bottom sheet ──────────────────────────────────

  Widget _buildPhone(BuildContext context, WidgetRef ref, int selectedIndex, dynamic user, bool isReachable, bool canManage, bool canCounter) {
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
      bottomNavigationBar: _PhoneGlassNavigation(
        selectedIndex: selectedIndex,
        moreLabel: moreLabel,
        moreIcon: moreIcon,
        onDestinationSelected: (index) => context.go(_phoneDestinations[index].path),
        onCreate: () => showCreateSheet(context, canManage: canManage),
        onMore: () => showMoreSheet(context, canManage: canManage, canCounter: canCounter),
      ),
    );
  }
}

// ── Desktop sidebar widget ────────────────────────────────────────────────────

class _RouteLineage extends StatelessWidget {
  const _RouteLineage({required this.child});
  final Widget child;

  String _section(String location) {
    if (location.startsWith('/tickets')) return 'Tickets';
    if (location.startsWith('/customers')) return 'Customers';
    if (location.startsWith('/inventory')) return 'Inventory';
    if (location.startsWith('/procurement')) return 'Purchase orders';
    if (location.startsWith('/finance') || location.startsWith('/invoices')) return 'Finance';
    if (location.startsWith('/current-work')) return 'Current work';
    if (location.startsWith('/settings')) return 'Settings';
    return 'Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).matchedLocation;
    final section = _section(location);
    final detail = location.endsWith('/new') ? 'Create' : location.endsWith('/edit') ? 'Edit' : null;
    return Column(
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          color: colors.surfaceContainerLow.withValues(alpha: .72),
          child: Text('Workspace  /  $section${detail == null ? '' : '  /  $detail'}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant)),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _PhoneGlassNavigation extends StatelessWidget {
  const _PhoneGlassNavigation({
    required this.selectedIndex,
    required this.moreLabel,
    required this.moreIcon,
    required this.onDestinationSelected,
    required this.onCreate,
    required this.onMore,
  });

  final int selectedIndex;
  final String moreLabel;
  final IconData moreIcon;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreate;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .16), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PhoneDestinationButton(destination: _phoneDestinations[0], selected: selectedIndex == 0, onTap: () => onDestinationSelected(0)),
            _PhoneDestinationButton(destination: _phoneDestinations[1], selected: selectedIndex == 1, onTap: () => onDestinationSelected(1)),
            Semantics(
              button: true,
              label: 'Create',
              child: Transform.translate(
                offset: const Offset(0, -12),
                child: FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(minimumSize: const Size(52, 52), padding: EdgeInsets.zero, shape: const CircleBorder(), elevation: 6),
                  child: const Icon(Icons.add, size: 25),
                ),
              ),
            ),
            _PhoneDestinationButton(destination: _phoneDestinations[2], selected: selectedIndex == 3, onTap: () => onDestinationSelected(2)),
            _PhoneDestinationButton(destination: (icon: moreIcon, activeIcon: moreIcon, label: moreLabel, path: ''), selected: selectedIndex == 4, onTap: onMore),
          ],
        ),
      ),
    );
  }
}

class _PhoneDestinationButton extends StatelessWidget {
  const _PhoneDestinationButton({required this.destination, required this.selected, required this.onTap});
  final _Dest destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? destination.activeIcon : destination.icon, size: 20, color: selected ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(destination.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: selected ? colors.primary : colors.onSurfaceVariant, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.user,
    required this.canManage,
    required this.canCounter,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final dynamic user;
  final bool canManage;
  final bool canCounter;
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
                if (_railDestinations[i].path == '/finance' && !canCounter) {
                  return const SizedBox.shrink();
                }
                final d = _railDestinations[i];
                final isSelected = i == selectedIndex;
                final item = _SidebarItem(
                  icon: isSelected ? d.activeIcon : d.icon,
                  label: d.label,
                  isSelected: isSelected,
                  onTap: () => onDestinationSelected(i),
                );
                if (d.path != '/inventory' || !canManage) return item;
                return Column(
                  children: [
                    item,
                    Padding(
                      padding: const EdgeInsets.only(left: 38, right: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => context.go('/procurement'),
                              style: TextButton.styleFrom(foregroundColor: _sidebarTextDim, padding: const EdgeInsets.symmetric(horizontal: 8)),
                              child: const Text('Purchase orders', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.go('/procurement/new'),
                            tooltip: 'Create purchase order',
                            color: _sidebarActiveIcon,
                            iconSize: 18,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
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
    required this.canCounter,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final dynamic user;
  final bool canManage;
  final bool canCounter;
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
                if (_railDestinations[i].path == '/finance' && !canCounter) {
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

void showCreateSheet(BuildContext context, {required bool canManage}) {
  final actions = <_Dest>[
    (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number, label: 'New ticket', path: '/tickets/new'),
    (icon: Icons.person_add_alt_1_outlined, activeIcon: Icons.person_add_alt_1, label: 'New customer', path: '/customers/new'),
    if (canManage) (icon: Icons.add_shopping_cart_outlined, activeIcon: Icons.add_shopping_cart, label: 'New purchase order', path: '/procurement/new'),
    (icon: Icons.play_circle_outline, activeIcon: Icons.play_circle, label: 'Start timer', path: '/current-work'),
  ];
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...actions.map((action) => ListTile(
              leading: Icon(action.icon, color: Theme.of(context).colorScheme.primary),
              title: Text(action.label),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onTap: () {
                Navigator.pop(context);
                context.go(action.path);
              },
            )),
          ],
        ),
      ),
    ),
  );
}

void showMoreSheet(BuildContext context, {bool canManage = false, bool canCounter = false}) {
  final items = _moreItems.where((d) {
    if (d.path == '/settings') return canManage;
    if (d.path == '/procurement') return canManage;
    if (d.path == '/finance') return canCounter;
    return true;
  }).toList();
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
