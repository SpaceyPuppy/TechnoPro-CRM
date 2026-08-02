import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardStats>> {
  DashboardNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Dio _dio;

  Future<void> fetch() async {
    // Preserve visible values while revalidating so navigation and resume do
    // not replace the dashboard with a loading spinner.
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final res = await _dio.get<Map<String, dynamic>>('/dashboard/stats');
      final stats = DashboardStats.fromJson(res.data!['data'] as Map<String, dynamic>);
      state = AsyncValue.data(stats);
    } on DioException catch (e) {
      state = AsyncValue.error(apiErrorMessage(e), StackTrace.current);
    }
  }

  Future<void> refresh() => fetch();
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardStats>>(
  (ref) => DashboardNotifier(ref.read(apiClientProvider)),
);
