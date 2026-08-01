import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';
import 'tickets_provider.dart';

final ticketChecklistProvider = FutureProvider.autoDispose
    .family<List<TicketChecklistItemModel>, String>((ref, ticketId) async {
  final dio = ref.read(apiClientProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/tickets/$ticketId/checklist',
  );
  return (response.data!['data'] as List)
      .map((item) => TicketChecklistItemModel.fromJson(
            item as Map<String, dynamic>,
          ))
      .toList();
});

class TicketChecklistSection extends ConsumerStatefulWidget {
  const TicketChecklistSection({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<TicketChecklistSection> createState() =>
      _TicketChecklistSectionState();
}

class _TicketChecklistSectionState
    extends ConsumerState<TicketChecklistSection> {
  final _controller = TextEditingController();
  final _busyItems = <String>{};
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(ticketChecklistProvider(widget.ticketId));
    ref.invalidate(ticketEventsProvider(widget.ticketId));
  }

  Future<void> _add() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      await ref.read(apiClientProvider).post(
        '/tickets/${widget.ticketId}/checklist',
        data: {'content': content},
      );
      _controller.clear();
      _refresh();
    } on DioException catch (error) {
      _showError(apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _setCompleted(
    TicketChecklistItemModel item,
    bool completed,
  ) async {
    if (_busyItems.contains(item.id)) return;
    setState(() => _busyItems.add(item.id));
    try {
      await ref.read(apiClientProvider).patch(
        '/tickets/${widget.ticketId}/checklist/${item.id}',
        data: {'completed': completed},
      );
      _refresh();
    } on DioException catch (error) {
      _showError(apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyItems.remove(item.id));
    }
  }

  Future<void> _delete(TicketChecklistItemModel item) async {
    if (_busyItems.contains(item.id)) return;
    setState(() => _busyItems.add(item.id));
    try {
      await ref.read(apiClientProvider).delete(
        '/tickets/${widget.ticketId}/checklist/${item.id}',
      );
      _refresh();
    } on DioException catch (error) {
      _showError(apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyItems.remove(item.id));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(ticketChecklistProvider(widget.ticketId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 500,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      labelText: 'Add a task',
                      border: OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Add task',
                  onPressed: _adding ? null : _add,
                  icon: _adding
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            checklist.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Row(
                children: [
                  Expanded(child: Text('Could not load checklist: $error')),
                  IconButton(
                    tooltip: 'Retry',
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
                ],
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No checklist items'),
                    )
                  : Column(
                      children: items
                          .map(
                            (item) => CheckboxListTile(
                              value: item.completed,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.content,
                                style: item.completed
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                      )
                                    : null,
                              ),
                              onChanged: _busyItems.contains(item.id)
                                  ? null
                                  : (value) => _setCompleted(item, value ?? false),
                              secondary: IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _busyItems.contains(item.id)
                                    ? null
                                    : () => _delete(item),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
