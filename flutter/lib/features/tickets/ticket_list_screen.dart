import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
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
      body: listState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(ticketListProvider.notifier).refresh(),
        ),
        data: (page) => page.data.isEmpty
            ? const Center(child: Text('No tickets found'))
            : RefreshIndicator(
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
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/tickets/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

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

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final TicketPriority priority;

  Color get _color => switch (priority) {
        TicketPriority.urgent => Colors.red,
        TicketPriority.high => Colors.orange,
        TicketPriority.normal => Colors.blue,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TicketStatus status;

  Color get _color => switch (status) {
        TicketStatus.open => Colors.blue,
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
