import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/procurement_repository.dart';
import 'procurement_provider.dart';
import '../../shared/widgets/adaptive_form_scaffold.dart';
import '../../shared/widgets/prism_surfaces.dart';

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderLine {
  String? supplierItemId;
  String? inventoryItemId;
  int packSize = 1;
  int minimumOrderQty = 1;
  final quantity = TextEditingController(text: '1');
  final unitCost = TextEditingController();

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }
}

class _PurchaseOrderFormScreenState extends ConsumerState<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _lines = <_PurchaseOrderLine>[_PurchaseOrderLine()];
  String? _supplierId;
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _chooseSupplier(String? value) {
    if (_supplierId == value) return;
    for (final line in _lines) {
      line.dispose();
    }
    setState(() {
      _supplierId = value;
      _lines
        ..clear()
        ..add(_PurchaseOrderLine());
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _supplierId == null || _lines.any((line) => line.inventoryItemId == null)) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'supplierId': _supplierId,
        'items': _lines.map((line) => {
          'inventoryItemId': line.inventoryItemId,
          'supplierItemId': line.supplierItemId,
          'quantity': int.parse(line.quantity.text),
          'unitCost': line.unitCost.text.trim(),
        }).toList(),
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
    final supplierItems = _supplierId == null ? null : ref.watch(supplierItemsForSupplierProvider(_supplierId!));
    return AdaptiveFormScaffold(
      title: 'New purchase order',
      child: suppliers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load suppliers: $error')),
        data: (supplierList) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<String>(
                value: _supplierId,
                decoration: const InputDecoration(labelText: 'Supplier *'),
                items: supplierList.map((supplier) => DropdownMenuItem(value: supplier.id, child: Text(supplier.name))).toList(),
                onChanged: _chooseSupplier,
                validator: (value) => value == null ? 'Choose a supplier' : null,
              ),
              const SizedBox(height: 20),
              Text('Order lines', style: Theme.of(context).textTheme.titleMedium),
              if (_supplierId == null) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Choose a supplier to see its supplier-specific SKUs and quoted costs.')),
              if (supplierItems != null) supplierItems.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (error, _) => Padding(padding: const EdgeInsets.only(top: 12), child: Text('Could not load supplier items: $error')),
                data: (options) => options.isEmpty
                    ? const Padding(padding: EdgeInsets.only(top: 12), child: Text('No active supplier item options. Add one from the inventory item first.'))
                    : Column(children: [
                      for (var index = 0; index < _lines.length; index++) _LineEditor(
                        key: ValueKey(_lines[index]),
                        line: _lines[index],
                        options: options,
                        canRemove: _lines.length > 1,
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() { final line = _lines.removeAt(index); line.dispose(); }),
                      ),
                      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => setState(() => _lines.add(_PurchaseOrderLine())), icon: const Icon(Icons.add), label: const Text('Add line'))),
                    ]),
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _saving || _supplierId == null ? null : _save, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_shopping_cart), label: const Text('Create purchase order')),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({super.key, required this.line, required this.options, required this.canRemove, required this.onChanged, required this.onRemove});

  final _PurchaseOrderLine line;
  final List<Map<String, dynamic>> options;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PrismSurface(
        radius: 20,
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [Expanded(child: Text('Supplier item', style: Theme.of(context).textTheme.labelLarge)), if (canRemove) IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Remove line', onPressed: onRemove)]),
          DropdownButtonFormField<String>(
            value: line.supplierItemId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Item *'),
            items: options.map((option) {
              final inventory = option['inventoryItem'] as Map<String, dynamic>?;
              final name = inventory?['name'] as String? ?? 'Unavailable item';
              final sku = option['supplierSku'] as String? ?? inventory?['sku'] as String? ?? 'No SKU';
              return DropdownMenuItem(value: option['id'] as String, child: Text('$name — $sku', overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (value) {
              final option = options.firstWhere((candidate) => candidate['id'] == value);
              final inventory = option['inventoryItem'] as Map<String, dynamic>?;
              line
                ..supplierItemId = value
                ..inventoryItemId = inventory?['id'] as String?
                ..packSize = option['packSize'] as int? ?? 1
                ..minimumOrderQty = option['minimumOrderQty'] as int? ?? 1;
              line.unitCost.text = (option['quotedUnitCost'] as String?) ?? (inventory?['cost'] as String? ?? '0.00');
              onChanged();
            },
            validator: (value) => value == null ? 'Choose a supplier item' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(controller: line.quantity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity *', helperText: 'MOQ ${line.minimumOrderQty}; pack size ${line.packSize}'), validator: (value) {
            final quantity = int.tryParse(value ?? '');
            if (quantity == null || quantity < 1) return 'Enter a whole quantity';
            if (quantity < line.minimumOrderQty) return 'Minimum order is ${line.minimumOrderQty}';
            if (quantity % line.packSize != 0) return 'Quantity must be a multiple of ${line.packSize}';
            return null;
          }),
          const SizedBox(height: 12),
          TextFormField(controller: line.unitCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit cost *'), validator: (value) => RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value?.trim() ?? '') ? null : 'Enter an amount with up to two decimals'),
        ]),
      ),
    );
  }
}
