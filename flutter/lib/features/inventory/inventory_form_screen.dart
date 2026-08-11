import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/adaptive_form_scaffold.dart';
import 'inventory_provider.dart';

class InventoryFormScreen extends ConsumerStatefulWidget {
  const InventoryFormScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<InventoryFormScreen> createState() => _InventoryFormScreenState();
}

class _InventoryFormScreenState extends ConsumerState<InventoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  bool _initialized = false;
  bool _trackStock = false;
  bool _posSellable = true;
  bool _serialized = false;
  bool _active = true;

  final _skuCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _openingReasonCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _upcCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _mpnCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  final _targetStockCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _internalNotesCtrl = TextEditingController();

  @override
  void dispose() {
    _skuCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _openingReasonCtrl.dispose();
    _barcodeCtrl.dispose();
    _upcCtrl.dispose(); _brandCtrl.dispose(); _categoryCtrl.dispose(); _subCategoryCtrl.dispose(); _modelCtrl.dispose(); _mpnCtrl.dispose(); _conditionCtrl.dispose(); _reorderCtrl.dispose(); _targetStockCtrl.dispose(); _warrantyCtrl.dispose(); _internalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'sku': _skuCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        if (widget.id == null && _costCtrl.text.isNotEmpty) 'cost': _costCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_barcodeCtrl.text.isNotEmpty) 'barcode': _barcodeCtrl.text.trim(),
        if (_upcCtrl.text.isNotEmpty) 'upc': _upcCtrl.text.trim(),
        if (_brandCtrl.text.isNotEmpty) 'brand': _brandCtrl.text.trim(),
        if (_categoryCtrl.text.isNotEmpty) 'category': _categoryCtrl.text.trim(),
        if (_subCategoryCtrl.text.isNotEmpty) 'subcategory': _subCategoryCtrl.text.trim(),
        if (_modelCtrl.text.isNotEmpty) 'compatibleModel': _modelCtrl.text.trim(),
        if (_mpnCtrl.text.isNotEmpty) 'manufacturerPartNumber': _mpnCtrl.text.trim(),
        if (_conditionCtrl.text.isNotEmpty) 'condition': _conditionCtrl.text.trim(),
        if (_reorderCtrl.text.isNotEmpty) 'reorderPoint': int.tryParse(_reorderCtrl.text),
        if (_targetStockCtrl.text.isNotEmpty) 'targetStockLevel': int.tryParse(_targetStockCtrl.text),
        if (_warrantyCtrl.text.isNotEmpty) 'warrantyMonths': int.tryParse(_warrantyCtrl.text),
        if (_internalNotesCtrl.text.isNotEmpty) 'internalNotes': _internalNotesCtrl.text.trim(),
        'active': _active, 'posSellable': _posSellable, 'serialized': _serialized,
        if (widget.id == null) 'stockQty': _trackStock && _stockCtrl.text.isNotEmpty ? int.tryParse(_stockCtrl.text) : null,
        if (widget.id == null && _stockCtrl.text.isNotEmpty) 'openingBalanceReason': _openingReasonCtrl.text.trim(),
      };
      if (widget.id == null) {
        await dio.post('/inventory', data: body);
      } else {
        await dio.patch('/inventory/${widget.id}', data: body);
      }
      ref.invalidate(inventoryListProvider);
      if (widget.id != null) ref.invalidate(inventoryDetailProvider(widget.id!));
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete ${_nameCtrl.text}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _saving = true;
                _error = null;
              });
              try {
                final dio = ref.read(apiClientProvider);
                await dio.delete('/inventory/${widget.id}');
                ref.invalidate(inventoryListProvider);
                if (mounted) context.pop();
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              } finally {
                if (mounted) setState(() => _saving = false);
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
  Widget build(BuildContext context) {
    final isEdit = widget.id != null;

    if (isEdit) {
      final itemAsync = ref.watch(inventoryDetailProvider(widget.id!));
      if (itemAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (itemAsync.hasError) {
        return Scaffold(body: ErrorView(message: itemAsync.error.toString()));
      }
      if (!_initialized) {
        _initialized = true;
        final item = itemAsync.value!;
        _skuCtrl.text = item.sku;
        _nameCtrl.text = item.name;
        _descCtrl.text = item.description ?? '';
        _priceCtrl.text = item.price;
        _costCtrl.text = item.cost;
        _barcodeCtrl.text = item.barcode ?? '';
        _upcCtrl.text = item.upc ?? ''; _brandCtrl.text = item.brand ?? ''; _categoryCtrl.text = item.category ?? ''; _subCategoryCtrl.text = item.subcategory ?? ''; _modelCtrl.text = item.compatibleModel ?? ''; _mpnCtrl.text = item.manufacturerPartNumber ?? ''; _conditionCtrl.text = item.condition ?? ''; _reorderCtrl.text = item.reorderPoint?.toString() ?? ''; _targetStockCtrl.text = item.targetStockLevel?.toString() ?? ''; _warrantyCtrl.text = item.warrantyMonths?.toString() ?? ''; _internalNotesCtrl.text = item.internalNotes ?? ''; _active = item.active; _posSellable = item.posSellable; _serialized = item.serialized;
        _trackStock = item.stockQty != null;
        _stockCtrl.text = item.stockQty?.toString() ?? '';
      }
    }

    return AdaptiveFormScaffold(
      title: isEdit ? 'Edit Item' : 'New Item',
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _skuCtrl,
              decoration: const InputDecoration(labelText: 'SKU *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price *', border: OutlineInputBorder(), prefixText: '\$'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Price is required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _costCtrl,
                  decoration: const InputDecoration(labelText: 'Cost', border: OutlineInputBorder(), prefixText: '\$'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Track stock quantity'),
              value: _trackStock,
              onChanged: (v) => setState(() => _trackStock = v),
            ),
            if (_trackStock) ...[
              TextFormField(
                controller: _stockCtrl,
                decoration: const InputDecoration(labelText: 'Stock Qty', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              if (!isEdit) ...[
                TextFormField(controller: _openingReasonCtrl, decoration: const InputDecoration(labelText: 'Opening-balance reason *', border: OutlineInputBorder()), validator: (value) => _trackStock && (_stockCtrl.text.isNotEmpty && _stockCtrl.text != '0') && (value == null || value.trim().isEmpty) ? 'Reason is required for opening stock' : null),
                const SizedBox(height: 16),
              ],
            ],
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(labelText: 'Barcode', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _upcCtrl, decoration: const InputDecoration(labelText: 'UPC / GTIN', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Brand / manufacturer', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(controller: _subCategoryCtrl, decoration: const InputDecoration(labelText: 'Sub-category', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(controller: _modelCtrl, decoration: const InputDecoration(labelText: 'Compatible device / model', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(controller: _mpnCtrl, decoration: const InputDecoration(labelText: 'Manufacturer part number', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(controller: _conditionCtrl, decoration: const InputDecoration(labelText: 'Condition', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: TextFormField(controller: _reorderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder point', border: OutlineInputBorder()))), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _targetStockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target stock', border: OutlineInputBorder())))]),
            const SizedBox(height: 16),
            TextFormField(controller: _warrantyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Warranty months', border: OutlineInputBorder())),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Sell through point of sale'), value: _posSellable, onChanged: (value) => setState(() => _posSellable = value)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Serialized item'), value: _serialized, onChanged: (value) => setState(() => _serialized = value)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active item'), value: _active, onChanged: (value) => setState(() => _active = value)),
            TextFormField(controller: _internalNotesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Internal notes', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Save Changes' : 'Create Item'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _saving ? null : _delete,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(50),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete Item'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
