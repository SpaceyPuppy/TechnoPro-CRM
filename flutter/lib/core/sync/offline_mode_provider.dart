import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineMode {
  final bool isEnabled;
  final bool isPreparing;

  const OfflineMode({
    this.isEnabled = false,
    this.isPreparing = false,
  });

  OfflineMode copyWith({
    bool? isEnabled,
    bool? isPreparing,
  }) {
    return OfflineMode(
      isEnabled: isEnabled ?? this.isEnabled,
      isPreparing: isPreparing ?? this.isPreparing,
    );
  }
}

/// Enables/disables explicit offline mode.
/// When enabled, the app syncs all data and is ready to work offline.
/// When disabled, the app works normally (online when available, offline when not).
final offlineModeProvider = StateNotifierProvider<OfflineModeNotifier, OfflineMode>((ref) {
  return OfflineModeNotifier();
});

class OfflineModeNotifier extends StateNotifier<OfflineMode> {
  OfflineModeNotifier() : super(const OfflineMode());

  void setEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
  }

  void setPreparing(bool preparing) {
    state = state.copyWith(isPreparing: preparing);
  }

  void setPreparationComplete() {
    state = state.copyWith(isPreparing: false);
  }
}
