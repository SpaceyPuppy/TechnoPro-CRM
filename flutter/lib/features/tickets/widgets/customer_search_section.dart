import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';

class CustomerSearchSection extends ConsumerStatefulWidget {
  const CustomerSearchSection({
    super.key,
    required this.onCustomerSelected,
  });

  final void Function(CustomerModel?) onCustomerSelected;

  @override
  ConsumerState<CustomerSearchSection> createState() => _CustomerSearchSectionState();
}

class _CustomerSearchSectionState extends ConsumerState<CustomerSearchSection> {
  CustomerModel? _selected;
  bool _showNewForm = false;
  bool _searching = false;
  List<CustomerModel> _results = [];
  Timer? _debounce;
  final _searchLink = LayerLink();
  final _searchFieldKey = GlobalKey();
  final _searchFocusNode = FocusNode();
  OverlayEntry? _resultsOverlay;
  bool _inlineResultsVisible = false;

  final _searchController = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  bool _savingNew = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _removeResultsOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      _removeResultsOverlay();
      return;
    }
    _removeResultsOverlay();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dio.get<Map<String, dynamic>>('/customers', queryParameters: {
        'search': q,
        'pageSize': 10,
      });
      final page = PaginatedResponse.fromJson(res.data!, CustomerModel.fromJson);
      if (!mounted || _searchController.text.trim() != q) return;
      setState(() => _results = page.data);
      _showResultsOverlay();
    } catch (_) {
      if (mounted && _searchController.text.trim() == q) {
        setState(() => _results = []);
        _showResultsOverlay();
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _createNewCustomer() async {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    if (first.isEmpty && last.isEmpty) return;

    setState(() => _savingNew = true);
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dio.post<Map<String, dynamic>>('/customers', data: {
        'firstName': first.isNotEmpty ? first : null,
        'lastName': last.isNotEmpty ? last : null,
        'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        'company': _companyCtrl.text.trim().isNotEmpty ? _companyCtrl.text.trim() : null,
      });
      final customer = CustomerModel.fromJson(res.data!['data'] as Map<String, dynamic>);
      if (mounted) {
        setState(() {
          _selected = customer;
          _showNewForm = false;
        });
        widget.onCustomerSelected(customer);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create customer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNew = false);
    }
  }

  void _selectCustomer(CustomerModel c) {
    setState(() {
      _selected = c;
      _searchController.clear();
      _results = [];
    });
    _removeResultsOverlay();
    widget.onCustomerSelected(c);
  }

  void _clearSelection() {
    setState(() => _selected = null);
    widget.onCustomerSelected(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _removeResultsOverlay() {
    _resultsOverlay?.remove();
    _resultsOverlay = null;
  }

  void _showResultsOverlay() {
    final overlay = Overlay.of(context);
    if (_resultsOverlay == null) {
      _resultsOverlay = OverlayEntry(builder: (_) => _buildResultsOverlay());
      overlay.insert(_resultsOverlay!);
    } else {
      _resultsOverlay!.markNeedsBuild();
    }
  }

  Widget _buildResultsOverlay() {
    final renderBox = _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? MediaQuery.sizeOf(context).width - 32;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CompositedTransformFollower(
      link: _searchLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No customers found — create a new one',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (context, i) {
                      final customer = _results[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            customer.displayName.isNotEmpty
                                ? customer.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                          ),
                        ),
                        title: Text(customer.displayName),
                        subtitle: customer.phone == null ? null : Text(customer.phone!),
                        onTap: () => _selectCustomer(customer),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selected != null) ...[
          _SelectedCustomerCard(
            customer: _selected!,
            onClear: _clearSelection,
          ),
        ] else if (_showNewForm) ...[
          _NewCustomerForm(
            firstNameCtrl: _firstNameCtrl,
            lastNameCtrl: _lastNameCtrl,
            phoneCtrl: _phoneCtrl,
            emailCtrl: _emailCtrl,
            companyCtrl: _companyCtrl,
            saving: _savingNew,
            onSave: _createNewCustomer,
            onCancel: () => setState(() => _showNewForm = false),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: CompositedTransformTarget(
                  link: _searchLink,
                  child: TextField(
                    key: _searchFieldKey,
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                    hintText: 'Search by name, phone, or email…',
                    prefixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showNewForm = true;
                    _searchController.clear();
                    _results = [];
                  });
                  _removeResultsOverlay();
                },
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
          if (_inlineResultsVisible && _results.isNotEmpty) ...[
            const SizedBox(height: 4),
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, i) {
                    final c = _results[i];
                    return InkWell(
                      onTap: () => _selectCustomer(c),
                      borderRadius: i == 0
                          ? const BorderRadius.vertical(top: Radius.circular(8))
                          : i == _results.length - 1
                              ? const BorderRadius.vertical(bottom: Radius.circular(8))
                              : BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                c.displayName.isNotEmpty
                                    ? c.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.displayName,
                                      style: textTheme.bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w500)),
                                  if (c.phone != null)
                                    Text(c.phone!,
                                        style: textTheme.bodySmall
                                            ?.copyWith(color: colorScheme.outline)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else if (_inlineResultsVisible && _results.isEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No customers found — create a new one',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  const _SelectedCustomerCard({required this.customer, required this.onClear});

  final CustomerModel customer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              customer.displayName.isNotEmpty
                  ? customer.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (customer.company != null)
                  Text(customer.company!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.outline)),
                if (customer.phone != null)
                  Text(customer.phone!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.outline)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
            tooltip: 'Remove customer',
          ),
        ],
      ),
    );
  }
}

class _NewCustomerForm extends StatelessWidget {
  const _NewCustomerForm({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.companyCtrl,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController companyCtrl;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Customer',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: companyCtrl,
            decoration: const InputDecoration(
              labelText: 'Company',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Customer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
