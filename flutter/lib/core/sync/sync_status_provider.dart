import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatus {
  final DateTime? lastSyncTime;
  final bool isSyncing;
  final int pendingMutationCount;

  const SyncStatus({
    this.lastSyncTime,
    this.isSyncing = false,
    this.pendingMutationCount = 0,
  });

  SyncStatus copyWith({
    DateTime? lastSyncTime,
    bool? isSyncing,
    int? pendingMutationCount,
  }) {
    return SyncStatus(
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingMutationCount: pendingMutationCount ?? this.pendingMutationCount,
    );
  }
}

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier();
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  void setSyncing(bool isSyncing) {
    state = state.copyWith(isSyncing: isSyncing);
  }

  void setLastSyncTime(DateTime? time) {
    state = state.copyWith(lastSyncTime: time);
  }

  void setPendingMutationCount(int count) {
    state = state.copyWith(pendingMutationCount: count);
  }

  void setSyncComplete() {
    state = state.copyWith(
      isSyncing: false,
      lastSyncTime: DateTime.now(),
    );
  }
}
