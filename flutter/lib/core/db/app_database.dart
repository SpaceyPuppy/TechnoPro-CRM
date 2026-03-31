import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// --- Tables ---

@DataClassName('CustomerDb')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get company => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TicketDb')
class Tickets extends Table {
  TextColumn get id => text()();
  TextColumn get ticketNumber => text()();
  TextColumn get customerId => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get assignedToId => text().nullable()();
  TextColumn get status => text()(); // 'open', 'in_progress', 'closed', etc.
  TextColumn get priority => text()(); // 'low', 'medium', 'high'
  TextColumn get summary => text()();
  TextColumn get description => text().nullable()();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get resolution => text().nullable()();
  TextColumn get dueDate => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TicketEventDb')
class TicketEvents extends Table {
  TextColumn get id => text()();
  TextColumn get ticketId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get eventType => text()(); // 'status_change', 'note', 'attachment', etc.
  TextColumn get content => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InventoryItemDb')
class InventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get stockQty => integer().nullable()();
  TextColumn get cost => text()(); // Stored as string to preserve precision
  TextColumn get price => text()(); // Stored as string to preserve precision
  TextColumn get barcode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncQueueDb')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()(); // 'ticket', 'customer', 'inventory', etc.
  TextColumn get operation => text()(); // 'create', 'update', 'delete'
  TextColumn get localId => text()(); // May start as 'local_<uuid>'
  TextColumn get serverId => text().nullable()(); // Mapped after server confirms
  TextColumn get payload => text()(); // JSON-encoded mutation
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

@DataClassName('DeviceDb')
class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get type => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serial => text().nullable()();
  TextColumn get imei => text().nullable()();
  TextColumn get password => text().nullable()();
  TextColumn get patternLock => text().nullable()();
  TextColumn get storage => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get carrier => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InvoiceDb')
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get ticketId => text().nullable()();
  TextColumn get type => text().withDefault(const Constant('invoice'))();
  TextColumn get quoteStatus => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get subtotal => text().withDefault(const Constant('0.00'))();
  TextColumn get taxRate => text().withDefault(const Constant('0.00'))();
  TextColumn get taxAmount => text().withDefault(const Constant('0.00'))();
  TextColumn get total => text().withDefault(const Constant('0.00'))();
  TextColumn get notes => text().nullable()();
  TextColumn get amountPaid => text().withDefault(const Constant('0.00'))();
  TextColumn get balance => text().withDefault(const Constant('0.00'))();
  BoolColumn get isLocalDraft => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LineItemDb')
class LineItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get inventoryItemId => text().nullable()();
  TextColumn get type => text().withDefault(const Constant('service'))();
  TextColumn get description => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get unitPrice => text().withDefault(const Constant('0.00'))();
  TextColumn get discount => text().withDefault(const Constant('0.00'))();
  TextColumn get total => text().withDefault(const Constant('0.00'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PaymentDb')
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get amount => text()();
  TextColumn get method => text().withDefault(const Constant('cash'))();
  TextColumn get type => text().withDefault(const Constant('payment'))();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppSettingsDb')
class AppSettingsTable extends Table {
  TextColumn get id => text().withDefault(const Constant('singleton'))();
  TextColumn get businessName => text().withDefault(const Constant(''))();
  TextColumn get businessAbn => text().withDefault(const Constant(''))();
  TextColumn get businessAddress => text().withDefault(const Constant(''))();
  TextColumn get businessPhone => text().withDefault(const Constant(''))();
  TextColumn get businessEmail => text().withDefault(const Constant(''))();
  TextColumn get gstRate => text().withDefault(const Constant('10.00'))();
  TextColumn get invoiceNotes => text().withDefault(const Constant(''))();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- Database ---

@DriftDatabase(tables: [
  Customers, Tickets, TicketEvents, InventoryItems, SyncQueue,
  Devices, Invoices, LineItems, Payments, AppSettingsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(devices);
        await m.createTable(invoices);
        await m.createTable(lineItems);
        await m.createTable(payments);
        await m.createTable(appSettingsTable);
      }
    },
  );

  // --- Customer queries ---

  Future<List<CustomerDb>> getAllCustomers() => select(customers).get();

  Stream<List<CustomerDb>> watchAllCustomers() => select(customers).watch();

  Future<CustomerDb?> getCustomerById(String id) =>
      (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertCustomer(CustomerDb customer) async {
    await into(customers).insertOnConflictUpdate(customer);
  }

  Future<void> upsertCustomers(List<CustomerDb> customers_) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(customers, customers_);
    });
  }

  Future<int> deleteCustomer(String id) =>
      (delete(customers)..where((t) => t.id.equals(id))).go();

  // --- Ticket queries ---

  Future<List<TicketDb>> getAllTickets() => select(tickets).get();

  Stream<List<TicketDb>> watchAllTickets() => select(tickets).watch();

  Future<TicketDb?> getTicketById(String id) =>
      (select(tickets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertTicket(TicketDb ticket) async {
    await into(tickets).insertOnConflictUpdate(ticket);
  }

  Future<void> upsertTickets(List<TicketDb> tickets_) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(tickets, tickets_);
    });
  }

