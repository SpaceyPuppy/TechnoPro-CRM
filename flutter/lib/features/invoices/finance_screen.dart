import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/layout_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_view.dart';
import 'invoices_provider.dart';

/// Finance hub: tabbed view with Invoices and Quotes.
/// Used as the list side inside AdaptiveSplitView at /finance.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key, this.selectedId, this.onSelect});

  final String? selectedId;
  final void Function(String id)? onSelect;

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Invoices'),
            Tab(text: 'Quotes'),
          ],
        ),
        actions: [
          _tab.index == 0
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(invoiceListProvider.notifier).refresh(),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(quoteListProvider.notifier).refresh(),
                ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _InvoiceTab(
            selectedId: widget.selectedId,
            onSelect: widget.onSelect,
            isQuoteTab: false,
          ),
          _InvoiceTab(
            selectedId: widget.selectedId,
            onSelect: widget.onSelect,
            isQuoteTab: true,
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) => FloatingActionButton(
          onPressed: () => _tab.index == 0
              ? context.go('/finance/new')
              : context.go('/finance/new?type=quote'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ── Tab content ──────────────────────────────────────────────────────────────

class _InvoiceTab extends ConsumerStatefulWidget {
  const _InvoiceTab({
    required this.selectedId,
    required this.onSelect,
    required this.isQuoteTab,
  });

  final String? selectedId;
  final void Function(String id)? onSelect;
  final bool isQuoteTab;

  @override
  ConsumerState<_InvoiceTab> createState() => _InvoiceTabState();
}

class _InvoiceTabState extends ConsumerState<_InvoiceTab>
    with AutomaticKeepAliveClientMixin {
  String? _statusFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = widget.isQuoteTab ? quoteListProvider : invoiceListProvider;
    final notifier = widget.isQuoteTab
        ? ref.read(quoteListProvider.notifier)
        : ref.read(invoiceListProvider.notifier);
    final listState = ref.watch(provider);
    final width = MediaQuery.sizeOf(context).width;
    final isTouch = ref.watch(touchModeProvider);
    final tier = layoutTier(width, isTouch);

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (!widget.isQuoteTab)
                _StatusFilterChips(
                  value: _statusFilter,
                  onChanged: (s) {
                    setState(() => _statusFilter = s);
                    notifier.fetch(status: s);
                  },
                )
              else
                _QuoteStatusFilterChips(
                  value: _statusFilter,
                  onChanged: (s) {
                    setState(() => _statusFilter = s);
                    notifier.fetch(status: s);
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final t = layoutTier(constraints.maxWidth, isTouch);
              return listState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: notifier.refresh,
                ),
                data: (page) {
                  if (page.data.isEmpty) {
                    return EmptyStateWidget(
                      icon: widget.isQuoteTab
                          ? Icons.request_quote_outlined
                          : Icons.receipt_long_outlined,
                      message: widget.isQuoteTab ? 'No quotes yet' : 'No invoices yet',
                    );
                  }
                  if (t == LayoutTier.desktop) {
                    return _DesktopTable(
                      invoices: page.data,
                      selectedId: widget.selectedId,
                      isQuoteTab: widget.isQuoteTab,
                      onTap: (inv) => widget.onSelect != null
                          ? widget.onSelect!(inv.id)
                          : context.go('/finance/${inv.id}'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      itemCount: page.data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, i) => _FinanceCard(
                        invoice: page.data[i],
                        isSelected: page.data[i].id == widget.selectedId,
                        onTap: () => widget.onSelect != null
                            ? widget.onSelect!(page.data[i].id)
                            : context.go('/finance/${page.data[i].id}'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Desktop table ─────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.invoices,
    required this.selectedId,
    required this.isQuoteTab,
    required this.onTap,
  });

  final List<InvoiceModel> invoices;
  final String? selectedId;
  final bool isQuoteTab;
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
            SizedBox(width: 120, child: Text('#', style: headerStyle)),
            SizedBox(width: 120, child: Text('Status', style: headerStyle)),
            SizedBox(width: 100, child: Text('Total', style: headerStyle)),
            if (!isQuoteTab)
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
            itemBuilder: (context, i) => _DesktopRow(
              invoice: invoices[i],
              isSelected: invoices[i].id == selectedId,
              isQuoteTab: isQuoteTab,
              onTap: () => onTap(invoices[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({
    required this.invoice,
    required this.isSelected,
    required this.isQuoteTab,
    required this.onTap,
  });

  final InvoiceModel invoice;
  final bool isSelected;
  final bool isQuoteTab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateStr =
        DateFormat('d MMM yy').format(DateTime.parse(invoice.createdAt).toLocal());
    final hasBalance = !isQuoteTab &&
        (double.tryParse(invoice.balance) ?? 0) > 0;
    final statusLabel =
        isQuoteTab ? invoice.quoteStatusLabel : invoice.statusLabel;
    final statusColor = _statusColor(isQuoteTab ? (invoice.quoteStatus ?? 'draft') : invoice.status);

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withAlpha(160)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 120,
              child: Text(invoice.invoiceNumber,
                  style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace', fontWeight: FontWeight.w500)),
            ),
            SizedBox(
              width: 120,
              child: _StatusPill(label: statusLabel, color: statusColor),
            ),
            SizedBox(
              width: 100,
              child: Text('\$${invoice.total}',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            if (!isQuoteTab)
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

// ── Touch card ────────────────────────────────────────────────────────────────

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.invoice,
    required this.onTap,
    this.isSelected = false,
  });

  final InvoiceModel invoice;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        invoice.isQuote ? invoice.quoteStatusLabel : invoice.statusLabel;
    final statusColor = _statusColor(
        invoice.isQuote ? (invoice.quoteStatus ?? 'draft') : invoice.status);

    return Card(
      color:
          isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        title: Text(invoice.invoiceNumber),
        subtitle: Text('\$${invoice.total}'
            '${invoice.isInvoice ? ' · Balance: \$${invoice.balance}' : ''}'),
        trailing: _StatusPill(label: statusLabel, color: statusColor),
      ),
    );
  }
}

// ── Shared status pill ────────────────────────────────────────────────────────

Color _statusColor(String status) => switch (status) {
      'draft' => Colors.grey,
      'open' => const Color(0xFF2563EB),
      'paid' => Colors.green,
      'void' => Colors.red,
      'sent' => const Color(0xFF7C3AED),
      'accepted' => Colors.green,
      'declined' => Colors.red,
      _ => Colors.grey,
    };

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [null, 'draft', 'open', 'paid', 'void'];
    final labels = ['All', 'Draft', 'Open', 'Paid', 'Void'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(options.length, (i) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(labels[i], style: const TextStyle(fontSize: 12)),
            selected: value == options[i],
            onSelected: (_) => onChanged(options[i]),
            visualDensity: VisualDensity.compact,
          ),
        )),
      ),
    );
  }
}

class _QuoteStatusFilterChips extends StatelessWidget {
  const _QuoteStatusFilterChips({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [null, 'draft', 'sent', 'accepted', 'declined'];
    final labels = ['All', 'Draft', 'Sent', 'Accepted', 'Declined'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(options.length, (i) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(labels[i], style: const TextStyle(fontSize: 12)),
            selected: value == options[i],
            onSelected: (_) => onChanged(options[i]),
            visualDensity: VisualDensity.compact,
          ),
        )),
      ),
    );
  }
}
