export const UserRole = {
  TECHNICIAN: "technician",
  COUNTER: "counter",
  MANAGER: "manager",
  ADMIN: "admin",
} as const;
export type UserRole = (typeof UserRole)[keyof typeof UserRole];

export const TicketStatus = {
  OPEN: "open",
  IN_PROGRESS: "in_progress",
  WAITING_PARTS: "waiting_parts",
  WAITING_CUSTOMER: "waiting_customer",
  RESOLVED: "resolved",
  CLOSED: "closed",
  CANCELLED: "cancelled",
} as const;
export type TicketStatus = (typeof TicketStatus)[keyof typeof TicketStatus];

export const TicketPriority = {
  LOW: "low",
  NORMAL: "normal",
  HIGH: "high",
  URGENT: "urgent",
} as const;
export type TicketPriority = (typeof TicketPriority)[keyof typeof TicketPriority];

export const TicketEventType = {
  STATUS_CHANGE: "status_change",
  NOTE: "note",
  ASSIGNMENT: "assignment",
  SYSTEM: "system",
} as const;
export type TicketEventType = (typeof TicketEventType)[keyof typeof TicketEventType];

export const LineItemType = {
  SERVICE: "service",
  PART: "part",
} as const;
export type LineItemType = (typeof LineItemType)[keyof typeof LineItemType];

export const InvoiceStatus = {
  DRAFT: "draft",
  OPEN: "open",
  PAID: "paid",
  VOID: "void",
} as const;
export type InvoiceStatus = (typeof InvoiceStatus)[keyof typeof InvoiceStatus];

export const PaymentMethod = {
  CASH: "cash",
  CARD: "card",
  EFTPOS: "eftpos",
  BANK_TRANSFER: "bank_transfer",
  OTHER: "other",
} as const;
export type PaymentMethod = (typeof PaymentMethod)[keyof typeof PaymentMethod];

export const PurchaseOrderStatus = {
  DRAFT: "draft",
  ORDERED: "ordered",
  RECEIVED: "received",
  CANCELLED: "cancelled",
} as const;
export type PurchaseOrderStatus = (typeof PurchaseOrderStatus)[keyof typeof PurchaseOrderStatus];

