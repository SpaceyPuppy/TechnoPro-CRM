import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import 'invoices_provider.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key, this.selectedId, this.onSelect});

  final String? selectedId;
  final void Function(String id)? onSelect;

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(invoiceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          _StatusFilterButton(
            value: _statusFilter,
            onChanged: (s) {
              setState(() => _statusFilter = s);
              ref.read(invoiceListProvider.notifier).fetch(status: s);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(invoiceListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: listState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(invoiceListProvider.notifier).refresh(),
        ),
        data: (page) => page.data.isEmpty
            ? const Center(child: Text('No invoices found'))
            : RefreshIndicator(
                onRefresh: () => ref.read(invoiceListProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: page.data.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => _InvoiceCard(
                    invoice: page.data[i],
                    isSelected: page.data[i].id == widget.selectedId,
                    onTap: () => widget.onSelect != null
                        ? widget.onSelect!(page.data[i].id)
                        : context.go('/invoices/${page.data[i].id}'),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/invoices/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap, this.isSelected = false});

  final InvoiceModel invoice;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        title: Text(invoice.invoiceNumber),
        subtitle: Text('\$${invoice.total} · Balance: \$${invoice.balance}'),
        trailing: _StatusChip(status: invoice.status),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color get _color => switch (status) {
        'draft' => Colors.grey,
        'open' => Colors.blue,
        'paid' => Colors.green,
        'void' => Colors.red,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        switch (status) {
          'draft' => 'Draft',
          'open' => 'Open',
          'paid' => 'Paid',
          'void' => 'Void',
          _ => status,
        },
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: _color.withAlpha(30),
      side: BorderSide(color: _color.withAlpha(80)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      icon: Badge(
        isLabelVisible: value != null,
        child: const Icon(Icons.filter_list),
      ),
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: null, child: Text('All statuses')),
        PopupMenuItem(value: 'draft', child: Text('Draft')),
        PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(value: 'paid', child: Text('Paid')),
        PopupMenuItem(value: 'void', child: Text('Void')),
      ],
    );
  }
}
