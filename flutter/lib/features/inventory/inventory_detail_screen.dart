import 'package:flutter/material.dart';
import '../../shared/widgets/prism_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/error_view.dart';
import 'inventory_provider.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

class InventoryDetailScreen extends ConsumerWidget {
  const InventoryDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _adjust(BuildContext context, WidgetRef ref, InventoryItemModel item) async {
    final delta = TextEditingController(); final reason = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Adjust stock'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextFormField(controller: delta, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Quantity change (+/-)')), TextFormField(controller: reason, decoration: const InputDecoration(labelText: 'Reason *'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post adjustment'))]));
    if (confirmed != true || int.tryParse(delta.text) == null || int.parse(delta.text) == 0 || reason.text.trim().isEmpty) return;
    await ref.read(apiClientProvider).post('/inventory/${item.id}/adjustments', data: {'quantityDelta': int.parse(delta.text), 'unitCost': item.cost, 'reasonCode': reason.text.trim(), 'sourceReference': 'manual-${DateTime.now().millisecondsSinceEpoch}'});
    ref.invalidate(inventoryDetailProvider(id)); ref.invalidate(inventoryListProvider); ref.invalidate(stockMovementsProvider(id));
  }

  Future<void> _addSupplierOption(BuildContext context, WidgetRef ref, InventoryItemModel item) async {
    final suppliersResponse = await ref.read(apiClientProvider).get<Map<String, dynamic>>('/suppliers');
    final suppliers = (suppliersResponse.data?['data'] as List? ?? []).cast<Map<String, dynamic>>();
    String? supplierId;
    final sku = TextEditingController(); final upc = TextEditingController(); final partNumber = TextEditingController(); final cost = TextEditingController(); final packSize = TextEditingController(text: '1'); final minimumOrderQty = TextEditingController(text: '1');
    var preferred = false;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Add supplier option'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: supplierId, isExpanded: true, decoration: const InputDecoration(labelText: 'Supplier *'), items: suppliers.map((supplier) => DropdownMenuItem(value: supplier['id'] as String, child: Text(supplier['name'] as String, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => setDialogState(() => supplierId = value)),
        TextFormField(controller: sku, decoration: const InputDecoration(labelText: 'Supplier SKU')),
        TextFormField(controller: upc, decoration: const InputDecoration(labelText: 'Supplier UPC')),
        TextFormField(controller: partNumber, decoration: const InputDecoration(labelText: 'Supplier part number')),
        TextFormField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quoted unit cost')),
        TextFormField(controller: packSize, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pack size *')),
        TextFormField(controller: minimumOrderQty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum order quantity *')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: preferred, onChanged: (value) => setDialogState(() => preferred = value ?? false), title: const Text('Preferred supplier option')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: supplierId == null ? null : () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
    )));
    final parsedPackSize = int.tryParse(packSize.text);
    final parsedMinimumOrderQty = int.tryParse(minimumOrderQty.text);
    if (confirmed != true || supplierId == null || parsedPackSize == null || parsedPackSize < 1 || parsedMinimumOrderQty == null || parsedMinimumOrderQty < 1) return;
    await ref.read(apiClientProvider).post('/inventory/${item.id}/supplier-items', data: {
      'supplierId': supplierId,
      if (sku.text.trim().isNotEmpty) 'supplierSku': sku.text.trim(),
      if (upc.text.trim().isNotEmpty) 'supplierUpc': upc.text.trim(),
      if (partNumber.text.trim().isNotEmpty) 'supplierPartNumber': partNumber.text.trim(),
      if (cost.text.trim().isNotEmpty) 'quotedUnitCost': cost.text.trim(),
      'packSize': parsedPackSize,
      'minimumOrderQty': parsedMinimumOrderQty,
      'preferred': preferred,
    });
    ref.invalidate(supplierItemsProvider(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(inventoryDetailProvider(id));
    final movementsAsync = ref.watch(stockMovementsProvider(id));
    final supplierItemsAsync = ref.watch(supplierItemsProvider(id));

    return itemAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      data: (item) => Scaffold(
        appBar: PrismAppBar(
          title: Text(item.name),
          actions: [
            if (item.stockQty != null) IconButton(icon: const Icon(Icons.tune), tooltip: 'Adjust stock', onPressed: () => _adjust(context, ref, item)),
            IconButton(icon: const Icon(Icons.local_shipping_outlined), tooltip: 'Add supplier option', onPressed: () => _addSupplierOption(context, ref, item)),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/inventory/$id/edit'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PrismSurface(
              radius: 26,
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
                    if (item.upc != null) _Row('UPC', item.upc!),
                    if (item.brand != null) _Row('Brand', item.brand!),
                    if (item.reorderPoint != null) _Row('Reorder at', '${item.reorderPoint} units'),
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
            const SizedBox(height: 16),
            Text('Supplier options', style: Theme.of(context).textTheme.titleMedium),
            supplierItemsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              error: (error, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Could not load supplier options: $error')),
              data: (options) => options.isEmpty
                  ? const Padding(padding: EdgeInsets.all(8), child: Text('No supplier options yet.'))
                  : PrismSurface(radius: 22, child: Column(children: options.map((option) => ListTile(
                    leading: Icon(option['preferred'] == true ? Icons.star : Icons.local_shipping_outlined),
                    title: Text(option['supplierName'] as String? ?? 'Supplier'),
                    subtitle: Text('UPC ${option['supplierUpc'] as String? ?? '—'} · Pack ${option['packSize']} · MOQ ${option['minimumOrderQty']}'),
                    trailing: Text(option['quotedUnitCost'] == null ? '' : '\$${option['quotedUnitCost']}'),
                  )).toList())),
            ),
            const SizedBox(height: 16),
            Text('Stock history', style: Theme.of(context).textTheme.titleMedium),
            movementsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Could not load stock history: $error')),
              data: (movements) => movements.isEmpty
                  ? const Padding(padding: EdgeInsets.all(8), child: Text('No stock movements yet.'))
                  : PrismSurface(radius: 22, child: Column(children: movements.take(20).map((movement) {
                      final delta = movement['quantityDelta'] as int? ?? 0;
                      return ListTile(
                        leading: Icon(delta >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline, color: delta >= 0 ? Colors.green : Colors.red),
                        title: Text('${movement['sourceType']}  ${delta >= 0 ? '+' : ''}$delta'),
                        subtitle: Text('${movement['reasonCode']} · balance ${movement['balanceAfter']}'),
                        trailing: Text('\$${movement['unitCost']}'),
                      );
                    }).toList())),
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
