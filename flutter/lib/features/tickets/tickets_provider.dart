import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

// --- Ticket list ---

class TicketListNotifier extends StateNotifier<AsyncValue<PaginatedResponse<TicketModel>>> {
  TicketListNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Dio _dio;
  int _page = 1;
  String? _statusFilter;

  Future<void> fetch({int page = 1, String? status}) async {
    _page = page;
    _statusFilter = status;
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{'page': page, 'pageSize': 20};
      if (status != null) params['status'] = status;
      final res = await _dio.get<Map<String, dynamic>>('/tickets', queryParameters: params);
      final parsed = PaginatedResponse.fromJson(res.data!, TicketModel.fromJson);
      state = AsyncValue.data(parsed);
    } on DioException catch (e) {
      state = AsyncValue.error(apiErrorMessage(e), StackTrace.current);
    }
  }

  Future<void> refresh() => fetch(page: _page, status: _statusFilter);
}

final ticketListProvider =
    StateNotifierProvider<TicketListNotifier, AsyncValue<PaginatedResponse<TicketModel>>>(
  (ref) => TicketListNotifier(ref.read(apiClientProvider)),
);

// --- Ticket detail ---

final ticketDetailProvider = FutureProvider.family<TicketModel, String>((ref, id) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/tickets/$id');
  return TicketModel.fromJson(res.data!['data'] as Map<String, dynamic>);
});

// --- Ticket events ---

final ticketEventsProvider =
    FutureProvider.family<List<TicketEventModel>, String>((ref, ticketId) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/tickets/$ticketId/events');
  final list = res.data!['data'] as List;
  return list.map((e) => TicketEventModel.fromJson(e as Map<String, dynamic>)).toList();
});

// --- Users list (for assignment dropdown) ---

final usersProvider = FutureProvider<List<UserModel>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/users');
  final list = res.data!['data'] as List;
  return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
});
