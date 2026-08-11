import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../inventory/inventory_provider.dart';
import '../../shared/models/models.dart';
import 'data/procurement_repository.dart';
import 'procurement_provider.dart';

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends ConsumerState<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitCost = TextEditingController();
  String? _supplierId;
  InventoryItemModel? _item;
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    _quantity.dispose();
    _unitCost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _supplierId == null || _item == null) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'supplierId': _supplierId,
        'items': [{
          'inventoryItemId': _item!.id,
          'description': _item!.name,
          'quantity': int.parse(_quantity.text),
          'unitCost': _unitCost.text.trim(),
        }],
      };
      if (_notes.text.trim().isNotEmpty) payload['notes'] = _notes.text.trim();
      await ref.read(procurementRepositoryProvider).createPurchaseOrder(payload);
      ref.invalidate(purchaseOrdersProvider);
      if (mounted) context.go('/procurement');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create purchase order: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final inventory = ref.watch(inventoryListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New purchase order')),
      body: suppliers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load suppliers: $error')),
        data: (supplierList) => inventory.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load inventory: $error')),
          data: (items) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  value: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier *'),
                  items: supplierList.map((supplier) => DropdownMenuItem(value: supplier.id, child: Text(supplier.name))).toList(),
                  onChanged: (value) => setState(() => _supplierId = value),
                  validator: (value) => value == null ? 'Choose a supplier' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<InventoryItemModel>(
                  value: _item,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Inventory item *'),
                  items: items.where((item) => item.active).map((item) => DropdownMenuItem(value: item, child: Text('${item.name} (${item.sku})', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (value) => setState(() { _item = value; if (value != null && _unitCost.text.isEmpty) _unitCost.text = value.cost; }),
                  validator: (value) => value == null ? 'Choose an inventory item' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity *'), validator: (value) => int.tryParse(value ?? '') == null || int.parse(value!) < 1 ? 'Enter a whole quantity' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _unitCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit cost *'), validator: (value) => RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value?.trim() ?? '') ? null : 'Enter an amount with up to two decimals'),
                const SizedBox(height: 16),
                TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_shopping_cart), label: const Text('Create purchase order')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
