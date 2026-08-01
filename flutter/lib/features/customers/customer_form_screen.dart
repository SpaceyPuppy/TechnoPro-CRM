import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/error_view.dart';
import 'customer_repository.dart';
import 'customers_provider.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  bool _initialized = false;
  bool _isBusiness = false;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _companyCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final company = _companyCtrl.text.trim();
      final name = _isBusiness
          ? company
          : [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
      final body = {
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'company': _isBusiness ? company : '',
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_addressCtrl.text.isNotEmpty) 'address': _addressCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      };
      final customerRepo = ref.read(customerRepositoryProvider);
      if (widget.id == null) {
        await customerRepo.create(body);
      } else {
        await customerRepo.update(widget.id!, body);
      }
      ref.invalidate(customerListProvider);
      if (widget.id != null) ref.invalidate(customerDetailProvider(widget.id!));
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

    if (isEdit) {
      final customerAsync = ref.watch(customerDetailProvider(widget.id!));
      if (customerAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (customerAsync.hasError) {
        return Scaffold(body: ErrorView(message: customerAsync.error.toString()));
      }
      if (!_initialized) {
        _initialized = true;
        final c = customerAsync.value!;
        _isBusiness = c.company?.isNotEmpty == true;
        _firstNameCtrl.text = c.firstName ?? (_isBusiness ? '' : c.name);
        _lastNameCtrl.text = c.lastName ?? '';
        _companyCtrl.text = c.company ?? (_isBusiness ? c.name : '');
        _emailCtrl.text = c.email ?? '';
        _phoneCtrl.text = c.phone ?? '';
        _addressCtrl.text = c.address ?? '';
        _notesCtrl.text = c.notes ?? '';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Customer' : 'New Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Individual'), icon: Icon(Icons.person)),
                ButtonSegment(value: true, label: Text('Business'), icon: Icon(Icons.business)),
              ],
              selected: {_isBusiness},
              onSelectionChanged: (values) => setState(() => _isBusiness = values.first),
            ),
            const SizedBox(height: 16),
            if (_isBusiness) ...[
              TextFormField(
                controller: _companyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _isBusiness && (value == null || value.trim().isEmpty)
                    ? 'Business name is required'
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameCtrl,
                    decoration: InputDecoration(
                      labelText: _isBusiness ? 'Contact First Name' : 'First Name *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => !_isBusiness && (value == null || value.trim().isEmpty)
                        ? 'First name is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameCtrl,
                    decoration: InputDecoration(
                      labelText: _isBusiness ? 'Contact Last Name' : 'Last Name',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Primary Address / Service Location',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Save Changes' : 'Create Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
