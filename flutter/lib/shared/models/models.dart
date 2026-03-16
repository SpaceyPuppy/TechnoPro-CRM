import 'enums.dart';

// --- Auth ---

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class LoginResponse {
  final String token;
  final UserModel user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
        token: j['token'] as String,
        user: UserModel.fromJson(j['user'] as Map<String, dynamic>),
      );
}

// --- Users ---

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool active;
  final String createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String,
        role: UserRole.fromString(j['role'] as String),
        active: j['active'] as bool,
        createdAt: j['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.value,
        'active': active,
        'createdAt': createdAt,
      };
}

// --- Customers ---

class CustomerModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  CustomerModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> j) => CustomerModel(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        notes: j['notes'] as String?,
        createdAt: j['createdAt'] as String,
        updatedAt: j['updatedAt'] as String,
      );
}

// --- Devices ---

class DeviceModel {
  final String id;
  final String customerId;
  final String? type;
  final String? brand;
  final String? model;
  final String? serial;
  final String? imei;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  DeviceModel({
    required this.id,
    required this.customerId,
    this.type,
    this.brand,
    this.model,
    this.serial,
    this.imei,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> j) => DeviceModel(
        id: j['id'] as String,
        customerId: j['customerId'] as String,
        type: j['type'] as String?,
        brand: j['brand'] as String?,
        model: j['model'] as String?,
        serial: j['serial'] as String?,
        imei: j['imei'] as String?,
        notes: j['notes'] as String?,
        createdAt: j['createdAt'] as String,
        updatedAt: j['updatedAt'] as String,
      );

  String get displayName {
    final parts = [brand, model].where((s) => s != null && s.isNotEmpty).join(' ');
    return parts.isNotEmpty ? parts : type ?? 'Unknown Device';
  }
}

// --- Tickets ---

class TicketModel {
  final String id;
  final String ticketNumber;
  final String customerId;
  final String? deviceId;
  final String? assignedToId;
  final TicketStatus status;
  final TicketPriority priority;
  final String summary;
  final String? description;
  final String? diagnosis;
  final String? resolution;
  final String? dueDate;
  final String createdAt;
  final String updatedAt;

  // Optionally populated by detail endpoint
  final CustomerModel? customer;
  final DeviceModel? device;
  final UserModel? assignedTo;

  TicketModel({
    required this.id,
    required this.ticketNumber,
    required this.customerId,
    this.deviceId,
    this.assignedToId,
    required this.status,
    required this.priority,
    required this.summary,
    this.description,
    this.diagnosis,
    this.resolution,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.device,
    this.assignedTo,
  });

  factory TicketModel.fromJson(Map<String, dynamic> j) => TicketModel(
        id: j['id'] as String,
        ticketNumber: j['ticketNumber'] as String,
        customerId: j['customerId'] as String,
        deviceId: j['deviceId'] as String?,
        assignedToId: j['assignedToId'] as String?,
        status: TicketStatus.fromString(j['status'] as String),
        priority: TicketPriority.fromString(j['priority'] as String),
        summary: j['summary'] as String,
        description: j['description'] as String?,
        diagnosis: j['diagnosis'] as String?,
        resolution: j['resolution'] as String?,
        dueDate: j['dueDate'] as String?,
        createdAt: j['createdAt'] as String,
        updatedAt: j['updatedAt'] as String,
        customer: j['customer'] != null
            ? CustomerModel.fromJson(j['customer'] as Map<String, dynamic>)
            : null,
        device: j['device'] != null
            ? DeviceModel.fromJson(j['device'] as Map<String, dynamic>)
            : null,
        assignedTo: j['assignedTo'] != null
            ? UserModel.fromJson(j['assignedTo'] as Map<String, dynamic>)
            : null,
      );
}

// --- Ticket Events ---

class TicketEventModel {
  final String id;
  final String ticketId;
  final String? userId;
  final TicketEventType eventType;
  final String? content;
  final String createdAt;
  final UserModel? user;

  TicketEventModel({
    required this.id,
    required this.ticketId,
    this.userId,
    required this.eventType,
    this.content,
    required this.createdAt,
    this.user,
  });

