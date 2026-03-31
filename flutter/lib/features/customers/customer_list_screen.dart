import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/layout_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_view.dart';
import 'customers_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key, this.selectedId, this.onSelect});

  final String? selectedId;
  final void Function(String id)? onSelect;

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  late TextEditingController _searchCtrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CustomerModel> _filterCustomers(List<CustomerModel> customers) {
    if (_searchQuery.isEmpty) return customers;
    final query = _searchQuery.toLowerCase();
    return customers.where((c) {
      return c.name.toLowerCase().contains(query) ||
          (c.email?.toLowerCase().contains(query) ?? false) ||
          (c.phone?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isTouch = ref.watch(touchModeProvider);
    final tier = layoutTier(width, isTouch);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(customerListProvider),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tier = layoutTier(constraints.maxWidth, isTouch);
          return customersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(customerListProvider),
            ),
            data: (customers) {
              final filtered = _filterCustomers(customers);
              if (filtered.isEmpty && _searchQuery.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.people_outline,
                  message: 'No customers yet',
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search by name, email, or phone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('No customers match "$_searchQuery"'),
                          )
                        : tier == LayoutTier.desktop
                            ? _DesktopCustomerTable(
                                customers: filtered,
                                selectedId: widget.selectedId,
                                onTap: (c) => widget.onSelect != null
                                    ? widget.onSelect!(c.id)
                                    : context.go('/customers/${c.id}'),
                              )
                            : RefreshIndicator(
                                onRefresh: () async => ref.invalidate(customerListProvider),
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(8),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                                  itemBuilder: (context, i) => _CustomerCard(
                                    customer: filtered[i],
                                    isSelected: filtered[i].id == widget.selectedId,
                                    onTap: () => widget.onSelect != null
                                        ? widget.onSelect!(filtered[i].id)
                                        : context.go('/customers/${filtered[i].id}'),
                                  ),
                                ),
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/customers/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Desktop table ---

class _DesktopCustomerTable extends StatelessWidget {
  const _DesktopCustomerTable({
    required this.customers,
    required this.selectedId,
    required this.onTap,
  });

  final List<CustomerModel> customers;
  final String? selectedId;
  final void Function(CustomerModel) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: colorScheme.surfaceContainerHighest.withAlpha(60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(flex: 2, child: Text('Name', style: headerStyle)),
            Expanded(flex: 2, child: Text('Email', style: headerStyle)),
            SizedBox(width: 140, child: Text('Phone', style: headerStyle)),
            SizedBox(width: 96, child: Text('Added', style: headerStyle)),
          ]),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: customers.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, i) => _DesktopCustomerRow(
              customer: customers[i],
              isSelected: customers[i].id == selectedId,
              onTap: () => onTap(customers[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopCustomerRow extends StatelessWidget {
  const _DesktopCustomerRow({
    required this.customer,
    required this.isSelected,
    required this.onTap,
  });

  final CustomerModel customer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateStr = DateFormat('d MMM yy')
        .format(DateTime.parse(customer.createdAt).toLocal());

    return Material(
      color: isSelected ? colorScheme.primaryContainer.withAlpha(160) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(customer.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
            Expanded(
              flex: 2,
              child: Text(customer.email ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
            SizedBox(
              width: 140,
              child: Text(customer.phone ?? '—',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
            SizedBox(
              width: 96,
              child: Text(dateStr,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.outline)),
            ),
          ]),
        ),
      ),
    );
  }
}

// --- Touch/tablet card ---

class _CustomerCard extends StatelessWidget {
  const _CustomerCard(
      {required this.customer, required this.onTap, this.isSelected = false});

  final CustomerModel customer;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(customer.name[0].toUpperCase())),
        title: Text(customer.name),
        subtitle: Text([
          if (customer.phone != null) customer.phone!,
          if (customer.email != null) customer.email!,
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
