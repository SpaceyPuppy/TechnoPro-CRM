import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../shared/widgets/error_view.dart';
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

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
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
      final dio = ref.read(apiClientProvider);
      final body = {
        'name': _nameCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      };
      if (widget.id == null) {
        await dio.post('/customers', data: body);
      } else {
        await dio.patch('/customers/${widget.id}', data: body);
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
        _nameCtrl.text = c.name;
        _emailCtrl.text = c.email ?? '';
        _phoneCtrl.text = c.phone ?? '';
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
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
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
