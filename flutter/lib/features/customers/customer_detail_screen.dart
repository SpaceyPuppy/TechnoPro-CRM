import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import 'customers_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(id));
    final ticketsAsync = ref.watch(customerTicketsProvider(id));

    return customerAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      data: (customer) => _CustomerDetailView(customer: customer, id: id),
    );
  }
}

class _CustomerDetailView extends ConsumerWidget {
  const _CustomerDetailView({required this.customer, required this.id});

  final CustomerModel customer;
  final String id;

  void _deleteCustomer(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete ${customer.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dio = ref.read(apiClientProvider);
                await dio.delete('/customers/$id');
                if (context.mounted) context.go('/customers');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(customerTicketsProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/customers/$id/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: () => _deleteCustomer(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(customer: customer),
          const SizedBox(height: 16),
          Text('Tickets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (tickets) => tickets.isEmpty
                ? const Text('No tickets for this customer')
                : Column(
                    children: tickets
                        .map((t) => Card(
                              child: ListTile(
                                title: Text(t.summary,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(t.ticketNumber),
                                trailing: Chip(
                                  label: Text(t.status.label,
                                      style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  labelPadding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                ),
                                onTap: () => context.go('/tickets/${t.id}'),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.customer});
  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null) _Row('Phone', customer.phone!),
            if (customer.email != null) _Row('Email', customer.email!),
            if (customer.notes != null && customer.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Notes', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(customer.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
