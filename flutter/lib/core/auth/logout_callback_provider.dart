import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registered by AuthNotifier on init. Called by the Dio 401 handler
/// to trigger full logout without creating a circular import.
final logoutCallbackProvider = StateProvider<void Function()?>((ref) => null);
