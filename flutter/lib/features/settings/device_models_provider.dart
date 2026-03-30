import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

final deviceModelsProvider = FutureProvider<List<DeviceModelEntry>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final res = await dio.get<Map<String, dynamic>>('/settings/device-models');
  final list = (res.data!['data'] as List)
      .map((e) => DeviceModelEntry.fromJson(e as Map<String, dynamic>))
      .toList();
  return list;
});
