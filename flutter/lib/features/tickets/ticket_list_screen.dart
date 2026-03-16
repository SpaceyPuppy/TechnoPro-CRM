import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/layout_provider.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_view.dart';
import 'tickets_provider.dart';

class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key, this.selectedId, this.onSelect});

  final String? selectedId;
  final void Function(String id)? onSelect;

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(ticketListProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isTouch = ref.watch(touchModeProvider);
    final tier = layoutTier(width, isTouch);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        actions: [
          _StatusFilterButton(
            value: _statusFilter,
            onChanged: (s) {
              setState(() => _statusFilter = s);
              ref.read(ticketListProvider.notifier).fetch(status: s);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(ticketListProvider.notifier).refresh(),
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
              onRetry: () => ref.read(ticketListProvider.notifier).refresh(),
            ),
            data: (page) {
              if (page.data.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.confirmation_number_outlined,
                  message: 'No tickets found',
                  action: FloatingActionButton.small(
                    onPressed: () => context.go('/tickets/new'),
                    child: const Icon(Icons.add),
                  ),
                );
              }
              if (tier == LayoutTier.desktop) {
                return _DesktopTicketTable(
                  tickets: page.data,
                  selectedId: widget.selectedId,
                  onTap: (t) => widget.onSelect != null
                      ? widget.onSelect!(t.id)
                      : context.go('/tickets/${t.id}'),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(ticketListProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: page.data.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => _TicketCard(
                    ticket: page.data[i],
                    isSelected: page.data[i].id == widget.selectedId,
                    onTap: () => widget.onSelect != null
                        ? widget.onSelect!(page.data[i].id)
                        : context.go('/tickets/${page.data[i].id}'),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/tickets/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Desktop table ---

class _DesktopTicketTable extends StatelessWidget {
  const _DesktopTicketTable({
    required this.tickets,
    required this.selectedId,
    required this.onTap,
  });

  final List<TicketModel> tickets;
  final String? selectedId;
  final void Function(TicketModel) onTap;

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
            SizedBox(width: 88, child: Text('#', style: headerStyle)),
            Expanded(flex: 3, child: Text('Summary', style: headerStyle)),
            SizedBox(width: 80, child: Text('Customer', style: headerStyle)),
            SizedBox(width: 112, child: Text('Status', style: headerStyle)),
            SizedBox(width: 80, child: Text('Priority', style: headerStyle)),
            SizedBox(width: 88, child: Text('Created', style: headerStyle)),
          ]),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: ListView.separated(
            itemCount: tickets.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, i) => _DesktopTicketRow(
              ticket: tickets[i],
              isSelected: tickets[i].id == selectedId,
              onTap: () => onTap(tickets[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopTicketRow extends StatelessWidget {
  const _DesktopTicketRow({
    required this.ticket,
    required this.isSelected,
    required this.onTap,
  });

  final TicketModel ticket;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateStr = DateFormat('d MMM yy')
        .format(DateTime.parse(ticket.createdAt).toLocal());

    return Material(
      color: isSelected ? colorScheme.primaryContainer.withAlpha(160) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 88,
              child: Text(ticket.ticketNumber,
                  style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              flex: 3,
              child: Text(ticket.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium),
            ),
            SizedBox(
              width: 80,
              child: Text(
                ticket.customer?.name ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            SizedBox(width: 112, child: _StatusChip(status: ticket.status)),
            SizedBox(width: 80, child: _PriorityBadge(priority: ticket.priority)),
            SizedBox(
              width: 88,
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

// --- Touch/tablet cards ---

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap, this.isSelected = false});

  final TicketModel ticket;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: _PriorityDot(priority: ticket.priority),
        title: Text(ticket.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${ticket.ticketNumber} · ${ticket.status.label}'),
        trailing: _StatusChip(status: ticket.status),
      ),
    );
  }
}

// --- Shared chips/dots used by both table and cards ---

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final TicketPriority priority;

  Color get _color => switch (priority) {
        TicketPriority.urgent => Colors.red,
        TicketPriority.high => Colors.orange,
        TicketPriority.normal => const Color(0xFF2563EB),
        TicketPriority.low => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final TicketPriority priority;

  Color get _color => switch (priority) {
        TicketPriority.urgent => Colors.red,
        TicketPriority.high => Colors.orange,
        TicketPriority.normal => const Color(0xFF2563EB),
        TicketPriority.low => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(priority.label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: _color)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TicketStatus status;

  Color get _color => switch (status) {
        TicketStatus.open => const Color(0xFF2563EB),
        TicketStatus.inProgress => Colors.orange,
        TicketStatus.waitingParts || TicketStatus.waitingCustomer => Colors.purple,
        TicketStatus.resolved => Colors.green,
        TicketStatus.closed || TicketStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label, style: const TextStyle(fontSize: 11)),
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
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('All statuses')),
        ...TicketStatus.values.map(
          (s) => PopupMenuItem(value: s.value, child: Text(s.label)),
        ),
      ],
    );
  }
}