  Future<int> deleteTicket(String id) =>
      (delete(tickets)..where((t) => t.id.equals(id))).go();

  // --- Ticket Event queries ---

  Future<List<TicketEventDb>> getTicketEvents(String ticketId) =>
      (select(ticketEvents)..where((t) => t.ticketId.equals(ticketId))).get();

  Stream<List<TicketEventDb>> watchTicketEvents(String ticketId) =>
      (select(ticketEvents)..where((t) => t.ticketId.equals(ticketId))).watch();

  Future<void> upsertTicketEvent(TicketEventDb event) async {
    await into(ticketEvents).insertOnConflictUpdate(event);
  }

  Future<void> upsertTicketEvents(List<TicketEventDb> events) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(ticketEvents, events);
    });
  }

  // --- Inventory queries ---

  Future<List<InventoryItemDb>> getAllInventory() => select(inventoryItems).get();

  Stream<List<InventoryItemDb>> watchAllInventory() => select(inventoryItems).watch();

  Future<InventoryItemDb?> getInventoryById(String id) =>
      (select(inventoryItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertInventoryItem(InventoryItemDb item) async {
    await into(inventoryItems).insertOnConflictUpdate(item);
  }

  Future<void> upsertInventoryItems(List<InventoryItemDb> items) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(inventoryItems, items);
    });
  }

  Future<int> deleteInventoryItem(String id) =>
      (delete(inventoryItems)..where((t) => t.id.equals(id))).go();

  // --- Sync Queue queries ---

  Future<List<SyncQueueDb>> getAllSyncQueue() => select(syncQueue).get();

  Future<void> queueMutation(SyncQueueCompanion item) async {
    await into(syncQueue).insert(item);
  }

  Future<void> incrementRetryCount(int id) async {
    final item = await (select(syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item != null) {
      await (update(syncQueue)..where((t) => t.id.equals(id))).write(
        SyncQueueCompanion(
          retryCount: Value(item.retryCount + 1),
        ),
      );
    }
  }

  Future<int> deleteSyncQueueItem(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  Future<void> clearSyncQueue() => delete(syncQueue).go();

  Future<List<SyncQueueDb>> getSyncQueueByEntity(String entity) =>
      (select(syncQueue)..where((t) => t.entity.equals(entity))).get();

  // --- Device queries ---

  Future<List<DeviceDb>> getAllDevices() => select(devices).get();

  Future<DeviceDb?> getDeviceById(String id) =>
      (select(devices)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertDevice(DeviceDb device) async {
    await into(devices).insertOnConflictUpdate(device);
  }

  Future<void> upsertDevices(List<DeviceDb> devices_) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(devices, devices_);
    });
  }

  Future<int> deleteDevice(String id) =>
      (delete(devices)..where((t) => t.id.equals(id))).go();

  // --- Invoice queries ---

  Future<List<InvoiceDb>> getAllInvoices() => select(invoices).get();

  Stream<List<InvoiceDb>> watchAllInvoices() => select(invoices).watch();

  Future<InvoiceDb?> getInvoiceById(String id) =>
      (select(invoices)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertInvoice(InvoiceDb invoice) async {
    await into(invoices).insertOnConflictUpdate(invoice);
  }

  Future<void> upsertInvoices(List<InvoiceDb> invoices_) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(invoices, invoices_);
    });
  }

  Stream<List<LineItemDb>> watchInvoiceLineItems(String invoiceId) =>
      (select(lineItems)..where((t) => t.invoiceId.equals(invoiceId))).watch();

  Stream<List<PaymentDb>> watchInvoicePayments(String invoiceId) =>
      (select(payments)..where((t) => t.invoiceId.equals(invoiceId))).watch();

  Future<int> deleteInvoice(String id) =>
      (delete(invoices)..where((t) => t.id.equals(id))).go();

  // --- Line Item queries ---

  Future<void> upsertLineItem(LineItemDb item) async {
    await into(lineItems).insert(item);
  }

  Future<void> upsertLineItems(List<LineItemDb> items) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(lineItems, items);
    });
  }

  Future<int> deleteLineItem(String id) =>
      (delete(lineItems)..where((t) => t.id.equals(id))).go();

  // --- Payment queries ---

  Future<void> upsertPayment(PaymentDb payment) async {
    await into(payments).insert(payment);
  }

  Future<void> upsertPayments(List<PaymentDb> payments_) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(payments, payments_);
    });
  }

  Future<int> deletePayment(String id) =>
      (delete(payments)..where((t) => t.id.equals(id))).go();

  // --- AppSettings queries ---

  Future<AppSettingsDb?> getAppSettings() =>
      (select(appSettingsTable)..where((t) => t.id.equals('singleton'))).getSingleOrNull();

  Future<void> upsertAppSettings(AppSettingsDb settings) async {
    await into(appSettingsTable).insertOnConflictUpdate(settings);
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'technopro_db');
}
