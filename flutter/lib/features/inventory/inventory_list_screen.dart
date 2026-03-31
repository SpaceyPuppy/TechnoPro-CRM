import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/layout_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_view.dart';
import 'inventory_provider.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key, this.selectedId, this.onSelect});

  final String? selectedId;
  final void Function(String id)? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryListProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isTouch = ref.watch(touchModeProvider);
    final tier = layoutTier(width, isTouch);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(inventoryListProvider),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tier = layoutTier(constraints.maxWidth, isTouch);
          return inventoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(inventoryListProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  message: 'No inventory items yet',
                );
              }
              if (tier == LayoutTier.desktop) {
                return _DesktopInventoryTable(
                  items: items,
                  selectedId: selectedId,
                  onTap: (item) => onSelect != null
                      ? onSelect!(item.id)
                      : context.go('/inventory/${item.id}'),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(inventoryListProvider),
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => _InventoryCard(
                    item: items[i],
                    isSelected: items[i].id == selectedId,
                    onTap: () => onSelect != null
                        ? onSelect!(items[i].id)
                        : context.go('/inventory/${items[i].id}'),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/inventory/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Desktop table ---

class _DesktopInventoryTable extends StatelessWidget {
  const _DesktopInventoryTable({
    required this.items,
    required this.selectedId,
    required this.onTap,
  });

  final List<InventoryItemModel> items;
  final String? selectedId;
  final void Function(InventoryItemModel) onTap;

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
            SizedBox(width: 120, child: Text('SKU', style: headerStyle)),
            Expanded(child: Text('Name', style: headerStyle)),
            SizedBox(width: 100, child: Text('Price', style: headerStyle)),
            SizedBox(width: 120, child: Text('Stock', style: headerStyle)),
          ]),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, i) => _DesktopInventoryRow(
              item: items[i],
              isSelected: items[i].id == selectedId,
              onTap: () => onTap(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopInventoryRow extends StatelessWidget {
  const _DesktopInventoryRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final InventoryItemModel item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final stockLabel = item.stockQty == null
        ? 'Untracked'
        : item.stockQty == 0
            ? 'Out of stock'
            : '${item.stockQty} in stock';
    final stockColor = item.stockQty == null
        ? colorScheme.outline
        : item.stockQty == 0
            ? Colors.red
            : Colors.green;

    return Material(
      color: isSelected ? colorScheme.primaryContainer.withAlpha(160) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 120,
              child: Text(item.sku,
                  style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium),
            ),
            SizedBox(
              width: 100,
              child: Text('\$${item.price}',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            SizedBox(
              width: 120,
              child: Text(stockLabel,
                  style: textTheme.bodySmall?.copyWith(color: stockColor)),
            ),
          ]),
        ),
      ),
    );
  }
}

// --- Touch/tablet card ---

class _InventoryCard extends StatelessWidget {
  const _InventoryCard(
      {required this.item, required this.onTap, this.isSelected = false});

  final InventoryItemModel item;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final stockLabel = item.stockQty == null
        ? 'Untracked'
        : item.stockQty == 0
            ? 'Out of stock'
            : '${item.stockQty} in stock';
    final stockColor = item.stockQty == null
        ? Colors.grey
        : item.stockQty == 0
            ? Colors.red
            : Colors.green;

    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        title: Text(item.name),
        subtitle: Text('${item.sku} · \$${item.price}'),
        trailing: Chip(
          label: Text(stockLabel, style: const TextStyle(fontSize: 11)),
          backgroundColor: stockColor.withAlpha(30),
          side: BorderSide(color: stockColor.withAlpha(80)),
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        ),
      ),
    );
  }
}
