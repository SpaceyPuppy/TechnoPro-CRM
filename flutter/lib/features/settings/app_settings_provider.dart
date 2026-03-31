import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/settings');
  return AppSettings.fromJson(res.data!['data'] as Map<String, dynamic>);
});
