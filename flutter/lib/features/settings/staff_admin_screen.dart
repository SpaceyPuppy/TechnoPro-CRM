import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

final staffListProvider = FutureProvider<List<UserModel>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/users',
    queryParameters: {'includeInactive': 'true'},
  );
  final rows = response.data?['data'] as List<dynamic>? ?? const [];
  return rows
      .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
      .toList();
});

class StaffAdminScreen extends ConsumerWidget {
  const StaffAdminScreen({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    UserModel? user,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StaffEditor(user: user),
    );
    if (saved == true) ref.invalidate(staffListProvider);
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    bool active,
  ) async {
    try {
      await ref.read(apiClientProvider).patch(
        '/users/${user.id}',
        data: {'active': active},
      );
      ref.invalidate(staffListProvider);
    } on DioException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Administration'),
        actions: [IconButton(onPressed: () => _openEditor(context, ref), tooltip: 'Add staff', icon: const Icon(Icons.person_add_outlined))],
      ),
      body: staff.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(staffListProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry: $error'),
          ),
        ),
        data: (users) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(staffListProvider);
            await ref.read(staffListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase()),
                ),
                title: Text(user.name),
                subtitle: Text('${user.email}\n${_roleLabel(user.role)}'),
                isThreeLine: true,
                trailing: Switch(
                  value: user.active,
                  onChanged: (active) => _setActive(context, ref, user, active),
                ),
                onTap: () => _openEditor(context, ref, user: user),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _roleLabel(UserRole role) => switch (role) {
      UserRole.technician => 'Technician',
      UserRole.counter => 'Counter',
      UserRole.manager => 'Manager',
      UserRole.admin => 'Administrator',
    };

class _StaffEditor extends ConsumerStatefulWidget {
  const _StaffEditor({this.user});

  final UserModel? user;

  @override
  ConsumerState<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends ConsumerState<_StaffEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  late UserRole _role;
  bool _saving = false;

  bool get _isNew => widget.user == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _role = widget.user?.role ?? UserRole.technician;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _role.value,
        if (_passwordController.text.isNotEmpty)
          'password': _passwordController.text,
      };
      final dio = ref.read(apiClientProvider);
      if (_isNew) {
        await dio.post('/users', data: data);
      } else {
        await dio.patch('/users/${widget.user!.id}', data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? 'Add Staff Member' : 'Edit Staff Member',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: UserRole.values
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(_roleLabel(role)),
                      ))
                  .toList(),
              onChanged: (role) => setState(() => _role = role!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _isNew ? 'Temporary Password' : 'New Password (optional)',
                helperText: 'At least 12 characters',
              ),
              validator: (value) {
                if (_isNew && (value == null || value.length < 12)) {
                  return 'Password must be at least 12 characters';
                }
                if (!_isNew && value != null && value.isNotEmpty && value.length < 12) {
                  return 'Password must be at least 12 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isNew ? 'Create Account' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
