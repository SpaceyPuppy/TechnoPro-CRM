import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';
import 'device_models_provider.dart';

class DeviceModelsScreen extends ConsumerWidget {
  const DeviceModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(deviceModelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Models')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        tooltip: 'Add model',
        child: const Icon(Icons.add),
      ),
      body: modelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (models) {
          if (models.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('No device models yet',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text('Tap + to add your first model',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
                ],
              ),
            );
          }

          // Group by manufacturer
          final grouped = <String, List<DeviceModelEntry>>{};
          for (final m in models) {
            grouped.putIfAbsent(m.manufacturer, () => []).add(m);
          }
          final manufacturers = grouped.keys.toList()..sort();

          return ListView.builder(
            itemCount: manufacturers.length,
            itemBuilder: (context, i) {
              final mfr = manufacturers[i];
              final items = grouped[mfr]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      mfr,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  ...items.map(
                    (model) => ListTile(
                      title: Text(model.name),
                      dense: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () =>
                                _showEditDialog(context, ref, model),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.error),
                            onPressed: () =>
                                _confirmDelete(context, ref, model),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < manufacturers.length - 1)
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String manufacturer, String name})>(
      context: context,
      builder: (_) => const _DeviceModelDialog(),
    );
    if (result == null) return;
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post<void>('/settings/device-models', data: {
        'manufacturer': result.manufacturer,
        'name': result.name,
      });
      ref.invalidate(deviceModelsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add model: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, DeviceModelEntry model) async {
    final result = await showDialog<({String manufacturer, String name})>(
      context: context,
      builder: (_) => _DeviceModelDialog(
        initialManufacturer: model.manufacturer,
        initialName: model.name,
      ),
    );
    if (result == null) return;
    try {
      final dio = ref.read(apiClientProvider);
      await dio.patch<void>('/settings/device-models/${model.id}', data: {
        'manufacturer': result.manufacturer,
        'name': result.name,
      });
      ref.invalidate(deviceModelsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update model: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DeviceModelEntry model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete model?'),
        content: Text('Delete "${model.manufacturer} ${model.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ref.read(apiClientProvider);
      await dio.delete<void>('/settings/device-models/${model.id}');
      ref.invalidate(deviceModelsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

class _DeviceModelDialog extends StatefulWidget {
  const _DeviceModelDialog({this.initialManufacturer, this.initialName});

  final String? initialManufacturer;
  final String? initialName;

  @override
  State<_DeviceModelDialog> createState() => _DeviceModelDialogState();
}

class _DeviceModelDialogState extends State<_DeviceModelDialog> {
  late final _mfrCtrl =
      TextEditingController(text: widget.initialManufacturer ?? '');
  late final _nameCtrl =
      TextEditingController(text: widget.initialName ?? '');

  @override
  void dispose() {
    _mfrCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialName != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Model' : 'Add Model'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _mfrCtrl,
            decoration: const InputDecoration(
              labelText: 'Manufacturer *',
              hintText: 'e.g. Apple',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: !isEdit,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Model Name *',
              hintText: 'e.g. iPhone 15 Pro',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: isEdit,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final mfr = _mfrCtrl.text.trim();
            final name = _nameCtrl.text.trim();
            if (mfr.isEmpty || name.isEmpty) return;
            Navigator.pop(context, (manufacturer: mfr, name: name));
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
