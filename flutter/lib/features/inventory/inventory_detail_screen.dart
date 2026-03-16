import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/error_view.dart';
import 'inventory_provider.dart';

class InventoryDetailScreen extends ConsumerWidget {
  const InventoryDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(inventoryDetailProvider(id));

    return itemAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      data: (item) => Scaffold(
        appBar: AppBar(
          title: Text(item.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/inventory/$id/edit'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('SKU', item.sku),
                    _Row('Price', '\$${item.price}'),
                    _Row('Cost', '\$${item.cost}'),
                    _Row(
                      'Stock',
                      item.stockQty == null
                          ? 'Not tracked'
                          : '${item.stockQty} units',
                    ),
                    if (item.barcode != null) _Row('Barcode', item.barcode!),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text('Description',
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(item.description!),
                    ],
                  ],
                ),
              ),
            ),
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
