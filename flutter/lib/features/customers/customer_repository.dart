import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/sync/sync_service.dart';

class CustomerRepository {
  CustomerRepository(this._ref);

  final Ref _ref;

  /// Returns a stream of all customers from the local database.
  Stream<List<CustomerDb>> watchAll() =>
      _ref.read(databaseProvider).watchAllCustomers();

  /// Fetches all customers, waits for sync to complete.
  Future<void> sync() => _ref.read(syncServiceProvider).syncCustomers();

  /// Gets a single customer by ID.
  Future<CustomerDb?> getById(String id) =>
      _ref.read(databaseProvider).getCustomerById(id);

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

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref);
});
