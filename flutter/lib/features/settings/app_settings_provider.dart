import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/db/database_provider.dart';
import '../../shared/models/models.dart';

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('/settings');
    return AppSettings.fromJson(res.data!['data'] as Map<String, dynamic>);
  } catch (_) {
    // Offline fallback: try to load from local database
    final db = ref.read(databaseProvider);
    final cached = await db.getAppSettings();
    if (cached != null) {
      return AppSettings.fromMap({
        'businessName': cached.businessName,
        'businessAbn': cached.businessAbn,
        'businessAddress': cached.businessAddress,
        'businessPhone': cached.businessPhone,
        'businessEmail': cached.businessEmail,
        'gstRate': cached.gstRate,
        'labourRate': '75.00',
        'invoiceNotes': cached.invoiceNotes,
      });
    }
    // Final fallback: empty settings
    return AppSettings.empty();
  }
});
