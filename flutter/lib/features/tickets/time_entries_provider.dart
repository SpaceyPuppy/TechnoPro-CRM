import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';

// List time entries for a ticket
final timeEntriesProvider =
    FutureProvider.family<List<TimeEntryModel>, String>((ref, ticketId) async {
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>(
      '/tickets/$ticketId/time-entries',
    );
    final list = res.data!['data'] as List;
    return list
        .map((e) => TimeEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});

// Notifier for local timer UI state (running entry ID, elapsed seconds)
class TimerNotifier extends StateNotifier<({String? runningId, int elapsedSeconds})> {
  TimerNotifier() : super((runningId: null, elapsedSeconds: 0));

  void startLocal(String entryId) {
    state = (runningId: entryId, elapsedSeconds: 0);
  }

  void tick() {
    if (state.runningId != null) {
      state = (runningId: state.runningId, elapsedSeconds: state.elapsedSeconds + 1);
    }
  }

  void stop() {
    state = (runningId: null, elapsedSeconds: 0);
  }
}

final timerStateProvider = StateNotifierProvider<TimerNotifier, ({String? runningId, int elapsedSeconds})>(
  (ref) => TimerNotifier(),
);

// Start time entry
final startTimeEntryProvider = FutureProvider.family<TimeEntryModel, (String, String?)>((ref, args) async {
  final (ticketId, note) = args;
  final dio = ref.read(apiClientProvider);
  try {
    final body = <String, dynamic>{};
    if (note != null && note.isNotEmpty) {
      body['note'] = note;
    }
    final res = await dio.post<Map<String, dynamic>>(
      '/tickets/$ticketId/time-entries/start',
      data: body.isEmpty ? null : body,
    );
    final entry = TimeEntryModel.fromJson(res.data!['data'] as Map<String, dynamic>);
    ref.invalidate(timeEntriesProvider(ticketId));
    return entry;
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});

// Stop time entry
final stopTimeEntryProvider = FutureProvider.family<TimeEntryModel, (String, String)>((ref, args) async {
  final (timeEntryId, ticketId) = args;
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.post<Map<String, dynamic>>(
      '/time-entries/$timeEntryId/stop',
    );
    final entry = TimeEntryModel.fromJson(res.data!['data'] as Map<String, dynamic>);
    ref.invalidate(timeEntriesProvider(ticketId));
    return entry;
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});

// Bill time entry (create labour line item)
final billTimeEntryProvider =
    FutureProvider.family<InvoiceModel, (String, String)>((ref, args) async {
  final (timeEntryId, ticketId) = args;
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.post<Map<String, dynamic>>(
      '/time-entries/$timeEntryId/bill',
    );
    final invoice = InvoiceModel.fromJson(res.data!['data'] as Map<String, dynamic>);
    ref.invalidate(timeEntriesProvider(ticketId));
    return invoice;
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});
