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
  email: string | null;
  phone: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateCustomerRequest {
  name: string;
  email?: string;
  phone?: string;
  notes?: string;
}

export interface UpdateCustomerRequest {
  name?: string;
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
  notes?: string;
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

export interface CreateTicketRequest {
  customerId: string;
  deviceId?: string;
  assignedToId?: string;
  priority?: TicketPriority;
  summary: string;
  description?: string;
  dueDate?: string;
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
