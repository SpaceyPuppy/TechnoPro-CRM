import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/models.dart';
import 'data/procurement_repository.dart';

final suppliersProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) async {
  final repo = ref.watch(procurementRepositoryProvider);
  return repo.getSuppliers();
});

final supplierProvider = FutureProvider.family.autoDispose<SupplierModel, String>((ref, id) async {
  final repo = ref.watch(procurementRepositoryProvider);
  return repo.getSupplierById(id);
});

final purchaseOrdersProvider = FutureProvider.autoDispose<List<PurchaseOrderModel>>((ref) async {
  final repo = ref.watch(procurementRepositoryProvider);
  return repo.getPurchaseOrders();
});

final purchaseOrderProvider = FutureProvider.family.autoDispose<PurchaseOrderModel, String>((ref, id) async {
  final repo = ref.watch(procurementRepositoryProvider);
  return repo.getPurchaseOrderById(id);
});
