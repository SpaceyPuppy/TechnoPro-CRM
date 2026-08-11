import 'package:flutter/material.dart';
import '../../shared/widgets/prism_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/prism_surfaces.dart';
import 'procurement_provider.dart';

class PurchaseOrdersListScreen extends ConsumerWidget {
  const PurchaseOrdersListScreen({
    super.key,
    this.selectedId,
    this.onSelect,
  });

  final String? selectedId;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrders = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: PrismAppBar(
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(icon: const Icon(Icons.local_shipping_outlined), tooltip: 'Suppliers', onPressed: () => context.go('/procurement/suppliers')),
          IconButton(icon: const Icon(Icons.add), tooltip: 'New purchase order', onPressed: () => context.go('/procurement/new')),
        ],
      ),
      body: asyncOrders.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No purchase orders found.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(purchaseOrdersProvider.future),
            child: ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final po = orders[index];
                final isSelected = po.id == selectedId;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: PrismSurface(
                    radius: 20,
                    tint: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .56) : null,
                    child: ListTile(
                  selected: isSelected,
                  title: Text(po.poNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${po.supplier?.name ?? 'Unknown Supplier'} • ${po.status.toUpperCase()}'),
                  trailing: Text('\$${po.totalCost}'),
                  onTap: () {
                    if (onSelect != null) {
                      onSelect!(po.id);
                    } else {
                      context.go('/purchase-orders/${po.id}');
                    }
                  },
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
