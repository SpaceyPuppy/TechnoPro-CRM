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
import '../../features/invoices/invoice_list_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoice_form_screen.dart';
import '../../shared/widgets/app_shell.dart';

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
      if (auth.isAuthenticated && isLoginRoute) return '/tickets';

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
            path: '/tickets',
            builder: (_, __) => const TicketListScreen(),
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
            builder: (_, __) => const CustomerListScreen(),
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
            builder: (_, __) => const InventoryListScreen(),
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
            path: '/invoices',
            builder: (_, __) => const InvoiceListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, state) => InvoiceFormScreen(
                  ticketId: state.uri.queryParameters['ticketId'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    InvoiceDetailScreen(id: state.pathParameters['id']!),
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
