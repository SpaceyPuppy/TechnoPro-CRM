import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

  /// Creates a new ticket. If offline, queues the mutation with device handling.
  /// If device data is provided and offline, creates a local device record first.
  Future<String> create(Map<String, dynamic> payload) async {
    if (!_ref.read(serverReachableProvider)) {
      // Offline path: handle device creation if device data is in payload
      final db = _ref.read(databaseProvider);
      final qm = _ref.read(queueManagerProvider);
      final customerId = payload['customerId'] as String;
      String? deviceId;

      // If device data is in payload, create a local device
      if (payload.containsKey('device') && payload['device'] != null) {
        final deviceData = payload['device'] as Map<String, dynamic>;
        deviceId = 'local_${const Uuid().v4()}';

        // Create local device record
        await db.upsertDevice(DeviceDb(
          id: deviceId,
          customerId: customerId,
          type: deviceData['type'] as String?,
          brand: deviceData['brand'] as String?,
          model: deviceData['model'] as String?,
          serial: deviceData['serial'] as String?,
          imei: deviceData['imei'] as String?,
          password: deviceData['password'] as String?,
          patternLock: deviceData['patternLock'] as String?,
          storage: deviceData['storage'] as String?,
          color: deviceData['color'] as String?,
          carrier: deviceData['carrier'] as String?,
          notes: deviceData['notes'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        // Queue device creation (must sync before ticket references it)
        await qm.queueCreate('device', deviceData);

        // Update payload to reference local device ID instead of nested object
        payload['deviceId'] = deviceId;
        payload.remove('device');
      }

      // Create local ticket
      final ticketLocalId = 'local_${const Uuid().v4()}';
      await db.upsertTicket(TicketDb(
        id: ticketLocalId,
        ticketNumber: 'DRAFT',
        customerId: customerId,
        deviceId: deviceId,
        assignedToId: payload['assignedToId'] as String?,
        status: payload['status'] as String? ?? 'open',
        priority: payload['priority'] as String? ?? 'medium',
        summary: payload['summary'] as String? ?? '',
        description: payload['description'] as String?,
        diagnosis: payload['diagnosis'] as String?,
        resolution: payload['resolution'] as String?,
        dueDate: payload['dueDate'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Queue ticket creation
      await qm.queueCreate('ticket', payload);

      return ticketLocalId;
    } else {
      // Online path: POST to API immediately
      final dio = _ref.read(apiClientProvider);
      final response = await dio.post<Map<String, dynamic>>('/tickets', data: payload);
      final ticketId = (response.data?['data']?['id'] ?? response.data?['id']) as String;

      // Upsert to local DB for caching
      await _ref.read(databaseProvider).upsertTicket(TicketDb(
        id: ticketId,
        ticketNumber: 'TKT-${ticketId.substring(0, 5).toUpperCase()}',
        customerId: payload['customerId'] as String,
        deviceId: response.data?['data']?['deviceId'] as String?,
        assignedToId: payload['assignedToId'] as String?,
        status: payload['status'] as String? ?? 'open',
        priority: payload['priority'] as String? ?? 'medium',
        summary: payload['summary'] as String? ?? '',
        description: payload['description'] as String?,
        diagnosis: payload['diagnosis'] as String?,
        resolution: payload['resolution'] as String?,
        dueDate: payload['dueDate'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

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
