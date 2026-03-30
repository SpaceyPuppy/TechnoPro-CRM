import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../settings/device_models_provider.dart';
import 'pattern_lock_widget.dart';

class DeviceSectionData {
  String? brand;
  String? model;
  String? serial;
  String? imei;
  String? password;
  String? patternLock;
  String? storage;
  String? color;
  String? carrier;
}

class DeviceSection extends ConsumerStatefulWidget {
  const DeviceSection({super.key, required this.data});

  final DeviceSectionData data;

  @override
  ConsumerState<DeviceSection> createState() => _DeviceSectionState();
}

class _DeviceSectionState extends ConsumerState<DeviceSection> {
  final _serialCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _storageCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _carrierCtrl = TextEditingController();
  final _modelSearchCtrl = TextEditingController();

  bool _showPassword = false;
  bool _showAdditional = false;
  bool _modelDropdownVisible = false;
  List<DeviceModelEntry> _filteredModels = [];

  @override
  void dispose() {
    _serialCtrl.dispose();
    _imeiCtrl.dispose();
    _passwordCtrl.dispose();
    _storageCtrl.dispose();
    _colorCtrl.dispose();
    _carrierCtrl.dispose();
    _modelSearchCtrl.dispose();
    super.dispose();
  }

  void _onModelSearch(String q, List<DeviceModelEntry> allModels) {
    if (q.trim().isEmpty) {
      setState(() { _filteredModels = []; _modelDropdownVisible = false; });
      return;
    }
    final lower = q.toLowerCase();
    setState(() {
      _filteredModels = allModels
          .where((m) => m.displayName.toLowerCase().contains(lower))
          .take(12)
          .toList();
      _modelDropdownVisible = true;
    });
  }

  void _selectModel(DeviceModelEntry m) {
    _modelSearchCtrl.text = m.displayName;
    widget.data.brand = m.manufacturer;
    widget.data.model = m.name;
    setState(() { _filteredModels = []; _modelDropdownVisible = false; });
  }

  Future<void> _showPatternLock() async {
    final result = await showPatternLockDialog(
      context,
      initialPattern: widget.data.patternLock,
    );
    if (result != null) {
      setState(() => widget.data.patternLock = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsAsync = ref.watch(deviceModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Model search
        modelsAsync.when(
          loading: () => const TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Loading device models…',
              prefixIcon: Icon(Icons.phone_android_outlined, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          error: (_, __) => TextField(
            controller: _modelSearchCtrl,
            onChanged: (q) => setState(() {
              widget.data.brand = null;
              widget.data.model = q.trim().isNotEmpty ? q.trim() : null;
            }),
            decoration: const InputDecoration(
              labelText: 'Device Model',
              prefixIcon: Icon(Icons.phone_android_outlined, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          data: (models) => Column(
            children: [
              TextField(
                controller: _modelSearchCtrl,
                onChanged: (q) {
                  _onModelSearch(q, models);
                  if (q.trim().isEmpty) {
                    widget.data.brand = null;
                    widget.data.model = null;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Device Model',
                  hintText: 'Search model…',
                  prefixIcon: Icon(Icons.phone_android_outlined, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_modelDropdownVisible && _filteredModels.isNotEmpty) ...[
                const SizedBox(height: 4),
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredModels.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: colorScheme.outlineVariant),
                      itemBuilder: (context, i) {
                        final m = _filteredModels[i];
                        return InkWell(
                          onTap: () => _selectModel(m),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: Theme.of(context).textTheme.bodyMedium),
                                Text(m.manufacturer,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colorScheme.outline)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _serialCtrl,
                onChanged: (v) => widget.data.serial = v.trim().isNotEmpty ? v.trim() : null,
                decoration: const InputDecoration(
                  labelText: 'Serial Number',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _imeiCtrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => widget.data.imei = v.trim().isNotEmpty ? v.trim() : null,
                decoration: const InputDecoration(
                  labelText: 'IMEI',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                onChanged: (v) =>
                    widget.data.password = v.trim().isNotEmpty ? v.trim() : null,
                decoration: InputDecoration(
                  labelText: 'Password / PIN',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _showPatternLock,
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(
                widget.data.patternLock != null ? 'Pattern Set' : 'Pattern Lock',
              ),
              style: widget.data.patternLock != null
                  ? OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                    )
                  : null,
            ),
          ],
        ),
        if (widget.data.patternLock != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              PatternLockDisplay(pattern: widget.data.patternLock!),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => widget.data.patternLock = null),
                child: const Text('Remove Pattern'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        // Additional info expandable
        InkWell(
          onTap: () => setState(() => _showAdditional = !_showAdditional),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _showAdditional
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  'Additional Info (storage, color, carrier)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
        if (_showAdditional) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _storageCtrl,
                  onChanged: (v) =>
                      widget.data.storage = v.trim().isNotEmpty ? v.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Storage',
                    hintText: '128GB',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _colorCtrl,
                  onChanged: (v) =>
                      widget.data.color = v.trim().isNotEmpty ? v.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _carrierCtrl,
                  onChanged: (v) =>
                      widget.data.carrier = v.trim().isNotEmpty ? v.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Carrier',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
