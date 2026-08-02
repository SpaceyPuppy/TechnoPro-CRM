import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/models/models.dart';
import '../time_entries_provider.dart';

class TimeEntryTimerWidget extends ConsumerStatefulWidget {
  const TimeEntryTimerWidget({
    Key? key,
    required this.ticketId,
  }) : super(key: key);

  final String ticketId;

  @override
  ConsumerState<TimeEntryTimerWidget> createState() => _TimeEntryTimerWidgetState();
}

class _TimeEntryTimerWidgetState extends ConsumerState<TimeEntryTimerWidget> {
  late StreamSubscription _timerSubscription;

  @override
  void initState() {
    super.initState();
    // Start a 1-second ticker to increment elapsed time
    _timerSubscription = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      ref.read(timerStateProvider.notifier).tick();
    });
  }

  @override
  void dispose() {
    _timerSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeEntries = ref.watch(timeEntriesProvider(widget.ticketId));
    final timerState = ref.watch(timerStateProvider);
    final currentUserId = ref.watch(authProvider).user?.id;

    return timeEntries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e'),
      ),
      data: (entries) {
        final running = entries.firstWhereOrNull(
          (e) => e.isRunning && e.userId == currentUserId,
        );
        if (running != null && timerState.runningId != running.id) {
          final initialSeconds = DateTime.now()
              .difference(DateTime.parse(running.startedAt))
              .inSeconds
              .clamp(0, 1 << 31)
              .toInt();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(timerStateProvider.notifier).startLocal(
                    running.id,
                    initialSeconds: initialSeconds,
                  );
            }
          });
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Tracking',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (running != null) ...[
                  Text(
                    'Running: ${_formatElapsed(timerState.elapsedSeconds)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed: () => _stopTimer(running.id),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.timer),
                        label: const Text('Start Timer'),
                        onPressed: () => _showStartDialog(context),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Add Manual Time'),
                        onPressed: () => _showManualDialog(context),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                if (entries.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'History (${entries.length})',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      ...entries.map((e) => _TimeEntryRow(
                            entry: e,
                            onBill: () => _showBillDialog(context, e),
                          )),
                    ],
                  ) else
                  const Text('No time entries yet'),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showStartDialog(BuildContext context) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Timer'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Optional note (e.g., "Diagnosis")',
          ),
          maxLines: 3,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startTimer(noteController.text);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _startTimer(String note) async {
    try {
      final entry = await ref.read(
        startTimeEntryProvider((widget.ticketId, note.isNotEmpty ? note : null)).future,
      );
      ref.read(timerStateProvider.notifier).startLocal(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timer started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showManualDialog(BuildContext context) {
    final minutesController = TextEditingController();
    final noteController = TextEditingController();
    final rateController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Manual Time'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minutesController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Labour rate (optional)',
                  prefixText: r'$',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(minutesController.text.trim());
              if (minutes == null || minutes < 1) return;
              Navigator.pop(ctx);
              _addManualTime(
                minutes,
                noteController.text.trim(),
                rateController.text.trim(),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualTime(int minutes, String note, String rate) async {
    try {
      await ref.read(
        addManualTimeEntryProvider((
          widget.ticketId,
          minutes,
          note.isEmpty ? null : note,
          rate.isEmpty ? null : _formatRate(rate),
        )).future,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual time added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatRate(String value) {
    final parsed = double.tryParse(value);
    return parsed == null ? value : parsed.toStringAsFixed(2);
  }

  void _stopTimer(String timeEntryId) async {
    try {
      await ref.read(
        stopTimeEntryProvider((timeEntryId, widget.ticketId)).future,
      );
      ref.read(timerStateProvider.notifier).stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timer stopped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showBillDialog(BuildContext context, TimeEntryModel entry) {
    final durationHours = (entry.durationSeconds ?? 0) / 3600;
    final labourRate = double.tryParse(entry.labourRate) ?? 75.0;
    final total = durationHours * labourRate;
    final descController = TextEditingController(
      text: 'Labour (${durationHours.toStringAsFixed(2)} hours)',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill Time Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duration: ${entry.formattedDuration}'),
              const SizedBox(height: 8),
              Text('Rate: \$${entry.labourRate}/hour'),
              const SizedBox(height: 8),
              Text(
                'Total: \$${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Line item description',
                ),
                maxLines: 2,
                maxLength: 500,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _billTimeEntry(entry, descController.text.trim());
            },
            child: const Text('Bill'),
          ),
        ],
      ),
    );
  }

  void _billTimeEntry(TimeEntryModel entry, [String? description]) async {
    try {
      await ref.read(
        billTimeEntryProvider((entry.id, widget.ticketId, description)).future,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time billed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _TimeEntryRow extends StatelessWidget {
  final TimeEntryModel entry;
  final VoidCallback onBill;

  const _TimeEntryRow({
    required this.entry,
    required this.onBill,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entry.formattedDuration),
      subtitle: Text(entry.note ?? 'No note'),
      trailing: entry.billedAs != null
          ? const Chip(label: Text('Billed'))
          : (entry.isRunning
              ? const SizedBox.shrink()
              : ElevatedButton(
                  onPressed: onBill,
                  child: const Text('Bill'),
                )),
      dense: true,
    );
  }
}

extension on List<TimeEntryModel> {
  TimeEntryModel? firstWhereOrNull(bool Function(TimeEntryModel) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
