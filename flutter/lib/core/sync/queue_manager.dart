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
  /// Called on reconnection. Server-side conflicts: server wins (overwrites local).
  Future<Map<String, String>> drainQueue() async {
    final db = _ref.read(databaseProvider);
    final dio = _ref.read(apiClientProvider);
    final idMappings = <String, String>{}; // localId -> serverId

    final items = await db.getAllSyncQueue();
    if (items.isEmpty) return idMappings;

    // Process by entity type, then by creation order
    final grouped = <String, List<SyncQueueDb>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.entity, () => []).add(item);
    }

    for (final entity in grouped.keys) {
      for (final item in grouped[entity]!) {
        try {
          await _processMutation(item, idMappings, dio, db);
        } catch (e) {
          // Increment retry count and continue
          await db.incrementRetryCount(item.id);
          print('Queue drain error for $entity ${item.localId}: $e');
        }
      }
    }

    return idMappings;
  }

  Future<void> _processMutation(
    SyncQueueDb item,
    Map<String, String> idMappings,
    dynamic dio,
    AppDatabase db,
  ) async {
    final payload = jsonDecode(item.payload) as Map<String, dynamic>;

    switch (item.operation) {
      case 'create':
        // POST to API, get server ID
        final endpoint = _getEndpoint(item.entity, 'create');
        final response = await dio.post<Map<String, dynamic>>(endpoint, data: payload);
        final serverId = (response.data?['data']?['id'] ?? response.data?['id']) as String?;

        if (serverId != null && item.localId.startsWith('local_')) {
          idMappings[item.localId] = serverId;
          // TODO: remap any references in related tables (e.g., ticket events with this ticket ID)
        }
        break;

      case 'update':
        // PATCH to API
        final endpoint = _getEndpoint(item.entity, 'update', item.localId);
        await dio.patch<Map<String, dynamic>>(endpoint, data: payload);
        break;

      case 'delete':
        // DELETE from API
        final endpoint = _getEndpoint(item.entity, 'delete', item.localId);
        await dio.delete<Map<String, dynamic>>(endpoint);
        break;
    }

    // Remove from queue on success
    await db.deleteSyncQueueItem(item.id);
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
