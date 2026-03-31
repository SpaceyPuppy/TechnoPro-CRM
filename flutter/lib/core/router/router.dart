import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/tickets/ticket_list_screen.dart';
import '../../features/tickets/ticket_detail_screen.dart';
import '../../features/tickets/ticket_form_screen.dart';
import '../../features/customers/customer_list_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/inventory/inventory_list_screen.dart';
import '../../features/inventory/inventory_detail_screen.dart';
import '../../features/inventory/inventory_form_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoice_form_screen.dart';
import '../../features/invoices/finance_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/device_models_screen.dart';
import '../../features/settings/business_settings_screen.dart';
import '../../shared/widgets/adaptive_split_view.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';

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
            path: '/tickets',
            builder: (_, __) => AdaptiveSplitView(
              listBuilder: (selectedId, onSelect) =>
                  TicketListScreen(selectedId: selectedId, onSelect: onSelect),
              detailBuilder: (id) => TicketDetailScreen(id: id),
              emptyDetail: const Center(child: Text('Select a ticket', style: TextStyle(color: Colors.grey))),
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
            builder: (_, __) => AdaptiveSplitView(
              listBuilder: (selectedId, onSelect) =>
                  CustomerListScreen(selectedId: selectedId, onSelect: onSelect),
              detailBuilder: (id) => CustomerDetailScreen(id: id),
              emptyDetail: const Center(child: Text('Select a customer', style: TextStyle(color: Colors.grey))),
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
            builder: (_, __) => AdaptiveSplitView(
              listBuilder: (selectedId, onSelect) =>
                  InventoryListScreen(selectedId: selectedId, onSelect: onSelect),
              detailBuilder: (id) => InventoryDetailScreen(id: id),
              emptyDetail: const Center(child: Text('Select an item', style: TextStyle(color: Colors.grey))),
            ),
            routes: [
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
            builder: (_, __) => AdaptiveSplitView(
              listBuilder: (selectedId, onSelect) =>
                  FinanceScreen(selectedId: selectedId, onSelect: onSelect),
              detailBuilder: (id) => InvoiceDetailScreen(id: id),
              emptyDetail: const Center(child: Text('Select an invoice or quote', style: TextStyle(color: Colors.grey))),
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
