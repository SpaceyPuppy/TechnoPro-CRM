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
        _syncDevices(),
        _syncInvoices(),
        _syncAppSettings(),
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
      final response = await dio.get<Map<String, dynamic>>('/customers?pageSize=100');
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
      final response = await dio.get<Map<String, dynamic>>('/tickets?pageSize=100');
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
      final response = await dio.get<Map<String, dynamic>>('/ticket-events?pageSize=100');
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
      final response = await dio.get<Map<String, dynamic>>('/inventory?pageSize=100');
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

  /// Syncs devices from the API and upserts them into the local DB.
  Future<void> _syncDevices() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/devices?pageSize=100');
      final data = response.data?['data'] as List<dynamic>? ?? [];

      final devices = data
          .map((j) {
            final d = j as Map<String, dynamic>;
            return DeviceDb(
              id: d['id'] as String,
              customerId: d['customerId'] as String,
              type: d['type'] as String?,
              brand: d['brand'] as String?,
              model: d['model'] as String?,
              serial: d['serial'] as String?,
              imei: d['imei'] as String?,
              password: d['password'] as String?,
              patternLock: d['patternLock'] as String?,
              storage: d['storage'] as String?,
              color: d['color'] as String?,
              carrier: d['carrier'] as String?,
              notes: d['notes'] as String?,
              createdAt: DateTime.parse(d['createdAt'] as String),
              updatedAt: DateTime.parse(d['updatedAt'] as String),
              syncedAt: DateTime.now(),
            );
          })
          .toList();

      await _ref.read(databaseProvider).upsertDevices(devices);
    } catch (e) {
      print('Device sync error: $e');
    }
  }

  /// Syncs invoices, line items, and payments from the API.
  Future<void> _syncInvoices() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/invoices?pageSize=100');
      final data = response.data?['data'] as List<dynamic>? ?? [];

      final invoices = <InvoiceDb>[];
      final lineItems = <LineItemDb>[];
      final payments = <PaymentDb>[];

      for (final item in data) {
        final inv = item as Map<String, dynamic>;
        invoices.add(InvoiceDb(
          id: inv['id'] as String,
          invoiceNumber: inv['invoiceNumber'] as String,
          ticketId: inv['ticketId'] as String?,
          type: inv['type'] as String? ?? 'invoice',
          quoteStatus: inv['quoteStatus'] as String?,
          status: inv['status'] as String? ?? 'draft',
          subtotal: inv['subtotal'] as String? ?? '0.00',
          taxRate: inv['taxRate'] as String? ?? '0.00',
          taxAmount: inv['taxAmount'] as String? ?? '0.00',
          total: inv['total'] as String? ?? '0.00',
          notes: inv['notes'] as String?,
          amountPaid: inv['amountPaid'] as String? ?? '0.00',
          balance: inv['balance'] as String? ?? '0.00',
          isLocalDraft: false,
          createdAt: DateTime.parse(inv['createdAt'] as String),
          updatedAt: DateTime.parse(inv['updatedAt'] as String),
          syncedAt: DateTime.now(),
        ));

        // Parse line items
        final items = inv['lineItems'] as List<dynamic>? ?? [];
        for (final li in items) {
          final line = li as Map<String, dynamic>;
          lineItems.add(LineItemDb(
            id: line['id'] as String,
            invoiceId: inv['id'] as String,
            inventoryItemId: line['inventoryItemId'] as String?,
            type: line['type'] as String? ?? 'service',
            description: line['description'] as String,
            quantity: line['quantity'] as int? ?? 1,
            unitPrice: line['unitPrice'] as String? ?? '0.00',
            discount: line['discount'] as String? ?? '0.00',
            total: line['total'] as String? ?? '0.00',
            createdAt: DateTime.parse(line['createdAt'] as String),
          ));
        }

        // Parse payments
        final pays = inv['payments'] as List<dynamic>? ?? [];
        for (final p in pays) {
          final pay = p as Map<String, dynamic>;
          payments.add(PaymentDb(
            id: pay['id'] as String,
            invoiceId: inv['id'] as String,
            amount: pay['amount'] as String,
            method: pay['method'] as String? ?? 'cash',
            type: pay['type'] as String? ?? 'payment',
            reference: pay['reference'] as String?,
            paidAt: DateTime.parse(pay['paidAt'] as String),
            createdAt: DateTime.parse(pay['createdAt'] as String),
          ));
        }
      }

      if (invoices.isNotEmpty) await _ref.read(databaseProvider).upsertInvoices(invoices);
      if (lineItems.isNotEmpty) await _ref.read(databaseProvider).upsertLineItems(lineItems);
      if (payments.isNotEmpty) await _ref.read(databaseProvider).upsertPayments(payments);
    } catch (e) {
      print('Invoice sync error: $e');
    }
  }

  /// Syncs app settings (business info, GST rate, etc.) from the API.
  Future<void> _syncAppSettings() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/settings');
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) return;

      await _ref.read(databaseProvider).upsertAppSettings(AppSettingsDb(
        id: 'singleton',
        businessName: data['business_name'] as String? ?? '',
        businessAbn: data['business_abn'] as String? ?? '',
        businessAddress: data['business_address'] as String? ?? '',
        businessPhone: data['business_phone'] as String? ?? '',
        businessEmail: data['business_email'] as String? ?? '',
        gstRate: data['gst_rate'] as String? ?? '10.00',
        invoiceNotes: data['invoice_notes'] as String? ?? '',
        syncedAt: DateTime.now(),
      ));
    } catch (e) {
      print('AppSettings sync error: $e');
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});
