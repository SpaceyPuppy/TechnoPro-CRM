import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/sync/offline_mode_provider.dart';

class OfflineStatusBanner extends ConsumerWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(serverReachableProvider);
    final offlineMode = ref.watch(offlineModeProvider);

    // Show banner if offline or in offline mode
    if (isOnline && !offlineMode.isEnabled) {
      return const SizedBox.shrink();
    }

    final bannerColor = !isOnline
        ? Colors.orange[700]
        : Colors.blue[700];

    final bannerText = !isOnline
        ? '📡 Working Offline'
        : '📌 Offline Mode Enabled';

    return Container(
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            bannerText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          if (!isOnline)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
