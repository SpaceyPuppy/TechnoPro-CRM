import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import 'customers_provider.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(customerListProvider),
          ),
        ],
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(customerListProvider),
        ),
        data: (customers) => customers.isEmpty
            ? const Center(child: Text('No customers found'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(customerListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => _CustomerCard(
                    customer: customers[i],
                    onTap: () => context.go('/customers/${customers[i].id}'),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/customers/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});

  final CustomerModel customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(customer.name[0].toUpperCase())),
        title: Text(customer.name),
        subtitle: Text([
          if (customer.phone != null) customer.phone!,
          if (customer.email != null) customer.email!,
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
