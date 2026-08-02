import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'time_entries_provider.dart';

class CurrentWorkScreen extends ConsumerStatefulWidget {
  const CurrentWorkScreen({super.key});

  @override
  ConsumerState<CurrentWorkScreen> createState() => _CurrentWorkScreenState();
}

class _CurrentWorkScreenState extends ConsumerState<CurrentWorkScreen> {
  Timer? _ticker;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentTimeEntryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(currentTimeEntryProvider),
          ),
        ],
      ),
      body: current.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load the current timer: $error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(currentTimeEntryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (entry) {
          if (entry == null) return _emptyState(context);
          final elapsed = DateTime.now()
              .difference(DateTime.parse(entry.startedAt))
              .inSeconds
              .clamp(0, 1 << 31)
              .toInt();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.timer, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _formatElapsed(elapsed),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.note?.isNotEmpty == true
                                ? entry.note!
                                : 'Timer running',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            icon: _stopping
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.stop),
                            label: const Text('Stop timer'),
                            onPressed: _stopping
                                ? null
                                : () => _stop(entry.id, entry.ticketId),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open ticket'),
                            onPressed: () => context.go('/tickets/${entry.ticketId}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No timer is running',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Open a ticket to start a timer or add time manually.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Open tickets'),
                onPressed: () => context.go('/tickets'),
              ),
            ],
          ),
        ),
      );

  String _formatElapsed(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> _stop(String entryId, String ticketId) async {
    setState(() => _stopping = true);
    try {
      await ref.read(stopTimeEntryProvider((entryId, ticketId)).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timer stopped')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not stop timer: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }
}
