import type {
  UserRole,
  TicketStatus,
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
  notes?: string;
}

export interface UpdateCustomerRequest {
  name?: string;
  firstName?: string;
  lastName?: string;
  company?: string;
  email?: string;
  phone?: string;
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
  status: TicketStatus;
  priority: TicketPriority;
  summary: string;
  description: string | null;
  diagnosis: string | null;
  resolution: string | null;
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
  priority?: TicketPriority;
  summary: string;
  description?: string;
  dueDate?: string;
  repairs?: TicketRepairItem[];
}

export interface UpdateTicketRequest {
  status?: TicketStatus;
  priority?: TicketPriority;
  assignedToId?: string | null;
  summary?: string;
  description?: string;
  diagnosis?: string;
  resolution?: string;
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
}

export interface UpdateInventoryItemRequest {
  sku?: string;
  name?: string;
  description?: string;
  stockQty?: number | null;
  cost?: string;
  price?: string;
  barcode?: string;
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
  discount: string;
  total: string;
  createdAt: string;
}

export interface CreateLineItemRequest {
  type: import("./enums.js").LineItemType;
  description: string;
  quantity?: number;
  unitPrice: string;
  inventoryItemId?: string;
}

export interface UpdateLineItemRequest {
  description?: string;
  quantity?: number;
  unitPrice?: string;
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
  invoice_notes: string;
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
