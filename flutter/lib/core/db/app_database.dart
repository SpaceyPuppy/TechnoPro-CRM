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

// --- Database ---

@DriftDatabase(tables: [Customers, Tickets, TicketEvents, InventoryItems, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'technopro_db');
}
