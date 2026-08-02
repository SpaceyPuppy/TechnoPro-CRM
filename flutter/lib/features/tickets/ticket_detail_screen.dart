import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import '../dashboard/dashboard_provider.dart';
import '../invoices/invoices_provider.dart';
import 'ticket_attachments.dart';
import 'ticket_checklist.dart';
import 'tickets_provider.dart';
import 'widgets/time_entry_widget.dart';

class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(ticketDetailProvider(id));
    final eventsAsync = ref.watch(ticketEventsProvider(id));

    return ticketAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      data: (ticket) => Scaffold(
        appBar: AppBar(
          title: Text(ticket.ticketNumber),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/tickets/$id/edit'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InfoCard(ticket: ticket),
            const SizedBox(height: 16),
            _QuickStatusControl(ticket: ticket),
            const SizedBox(height: 16),
            _InvoiceSection(ticketId: id),
            const SizedBox(height: 16),
            TimeEntryTimerWidget(ticketId: id),
            const SizedBox(height: 16),
            TicketChecklistSection(ticketId: id),
            const SizedBox(height: 16),
            TicketAttachmentsSection(ticketId: id),
            const SizedBox(height: 16),
            _AddNoteCard(ticketId: id, onAdded: () {
              ref.invalidate(ticketEventsProvider(id));
            }),
            const SizedBox(height: 16),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (events) => events.isEmpty
                  ? const Text('No events yet')
                  : Column(
                      children: events
                          .map((e) => _EventTile(event: e))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatusControl extends ConsumerStatefulWidget {
  const _QuickStatusControl({required this.ticket});

  final TicketModel ticket;

  @override
  ConsumerState<_QuickStatusControl> createState() => _QuickStatusControlState();
}

class _QuickStatusControlState extends ConsumerState<_QuickStatusControl> {
  bool _updating = false;

  bool _isTerminal(TicketStatus status) =>
      status == TicketStatus.resolved ||
      status == TicketStatus.closed ||
      status == TicketStatus.cancelled;

  Future<bool> _confirmTerminalTransition(TicketStatus status) async {
    final action = status == TicketStatus.resolved ? 'resolve' : status.label.toLowerCase();
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${status.label} ticket?'),
            content: Text(
              'Are you sure you want to $action ${widget.ticket.ticketNumber}? '
              'This is a terminal ticket status.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(status == TicketStatus.resolved ? 'Resolve' : status.label),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _setStatus(TicketStatus status) async {
    if (_updating || status == widget.ticket.status) return;
    if (_isTerminal(status) && !(await _confirmTerminalTransition(status))) return;

    setState(() => _updating = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.patch<void>(
        '/tickets/${widget.ticket.id}',
        data: {'status': status.value},
      );
      ref.invalidate(ticketDetailProvider(widget.ticket.id));
      ref.invalidate(ticketEventsProvider(widget.ticket.id));
      ref.read(ticketListProvider.notifier).refresh();
      ref.read(dashboardProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket marked ${status.label.toLowerCase()}')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update ticket: ${apiErrorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canChangeStatus = ref.watch(authProvider).user?.role.canTech ?? false;
    if (!canChangeStatus) return const SizedBox.shrink();

    final canResolve = widget.ticket.status != TicketStatus.resolved &&
        widget.ticket.status != TicketStatus.closed &&
        widget.ticket.status != TicketStatus.cancelled;
    final canClose = widget.ticket.status != TicketStatus.closed &&
        widget.ticket.status != TicketStatus.cancelled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(label: Text(widget.ticket.status.label)),
                const Spacer(),
                PopupMenuButton<TicketStatus>(
                  enabled: !_updating,
                  tooltip: 'Change status',
                  onSelected: _setStatus,
                  itemBuilder: (_) => TicketStatus.values
                      .where((status) => status != widget.ticket.status)
                      .map(
                        (status) => PopupMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 18),
                        SizedBox(width: 4),
                        Text('Change'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (canResolve || canClose) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canResolve)
                    FilledButton.icon(
                      onPressed: _updating ? null : () => _setStatus(TicketStatus.resolved),
                      icon: const Icon(Icons.task_alt, size: 18),
                      label: const Text('Resolve'),
                    ),
                  if (canClose)
                    OutlinedButton.icon(
                      onPressed: _updating ? null : () => _setStatus(TicketStatus.closed),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.ticket});
  final TicketModel ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ticket.summary, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _Row('Type', ticket.ticketType.label),
            _Row('Status', ticket.status.label),
            _Row('Priority', ticket.priority.label),
            if (ticket.customer != null) _Row('Customer', ticket.customer!.name),
            if (ticket.device != null)
              _Row('Device', ticket.device!.displayName),
            if (ticket.assignedTo != null)
              _Row('Assigned To', ticket.assignedTo!.name),
            if (ticket.scheduledAt != null)
              _Row('Scheduled', _formatDateTime(ticket.scheduledAt!)),
            if (ticket.dueDate != null) _Row('Due', _formatDateTime(ticket.dueDate!)),
            if (ticket.serviceLocation?.isNotEmpty == true)
              _Row('Location', ticket.serviceLocation!),
            if (ticket.description != null && ticket.description!.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Description', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(ticket.description!),
            ],
            if (ticket.diagnosis != null && ticket.diagnosis!.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Diagnosis', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(ticket.diagnosis!),
            ],
            if (ticket.resolution != null && ticket.resolution!.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Resolution', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(ticket.resolution!),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String value) {
    final date = DateTime.parse(value).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _AddNoteCard extends ConsumerStatefulWidget {
  const _AddNoteCard({required this.ticketId, required this.onAdded});
  final String ticketId;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends ConsumerState<_AddNoteCard> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/tickets/${widget.ticketId}/notes', data: {
        'content': _ctrl.text.trim(),
      });
      _ctrl.clear();
      widget.onAdded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Add a note…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceSection extends ConsumerWidget {
  const _InvoiceSection({required this.ticketId});
  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCounter = ref.watch(authProvider).user?.role.canCounter ?? false;
    if (!canCounter) return const SizedBox.shrink();
    final invoiceAsync = ref.watch(ticketInvoiceProvider(ticketId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Invoice', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            invoiceAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (invoice) => invoice == null
                  ? TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Invoice'),
                      onPressed: () =>
                          context.go('/finance/new?ticketId=$ticketId'),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        invoiceAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed to load invoice: $e'),
          data: (invoice) => invoice == null
              ? const Text('No invoice for this ticket',
                  style: TextStyle(color: Colors.grey))
              : Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text(invoice.invoiceNumber),
                    subtitle: Text(
                        'Total: \$${invoice.total} · Balance: \$${invoice.balance}'),
                    trailing: Chip(
                      label: Text(invoice.statusLabel,
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onTap: () => context.go('/finance/${invoice.id}'),
                  ),
                ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final TicketEventModel event;

  IconData get _icon => switch (event.eventType) {
        TicketEventType.note => Icons.comment_outlined,
        TicketEventType.statusChange => Icons.swap_horiz,
        TicketEventType.assignment => Icons.person_outline,
        TicketEventType.system => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icon, size: 20),
      title: Text(event.content ?? event.eventType.value),
      subtitle: Text(
        [
          if (event.user != null) event.user!.name,
          event.createdAt,
        ].join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      dense: true,
    );
  }
}
