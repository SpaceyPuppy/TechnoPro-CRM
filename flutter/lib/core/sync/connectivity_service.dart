import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'sync_service.dart';

class ConnectivityService {
  ConnectivityService(this._ref) {
    _init();
  }

  final Ref _ref;

  void _init() {
    final connectivity = Connectivity();

    // Listen for connectivity changes
    connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);

      _ref.read(serverReachableProvider.notifier).state = isOnline;

      if (isOnline) {
        // Trigger a full sync when coming back online
        _ref.read(syncServiceProvider).syncAll();
        // TODO: Phase B — also drain sync queue here
      }
    });

    // Check initial connectivity state
    connectivity.checkConnectivity().then((results) {
      final isOnline = results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
      _ref.read(serverReachableProvider.notifier).state = isOnline;
    });
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(ref);
});
