import 'package:flutter/material.dart';
import '../../shared/widgets/prism_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/sync/offline_mode_provider.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_status_provider.dart';

class OfflineSyncScreen extends ConsumerWidget {
  const OfflineSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isOnline = ref.watch(serverReachableProvider);
    final offlineMode = ref.watch(offlineModeProvider);

    return Scaffold(
      appBar: const PrismAppBar(title: Text('Offline & Sync')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Connection Status Card
          PrismSurface(
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isOnline ? Icons.cloud_done : Icons.cloud_off,
                        color: isOnline ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'Connected' : 'Offline',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              isOnline
                                  ? 'All changes sync immediately'
                                  : 'Changes will sync when you reconnect',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sync Status Section
          Text(
            'Sync Status',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          PrismSurface(
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last Sync Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last synced',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        syncStatus.lastSyncTime != null
                            ? DateFormat('MMM d, h:mm a').format(syncStatus.lastSyncTime!)
                            : 'Never',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pending Mutations Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending changes',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: syncStatus.pendingMutationCount > 0
                              ? Colors.orange[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${syncStatus.pendingMutationCount}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: syncStatus.pendingMutationCount > 0
                                    ? Colors.orange[900]
                                    : Colors.green[900],
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sync Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Currently syncing',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (syncStatus.isSyncing)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[700],
                          size: 16,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Offline Mode Section
          Text(
            'Offline Mode',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          PrismSurface(
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prepare for offline work',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              offlineMode.isEnabled
                                  ? 'Working offline mode enabled'
                                  : 'Toggle to sync all data and prepare for offline',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: offlineMode.isEnabled,
                        onChanged: offlineMode.isPreparing || syncStatus.isSyncing
                            ? null
                            : (value) async {
                                if (value) {
                                  // Enable offline mode: sync all data first
                                  ref.read(offlineModeProvider.notifier).setPreparing(true);
                                  await ref.read(syncServiceProvider).syncAll();
                                  ref.read(offlineModeProvider.notifier).setEnabled(true);
                                  ref.read(offlineModeProvider.notifier).setPreparationComplete();
                                } else {
                                  // Disable offline mode
                                  ref.read(offlineModeProvider.notifier).setEnabled(false);
                                }
                              },
                      ),
                    ],
                  ),
                  if (offlineMode.isPreparing) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Preparing for offline...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Manual Sync Button
          FilledButton.icon(
            onPressed: syncStatus.isSyncing
                ? null
                : () async {
                    // Trigger a full sync
                    await ref.read(syncServiceProvider).syncAll();
                  },
            icon: syncStatus.isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(syncStatus.isSyncing ? 'Syncing...' : 'Sync Now'),
          ),
          const SizedBox(height: 24),

          // Info Section
          PrismSurface(
            radius: 24,
            tint: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .48),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How offline sync works',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Data from the server is automatically cached when you\'re online.\n'
                    '• When offline, you can view cached data and make changes.\n'
                    '• Your changes are queued and sent to the server when you reconnect.\n'
                    '• Use "Sync Now" to manually refresh data from the server.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
