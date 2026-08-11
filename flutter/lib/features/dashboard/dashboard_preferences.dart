import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _defaultDashboardSections = ['overview', 'status', 'mine', 'activity'];
const _dashboardSectionsKey = 'dashboard_sections_v1';

class DashboardLayoutNotifier extends StateNotifier<List<String>> {
  DashboardLayoutNotifier() : super(_defaultDashboardSections) {
    _load();
  }

  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  Future<void> _load() async {
    final raw = await _storage.read(key: _dashboardSectionsKey);
    if (raw == null) return;
    try {
      final saved = (jsonDecode(raw) as List).cast<String>();
      final valid = saved.where(_defaultDashboardSections.contains).toList();
      state = [...valid, ..._defaultDashboardSections.where((item) => !valid.contains(item))];
    } catch (_) {
      state = _defaultDashboardSections;
    }
  }

  Future<void> save(List<String> sections) async {
    state = List.unmodifiable(sections);
    await _storage.write(key: _dashboardSectionsKey, value: jsonEncode(state));
  }

  Future<void> reset() => save(_defaultDashboardSections);
}

final dashboardLayoutProvider =
    StateNotifierProvider<DashboardLayoutNotifier, List<String>>(
  (ref) => DashboardLayoutNotifier(),
);
