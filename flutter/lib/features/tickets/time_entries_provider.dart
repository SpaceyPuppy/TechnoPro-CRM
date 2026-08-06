import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/models.dart';
import '../dashboard/dashboard_provider.dart';

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

  void startLocal(String entryId, {int initialSeconds = 0}) {
    state = (runningId: entryId, elapsedSeconds: initialSeconds);
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
final startTimeEntryProvider = FutureProvider.autoDispose.family<TimeEntryModel, (String, String?)>((ref, args) async {
  final (ticketId, note) = args;
  final dio = ref.read(apiClientProvider);
  try {
    final body = <String, dynamic>{};
    if (note != null && note.isNotEmpty) {
      body['note'] = note;
    }
    final res = await dio.post<Map<String, dynamic>>(
      '/tickets/$ticketId/time-entries/start',
      data: body,
    );
    final entry = TimeEntryModel.fromJson(res.data!['data'] as Map<String, dynamic>);
    ref.invalidate(timeEntriesProvider(ticketId));
    ref.invalidate(currentTimeEntryProvider);
    ref.invalidate(dashboardProvider);
    return entry;
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});

// Stop time entry
final stopTimeEntryProvider = FutureProvider.autoDispose.family<TimeEntryModel, (String, String)>((ref, args) async {
  final (timeEntryId, ticketId) = args;
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.post<Map<String, dynamic>>(
      '/time-entries/$timeEntryId/stop',
    );
    final entry = TimeEntryModel.fromJson(res.data!['data'] as Map<String, dynamic>);
    ref.invalidate(timeEntriesProvider(ticketId));
    ref.invalidate(currentTimeEntryProvider);
    ref.invalidate(dashboardProvider);
    return entry;
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});

final currentTimeEntryProvider = FutureProvider<TimeEntryModel?>((ref) async {
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('/time-entries/current');
    final data = res.data!['data'];
    return data == null
        ? null
        : TimeEntryModel.fromJson(data as Map<String, dynamic>);
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});

final addManualTimeEntryProvider =
    FutureProvider.autoDispose.family<TimeEntryModel, (String, int, String?, String?)>((ref, args) async {
  final (ticketId, durationMinutes, note, labourRate) = args;
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.post<Map<String, dynamic>>(
      '/tickets/$ticketId/time-entries/manual',
      data: {
        'durationSeconds': durationMinutes * 60,
        if (note != null && note.isNotEmpty) 'note': note,
        if (labourRate != null && labourRate.isNotEmpty) 'labourRate': labourRate,
      },
    );
    final entry = TimeEntryModel.fromJson(res.data!['data'] as Map<String, dynamic>);
    ref.invalidate(timeEntriesProvider(ticketId));
    ref.invalidate(dashboardProvider);
    return entry;
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});

// Bill time entry (create labour line item)
final billTimeEntryProvider =
    FutureProvider.autoDispose.family<InvoiceModel, (String, String, String?)>((ref, args) async {
  final (timeEntryId, ticketId, description) = args;
  final dio = ref.read(apiClientProvider);
  try {
    final res = await dio.post<Map<String, dynamic>>(
      '/time-entries/$timeEntryId/bill',
      data: {
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    final invoice = InvoiceModel.fromJson(res.data!['data'] as Map<String, dynamic>);
    ref.invalidate(timeEntriesProvider(ticketId));
    ref.invalidate(dashboardProvider);
    return invoice;
  } on DioException catch (e) {
    throw apiErrorMessage(e);
  }
});
