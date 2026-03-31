import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/models.dart';
import '../api/api_client.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import 'sync_status_provider.dart';

class SyncService {
  SyncService(this._ref);

  final Ref _ref;

  /// Syncs all data from the API to the local database.
  /// Called on app startup and when connectivity is restored.
  Future<void> syncAll() async {
    if (!_ref.read(serverReachableProvider)) {
      return;
    }

    _ref.read(syncStatusProvider.notifier).setSyncing(true);
    try {
      await Future.wait([
        _syncCustomers(),
        _syncTickets(),
        _syncTicketEvents(),
        _syncInventory(),
      ], eagerError: false);
      _ref.read(syncStatusProvider.notifier).setSyncComplete();
    } catch (e) {
      // Log error but don't throw — allow partial sync
      print('Sync error: $e');
      _ref.read(syncStatusProvider.notifier).setSyncing(false);
    }
  }

  /// Fetches all customers from the API and upserts them into the local DB.
  Future<void> _syncCustomers() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/customers?limit=1000');
      final data = response.data?['data'] as List<dynamic>? ?? [];

      final customers = data
          .map((j) => CustomerModel.fromJson(j as Map<String, dynamic>))
          .map((c) => CustomerDb(
                id: c.id,
                name: c.name,
                firstName: c.firstName,
                lastName: c.lastName,
                company: c.company,
                email: c.email,
                phone: c.phone,
                notes: c.notes,
                createdAt: DateTime.parse(c.createdAt),
                updatedAt: DateTime.parse(c.updatedAt),
                syncedAt: DateTime.now(),
              ))
          .toList();

      await _ref.read(databaseProvider).upsertCustomers(customers);
    } catch (e) {
      print('Customer sync error: $e');
    }
  }

  /// Fetches all tickets from the API and upserts them into the local DB.
  Future<void> _syncTickets() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/tickets?limit=1000');
      final data = response.data?['data'] as List<dynamic>? ?? [];

      final tickets = data
          .map((j) => TicketModel.fromJson(j as Map<String, dynamic>))
          .map((t) => TicketDb(
                id: t.id,
                ticketNumber: t.ticketNumber,
                customerId: t.customerId,
                deviceId: t.deviceId,
                assignedToId: t.assignedToId,
                status: t.status.value,
                priority: t.priority.value,
                summary: t.summary,
                description: t.description,
                diagnosis: t.diagnosis,
                resolution: t.resolution,
                dueDate: t.dueDate,
                createdAt: DateTime.parse(t.createdAt),
                updatedAt: DateTime.parse(t.updatedAt),
                syncedAt: DateTime.now(),
              ))
          .toList();

      await _ref.read(databaseProvider).upsertTickets(tickets);
    } catch (e) {
      print('Ticket sync error: $e');
    }
  }

  /// Fetches all ticket events and upserts them into the local DB.
  Future<void> _syncTicketEvents() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/ticket-events?limit=5000');
      final data = response.data?['data'] as List<dynamic>? ?? [];

      final events = data
          .map((j) => TicketEventModel.fromJson(j as Map<String, dynamic>))
          .map((e) => TicketEventDb(
                id: e.id,
                ticketId: e.ticketId,
                userId: e.userId,
                eventType: e.eventType.value,
                content: e.content,
                createdAt: DateTime.parse(e.createdAt),
              ))
          .toList();

      await _ref.read(databaseProvider).upsertTicketEvents(events);
    } catch (e) {
      print('Ticket event sync error: $e');
    }
  }

  /// Fetches all inventory items from the API and upserts them into the local DB.
  Future<void> _syncInventory() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/inventory?limit=1000');
      final data = response.data?['data'] as List<dynamic>? ?? [];

      final items = data
          .map((j) => InventoryItemModel.fromJson(j as Map<String, dynamic>))
          .map((i) => InventoryItemDb(
                id: i.id,
                sku: i.sku,
                name: i.name,
                description: i.description,
                stockQty: i.stockQty,
                cost: i.cost,
                price: i.price,
                barcode: i.barcode,
                createdAt: DateTime.parse(i.createdAt),
                updatedAt: DateTime.parse(i.updatedAt),
                syncedAt: DateTime.now(),
              ))
          .toList();

      await _ref.read(databaseProvider).upsertInventoryItems(items);
    } catch (e) {
      print('Inventory sync error: $e');
    }
  }

  /// Syncs only tickets and events (faster, for pull-to-refresh on ticket screens).
  Future<void> syncTickets() async {
    if (!_ref.read(serverReachableProvider)) {
      return;
    }

    _ref.read(syncStatusProvider.notifier).setSyncing(true);
    try {
      await Future.wait([
        _syncTickets(),
        _syncTicketEvents(),
      ], eagerError: false);
      _ref.read(syncStatusProvider.notifier).setSyncComplete();
    } catch (e) {
      print('Ticket sync error: $e');
      _ref.read(syncStatusProvider.notifier).setSyncing(false);
    }
  }

  /// Syncs only customers (faster, for pull-to-refresh on customer screens).
  Future<void> syncCustomers() async {
    if (!_ref.read(serverReachableProvider)) {
      return;
    }

    _ref.read(syncStatusProvider.notifier).setSyncing(true);
    try {
      await _syncCustomers();
      _ref.read(syncStatusProvider.notifier).setSyncComplete();
    } catch (e) {
      print('Customer sync error: $e');
      _ref.read(syncStatusProvider.notifier).setSyncing(false);
    }
  }

  /// Syncs only inventory (faster, for pull-to-refresh on inventory screens).
  Future<void> syncInventory() async {
    if (!_ref.read(serverReachableProvider)) {
      return;
    }

    _ref.read(syncStatusProvider.notifier).setSyncing(true);
    try {
      await _syncInventory();
      _ref.read(syncStatusProvider.notifier).setSyncComplete();
    } catch (e) {
      print('Inventory sync error: $e');
      _ref.read(syncStatusProvider.notifier).setSyncing(false);
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});
