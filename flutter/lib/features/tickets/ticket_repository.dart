import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
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

  /// Phase B: Queue an update mutation (offline-capable).
  /// For now, this is a stub — Phase B will implement queuing.
  Future<void> updateStatus(String id, String status) async {
    // TODO: Phase B — queue if offline, or POST to API if online
    throw UnimplementedError('Mutations deferred to Phase B');
  }

  /// Phase B: Queue a delete mutation.
  Future<void> delete(String id) async {
    // TODO: Phase B — queue if offline, or DELETE to API if online
    throw UnimplementedError('Mutations deferred to Phase B');
  }
}

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository(ref);
});
