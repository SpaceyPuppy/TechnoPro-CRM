import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/sync/queue_manager.dart';
import '../../core/sync/sync_service.dart';
import '../../shared/models/models.dart';

class TicketRepository {
  TicketRepository(this._ref);

  final Ref _ref;

  /// Returns a stream of all tickets from the local database.
  /// The stream updates whenever the database changes.
  Stream<List<TicketDb>> watchAll() =>
      _ref.read(databaseProvider).watchAllTickets();

  /// Fetches all tickets, waits for sync to complete.
  /// Should be called on screen init and pull-to-refresh.
  Future<void> sync() => _ref.read(syncServiceProvider).syncTickets();

  /// Gets a single ticket by ID.
  Future<TicketDb?> getById(String id) =>
      _ref.read(databaseProvider).getTicketById(id);

  /// Gets all events for a ticket, as a stream.
  Stream<List<TicketEventDb>> watchEvents(String ticketId) =>
      _ref.read(databaseProvider).watchTicketEvents(ticketId);

  /// Creates a new ticket. If offline, queues the mutation; if online, POSTs immediately.
  Future<String> create(Map<String, dynamic> payload) async {
    if (!_ref.read(serverReachableProvider)) {
      // Queue for later
      return _ref.read(queueManagerProvider).queueCreate('ticket', payload);
    } else {
      // POST to API immediately
      final dio = _ref.read(apiClientProvider);
      final response = await dio.post<Map<String, dynamic>>('/tickets', data: payload);
      final ticketId = (response.data?['data']?['id'] ?? response.data?['id']) as String;
      return ticketId;
    }
  }

  /// Updates a ticket. If offline, queues the mutation; if online, PATCHes immediately.
  Future<void> update(String id, Map<String, dynamic> payload) async {
    if (!_ref.read(serverReachableProvider)) {
      // Queue for later
      await _ref.read(queueManagerProvider).queueUpdate('ticket', id, payload);
    } else {
      // PATCH to API immediately
      await _ref.read(apiClientProvider).patch('/tickets/$id', data: payload);
    }
    // Optimistically update local DB
    final db = _ref.read(databaseProvider);
    final current = await db.getTicketById(id);
    if (current != null) {
      // Merge payload into current ticket
      final updated = current.copyWith(
        status: payload['status'] ?? current.status,
        priority: payload['priority'] ?? current.priority,
        summary: payload['summary'] ?? current.summary,
        description: payload['description'] ?? current.description,
        diagnosis: payload['diagnosis'] ?? current.diagnosis,
        resolution: payload['resolution'] ?? current.resolution,
        dueDate: payload['dueDate'] ?? current.dueDate,
        assignedToId: payload['assignedToId'] ?? current.assignedToId,
        updatedAt: DateTime.now(),
      );
      await db.upsertTicket(updated);
    }
  }

  /// Deletes a ticket. If offline, queues the mutation; if online, DELETEs immediately.
  Future<void> delete(String id) async {
    if (!_ref.read(serverReachableProvider)) {
      // Queue for later
      await _ref.read(queueManagerProvider).queueDelete('ticket', id);
    } else {
      // DELETE from API immediately
      await _ref.read(apiClientProvider).delete('/tickets/$id');
    }
    // Optimistically delete from local DB
    await _ref.read(databaseProvider).deleteTicket(id);
  }
}

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository(ref);
});
