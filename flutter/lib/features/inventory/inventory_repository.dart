import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/sync/queue_manager.dart';
import '../../core/sync/sync_service.dart';

class InventoryRepository {
  InventoryRepository(this._ref);

  final Ref _ref;

  void _requireConnection() {
    if (!_ref.read(serverReachableProvider)) {
      throw StateError('A server connection is required to save changes.');
    }
  }

  /// Returns a stream of all inventory items from the local database.
  Stream<List<InventoryItemDb>> watchAll() =>
      _ref.read(databaseProvider).watchAllInventory();

  /// Fetches all inventory items, waits for sync to complete.
  Future<void> sync() => _ref.read(syncServiceProvider).syncInventory();

  /// Gets a single inventory item by ID.
  Future<InventoryItemDb?> getById(String id) =>
      _ref.read(databaseProvider).getInventoryById(id);

  /// Creates a new inventory item. If offline, queues; if online, POSTs immediately.
  Future<String> create(Map<String, dynamic> payload) async {
    _requireConnection();
    if (!_ref.read(serverReachableProvider)) {
      return _ref.read(queueManagerProvider).queueCreate('inventory', payload);
    } else {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.post<Map<String, dynamic>>('/inventory', data: payload);
      return (response.data?['data']?['id'] ?? response.data?['id']) as String;
    }
  }

  /// Updates an inventory item. If offline, queues; if online, PATCHes immediately.
  Future<void> update(String id, Map<String, dynamic> payload) async {
    _requireConnection();
    if (!_ref.read(serverReachableProvider)) {
      await _ref.read(queueManagerProvider).queueUpdate('inventory', id, payload);
    } else {
      await _ref.read(apiClientProvider).patch('/inventory/$id', data: payload);
    }
    // Optimistically update local DB
    final db = _ref.read(databaseProvider);
    final current = await db.getInventoryById(id);
    if (current != null) {
      final updated = current.copyWith(
        sku: payload['sku'] ?? current.sku,
        name: payload['name'] ?? current.name,
        description: payload['description'] ?? current.description,
        stockQty: payload['stockQty'] ?? current.stockQty,
        cost: payload['cost'] ?? current.cost,
        price: payload['price'] ?? current.price,
        barcode: payload['barcode'] ?? current.barcode,
        updatedAt: DateTime.now(),
      );
      await db.upsertInventoryItem(updated);
    }
  }

  /// Deletes an inventory item. If offline, queues; if online, DELETEs immediately.
  Future<void> delete(String id) async {
    _requireConnection();
    if (!_ref.read(serverReachableProvider)) {
      await _ref.read(queueManagerProvider).queueDelete('inventory', id);
    } else {
      await _ref.read(apiClientProvider).delete('/inventory/$id');
    }
    // Optimistically delete from local DB
    await _ref.read(databaseProvider).deleteInventoryItem(id);
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref);
});
