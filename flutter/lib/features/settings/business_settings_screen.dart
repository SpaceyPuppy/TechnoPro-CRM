import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';
import 'app_settings_provider.dart';

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String? _savedMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abnCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _initFromSettings(AppSettings s) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = s.businessName;
    _abnCtrl.text = s.businessAbn;
    _addressCtrl.text = s.businessAddress;
    _phoneCtrl.text = s.businessPhone;
    _emailCtrl.text = s.businessEmail;
    _gstCtrl.text = s.gstRate;
    _notesCtrl.text = s.invoiceNotes;
  }

  Future<void> _save() async {
    setState(() { _saving = true; _savedMessage = null; });
    try {
      final dio = ref.read(apiClientProvider);
      await dio.patch<void>('/settings', data: {
        'business_name': _nameCtrl.text.trim(),
        'business_abn': _abnCtrl.text.trim(),
        'business_address': _addressCtrl.text.trim(),
        'business_phone': _phoneCtrl.text.trim(),
        'business_email': _emailCtrl.text.trim(),
        'gst_rate': _gstCtrl.text.trim(),
        'invoice_notes': _notesCtrl.text.trim(),
      });
      ref.invalidate(appSettingsProvider);
      if (mounted) setState(() => _savedMessage = 'Settings saved');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Business & Tax Settings')),
        body: Center(child: Text('Failed to load: $e')),
      ),
      data: (settings) {
        _initFromSettings(settings);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Business & Tax Settings'),
            actions: [
              if (_savedMessage != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      _savedMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel('Business Details'),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _abnCtrl,
                decoration: const InputDecoration(
                  labelText: 'ABN',
                  hintText: 'XX XXX XXX XXX',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel('Tax Settings'),
              const SizedBox(height: 4),
              Text(
                'GST is applied to all invoices and quotes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _gstCtrl,
                decoration: const InputDecoration(
                  labelText: 'GST Rate',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              _SectionLabel('Invoice Defaults'),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Default invoice notes / payment terms',
                  hintText: 'e.g. Payment due on collection. Thank you for your business.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Settings'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }
}
