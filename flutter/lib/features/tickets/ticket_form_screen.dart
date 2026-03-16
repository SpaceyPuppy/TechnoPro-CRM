import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import '../customers/customers_provider.dart';
import 'tickets_provider.dart';

class TicketFormScreen extends ConsumerStatefulWidget {
  const TicketFormScreen({super.key, this.id});

  /// If set, we're editing an existing ticket. If null, creating new.
  final String? id;

  @override
  ConsumerState<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends ConsumerState<TicketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  // Form fields
  String? _customerId;
  String? _assignedToId;
  TicketStatus _status = TicketStatus.open;
  TicketPriority _priority = TicketPriority.normal;
  final _summaryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _resolutionCtrl = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _descCtrl.dispose();
    _diagnosisCtrl.dispose();
    _resolutionCtrl.dispose();
    super.dispose();
  }

  void _initFromTicket(TicketModel t) {
    if (_initialized) return;
    _initialized = true;
    _customerId = t.customerId;
    _assignedToId = t.assignedToId;
    _status = t.status;
    _priority = t.priority;
    _summaryCtrl.text = t.summary;
    _descCtrl.text = t.description ?? '';
    _diagnosisCtrl.text = t.diagnosis ?? '';
    _resolutionCtrl.text = t.resolution ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dio = ref.read(apiClientProvider);
      if (widget.id == null) {
        // Create
        await dio.post('/tickets', data: {
          'customerId': _customerId,
          if (_assignedToId != null) 'assignedToId': _assignedToId,
          'priority': _priority.value,
          'summary': _summaryCtrl.text.trim(),
          if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        });
      } else {
        // Update
        await dio.patch('/tickets/${widget.id}', data: {
          'status': _status.value,
          'priority': _priority.value,
          'assignedToId': _assignedToId,
          'summary': _summaryCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'diagnosis': _diagnosisCtrl.text.trim(),
          'resolution': _resolutionCtrl.text.trim(),
        });
      }
      ref.invalidate(ticketListProvider);
      if (widget.id != null) ref.invalidate(ticketDetailProvider(widget.id!));
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.id != null;
    final customersAsync = ref.watch(customerListProvider);
    final usersAsync = ref.watch(usersProvider);

    if (isEdit) {
      final ticketAsync = ref.watch(ticketDetailProvider(widget.id!));
      if (ticketAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (ticketAsync.hasError) {
        return Scaffold(body: ErrorView(message: ticketAsync.error.toString()));
      }
      _initFromTicket(ticketAsync.value!);
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Ticket' : 'New Ticket')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer
            customersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load customers: $e'),
              data: (customers) => DropdownButtonFormField<String>(
                value: _customerId,
                decoration: const InputDecoration(labelText: 'Customer *', border: OutlineInputBorder()),
                items: customers
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _customerId = v),
                validator: (v) => v == null ? 'Customer is required' : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _summaryCtrl,
              decoration: const InputDecoration(labelText: 'Summary *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Summary is required' : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<TicketPriority>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                  items: TicketPriority.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TicketStatus>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: TicketStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            usersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (users) => DropdownButtonFormField<String?>(
                value: _assignedToId,
                decoration: const InputDecoration(labelText: 'Assigned To', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                ],
                onChanged: (v) => setState(() => _assignedToId = v),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            if (isEdit) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _diagnosisCtrl,
                decoration: const InputDecoration(labelText: 'Diagnosis', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _resolutionCtrl,
                decoration: const InputDecoration(labelText: 'Resolution', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Save Changes' : 'Create Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
