import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/error_view.dart';
import 'tickets_provider.dart';
import 'widgets/customer_search_section.dart';
import 'widgets/device_section.dart';
import 'widgets/repairs_section.dart';

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

  // — Edit-only fields —
  TicketStatus _status = TicketStatus.new_;
  TicketType _ticketType = TicketType.repair;
  bool _initialized = false;

  // — Create fields —
  CustomerModel? _selectedCustomer;
  final _deviceData = DeviceSectionData();
  final _repairItems = <RepairLineItem>[];

  // — Shared ticket fields —
  TicketPriority _priority = TicketPriority.normal;
  String? _assignedToId;
  DateTime? _scheduledAt;
  DateTime? _dueDate;
  final _summaryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _serviceLocationCtrl = TextEditingController();

  // — Edit-only extra fields —
  final _diagnosisCtrl = TextEditingController();
  final _resolutionCtrl = TextEditingController();

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _descCtrl.dispose();
    _serviceLocationCtrl.dispose();
    _diagnosisCtrl.dispose();
    _resolutionCtrl.dispose();
    super.dispose();
  }

  void _initFromTicket(TicketModel t) {
    if (_initialized) return;
    _initialized = true;
    _status = t.status;
    _ticketType = t.ticketType;
    _priority = t.priority;
    _assignedToId = t.assignedToId;
    _summaryCtrl.text = t.summary;
    _descCtrl.text = t.description ?? '';
    _serviceLocationCtrl.text = t.serviceLocation ?? '';
    _diagnosisCtrl.text = t.diagnosis ?? '';
    _resolutionCtrl.text = t.resolution ?? '';
    _scheduledAt = t.scheduledAt == null ? null : DateTime.parse(t.scheduledAt!).toLocal();
    _dueDate = t.dueDate == null ? null : DateTime.parse(t.dueDate!).toLocal();
  }

  Future<void> _pickDateTime({required bool scheduled}) async {
    final current = scheduled ? _scheduledAt : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        current ?? DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    if (pickedTime == null) return;
    final value = DateTime(
      picked.year,
      picked.month,
      picked.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (scheduled) {
        _scheduledAt = value;
      } else {
        _dueDate = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.id == null;
    if (isNew && _selectedCustomer == null) {
      setState(() => _error = 'Please select or create a customer.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final dio = ref.read(apiClientProvider);

      if (isNew) {
        final body = <String, dynamic>{
          'customerId': _selectedCustomer!.id,
          'ticketType': _ticketType.value,
          'priority': _priority.value,
          'summary': _summaryCtrl.text.trim(),
          if (_assignedToId != null) 'assignedToId': _assignedToId,
          if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
          if (_serviceLocationCtrl.text.isNotEmpty)
            'serviceLocation': _serviceLocationCtrl.text.trim(),
          if (_scheduledAt != null)
            'scheduledAt': _scheduledAt!.toUtc().toIso8601String(),
          if (_dueDate != null)
            'dueDate': _dueDate!.toUtc().toIso8601String(),
        };

        // Device — only include if at least one field is filled
        final hasDevice = _deviceData.model != null ||
            _deviceData.serial != null ||
            _deviceData.imei != null;
        if (hasDevice) {
          body['device'] = {
            if (_deviceData.brand != null) 'brand': _deviceData.brand,
            if (_deviceData.model != null) 'model': _deviceData.model,
            if (_deviceData.serial != null) 'serial': _deviceData.serial,
            if (_deviceData.imei != null) 'imei': _deviceData.imei,
            if (_deviceData.password != null) 'password': _deviceData.password,
            if (_deviceData.patternLock != null)
              'patternLock': _deviceData.patternLock,
            if (_deviceData.storage != null) 'storage': _deviceData.storage,
            if (_deviceData.color != null) 'color': _deviceData.color,
            if (_deviceData.carrier != null) 'carrier': _deviceData.carrier,
          };
        }

        if (_repairItems.isNotEmpty) {
          body['repairs'] = _repairItems.map((r) => r.toJson()).toList();
        }

        await dio.post('/tickets', data: body);
      } else {
        await dio.patch('/tickets/${widget.id}', data: {
          'ticketType': _ticketType.value,
          'status': _status.value,
          'priority': _priority.value,
          'assignedToId': _assignedToId,
          'summary': _summaryCtrl.text.trim(),
          if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
          'serviceLocation': _serviceLocationCtrl.text.trim().isEmpty
              ? null
              : _serviceLocationCtrl.text.trim(),
          if (_diagnosisCtrl.text.isNotEmpty)
            'diagnosis': _diagnosisCtrl.text.trim(),
          if (_resolutionCtrl.text.isNotEmpty)
            'resolution': _resolutionCtrl.text.trim(),
          'scheduledAt': _scheduledAt?.toUtc().toIso8601String(),
          'dueDate': _dueDate?.toUtc().toIso8601String(),
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
    final canManage = ref.watch(authProvider).user?.role.canManage ?? false;

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
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Ticket' : 'New Ticket'),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (!isEdit) ...[
                    // ── Customer ──────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.person_outline,
                      title: 'Customer',
                    ),
                    const SizedBox(height: 10),
                    CustomerSearchSection(
                      onCustomerSelected: (customer) {
                        setState(() {
                          _selectedCustomer = customer;
                          if (_serviceLocationCtrl.text.isEmpty &&
                              customer?.address?.isNotEmpty == true) {
                            _serviceLocationCtrl.text = customer!.address!;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Device ────────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.phone_android_outlined,
                      title: 'Device',
                    ),
                    const SizedBox(height: 10),
                    DeviceSection(data: _deviceData),
                    const SizedBox(height: 24),

                    // ── Repairs ───────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.build_outlined,
                      title: 'Repairs & Parts',
                    ),
                    const SizedBox(height: 10),
                    RepairsSection(items: _repairItems),
                    const SizedBox(height: 24),
                  ],

                  // ── Ticket Details ────────────────────────────────
                  _SectionHeader(
                    icon: Icons.assignment_outlined,
                    title: 'Ticket Details',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _summaryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Summary *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Summary is required' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TicketType>(
                    value: _ticketType,
                    decoration: const InputDecoration(
                      labelText: 'Service Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: TicketType.values
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _ticketType = value!),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _serviceLocationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Service Location (optional)',
                      hintText: 'Customer address, site or remote connection details',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TicketPriority>(
                          value: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: TicketPriority.values
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.label),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _priority = v!),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<TicketStatus>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: TicketStatus.values
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.label),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (canManage) ...[
                    _UsersDropdown(
                      value: _assignedToId,
                      onChanged: (v) => setState(() => _assignedToId = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _DateTimeField(
                    label: 'Scheduled For',
                    value: _scheduledAt,
                    onTap: () => _pickDateTime(scheduled: true),
                    onClear: () => setState(() => _scheduledAt = null),
                  ),
                  const SizedBox(height: 10),
                  _DateTimeField(
                    label: 'Due Date',
                    value: _dueDate,
                    onTap: () => _pickDateTime(scheduled: false),
                    onClear: () => setState(() => _dueDate = null),
                  ),
                  const SizedBox(height: 24),

                  // ── Notes ─────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.notes_outlined,
                    title: 'Notes',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description / intake notes',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 4,
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _diagnosisCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Diagnosis',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _resolutionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Resolution',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Create Ticket'),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? 'Not set'
        : '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/${value!.year} '
            '${value!.hour.toString().padLeft(2, '0')}:'
            '${value!.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          formatted,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: value == null ? Theme.of(context).colorScheme.outline : null,
              ),
        ),
      ),
    );
  }
}

class _UsersDropdown extends ConsumerWidget {
  const _UsersDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    return usersAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (users) => DropdownButtonFormField<String?>(
        value: value,
        decoration: const InputDecoration(
          labelText: 'Assigned To',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Unassigned')),
          ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
