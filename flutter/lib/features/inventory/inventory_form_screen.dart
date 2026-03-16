import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../shared/widgets/error_view.dart';
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

  final _skuCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  @override
  void dispose() {
    _skuCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _barcodeCtrl.dispose();
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
        if (_costCtrl.text.isNotEmpty) 'cost': _costCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_barcodeCtrl.text.isNotEmpty) 'barcode': _barcodeCtrl.text.trim(),
        'stockQty': _trackStock && _stockCtrl.text.isNotEmpty
            ? int.tryParse(_stockCtrl.text)
            : null,
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
        _trackStock = item.stockQty != null;
        _stockCtrl.text = item.stockQty?.toString() ?? '';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Item' : 'New Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
            ],
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(labelText: 'Barcode', border: OutlineInputBorder()),
            ),
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
          ],
        ),
      ),
    );
  }
}
