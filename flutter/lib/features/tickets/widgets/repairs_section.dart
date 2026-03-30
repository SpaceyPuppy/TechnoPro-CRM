import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';

class RepairLineItem {
  String? inventoryItemId;
  String description;
  double unitPrice;
  int quantity;
  double discount; // 0–100

  RepairLineItem({
    this.inventoryItemId,
    required this.description,
    required this.unitPrice,
    this.quantity = 1,
    this.discount = 0,
  });

  double get subtotal => unitPrice * quantity * (1 - discount / 100);

  Map<String, dynamic> toJson() => {
        if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        'type': 'labour',
        'description': description,
        'unitPrice': unitPrice.toStringAsFixed(2),
        'quantity': quantity,
        'discount': discount.toStringAsFixed(2),
      };
}

class RepairsSection extends ConsumerStatefulWidget {
  const RepairsSection({super.key, required this.items});

  /// Mutable list — caller holds the reference and reads it at submit time.
  final List<RepairLineItem> items;

  @override
  ConsumerState<RepairsSection> createState() => _RepairsSectionState();
}

class _RepairsSectionState extends ConsumerState<RepairsSection> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<InventoryItemModel> _results = [];
  bool _dropdownVisible = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _results = []; _dropdownVisible = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dio.get<Map<String, dynamic>>('/inventory', queryParameters: {
        'search': q,
        'pageSize': 10,
      });
      final page = PaginatedResponse.fromJson(res.data!, InventoryItemModel.fromJson);
      if (mounted) setState(() { _results = page.data; _dropdownVisible = true; });
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addFromInventory(InventoryItemModel item) {
    _searchCtrl.clear();
    setState(() { _results = []; _dropdownVisible = false; });
    final price = double.tryParse(item.price) ?? 0.0;
    setState(() {
      widget.items.add(RepairLineItem(
        inventoryItemId: item.id,
        description: item.name,
        unitPrice: price,
      ));
    });
  }

  void _addCustomItem() {
    showDialog<RepairLineItem>(
      context: context,
      builder: (_) => const _CustomItemDialog(),
    ).then((item) {
      if (item != null) setState(() => widget.items.add(item));
    });
  }

  void _removeItem(int index) => setState(() => widget.items.removeAt(index));

  double get _total =>
      widget.items.fold(0.0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search parts & services…',
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
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _addCustomItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Custom'),
            ),
          ],
        ),

        // Inventory dropdown
        if (_dropdownVisible && _results.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final item = _results[i];
                  return InkWell(
                    onTap: () => _addFromInventory(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: Theme.of(context).textTheme.bodyMedium),
                                Text(item.sku,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colorScheme.outline)),
                              ],
                            ),
                          ),
                          Text('\$${item.price}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // Line items list
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...widget.items.asMap().entries.map(
                (e) => _RepairLineItemRow(
                  key: ValueKey(e.key),
                  item: e.value,
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeItem(e.key),
                ),
              ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Subtotal: \$${_total.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RepairLineItemRow extends StatefulWidget {
  const _RepairLineItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final RepairLineItem item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_RepairLineItemRow> createState() => _RepairLineItemRowState();
}

class _RepairLineItemRowState extends State<_RepairLineItemRow> {
  late final _priceCtrl =
      TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
  late final _discountCtrl =
      TextEditingController(text: widget.item.discount > 0
          ? widget.item.discount.toStringAsFixed(0)
          : '');

  @override
  void dispose() {
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: colorScheme.outline),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Quantity stepper
              _QtyButton(
                icon: Icons.remove,
                onPressed: widget.item.quantity > 1
                    ? () {
                        setState(() => widget.item.quantity--);
                        widget.onChanged();
                      }
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${widget.item.quantity}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              _QtyButton(
                icon: Icons.add,
                onPressed: () {
                  setState(() => widget.item.quantity++);
                  widget.onChanged();
                },
              ),
              const SizedBox(width: 8),
              // Unit price
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    widget.item.unitPrice = double.tryParse(v) ?? 0.0;
                    widget.onChanged();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Discount %
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    widget.item.discount =
                        (double.tryParse(v) ?? 0.0).clamp(0.0, 100.0);
                    widget.onChanged();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Disc%',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '\$${widget.item.subtotal.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }
}

class _CustomItemDialog extends StatefulWidget {
  const _CustomItemDialog();

  @override
  State<_CustomItemDialog> createState() => _CustomItemDialogState();
}

class _CustomItemDialogState extends State<_CustomItemDialog> {
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Unit Price *',
              prefixText: '\$',
              border: OutlineInputBorder(),
              isDense: true,
            ),
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
            final desc = _descCtrl.text.trim();
            final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
            if (desc.isEmpty) return;
            Navigator.pop(
              context,
              RepairLineItem(description: desc, unitPrice: price),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
