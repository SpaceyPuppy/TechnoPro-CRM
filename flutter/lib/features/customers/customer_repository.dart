import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/sync/queue_manager.dart';
import '../../core/sync/sync_service.dart';

class CustomerRepository {
  CustomerRepository(this._ref);

  final Ref _ref;

  void _requireConnection() {
    if (!_ref.read(serverReachableProvider)) {
      throw StateError('A server connection is required to save changes.');
    }
  }

  /// Returns a stream of all customers from the local database.
  Stream<List<CustomerDb>> watchAll() =>
      _ref.read(databaseProvider).watchAllCustomers();

  /// Fetches all customers, waits for sync to complete.
  Future<void> sync() => _ref.read(syncServiceProvider).syncCustomers();

  /// Gets a single customer by ID.
  Future<CustomerDb?> getById(String id) =>
      _ref.read(databaseProvider).getCustomerById(id);

  /// Creates a new customer. If offline, queues; if online, POSTs immediately.
  Future<String> create(Map<String, dynamic> payload) async {
    _requireConnection();
    if (!_ref.read(serverReachableProvider)) {
      return _ref.read(queueManagerProvider).queueCreate('customer', payload);
    } else {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.post<Map<String, dynamic>>('/customers', data: payload);
      return (response.data?['data']?['id'] ?? response.data?['id']) as String;
    }
  }

  /// Updates a customer. If offline, queues; if online, PATCHes immediately.
  Future<void> update(String id, Map<String, dynamic> payload) async {
    _requireConnection();
    if (!_ref.read(serverReachableProvider)) {
      await _ref.read(queueManagerProvider).queueUpdate('customer', id, payload);
    } else {
      await _ref.read(apiClientProvider).patch('/customers/$id', data: payload);
    }
    // Optimistically update local DB
    final db = _ref.read(databaseProvider);
    final current = await db.getCustomerById(id);
    if (current != null) {
      final updated = current.copyWith(
        name: payload['name'] ?? current.name,
        firstName: payload['firstName'] ?? current.firstName,
        lastName: payload['lastName'] ?? current.lastName,
        company: payload['company'] ?? current.company,
        email: payload['email'] ?? current.email,
        phone: payload['phone'] ?? current.phone,
        notes: payload['notes'] ?? current.notes,
        updatedAt: DateTime.now(),
      );
      await db.upsertCustomer(updated);
    }
  }

  /// Deletes a customer. If offline, queues; if online, DELETEs immediately.
  Future<void> delete(String id) async {
    _requireConnection();
    if (!_ref.read(serverReachableProvider)) {
      await _ref.read(queueManagerProvider).queueDelete('customer', id);
    } else {
      await _ref.read(apiClientProvider).delete('/customers/$id');
    }
    // Optimistically delete from local DB
    await _ref.read(databaseProvider).deleteCustomer(id);
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref);
});
