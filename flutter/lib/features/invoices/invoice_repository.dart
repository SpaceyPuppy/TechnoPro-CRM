import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/api_client.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/sync/queue_manager.dart';
import '../../shared/models/models.dart';

class InvoiceRepository {
  InvoiceRepository(this._ref);

  final Ref _ref;

  Stream<List<InvoiceDb>> watchAll() => _ref.read(databaseProvider).watchAllInvoices();

  Future<InvoiceDb?> getById(String id) =>
      _ref.read(databaseProvider).getInvoiceById(id);

  Stream<List<LineItemDb>> watchLineItems(String invoiceId) =>
      _ref.read(databaseProvider).watchInvoiceLineItems(invoiceId);

  Stream<List<PaymentDb>> watchPayments(String invoiceId) =>
      _ref.read(databaseProvider).watchInvoicePayments(invoiceId);

  /// Creates a new invoice. If offline, creates locally with DRAFT number and queues sync.
  Future<String> create({ String? ticketId, bool isQuote = false }) async {
    final isOnline = _ref.read(serverReachableProvider);
    final db = _ref.read(databaseProvider);

    if (!isOnline) {
      // Create local draft invoice
      final localId = 'local_${const Uuid().v4()}';
      await db.upsertInvoice(InvoiceDb(
        id: localId,
        invoiceNumber: 'DRAFT',
        ticketId: ticketId,
        type: isQuote ? 'quote' : 'invoice',
        quoteStatus: isQuote ? 'draft' : null,
        status: 'draft',
        isLocalDraft: true,
        subtotal: '0.00',
        taxRate: '0.00',
        taxAmount: '0.00',
        total: '0.00',
        amountPaid: '0.00',
        balance: '0.00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Queue for sync
      await _ref.read(queueManagerProvider).queueCreate(
        'invoice',
        {
          if (ticketId != null) 'ticketId': ticketId,
          'type': isQuote ? 'quote' : 'invoice',
        },
      );

      return localId;
    } else {
      // POST to API
      final dio = _ref.read(apiClientProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/invoices',
        data: {
          if (ticketId != null) 'ticketId': ticketId,
          if (isQuote) 'type': 'quote',
        },
      );
      final serverId = (res.data?['data']?['id'] ?? res.data?['id']) as String;

      // Upsert to local DB
      await db.upsertInvoice(InvoiceDb(
        id: serverId,
        invoiceNumber: 'INV-${serverId.substring(0, 5).toUpperCase()}',
        ticketId: ticketId,
        type: isQuote ? 'quote' : 'invoice',
        quoteStatus: isQuote ? 'draft' : null,
        status: 'draft',
        isLocalDraft: false,
        subtotal: '0.00',
        taxRate: '0.00',
        taxAmount: '0.00',
        total: '0.00',
        amountPaid: '0.00',
        balance: '0.00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      return serverId;
    }
  }

  /// Adds a line item to an invoice. If offline, queues the addition.
  Future<String> addLineItem(
    String invoiceId, {
    required String description,
    required String type, // 'service' or 'part'
    required int quantity,
    required String unitPrice,
    String discount = '0.00',
    String? inventoryItemId,
  }) async {
    final isOnline = _ref.read(serverReachableProvider);
    final db = _ref.read(databaseProvider);
    final localId = 'local_${const Uuid().v4()}';

    // Calculate total
    final qty = quantity.toDouble();
    final unit = double.parse(unitPrice);
    final disc = double.parse(discount);
    final total = ((qty * unit) - disc).toStringAsFixed(2);

    if (!isOnline) {
      // Create local line item
      await db.upsertLineItem(LineItemDb(
        id: localId,
        invoiceId: invoiceId,
        inventoryItemId: inventoryItemId,
        type: type,
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        discount: discount,
        total: total,
        createdAt: DateTime.now(),
      ));

      // Queue for sync
      await _ref.read(queueManagerProvider).queueCreate(
        'line_item',
        {
          'invoiceId': invoiceId,
          'type': type,
          'description': description,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'discount': discount,
          if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        },
      );

      return localId;
    } else {
      // POST to API
      final dio = _ref.read(apiClientProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/invoices/$invoiceId/line-items',
        data: {
          'type': type,
          'description': description,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'discount': discount,
          if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        },
      );
      final serverId = (res.data?['data']?['id'] ?? res.data?['id']) as String;

      // Upsert to local DB
      await db.upsertLineItem(LineItemDb(
        id: serverId,
        invoiceId: invoiceId,
        inventoryItemId: inventoryItemId,
        type: type,
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        discount: discount,
        total: total,
        createdAt: DateTime.now(),
      ));

      return serverId;
    }
  }

  /// Records a payment for an invoice. If offline, queues the payment.
  Future<String> addPayment(
    String invoiceId, {
    required String amount,
    required String method, // 'cash', 'card', 'eftpos', 'bank_transfer', 'other'
    String type = 'payment', // 'deposit', 'payment', 'refund'
    String? reference,
  }) async {
    final isOnline = _ref.read(serverReachableProvider);
    final db = _ref.read(databaseProvider);
    final localId = 'local_${const Uuid().v4()}';
    final now = DateTime.now();

    if (!isOnline) {
      // Create local payment
      await db.upsertPayment(PaymentDb(
        id: localId,
        invoiceId: invoiceId,
        amount: amount,
        method: method,
        type: type,
        reference: reference,
        paidAt: now,
        createdAt: now,
      ));

      // Queue for sync
      await _ref.read(queueManagerProvider).queueCreate(
        'payment',
        {
          'invoiceId': invoiceId,
          'amount': amount,
          'method': method,
          'type': type,
          if (reference != null) 'reference': reference,
        },
      );

      return localId;
    } else {
      // POST to API
      final dio = _ref.read(apiClientProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/invoices/$invoiceId/payments',
        data: {
          'amount': amount,
          'method': method,
          'type': type,
          if (reference != null) 'reference': reference,
        },
      );
      final serverId = (res.data?['data']?['id'] ?? res.data?['id']) as String;

      // Upsert to local DB
      await db.upsertPayment(PaymentDb(
        id: serverId,
        invoiceId: invoiceId,
        amount: amount,
        method: method,
        type: type,
        reference: reference,
        paidAt: now,
        createdAt: now,
      ));

      return serverId;
    }
  }

  /// Deletes a line item.
  Future<void> deleteLineItem(String invoiceId, String lineItemId) async {
    final isOnline = _ref.read(serverReachableProvider);
    final db = _ref.read(databaseProvider);

    if (!isOnline) {
      // Queue delete
      await _ref.read(queueManagerProvider).queueDelete('line_item', lineItemId);
    } else {
      // DELETE from API
      await _ref.read(apiClientProvider).delete('/invoices/$invoiceId/line-items/$lineItemId');
    }

    // Delete from local DB
    await db.deleteLineItem(lineItemId);
  }

  /// Deletes a payment.
  Future<void> deletePayment(String invoiceId, String paymentId) async {
    final isOnline = _ref.read(serverReachableProvider);
    final db = _ref.read(databaseProvider);

    if (!isOnline) {
      // Queue delete
      await _ref.read(queueManagerProvider).queueDelete('payment', paymentId);
    } else {
      // DELETE from API
      await _ref.read(apiClientProvider).delete('/invoices/$invoiceId/payments/$paymentId');
    }

    // Delete from local DB
    await db.deletePayment(paymentId);
  }

  /// Assemble a full InvoiceModel from local DB data for PDF generation or preview.
  Future<InvoiceModel?> buildInvoiceModel(String invoiceId) async {
    final db = _ref.read(databaseProvider);
    final invoice = await db.getInvoiceById(invoiceId);
    if (invoice == null) return null;

    final lineItems = await (db.select(db.lineItems)
          ..where((t) => t.invoiceId.equals(invoiceId)))
        .get();
    final payments = await (db.select(db.payments)
          ..where((t) => t.invoiceId.equals(invoiceId)))
        .get();

    return InvoiceModel(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      ticketId: invoice.ticketId,
      type: invoice.type,
      quoteStatus: invoice.quoteStatus,
      status: invoice.status,
      subtotal: invoice.subtotal,
      taxRate: invoice.taxRate,
      taxAmount: invoice.taxAmount,
      total: invoice.total,
      notes: invoice.notes,
      amountPaid: invoice.amountPaid,
      balance: invoice.balance,
      createdAt: invoice.createdAt.toIso8601String(),
      updatedAt: invoice.updatedAt.toIso8601String(),
      lineItems: lineItems
          .map((li) => LineItemModel(
                id: li.id,
                invoiceId: li.invoiceId,
                inventoryItemId: li.inventoryItemId,
                type: li.type,
                description: li.description,
                quantity: li.quantity,
                unitPrice: li.unitPrice,
                discount: li.discount,
                total: li.total,
                createdAt: li.createdAt.toIso8601String(),
              ))
          .toList(),
      payments: payments
          .map((p) => PaymentModel(
                id: p.id,
                invoiceId: p.invoiceId,
                amount: p.amount,
                method: p.method,
                type: p.type,
                reference: p.reference,
                paidAt: p.paidAt.toIso8601String(),
                createdAt: p.createdAt.toIso8601String(),
              ))
          .toList(),
    );
  }
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref);
});
