import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/api_client.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';

class QueueManager {
  QueueManager(this._ref);

  final Ref _ref;

  /// Queues a create mutation. Returns a local ID (local_<uuid>) for optimistic updates.
  /// The mutation will be sent to the server when back online.
  Future<String> queueCreate(
    String entity,
    Map<String, dynamic> payload,
  ) async {
    final localId = 'local_${const Uuid().v4()}';
    await _ref.read(databaseProvider).queueMutation(
      SyncQueueCompanion(
        entity: Value(entity),
        operation: Value('create'),
        localId: Value(localId),
        payload: Value(jsonEncode(payload)),
      ),
    );
    return localId;
  }

  /// Queues an update mutation.
  Future<void> queueUpdate(
    String entity,
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _ref.read(databaseProvider).queueMutation(
      SyncQueueCompanion(
        entity: Value(entity),
        operation: Value('update'),
        localId: Value(id),
        payload: Value(jsonEncode(payload)),
      ),
    );
  }

  /// Queues a delete mutation.
  Future<void> queueDelete(
    String entity,
    String id,
  ) async {
    await _ref.read(databaseProvider).queueMutation(
      SyncQueueCompanion(
        entity: Value(entity),
        operation: Value('delete'),
        localId: Value(id),
        payload: Value('{}'),
      ),
    );
  }

  /// Gets all pending sync queue items (for debugging/UI).
  Future<List<SyncQueueDb>> getPendingMutations() =>
      _ref.read(databaseProvider).getAllSyncQueue();

  /// Drains the sync queue: processes all queued mutations against the API.
  /// Processes in dependency order: customer → device → ticket → invoice → line_item → payment.
  /// Rewrites foreign key IDs in payloads and local DB records after sync.
  Future<Map<String, String>> drainQueue() async {
    final db = _ref.read(databaseProvider);
    final dio = _ref.read(apiClientProvider);
    final idMappings = <String, String>{}; // localId -> serverId

    final items = await db.getAllSyncQueue();
    if (items.isEmpty) return idMappings;

    // Process in dependency order
    final order = ['customer', 'device', 'ticket', 'invoice', 'line_item', 'payment'];
    for (final entity in order) {
      final itemsForEntity = items.where((i) => i.entity == entity).toList();
      // Sort by creation time to maintain FIFO within entity type
      itemsForEntity.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final item in itemsForEntity) {
        try {
          // Rewrite any local IDs in the payload before sending
          final payload = _rewriteLocalIds(jsonDecode(item.payload) as Map<String, dynamic>, idMappings);
          final serverId = await _processMutation(item, payload, dio, db);
          if (serverId != null && item.localId.startsWith('local_')) {
            idMappings[item.localId] = serverId;
            // Remap the local ID to server ID in the local DB
            await _remapLocalId(entity, item.localId, serverId, db);
          }
          await db.deleteSyncQueueItem(item.id);
        } catch (e) {
          // Increment retry count and continue
          await db.incrementRetryCount(item.id);
          print('Queue drain error for $entity ${item.localId}: $e');
        }
      }
    }

    return idMappings;
  }

  /// Rewrites any local IDs in the payload using the id mapping.
  Map<String, dynamic> _rewriteLocalIds(
    Map<String, dynamic> payload,
    Map<String, String> idMap,
  ) {
    return payload.map((key, value) {
      if (value is String && idMap.containsKey(value)) {
        return MapEntry(key, idMap[value]!);
      }
      return MapEntry(key, value);
    });
  }

  /// Remaps a local ID to the server ID in the local database.
  /// Updates the primary key and any foreign keys referencing this ID.
  Future<void> _remapLocalId(
    String entity,
    String localId,
    String serverId,
    AppDatabase db,
  ) async {
    switch (entity) {
      case 'customer':
        final cust = await db.getCustomerById(localId);
        if (cust != null) {
          await db.deleteCustomer(localId);
          await db.upsertCustomer(cust.copyWith(id: serverId));
        }
        break;
      case 'device':
        final dev = await db.getDeviceById(localId);
        if (dev != null) {
          await db.deleteDevice(localId);
          await db.upsertDevice(dev.copyWith(id: serverId));
        }
        break;
      case 'ticket':
        final tkt = await db.getTicketById(localId);
        if (tkt != null) {
          await db.deleteTicket(localId);
          await db.upsertTicket(tkt.copyWith(id: serverId, ticketNumber: 'TKT-${serverId.substring(0, 5).toUpperCase()}'));
        }
        break;
      case 'invoice':
        final inv = await db.getInvoiceById(localId);
        if (inv != null) {
          // Remap all line items and payments to reference the new invoice ID
          final lineItems = await (db.select(db.lineItems)
                ..where((t) => t.invoiceId.equals(localId)))
              .get();
          final payments = await (db.select(db.payments)
                ..where((t) => t.invoiceId.equals(localId)))
              .get();

          await db.deleteInvoice(localId);
          await db.upsertInvoice(
            inv.copyWith(
              id: serverId,
              invoiceNumber: 'INV-${serverId.substring(0, 5).toUpperCase()}',
              isLocalDraft: false,
            ),
          );

          // Update line items to reference new invoice ID
          if (lineItems.isNotEmpty) {
            await db.upsertLineItems(
              lineItems.map((li) => li.copyWith(invoiceId: serverId)).toList(),
            );
          }

          // Update payments to reference new invoice ID
          if (payments.isNotEmpty) {
            await db.upsertPayments(
              payments.map((p) => p.copyWith(invoiceId: serverId)).toList(),
            );
          }
        }
        break;
      case 'line_item':
      case 'payment':
        // These don't have their own server-side IDs in the same way; they're referenced by FK
        // If needed, could handle FK updates here, but for now they're small leaf nodes
        break;
    }
  }

  Future<String?> _processMutation(
    SyncQueueDb item,
    Map<String, dynamic> payload,
    dynamic dio,
    AppDatabase db,
  ) async {
    String? serverId;

    switch (item.operation) {
      case 'create':
        // POST to API, get server ID
        final endpoint = _getEndpoint(item.entity, 'create');
        final response = await dio.post<Map<String, dynamic>>(endpoint, data: payload);
        serverId = (response.data?['data']?['id'] ?? response.data?['id']) as String?;
        break;

      case 'update':
        // PATCH to API
        final endpoint = _getEndpoint(item.entity, 'update', item.localId);
        await dio.patch<Map<String, dynamic>>(endpoint, data: payload);
        serverId = null;
        break;

      case 'delete':
        // DELETE from API
        final endpoint = _getEndpoint(item.entity, 'delete', item.localId);
        await dio.delete<Map<String, dynamic>>(endpoint);
        serverId = null;
        break;
    }

    return serverId;
  }

  String _getEndpoint(String entity, String operation, [String? id]) {
    switch (entity) {
      case 'ticket':
        return id == null ? '/tickets' : '/tickets/$id';
      case 'customer':
        return id == null ? '/customers' : '/customers/$id';
      case 'inventory':
        return id == null ? '/inventory' : '/inventory/$id';
      default:
        throw UnsupportedError('Unknown entity: $entity');
    }
  }
}

final queueManagerProvider = Provider<QueueManager>((ref) {
  return QueueManager(ref);
});
