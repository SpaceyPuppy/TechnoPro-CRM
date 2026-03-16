import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import 'inventory_provider.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(inventoryListProvider),
          ),
        ],
      ),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inventoryListProvider),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No inventory items found'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(inventoryListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => _InventoryCard(
                    item: items[i],
                    onTap: () => context.go('/inventory/${items[i].id}'),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/inventory/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onTap});

  final InventoryItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stockLabel = item.stockQty == null
        ? 'Untracked'
        : item.stockQty == 0
            ? 'Out of stock'
            : '${item.stockQty} in stock';

    final stockColor = item.stockQty == null
        ? Colors.grey
        : item.stockQty == 0
            ? Colors.red
            : Colors.green;

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(item.name),
        subtitle: Text('${item.sku} · \$${item.price}'),
        trailing: Chip(
          label: Text(stockLabel, style: const TextStyle(fontSize: 11)),
          backgroundColor: stockColor.withAlpha(30),
          side: BorderSide(color: stockColor.withAlpha(80)),
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        ),
      ),
    );
  }
}
