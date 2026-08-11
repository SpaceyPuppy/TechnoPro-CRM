import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

final inventoryListProvider = FutureProvider<List<InventoryItemModel>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/inventory', queryParameters: {
    'page': 1,
    'pageSize': 200,
  });
  final page = PaginatedResponse.fromJson(res.data!, InventoryItemModel.fromJson);
  return page.data;
});

final inventoryDetailProvider =
    FutureProvider.family<InventoryItemModel, String>((ref, id) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/inventory/$id');
  return InventoryItemModel.fromJson(res.data!['data'] as Map<String, dynamic>);
});

/// The server ledger is authoritative for stock changes. Keeping it separate
/// from the catalogue model prevents an edit form from treating movements as
/// mutable item fields.
final stockMovementsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/inventory/$id/movements');
  return (res.data?['data'] as List? ?? []).cast<Map<String, dynamic>>();
});
