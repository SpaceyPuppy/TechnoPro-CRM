import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/layout_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/empty_state_widget.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final isTouch = ref.watch(touchModeProvider);
    final tier = layoutTier(width, isTouch);

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tier = layoutTier(constraints.maxWidth, isTouch);
          return listState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.read(invoiceListProvider.notifier).refresh(),
            ),
            data: (page) {
              if (page.data.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  message: 'No invoices yet',
                );
              }
              if (tier == LayoutTier.desktop) {
                return _DesktopInvoiceTable(
                  invoices: page.data,
                  selectedId: widget.selectedId,
                  onTap: (inv) => widget.onSelect != null
                      ? widget.onSelect!(inv.id)
                      : context.go('/invoices/${inv.id}'),
                );
              }
              return RefreshIndicator(
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
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/invoices/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Desktop table ---

class _DesktopInvoiceTable extends StatelessWidget {
  const _DesktopInvoiceTable({
    required this.invoices,
    required this.selectedId,
    required this.onTap,
  });

  final List<InvoiceModel> invoices;
  final String? selectedId;
  final void Function(InvoiceModel) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: colorScheme.surfaceContainerHighest.withAlpha(60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(width: 112, child: Text('#', style: headerStyle)),
            SizedBox(width: 100, child: Text('Status', style: headerStyle)),
            SizedBox(width: 100, child: Text('Total', style: headerStyle)),
            SizedBox(width: 100, child: Text('Balance', style: headerStyle)),
            Expanded(child: Text('Date', style: headerStyle)),
          ]),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: ListView.separated(
            itemCount: invoices.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, i) => _DesktopInvoiceRow(
              invoice: invoices[i],
              isSelected: invoices[i].id == selectedId,
              onTap: () => onTap(invoices[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopInvoiceRow extends StatelessWidget {
  const _DesktopInvoiceRow({
    required this.invoice,
    required this.isSelected,
    required this.onTap,
  });

  final InvoiceModel invoice;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateStr = DateFormat('d MMM yy')
        .format(DateTime.parse(invoice.createdAt).toLocal());
    final hasBalance = double.tryParse(invoice.balance) != null &&
        double.parse(invoice.balance) > 0;

    return Material(
      color: isSelected ? colorScheme.primaryContainer.withAlpha(160) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 112,
              child: Text(invoice.invoiceNumber,
                  style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500)),
            ),
            SizedBox(width: 100, child: _StatusChip(status: invoice.status)),
            SizedBox(
              width: 100,
              child: Text('\$${invoice.total}',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            SizedBox(
              width: 100,
              child: Text(
                '\$${invoice.balance}',
                style: textTheme.bodySmall?.copyWith(
                  color: hasBalance ? Colors.red : colorScheme.outline,
                  fontWeight: hasBalance ? FontWeight.w600 : null,
                ),
              ),
            ),
            Expanded(
              child: Text(dateStr,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.outline)),
            ),
          ]),
        ),
      ),
    );
  }
}

// --- Touch/tablet card ---

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard(
      {required this.invoice, required this.onTap, this.isSelected = false});

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

// --- Shared chips ---

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color get _color => switch (status) {
        'draft' => Colors.grey,
        'open' => const Color(0xFF2563EB),
        'paid' => Colors.green,
        'void' => Colors.red,
        _ => Colors.grey,
      };

  String get _label => switch (status) {
        'draft' => 'Draft',
        'open' => 'Open',
        'paid' => 'Paid',
        'void' => 'Void',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_label, style: const TextStyle(fontSize: 11)),
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
