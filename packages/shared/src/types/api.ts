import type {
  UserRole,
  TicketStatus,
  TicketType,
  TicketPriority,
  TicketEventType,
  LineItemType,
  InvoiceStatus,
  PaymentMethod,
} from "./enums.js";

// --- Auth ---

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: UserResponse;
}

// --- Users ---

export interface UserResponse {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  active: boolean;
  createdAt: string;
}

// --- Customers ---

export interface CustomerResponse {
  id: string;
  name: string;
  firstName: string | null;
  lastName: string | null;
  company: string | null;
  email: string | null;
  phone: string | null;
  address: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateCustomerRequest {
  name?: string;
  firstName?: string;
  lastName?: string;
  company?: string;
  email?: string;
  phone?: string;
  address?: string;
  notes?: string;
}

export interface UpdateCustomerRequest {
  name?: string;
  firstName?: string;
  lastName?: string;
  company?: string;
  email?: string;
  phone?: string;
  address?: string;
  notes?: string;
}

// --- Devices ---

export interface DeviceResponse {
  id: string;
  customerId: string;
  type: string | null;
  brand: string | null;
  model: string | null;
  serial: string | null;
  imei: string | null;
  password: string | null;
  patternLock: string | null;
  storage: string | null;
  color: string | null;
  carrier: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateDeviceRequest {
  customerId: string;
  type?: string;
  brand?: string;
  model?: string;
  serial?: string;
  imei?: string;
  password?: string;
  patternLock?: string;
  storage?: string;
  color?: string;
  carrier?: string;
  notes?: string;
}

// --- Device Models (Settings) ---

export interface DeviceModelResponse {
  id: string;
  manufacturer: string;
  name: string;
  sortOrder: number;
}

export interface CreateDeviceModelRequest {
  manufacturer: string;
  name: string;
  sortOrder?: number;
}

export interface UpdateDeviceModelRequest {
  manufacturer?: string;
  name?: string;
  sortOrder?: number;
}

// --- Tickets ---

export interface TicketResponse {
  id: string;
  ticketNumber: string;
  customerId: string;
  deviceId: string | null;
  assignedToId: string | null;
  ticketType: TicketType;
  status: TicketStatus;
  priority: TicketPriority;
  summary: string;
  description: string | null;
  serviceLocation: string | null;
  diagnosis: string | null;
  resolution: string | null;
  scheduledAt: string | null;
  dueDate: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface TicketRepairItem {
  type: LineItemType;
  description: string;
  unitPrice: string;
  quantity?: number;
  discount?: string; // percentage e.g. "10.00"
  inventoryItemId?: string;
}

export interface CreateTicketDeviceData {
  brand?: string;
  model?: string;
  serial?: string;
  imei?: string;
  password?: string;
  patternLock?: string;
  storage?: string;
  color?: string;
  carrier?: string;
}

export interface CreateTicketRequest {
  customerId: string;
  deviceId?: string;
  device?: CreateTicketDeviceData;
  assignedToId?: string;
  ticketType?: TicketType;
  priority?: TicketPriority;
  summary: string;
  description?: string;
  serviceLocation?: string;
  scheduledAt?: string;
  dueDate?: string;
  repairs?: TicketRepairItem[];
}

export interface UpdateTicketRequest {
  ticketType?: TicketType;
  status?: TicketStatus;
  priority?: TicketPriority;
  assignedToId?: string | null;
  summary?: string;
  description?: string;
  serviceLocation?: string | null;
  diagnosis?: string;
  resolution?: string;
  scheduledAt?: string | null;
  dueDate?: string | null;
}

// --- Ticket Events ---

export interface TicketEventResponse {
  id: string;
  ticketId: string;
  userId: string | null;
  eventType: TicketEventType;
  content: string | null;
  createdAt: string;
}

export interface CreateTicketEventRequest {
  eventType: TicketEventType;
  content?: string;
}

export interface TicketChecklistItemResponse {
  id: string;
  ticketId: string;
  content: string;
  completed: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

// --- Inventory ---

export interface InventoryItemResponse {
  id: string;
  sku: string;
  name: string;
  description: string | null;
  stockQty: number | null; // null = stock not tracked
  cost: string;
  price: string;
  barcode: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateInventoryItemRequest {
  sku: string;
  name: string;
  description?: string;
  stockQty?: number | null;
  cost?: string;
  price: string;
  barcode?: string;
  upc?: string; manufacturerPartNumber?: string; itemType?: string; category?: string; subcategory?: string; brand?: string; compatibleModel?: string; condition?: string;
  reorderPoint?: number | null; targetStockLevel?: number | null; warrantyMonths?: number | null; internalNotes?: string;
  active?: boolean; posSellable?: boolean; serialized?: boolean;
}

export interface UpdateInventoryItemRequest {
  sku?: string;
  name?: string;
  description?: string;
  stockQty?: number | null;
  cost?: string;
  price?: string;
  barcode?: string;
  upc?: string | null; manufacturerPartNumber?: string | null; itemType?: string; category?: string | null; subcategory?: string | null; brand?: string | null; compatibleModel?: string | null; condition?: string | null;
  reorderPoint?: number | null; targetStockLevel?: number | null; warrantyMonths?: number | null; internalNotes?: string | null;
  active?: boolean; posSellable?: boolean; serialized?: boolean;
}

// --- Line Items ---

export interface LineItemResponse {
  id: string;
  invoiceId: string;
  inventoryItemId: string | null;
  type: import("./enums.js").LineItemType;
  description: string;
  quantity: number;
  unitPrice: string;
  taxTreatment: "inclusive" | "exclusive";
  discount: string;
  total: string;
  createdAt: string;
}

export interface CreateLineItemRequest {
  type: import("./enums.js").LineItemType;
  description: string;
  quantity?: number;
  unitPrice: string;
  taxTreatment?: "inclusive" | "exclusive";
  inventoryItemId?: string;
}

export interface UpdateLineItemRequest {
  description?: string;
  quantity?: number;
  unitPrice?: string;
  taxTreatment?: "inclusive" | "exclusive";
}

// --- Invoices ---

export type InvoiceType = "invoice" | "quote";
export type QuoteStatus = "draft" | "sent" | "accepted" | "declined";

export interface InvoiceResponse {
  id: string;
  invoiceNumber: string;
  ticketId: string | null;
  type: InvoiceType;
  quoteStatus: QuoteStatus | null;
  convertedTicketId: string | null;
  subtotal: string;
  taxRate: string;
  taxAmount: string;
  total: string;
  status: import("./enums.js").InvoiceStatus;
  notes: string | null;
  amountPaid: string;
  balance: string;
  createdAt: string;
  updatedAt: string;
}

export interface InvoiceDetailResponse extends InvoiceResponse {
  lineItems: LineItemResponse[];
  payments: PaymentResponse[];
}

export interface CreateInvoiceRequest {
  ticketId?: string;
  type?: InvoiceType;
}

// --- Payments ---

export type PaymentType = "deposit" | "payment" | "refund";

export interface PaymentResponse {
  id: string;
  invoiceId: string;
  amount: string;
  method: import("./enums.js").PaymentMethod;
  type: PaymentType;
  reference: string | null;
  paidAt: string;
  createdAt: string;
}

export interface CreatePaymentRequest {
  amount: string;
  method: import("./enums.js").PaymentMethod;
  type?: PaymentType;
  reference?: string;
  paidAt?: string;
}

// --- App Settings ---

export interface AppSettings {
  business_name: string;
  business_abn: string;
  business_address: string;
  business_phone: string;
  business_email: string;
  gst_rate: string;
  tax_entry_mode: "inclusive" | "exclusive";
  invoice_notes: string;
  labour_rate?: string;
}

// --- Time Entries ---

export interface TimeEntryResponse {
  id: string;
  ticketId: string;
  userId: string;
  startedAt: string;
  stoppedAt: string | null;
  durationSeconds: number | null;
  note: string | null;
  labourRate: string;
  billable: boolean;
  billedAs: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface StartTimeEntryRequest {
  note?: string;
  labourRate?: string;
  billable?: boolean;
}

export interface UpdateTimeEntryRequest {
  billable: boolean;
}

export interface BillTimeEntryRequest {
  description?: string;
}

// --- Attachments ---

export interface AttachmentResponse {
  id: string;
  ticketId: string;
  uploadedById: string;
  fileName: string;
  filePath: string;
  mimeType: string;
  fileSize: number;
  createdAt: string;
}

// --- Dashboard ---

export interface DashboardTicketCount {
  status: string;
  count: number;
}

export interface DashboardRecentEvent {
  id: string;
  ticketId: string;
  ticketNumber: string;
  ticketSummary: string;
  eventType: string;
  content: string | null;
  createdAt: string;
}

export interface DashboardStatsResponse {
  ticketCounts: DashboardTicketCount[];
  overdueCount: number;
  unassignedCount: number;
  unbilledCount: number;
  todayNewTickets: number;
  todayRevenue: string;
  recentEvents: DashboardRecentEvent[];
  myTickets?: TicketResponse[];
}

// --- Pagination ---

export interface PaginationParams {
  page?: number;
  pageSize?: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    pageSize: number;
    totalCount: number;
    totalPages: number;
  };
}

// --- Suppliers ---

export interface SupplierResponse {
  id: string;
  name: string;
  contactName: string | null;
  email: string | null;
  phone: string | null;
  accountNumber: string | null;
  leadTimeDays: number | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateSupplierRequest {
  name: string;
  contactName?: string;
  email?: string;
  phone?: string;
  accountNumber?: string;
  leadTimeDays?: number;
  notes?: string;
}

export interface UpdateSupplierRequest {
  name?: string;
  contactName?: string;
  email?: string;
  phone?: string;
  accountNumber?: string;
  leadTimeDays?: number;
  notes?: string;
}

// --- Purchase Orders ---

export interface POItemResponse {
  id: string;
  poId: string;
  inventoryItemId?: string | null;
  supplierItemId?: string | null;
  supplierSku?: string | null;
  description?: string | null;
  quantity: number;
  receivedQty: number;
  cancelledQty: number;
  unitCost: string;
  totalCost: string; // Line total (quantity * unitCost)
  totalMarginCalc: string | null;
  createdAt: string;
}

export interface PurchaseOrderResponse {
  id: string;
  poNumber: string;
  supplierId: string;
  status: import("./enums.js").PurchaseOrderStatus;
  expectedDeliveryDate: string | null;
  totalCost: string;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PurchaseOrderDetailResponse extends PurchaseOrderResponse {
  items: POItemResponse[];
}

export interface CreatePOItemRequest {
  inventoryItemId?: string;
  supplierItemId?: string;
  description?: string;
  quantity: number;
  unitCost: string;
}

export interface CreatePurchaseOrderRequest {
  supplierId: string;
  expectedDeliveryDate?: string;
  notes?: string;
  items: CreatePOItemRequest[];
}

export interface UpdatePurchaseOrderRequest {
  status?: import("./enums.js").PurchaseOrderStatus;
  expectedDeliveryDate?: string;
  notes?: string;
}

export interface ReceivePurchaseOrderRequest {
  receiptReference: string;
  lines: Array<{ poItemId: string; receivedQty: number; cancelledQty?: number; unitCost?: string; reasonCode?: string; reasonNote?: string }>;
}

// --- API wrapper ---

export interface ApiResponse<T> {
  data: T;
}

export interface ApiError {
  error: {
    code: string;
    message: string;
    details?: { field: string; message: string }[];
  };
}
