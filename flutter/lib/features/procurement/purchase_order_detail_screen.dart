import 'package:flutter/material.dart';
import '../../shared/widgets/prism_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'procurement_provider.dart';
import 'data/procurement_repository.dart';
import '../../shared/models/models.dart';

class PurchaseOrderDetailScreen extends ConsumerWidget {
  const PurchaseOrderDetailScreen({super.key, required this.id});

  final String id;

  void _receivePO(BuildContext context, WidgetRef ref, PurchaseOrderModel po) async {
    final lines = po.items.where((item) => item.quantity > item.receivedQty + item.cancelledQty).toList();
    final controllers = {for (final item in lines) item.id: TextEditingController(text: (item.quantity - item.receivedQty - item.cancelledQty).toString())};
    final cancelControllers = {for (final item in lines) item.id: TextEditingController(text: '0')};
    final reference = TextEditingController();
    final reason = TextEditingController(text: 'supplier_receipt');
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Receive shipment'), content: SizedBox(width: 520, child: ListView(shrinkWrap: true, children: [TextFormField(controller: reference, decoration: const InputDecoration(labelText: 'Supplier receipt / delivery reference *')), TextFormField(controller: reason, decoration: const InputDecoration(labelText: 'Receipt/cancellation reason *')), const SizedBox(height: 12), ...lines.expand((item) => [TextFormField(controller: controllers[item.id], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${item.inventoryItem?.name ?? item.description ?? 'Item'} — receive (remaining ${item.quantity - item.receivedQty - item.cancelledQty})')), TextFormField(controller: cancelControllers[item.id], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cancel / supplier-refund quantity')), const SizedBox(height: 8)])])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm receipt'))]));
    if (confirmed != true || reference.text.trim().isEmpty || reason.text.trim().isEmpty) return;
    final repo = ref.read(procurementRepositoryProvider);
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await repo.receivePurchaseOrder(id, {'receiptReference': reference.text.trim(), 'lines': lines.map((item) => {'poItemId': item.id, 'receivedQty': int.tryParse(controllers[item.id]!.text) ?? 0, 'cancelledQty': int.tryParse(cancelControllers[item.id]!.text) ?? 0, 'reasonCode': reason.text.trim()}).where((line) => (line['receivedQty'] as int) > 0 || (line['cancelledQty'] as int) > 0).toList()});
      
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close dialog

      final width = MediaQuery.sizeOf(context).width;
      final isLarge = width > 600;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Order Received')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: isLarge 
            ? EdgeInsets.only(left: width - 380, right: 24, bottom: 24) 
            : const EdgeInsets.fromLTRB(16, 0, 16, 40),
        ),
      );
      
      ref.invalidate(purchaseOrderProvider(id));
      ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close dialog
        final width = MediaQuery.sizeOf(context).width;
        final isLarge = width > 600;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to receive PO: $e')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: isLarge 
              ? EdgeInsets.only(left: width - 380, right: 24, bottom: 24) 
              : const EdgeInsets.fromLTRB(16, 0, 16, 70),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrder = ref.watch(purchaseOrderProvider(id));

    return Scaffold(
      appBar: PrismAppBar(
        title: const Text('PO Details'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: asyncOrder.when(
        data: (po) {
          final isReceived = po.status == 'received';
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Order: ${po.poNumber}', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Supplier: ${po.supplier?.name ?? 'Unknown'}'),
                    Text('Status: ${po.status.toUpperCase()}'),
                    Text('Total: \$${po.totalCost}'),
                    const SizedBox(height: 24),
                    const Text('Line Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...po.items.map((item) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item.inventoryItem?.name ?? item.description ?? 'Unknown Item'),
                            subtitle: Text('Ordered: ${item.quantity} · Received: ${item.receivedQty} · Cancelled: ${item.cancelledQty}\n@ \$${item.unitCost}${item.supplierSku == null ? '' : ' · ${item.supplierSku}'}'),
                            trailing: Text('\$${item.totalCost}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        )),
                  ],
                ),
              ),
              if (!isReceived)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      icon: const Icon(Icons.inbox),
                      label: const Text('Receive Order (Update Inventory)'),
                      onPressed: () => _receivePO(context, ref, po),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading PO: $err')),
      ),
    );
  }
}