  factory TicketEventModel.fromJson(Map<String, dynamic> j) => TicketEventModel(
        id: j['id'] as String,
        ticketId: j['ticketId'] as String,
        userId: j['userId'] as String?,
        eventType: TicketEventType.fromString(j['eventType'] as String),
        content: j['content'] as String?,
        createdAt: j['createdAt'] as String,
        user: j['user'] != null ? UserModel.fromJson(j['user'] as Map<String, dynamic>) : null,
      );
}

// --- Inventory ---

class InventoryItemModel {
  final String id;
  final String sku;
  final String name;
  final String? description;
  final int? stockQty;
  final String cost;
  final String price;
  final String? barcode;
  final String createdAt;
  final String updatedAt;

  InventoryItemModel({
    required this.id,
    required this.sku,
    required this.name,
    this.description,
    this.stockQty,
    required this.cost,
    required this.price,
    this.barcode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> j) => InventoryItemModel(
        id: j['id'] as String,
        sku: j['sku'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        stockQty: j['stockQty'] as int?,
        cost: j['cost'] as String,
        price: j['price'] as String,
        barcode: j['barcode'] as String?,
        createdAt: j['createdAt'] as String,
        updatedAt: j['updatedAt'] as String,
      );
}

// --- Line Items ---

class LineItemModel {
  final String id;
  final String invoiceId;
  final String? inventoryItemId;
  final String type;
  final String description;
  final int quantity;
  final String unitPrice;
  final String total;
  final String createdAt;

  LineItemModel({
    required this.id,
    required this.invoiceId,
    this.inventoryItemId,
    required this.type,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.createdAt,
  });

  factory LineItemModel.fromJson(Map<String, dynamic> j) => LineItemModel(
        id: j['id'] as String,
        invoiceId: j['invoiceId'] as String,
        inventoryItemId: j['inventoryItemId'] as String?,
        type: j['type'] as String,
        description: j['description'] as String,
        quantity: j['quantity'] as int,
        unitPrice: j['unitPrice'] as String,
        total: j['total'] as String,
        createdAt: j['createdAt'] as String,
      );
}

// --- Payments ---

class PaymentModel {
  final String id;
  final String invoiceId;
  final String amount;
  final String method;
  final String? reference;
  final String paidAt;
  final String createdAt;

  PaymentModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    this.reference,
    required this.paidAt,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> j) => PaymentModel(
        id: j['id'] as String,
        invoiceId: j['invoiceId'] as String,
        amount: j['amount'] as String,
        method: j['method'] as String,
        reference: j['reference'] as String?,
        paidAt: j['paidAt'] as String,
        createdAt: j['createdAt'] as String,
      );
}

// --- Invoices ---

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String? ticketId;
  final String subtotal;
  final String tax;
  final String total;
  final String status;
  final String amountPaid;
  final String balance;
  final String createdAt;
  final String updatedAt;
  final List<LineItemModel> lineItems;
  final List<PaymentModel> payments;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.ticketId,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.amountPaid,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
    this.lineItems = const [],
    this.payments = const [],
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> j) => InvoiceModel(
        id: j['id'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
        ticketId: j['ticketId'] as String?,
        subtotal: j['subtotal'] as String,
        tax: j['tax'] as String,
        total: j['total'] as String,
        status: j['status'] as String,
        amountPaid: j['amountPaid'] as String,
        balance: j['balance'] as String,
        createdAt: j['createdAt'] as String,
        updatedAt: j['updatedAt'] as String,
        lineItems: (j['lineItems'] as List? ?? [])
            .map((e) => LineItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        payments: (j['payments'] as List? ?? [])
            .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get statusLabel => switch (status) {
        'draft' => 'Draft',
        'open' => 'Open',
        'paid' => 'Paid',
        'void' => 'Void',
        _ => status,
      };

  bool get isPaid => status == 'paid';
  bool get isVoid => status == 'void';
  bool get canEdit => status == 'draft';
}

// --- Pagination ---

class PaginatedResponse<T> {
  final List<T> data;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  PaginatedResponse({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final pagination = j['pagination'] as Map<String, dynamic>;
    return PaginatedResponse(
      data: (j['data'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      page: pagination['page'] as int,
      pageSize: pagination['pageSize'] as int,
      totalCount: pagination['totalCount'] as int,
      totalPages: pagination['totalPages'] as int,
    );
  }
}
