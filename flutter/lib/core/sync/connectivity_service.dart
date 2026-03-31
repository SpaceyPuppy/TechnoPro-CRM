import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'queue_manager.dart';
import 'sync_service.dart';
import 'sync_status_provider.dart';

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
        _onReconnect();
      } else {
        _updatePendingMutationCount();
      }
    });

    // Check initial connectivity state
    connectivity.checkConnectivity().then((results) {
      final isOnline = results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
      _ref.read(serverReachableProvider.notifier).state = isOnline;
      _updatePendingMutationCount();
    });
  }

  Future<void> _onReconnect() async {
    // Drain sync queue first (queued mutations)
    await _ref.read(queueManagerProvider).drainQueue();
    _updatePendingMutationCount();
    // Then pull fresh data from server
    await _ref.read(syncServiceProvider).syncAll();
  }

  Future<void> _updatePendingMutationCount() async {
    final pending = await _ref.read(queueManagerProvider).getPendingMutations();
    _ref.read(syncStatusProvider.notifier).setPendingMutationCount(pending.length);
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(ref);
});
