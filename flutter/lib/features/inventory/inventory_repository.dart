import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/sync/sync_service.dart';

class InventoryRepository {
  InventoryRepository(this._ref);

  final Ref _ref;

  /// Returns a stream of all inventory items from the local database.
  Stream<List<InventoryItemDb>> watchAll() =>
      _ref.read(databaseProvider).watchAllInventory();

  /// Fetches all inventory items, waits for sync to complete.
  Future<void> sync() => _ref.read(syncServiceProvider).syncInventory();

  /// Gets a single inventory item by ID.
  Future<InventoryItemDb?> getById(String id) =>
      _ref.read(databaseProvider).getInventoryById(id);

  /// Phase B: Queue an update mutation.
  Future<void> update(String id, Map<String, dynamic> updates) async {
    // TODO: Phase B — queue if offline, or PATCH to API if online
    throw UnimplementedError('Mutations deferred to Phase B');
  }

  /// Phase B: Queue a delete mutation.
  Future<void> delete(String id) async {
    // TODO: Phase B — queue if offline, or DELETE to API if online
    throw UnimplementedError('Mutations deferred to Phase B');
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref);
});
