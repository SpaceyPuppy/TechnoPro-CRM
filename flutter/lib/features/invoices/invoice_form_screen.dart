import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../tickets/time_entries_provider.dart';
import '../dashboard/dashboard_provider.dart';
import '../tickets/tickets_provider.dart';
import 'invoice_repository.dart';
import 'invoices_provider.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key, this.ticketId, this.isQuote = false});

  /// Pre-selected ticket when creating from ticket detail screen.
  final String? ticketId;

  /// When true, creates a Quote instead of an Invoice.
  final bool isQuote;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  String? _ticketId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticketId = widget.ticketId;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final id = await invoiceRepo.create(ticketId: _ticketId, isQuote: widget.isQuote);
      if (widget.isQuote) {
        ref.invalidate(quoteListProvider);
      } else {
        ref.invalidate(invoiceListProvider);
      }
      if (_ticketId != null) {
        ref.invalidate(ticketInvoiceProvider(_ticketId!));
        ref.invalidate(timeEntriesProvider(_ticketId!));
      }
      ref.invalidate(dashboardProvider);
      if (mounted) context.go('/finance/$id');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketListProvider);
    final title = widget.isQuote ? 'New Quote' : 'New Invoice';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ticketsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (page) => DropdownButtonFormField<String?>(
              value: _ticketId,
              decoration: const InputDecoration(
                  labelText: 'Link to Ticket (optional)',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('No ticket')),
                ...page.data.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.ticketNumber} — ${t.summary}',
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => setState(() => _ticketId = v),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Create $title'),
          ),
        ],
      ),
    );
  }
}
