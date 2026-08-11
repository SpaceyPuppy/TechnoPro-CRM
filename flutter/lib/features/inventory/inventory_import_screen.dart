import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/prism_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import 'inventory_provider.dart';

class InventoryImportScreen extends ConsumerStatefulWidget {
  const InventoryImportScreen({super.key});
  @override
  ConsumerState<InventoryImportScreen> createState() => _InventoryImportScreenState();
}

class _InventoryImportScreenState extends ConsumerState<InventoryImportScreen> {
  List<Map<String, dynamic>> _rows = const [];
  List<dynamic> _preview = const [];
  bool _busy = false;
  String? _error;
  final _reason = TextEditingController(text: 'initial catalogue import');

  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  Future<void> _pickCsv() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (picked == null || picked.files.single.bytes == null) return;
    final lines = const LineSplitter().convert(utf8.decode(picked.files.single.bytes!)).where((line) => line.trim().isNotEmpty).toList();
    if (lines.length < 2) { setState(() => _error = 'The CSV needs a header and at least one item row.'); return; }
    final headers = _csvLine(lines.first);
    final rows = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final values = _csvLine(line);
      final row = <String, dynamic>{};
      for (var index = 0; index < headers.length; index++) { row[headers[index]] = index < values.length ? values[index] : ''; }
      if ((row['stockQty'] as String?)?.trim().isNotEmpty == true) row['stockQty'] = int.tryParse(row['stockQty'] as String);
      rows.add(row);
    }
    setState(() { _rows = rows; _preview = const []; _error = null; });
    await _runPreview();
  }

  List<String> _csvLine(String line) {
    final values = <String>[]; var value = ''; var quoted = false;
    for (var i = 0; i < line.length; i++) { final char = line[i]; if (char == '"') { if (quoted && i + 1 < line.length && line[i + 1] == '"') { value += char; i++; } else { quoted = !quoted; } } else if (char == ',' && !quoted) { values.add(value.trim()); value = ''; } else { value += char; } }
    values.add(value.trim()); return values;
  }

  Future<void> _runPreview() async {
    if (_rows.isEmpty) return;
    setState(() => _busy = true);
    try { final response = await ref.read(apiClientProvider).post<Map<String, dynamic>>('/inventory/import/preview', data: {'rows': _rows}); setState(() => _preview = response.data?['data']?['rows'] as List? ?? const []); }
    catch (error) { setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _commit() async {
    if (_preview.any((row) => ((row['errors'] as List?) ?? const []).isNotEmpty) || _reason.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post('/inventory/import', data: {'rows': _rows, 'openingBalanceReason': _reason.text.trim(), 'confirmed': true, 'importReference': 'csv-${DateTime.now().millisecondsSinceEpoch}'});
      ref.invalidate(inventoryListProvider); if (mounted) context.pop();
    } catch (error) { setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const PrismAppBar(title: Text('Import inventory CSV')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Use columns: sku, name, price, cost, stockQty, description, barcode, upc, brand, category, supplierId, supplierSku.'),
      const SizedBox(height: 16), OutlinedButton.icon(onPressed: _busy ? null : _pickCsv, icon: const Icon(Icons.upload_file), label: const Text('Choose CSV and preview')),
      if (_rows.isNotEmpty) ...[const SizedBox(height: 16), Text('${_rows.length} rows loaded'), TextFormField(controller: _reason, decoration: const InputDecoration(labelText: 'Opening-balance reason *', border: OutlineInputBorder()))],
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (_preview.isNotEmpty) ...[const SizedBox(height: 16), const Text('Preview'), ..._preview.take(50).map((row) => ListTile(title: Text('${row['action']}: ${row['sku']}'), subtitle: Text(((row['errors'] as List?) ?? const []).join('; ')))), if (_preview.length > 50) Text('${_preview.length - 50} more rows'), const SizedBox(height: 16), FilledButton(onPressed: _busy || _preview.any((row) => ((row['errors'] as List?) ?? const []).isNotEmpty) ? null : _commit, child: _busy ? const CircularProgressIndicator() : const Text('Confirm import'))],
    ]),
  );
}
