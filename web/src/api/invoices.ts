import { api } from "./client";
import type {
  ApiResponse,
  PaginatedResponse,
  InvoiceResponse,
  InvoiceDetailResponse,
  CreateInvoiceRequest,
  CreateLineItemRequest,
  UpdateLineItemRequest,
  CreatePaymentRequest,
} from "@technopro/shared";

export const invoicesApi = {
  list: (params: { page?: number; pageSize?: number; status?: string; type?: string; quoteStatus?: string; ticketId?: string } = {}) => {
    const qs = new URLSearchParams();
    if (params.page) qs.set("page", String(params.page));
    if (params.pageSize) qs.set("pageSize", String(params.pageSize));
    if (params.status) qs.set("status", params.status);
    if (params.type) qs.set("type", params.type);
    if (params.quoteStatus) qs.set("quoteStatus", params.quoteStatus);
    if (params.ticketId) qs.set("ticketId", params.ticketId);
    return api.get<PaginatedResponse<InvoiceResponse>>(`/api/v1/invoices?${qs}`);
  },
  get: (id: string) =>
    api.get<ApiResponse<InvoiceDetailResponse>>(`/api/v1/invoices/${id}`),
  create: (body: CreateInvoiceRequest) =>
    api.post<ApiResponse<InvoiceDetailResponse>>("/api/v1/invoices", body),
  updateStatus: (id: string, status: string) =>
    api.patch<ApiResponse<InvoiceDetailResponse>>(`/api/v1/invoices/${id}/status`, { status }),
  addLineItem: (id: string, body: CreateLineItemRequest) =>
    api.post<ApiResponse<InvoiceDetailResponse>>(`/api/v1/invoices/${id}/line-items`, body),
  updateLineItem: (id: string, lineItemId: string, body: UpdateLineItemRequest) =>
    api.patch<ApiResponse<InvoiceDetailResponse>>(
      `/api/v1/invoices/${id}/line-items/${lineItemId}`,
      body,
    ),
  removeLineItem: (id: string, lineItemId: string) =>
    api.delete<void>(`/api/v1/invoices/${id}/line-items/${lineItemId}`),
  addPayment: (id: string, body: CreatePaymentRequest) =>
    api.post<ApiResponse<InvoiceDetailResponse>>(`/api/v1/invoices/${id}/payments`, body),
};
