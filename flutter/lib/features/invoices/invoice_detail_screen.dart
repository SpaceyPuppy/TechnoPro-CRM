import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import '../inventory/inventory_provider.dart';
import 'invoices_provider.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(id));

    return invoiceAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      data: (invoice) => Scaffold(
        appBar: AppBar(
          title: Text(invoice.invoiceNumber),
          actions: [
            Chip(
              label: Text(invoice.statusLabel, style: const TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryCard(invoice: invoice),
            const SizedBox(height: 16),
            _StatusActions(invoice: invoice, onChanged: () => ref.invalidate(invoiceDetailProvider(id))),
            const SizedBox(height: 16),
            _LineItemsSection(invoice: invoice, onChanged: () => ref.invalidate(invoiceDetailProvider(id))),
            const SizedBox(height: 16),
            _PaymentsSection(invoice: invoice, onChanged: () => ref.invalidate(invoiceDetailProvider(id))),
          ],
        ),
      ),
    );
  }
}

// --- Summary card ---

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.invoice});
  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row('Subtotal', '\$${invoice.subtotal}'),
            _Row('Tax', '\$${invoice.tax}'),
            const Divider(height: 16),
            _Row('Total', '\$${invoice.total}', bold: true),
            _Row('Paid', '\$${invoice.amountPaid}'),
            _Row('Balance', '\$${invoice.balance}', bold: double.tryParse(invoice.balance) != 0),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

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
          Text(value,
              style: bold
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
                  : null),
        ],
      ),
    );
  }
}

// --- Status actions ---

class _StatusActions extends ConsumerWidget {
  const _StatusActions({required this.invoice, required this.onChanged});
  final InvoiceModel invoice;
  final VoidCallback onChanged;

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String newStatus) async {
    try {
      final dio = ref.read(apiClientProvider);
      await dio.patch('/invoices/${invoice.id}/status', data: {'status': newStatus});
      ref.invalidate(invoiceListProvider);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invoice.isPaid || invoice.isVoid) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      children: [
        if (invoice.status == 'draft')
          FilledButton.tonal(
            onPressed: () => _setStatus(context, ref, 'open'),
            child: const Text('Mark as Open'),
          ),
        if (invoice.status == 'open')
          FilledButton(
            onPressed: () => _setStatus(context, ref, 'paid'),
            child: const Text('Mark as Paid'),
          ),
        OutlinedButton(
          onPressed: () => _setStatus(context, ref, 'void'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Void'),
        ),
      ],
    );
  }
}

// --- Line items section ---

class _LineItemsSection extends ConsumerWidget {
  const _LineItemsSection({required this.invoice, required this.onChanged});
  final InvoiceModel invoice;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (invoice.canEdit)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: () => _showAddLineItem(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (invoice.lineItems.isEmpty)
          const Text('No line items yet', style: TextStyle(color: Colors.grey))
        else
          ...invoice.lineItems.map((li) => _LineItemTile(
                item: li,
                canDelete: invoice.canEdit,
                onDelete: () async {
                  try {
                    final dio = ref.read(apiClientProvider);
                    await dio.delete('/invoices/${invoice.id}/line-items/${li.id}');
                    ref.invalidate(invoiceListProvider);
                    onChanged();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
              )),
      ],
    );
  }

  void _showAddLineItem(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddLineItemSheet(
        invoiceId: invoice.id,
        onAdded: () {
          ref.invalidate(invoiceListProvider);
          onChanged();
        },
      ),
    );
  }
}

class _LineItemTile extends StatelessWidget {
  const _LineItemTile({required this.item, required this.canDelete, required this.onDelete});
  final LineItemModel item;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.description),
      subtitle: Text('${item.quantity} × \$${item.unitPrice}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('\$${item.total}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (canDelete) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.red,
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

// --- Add line item bottom sheet ---

class _AddLineItemSheet extends ConsumerStatefulWidget {
  const _AddLineItemSheet({required this.invoiceId, required this.onAdded});
  final String invoiceId;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddLineItemSheet> createState() => _AddLineItemSheetState();
}

class _AddLineItemSheetState extends ConsumerState<_AddLineItemSheet> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'service';
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String? _inventoryItemId;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  String _formatPrice(String raw) {
    final d = double.tryParse(raw.replaceAll(',', ''));
    if (d == null) return raw;
    return d.toStringAsFixed(2);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/invoices/${widget.invoiceId}/line-items', data: {
        'type': _type,
        'description': _descCtrl.text.trim(),
        'unitPrice': _formatPrice(_priceCtrl.text.trim()),
        'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        if (_inventoryItemId != null) 'inventoryItemId': _inventoryItemId,
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryListProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Line Item', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'service', label: Text('Service')),
                ButtonSegment(value: 'part', label: Text('Part')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            if (_type == 'part')
              inventoryAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) => DropdownButtonFormField<String?>(
                  value: _inventoryItemId,
                  decoration: const InputDecoration(
                    labelText: 'From inventory (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Custom item')),
                    ...items.map((i) => DropdownMenuItem(
                          value: i.id,
                          child: Text('${i.name} — \$${i.price}'),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => _inventoryItemId = v);
                    if (v != null) {
                      final item = items.firstWhere((i) => i.id == v);
                      _descCtrl.text = item.name;
                      _priceCtrl.text = item.price;
                    }
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description *', border: OutlineInputBorder(), isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Unit Price *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: '\$'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add Line Item'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Payments section ---

class _PaymentsSection extends ConsumerWidget {
  const _PaymentsSection({required this.invoice, required this.onChanged});
  final InvoiceModel invoice;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Payments', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (!invoice.isPaid && !invoice.isVoid)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Payment'),
                onPressed: () => _showAddPayment(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (invoice.payments.isEmpty)
          const Text('No payments recorded', style: TextStyle(color: Colors.grey))
        else
          ...invoice.payments.map((p) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payment, size: 20),
                title: Text('\$${p.amount} · ${_methodLabel(p.method)}'),
                subtitle: Text(p.reference != null ? '${p.reference} · ${p.paidAt}' : p.paidAt),
                trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
              )),
      ],
    );
  }

  String _methodLabel(String m) => switch (m) {
        'cash' => 'Cash',
        'card' => 'Card',
        'eftpos' => 'EFTPOS',
        'bank_transfer' => 'Bank Transfer',
        _ => 'Other',
      };

  void _showAddPayment(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPaymentSheet(
        invoiceId: invoice.id,
        balance: invoice.balance,
        onAdded: () {
          ref.invalidate(invoiceListProvider);
          onChanged();
        },
      ),
    );
  }
}

// --- Add payment bottom sheet ---

class _AddPaymentSheet extends ConsumerStatefulWidget {
  const _AddPaymentSheet(
      {required this.invoiceId, required this.balance, required this.onAdded});
  final String invoiceId;
  final String balance;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.balance;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  String _formatAmount(String raw) {
    final d = double.tryParse(raw.replaceAll(',', ''));
    if (d == null) return raw;
    return d.toStringAsFixed(2);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/invoices/${widget.invoiceId}/payments', data: {
        'amount': _formatAmount(_amountCtrl.text.trim()),
        'method': _method,
        if (_referenceCtrl.text.isNotEmpty) 'reference': _referenceCtrl.text.trim(),
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record Payment', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                  labelText: 'Amount *',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixText: '\$'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(
                  labelText: 'Method', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'eftpos', child: Text('EFTPOS')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _method = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
