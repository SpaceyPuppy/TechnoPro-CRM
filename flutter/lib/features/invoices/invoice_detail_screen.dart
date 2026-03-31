import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import '../inventory/inventory_provider.dart';
import '../settings/app_settings_provider.dart';
import 'invoice_repository.dart';
import 'invoices_provider.dart';
import 'pdf_invoice_service.dart';

// Fetches the customer linked to a ticket (used for PDF header)
final _ticketCustomerProvider =
    FutureProvider.family<CustomerModel?, String>((ref, ticketId) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/tickets/$ticketId');
  final data = res.data!['data'] as Map<String, dynamic>;
  if (data['customer'] == null) return null;
  return CustomerModel.fromJson(data['customer'] as Map<String, dynamic>);
});

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
            _PdfButton(invoice: invoice),
            const SizedBox(width: 4),
            Chip(
              label: Text(
                invoice.isQuote ? invoice.quoteStatusLabel : invoice.statusLabel,
                style: const TextStyle(fontSize: 11),
              ),
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

// ---------------------------------------------------------------------------
// PDF action button
// ---------------------------------------------------------------------------

class _PdfButton extends ConsumerStatefulWidget {
  const _PdfButton({required this.invoice});
  final InvoiceModel invoice;

  @override
  ConsumerState<_PdfButton> createState() => _PdfButtonState();
}

class _PdfButtonState extends ConsumerState<_PdfButton> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final settingsAsync = ref.read(appSettingsProvider);
      final settings = settingsAsync.valueOrNull;
      if (settings == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings not loaded — try again')),
        );
        return;
      }

      // Try to get customer from linked ticket
      CustomerModel? customer;
      if (widget.invoice.ticketId != null) {
        customer = await ref.read(
          _ticketCustomerProvider(widget.invoice.ticketId!).future,
        );
      }

      final doc = await PdfInvoiceService.buildInvoicePdf(
        widget.invoice,
        settings,
        customerName: customer?.displayName,
        customerPhone: customer?.phone,
        customerEmail: customer?.email,
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${widget.invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _print() async {
    setState(() => _generating = true);
    try {
      final settingsAsync = ref.read(appSettingsProvider);
      final settings = settingsAsync.valueOrNull;
      if (settings == null) return;

      CustomerModel? customer;
      if (widget.invoice.ticketId != null) {
        customer = await ref.read(
          _ticketCustomerProvider(widget.invoice.ticketId!).future,
        );
      }

      final doc = await PdfInvoiceService.buildInvoicePdf(
        widget.invoice,
        settings,
        customerName: customer?.displayName,
        customerPhone: customer?.phone,
        customerEmail: customer?.email,
      );

      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_generating) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: 'PDF',
      onSelected: (v) {
        if (v == 'share') _generate();
        if (v == 'print') _print();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'share', child: Text('Share / Email PDF')),
        PopupMenuItem(value: 'print', child: Text('Print')),
      ],
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
            _Row('GST', '\$${invoice.taxAmount}'),
            const Divider(height: 16),
            _Row('Total', '\$${invoice.total}', bold: true),
            if (invoice.deposits.isNotEmpty) ...[
              _Row(
                'Deposits',
                '-\$${invoice.deposits.fold(0.0, (s, p) => s + (double.tryParse(p.amount) ?? 0)).toStringAsFixed(2)}',
                color: Colors.teal,
              ),
            ],
            if (invoice.regularPayments.isNotEmpty)
              _Row(
                'Payments',
                '-\$${invoice.regularPayments.fold(0.0, (s, p) => s + (double.tryParse(p.amount) ?? 0)).toStringAsFixed(2)}',
              ),
            if (invoice.payments.isNotEmpty) ...[
              const Divider(height: 12),
              _Row('Balance', '\$${invoice.balance}',
                  bold: (double.tryParse(invoice.balance) ?? 0) > 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

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
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: color)
                  : color != null
                      ? TextStyle(color: color)
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

  Future<void> _setQuoteStatus(BuildContext context, WidgetRef ref, String newStatus) async {
    try {
      final dio = ref.read(apiClientProvider);
      await dio.patch('/invoices/${invoice.id}/quote-status', data: {'quoteStatus': newStatus});
      ref.invalidate(quoteListProvider);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _convertToTicket(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dio.patch<Map<String, dynamic>>(
          '/invoices/${invoice.id}/convert-to-ticket');
      final ticketId = res.data!['data']['ticketId'] as String;
      ref.invalidate(quoteListProvider);
      onChanged();
      if (context.mounted) {
        context.go('/tickets/$ticketId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Quote actions
    if (invoice.isQuote) {
      final qs = invoice.quoteStatus ?? 'draft';
      if (qs == 'declined') return const SizedBox.shrink();

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (qs == 'draft')
            FilledButton.tonal(
              onPressed: () => _setQuoteStatus(context, ref, 'sent'),
              child: const Text('Mark as Sent'),
            ),
          if (qs == 'sent') ...[
            FilledButton(
              onPressed: () => _setQuoteStatus(context, ref, 'accepted'),
              child: const Text('Mark Accepted'),
            ),
            OutlinedButton(
              onPressed: () => _setQuoteStatus(context, ref, 'declined'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Decline'),
            ),
          ],
          if (qs == 'accepted' && invoice.convertedTicketId == null)
            FilledButton.icon(
              icon: const Icon(Icons.confirmation_number_outlined, size: 18),
              label: const Text('Convert to Ticket'),
              onPressed: () => _convertToTicket(context, ref),
            ),
          if (qs == 'accepted' && invoice.convertedTicketId != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View Ticket'),
              onPressed: () => context.go('/tickets/${invoice.convertedTicketId}'),
            ),
        ],
      );
    }

    // Invoice actions
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
                    final invoiceRepo = ref.read(invoiceRepositoryProvider);
                    await invoiceRepo.deleteLineItem(invoice.id, li.id);
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
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      await invoiceRepo.addLineItem(
        widget.invoiceId,
        description: _descCtrl.text.trim(),
        type: _type,
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        unitPrice: _formatPrice(_priceCtrl.text.trim()),
        inventoryItemId: _inventoryItemId,
      );
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
        else ...[
          if (invoice.deposits.isNotEmpty) ...[
            _PaymentGroupHeader('Deposits', Colors.teal),
            ...invoice.deposits.map((p) => _PaymentTile(payment: p, methodLabel: _methodLabel(p.method))),
            const SizedBox(height: 8),
          ],
          if (invoice.regularPayments.isNotEmpty) ...[
            if (invoice.deposits.isNotEmpty)
              _PaymentGroupHeader('Payments', null),
            ...invoice.regularPayments.map((p) => _PaymentTile(payment: p, methodLabel: _methodLabel(p.method))),
          ],
        ],
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

// --- Payment group helpers ---

class _PaymentGroupHeader extends StatelessWidget {
  const _PaymentGroupHeader(this.label, this.color);
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color ?? Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.methodLabel});
  final PaymentModel payment;
  final String methodLabel;

  @override
  Widget build(BuildContext context) {
    final isDeposit = payment.isDeposit;
    final isRefund = payment.isRefund;
    final icon = isDeposit
        ? Icons.savings_outlined
        : isRefund
            ? Icons.undo
            : Icons.payment;
    final color = isDeposit
        ? Colors.teal
        : isRefund
            ? Colors.orange
            : Colors.green;
    final typeTag = isDeposit ? ' · Deposit' : isRefund ? ' · Refund' : '';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: color),
      title: Text('\$${payment.amount} · $methodLabel$typeTag'),
      subtitle: Text(
          payment.reference != null
              ? '${payment.reference} · ${payment.paidAt}'
              : payment.paidAt),
      trailing: Icon(Icons.check_circle, color: color, size: 18),
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
  String _type = 'payment'; // deposit | payment | refund
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
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      await invoiceRepo.addPayment(
        widget.invoiceId,
        amount: _formatAmount(_amountCtrl.text.trim()),
        method: _method,
        type: _type,
        reference: _referenceCtrl.text.isNotEmpty ? _referenceCtrl.text.trim() : null,
      );
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
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'deposit', label: Text('Deposit')),
                ButtonSegment(value: 'payment', label: Text('Payment')),
                ButtonSegment(value: 'refund', label: Text('Refund')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
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
                  : Text(_type == 'deposit' ? 'Record Deposit' : _type == 'refund' ? 'Record Refund' : 'Record Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
