import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

// --- Customer list (also used by ticket form dropdown) ---

final customerListProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/customers', queryParameters: {
    'page': 1,
    'pageSize': 200,
  });
  final page = PaginatedResponse.fromJson(res.data!, CustomerModel.fromJson);
  return page.data;
});

// --- Customer detail ---

final customerDetailProvider = FutureProvider.family<CustomerModel, String>((ref, id) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/customers/$id');
  return CustomerModel.fromJson(res.data!['data'] as Map<String, dynamic>);
});

// --- Customer tickets ---

final customerTicketsProvider =
    FutureProvider.family<List<TicketModel>, String>((ref, customerId) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/tickets', queryParameters: {
    'customerId': customerId,
    'pageSize': 50,
  });
  final page = PaginatedResponse.fromJson(res.data!, TicketModel.fromJson);
  return page.data;
});
