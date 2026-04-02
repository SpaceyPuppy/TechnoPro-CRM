import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';

class ProcurementRepository {
  ProcurementRepository(this._ref);

  final Ref _ref;

  // --- Suppliers ---

  Future<List<SupplierModel>> getSuppliers() async {
    final dio = _ref.read(apiClientProvider);
    final response = await dio.get<Map<String, dynamic>>('/suppliers');
    final data = response.data?['data'] as List?;
    if (data == null) return [];
    return data.map((j) => SupplierModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<SupplierModel> getSupplierById(String id) async {
    final dio = _ref.read(apiClientProvider);
    final response = await dio.get<Map<String, dynamic>>('/suppliers/$id');
    return SupplierModel.fromJson(response.data?['data'] as Map<String, dynamic>);
  }

  Future<String> createSupplier(Map<String, dynamic> payload) async {
    final dio = _ref.read(apiClientProvider);
    final response = await dio.post<Map<String, dynamic>>('/suppliers', data: payload);
    return (response.data?['data']?['id'] ?? response.data?['id']) as String;
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> payload) async {
    final dio = _ref.read(apiClientProvider);
    await dio.patch('/suppliers/$id', data: payload);
  }

  Future<void> deleteSupplier(String id) async {
    final dio = _ref.read(apiClientProvider);
    await dio.delete('/suppliers/$id');
  }

  // --- Purchase Orders ---

  Future<List<PurchaseOrderModel>> getPurchaseOrders() async {
    final dio = _ref.read(apiClientProvider);
    final response = await dio.get<Map<String, dynamic>>('/purchase-orders');
    final data = response.data?['data'] as List?;
    if (data == null) return [];
    return data.map((j) => PurchaseOrderModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PurchaseOrderModel> getPurchaseOrderById(String id) async {
    final dio = _ref.read(apiClientProvider);
    final response = await dio.get<Map<String, dynamic>>('/purchase-orders/$id');
    return PurchaseOrderModel.fromJson(response.data?['data'] as Map<String, dynamic>);
  }

  // Receives the PO and auto-increments inventory across items locally via backend
  Future<void> receivePurchaseOrder(String id, {String? notes}) async {
    final dio = _ref.read(apiClientProvider);
    await dio.post('/purchase-orders/$id/receive', data: notes != null ? {'notes': notes} : {});
  }
}

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  return ProcurementRepository(ref);
});
