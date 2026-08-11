import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/procurement_repository.dart';
import 'procurement_provider.dart';
import '../../shared/models/models.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {SupplierModel? supplier}) async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SupplierEditor(supplier: supplier),
    );
    if (payload == null) return;
    try {
      final repository = ref.read(procurementRepositoryProvider);
      if (supplier == null) {
        await repository.createSupplier(payload);
      } else {
        await repository.updateSupplier(supplier.id, payload);
      }
      ref.invalidate(suppliersProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save supplier: $error')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, SupplierModel supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete supplier?'),
        content: Text('Delete "${supplier.name}"? Suppliers attached to purchase orders cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(procurementRepositoryProvider).deleteSupplier(supplier.id);
      ref.invalidate(suppliersProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete supplier: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New supplier',
            onPressed: () => _openEditor(context, ref),
          ),
        ],
      ),
      body: suppliers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(suppliersProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry: $error'),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    const Text('No suppliers yet'),
                    const SizedBox(height: 8),
                    FilledButton.icon(onPressed: () => _openEditor(context, ref), icon: const Icon(Icons.add), label: const Text('Add supplier')),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(suppliersProvider),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final supplier = items[index];
                    final details = [supplier.contactName, supplier.phone, supplier.email].whereType<String>().where((value) => value.isNotEmpty).join(' - ');
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                      title: Text(supplier.name),
                      subtitle: Text(details.isEmpty ? 'No contact details' : details),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit supplier', onPressed: () => _openEditor(context, ref, supplier: supplier)),
                          IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), tooltip: 'Delete supplier', onPressed: () => _confirmDelete(context, ref, supplier)),
                        ],
                      ),
                      onTap: () => _openEditor(context, ref, supplier: supplier),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _SupplierEditor extends StatefulWidget {
  const _SupplierEditor({this.supplier});
  final SupplierModel? supplier;

  @override
  State<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<_SupplierEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.supplier?.name ?? '');
  late final _contact = TextEditingController(text: widget.supplier?.contactName ?? '');
  late final _email = TextEditingController(text: widget.supplier?.email ?? '');
  late final _phone = TextEditingController(text: widget.supplier?.phone ?? '');
  late final _account = TextEditingController(text: widget.supplier?.accountNumber ?? '');
  late final _leadTime = TextEditingController(text: widget.supplier?.leadTimeDays?.toString() ?? '');
  late final _notes = TextEditingController(text: widget.supplier?.notes ?? '');

  @override
  void dispose() {
    _name.dispose(); _contact.dispose(); _email.dispose(); _phone.dispose(); _account.dispose(); _leadTime.dispose(); _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'contactName': _contact.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'accountNumber': _account.text.trim(),
      'leadTimeDays': _leadTime.text.trim().isEmpty ? null : int.parse(_leadTime.text.trim()),
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.supplier != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(children: [Text(editing ? 'Edit supplier' : 'New supplier', style: Theme.of(context).textTheme.titleLarge), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
            const SizedBox(height: 16),
            TextFormField(controller: _name, autofocus: !editing, decoration: const InputDecoration(labelText: 'Supplier name *', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Supplier name is required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), validator: (value) => value != null && value.isNotEmpty && !value.contains('@') ? 'Enter a valid email address' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _account, decoration: const InputDecoration(labelText: 'Account number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _leadTime, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lead time (days)', border: OutlineInputBorder()), validator: (value) => value != null && value.isNotEmpty && int.tryParse(value) == null ? 'Enter whole days' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(editing ? 'Save changes' : 'Create supplier')),
          ],
        ),
      ),
    );
  }
}
