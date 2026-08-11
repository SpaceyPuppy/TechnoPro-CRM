import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/tickets/ticket_list_screen.dart';
import '../../features/tickets/ticket_detail_screen.dart';
import '../../features/tickets/ticket_form_screen.dart';
import '../../features/tickets/current_work_screen.dart';
import '../../features/customers/customer_list_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/inventory/inventory_list_screen.dart';
import '../../features/inventory/inventory_detail_screen.dart';
import '../../features/inventory/inventory_form_screen.dart';
import '../../features/inventory/inventory_import_screen.dart';
import '../../features/procurement/purchase_orders_list_screen.dart';
import '../../features/procurement/purchase_order_detail_screen.dart';
import '../../features/procurement/purchase_order_form_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoice_form_screen.dart';
import '../../features/invoices/finance_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/device_models_screen.dart';
import '../../features/settings/business_settings_screen.dart';
import '../../features/settings/staff_admin_screen.dart';
import '../../shared/widgets/side_panel.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../shared/models/enums.dart' show UserRolePermissions;

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(authProvider);

      // Wait for auth init
      if (auth.isLoading) return null;

      final isLoginRoute = state.matchedLocation == '/login';

      if (!auth.isAuthenticated && !isLoginRoute) return '/login';
      if (auth.isAuthenticated && isLoginRoute) return '/dashboard';

      final role = auth.user?.role;
      if (state.matchedLocation.startsWith('/finance') && !(role?.canCounter ?? false)) {
        return '/dashboard';
      }
      if (state.matchedLocation.startsWith('/settings') && !(role?.canManage ?? false)) {
        return '/dashboard';
      }
      if (state.matchedLocation.startsWith('/procurement') && !(role?.canManage ?? false)) return '/dashboard';

      return null;
    },
    refreshListenable: _AuthStateListenable(ref, authNotifier),
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/current-work',
            builder: (_, __) => const CurrentWorkScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (_, __) => SidePanelShell(
              listBuilder: (selectedId, onSelect) =>
                  TicketListScreen(selectedId: selectedId, onSelect: onSelect),
              panelBuilder: (id) => TicketDetailScreen(id: id),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const TicketFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => TicketDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => TicketFormScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/customers',
            builder: (_, __) => SidePanelShell(
              listBuilder: (selectedId, onSelect) =>
                  CustomerListScreen(selectedId: selectedId, onSelect: onSelect),
              panelBuilder: (id) => CustomerDetailScreen(id: id),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const CustomerFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    CustomerDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) =>
                        CustomerFormScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => SidePanelShell(
              listBuilder: (selectedId, onSelect) =>
                  InventoryListScreen(selectedId: selectedId, onSelect: onSelect),
              panelBuilder: (id) => InventoryDetailScreen(id: id),
            ),
            routes: [
              GoRoute(path: 'import', builder: (_, __) => const InventoryImportScreen()),
              GoRoute(
                path: 'new',
                builder: (_, __) => const InventoryFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    InventoryDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) =>
                        InventoryFormScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/finance',
            builder: (_, __) => SidePanelShell(
              listBuilder: (selectedId, onSelect) =>
                  FinanceScreen(selectedId: selectedId, onSelect: onSelect),
              panelBuilder: (id) => InvoiceDetailScreen(id: id),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, state) => InvoiceFormScreen(
                  ticketId: state.uri.queryParameters['ticketId'],
                  isQuote: state.uri.queryParameters['type'] == 'quote',
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    InvoiceDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/procurement', builder: (_, __) => const PurchaseOrdersListScreen(), routes: [GoRoute(path: 'new', builder: (_, __) => const PurchaseOrderFormScreen()), GoRoute(path: ':id', builder: (_, state) => PurchaseOrderDetailScreen(id: state.pathParameters['id']!))]),
          // Legacy /invoices redirect for ticket-linked invoice creation
          GoRoute(
            path: '/invoices',
            redirect: (_, state) => '/finance',
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'business',
                builder: (_, __) => const BusinessSettingsScreen(),
              ),
              GoRoute(
                path: 'device-models',
                builder: (_, __) => const DeviceModelsScreen(),
              ),
              GoRoute(
                path: 'staff',
                builder: (_, __) => const StaffAdminScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth state changes into a Listenable for GoRouter.refresh
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref, AuthNotifier notifier) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
