import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

// --- Invoice list ---

class InvoiceListNotifier
    extends StateNotifier<AsyncValue<PaginatedResponse<InvoiceModel>>> {
  InvoiceListNotifier(this._dio, {this.typeFilter}) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Dio _dio;
  final String? typeFilter; // 'invoice' | 'quote' | null (all)
  int _page = 1;
  String? _statusFilter;

  Future<void> fetch({int page = 1, String? status}) async {
    _page = page;
    _statusFilter = status;
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{'page': page, 'pageSize': 20};
      if (status != null) params['status'] = status;
      if (typeFilter != null) params['type'] = typeFilter;
      final res =
          await _dio.get<Map<String, dynamic>>('/invoices', queryParameters: params);
      final parsed = PaginatedResponse.fromJson(res.data!, InvoiceModel.fromJson);
      state = AsyncValue.data(parsed);
    } on DioException catch (e) {
      state = AsyncValue.error(apiErrorMessage(e), StackTrace.current);
    }
  }

  Future<void> refresh() => fetch(page: _page, status: _statusFilter);
}

final invoiceListProvider = StateNotifierProvider<InvoiceListNotifier,
    AsyncValue<PaginatedResponse<InvoiceModel>>>(
  (ref) => InvoiceListNotifier(ref.read(apiClientProvider), typeFilter: 'invoice'),
);

final quoteListProvider = StateNotifierProvider<InvoiceListNotifier,
    AsyncValue<PaginatedResponse<InvoiceModel>>>(
  (ref) => InvoiceListNotifier(ref.read(apiClientProvider), typeFilter: 'quote'),
);

// --- Invoice detail ---

final invoiceDetailProvider =
    FutureProvider.family<InvoiceModel, String>((ref, id) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/invoices/$id');
  return InvoiceModel.fromJson(res.data!['data'] as Map<String, dynamic>);
});

// --- Invoice for a ticket ---

final ticketInvoiceProvider =
    FutureProvider.family<InvoiceModel?, String>((ref, ticketId) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>(
    '/invoices',
    queryParameters: {'ticketId': ticketId, 'pageSize': 1},
  );
  final page = PaginatedResponse.fromJson(res.data!, InvoiceModel.fromJson);
  return page.data.isEmpty ? null : page.data.first;
});
