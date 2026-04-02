import { api } from "./client";
import type {
  ApiResponse,
  PaginatedResponse,
  PurchaseOrderDetailResponse,
  CreatePurchaseOrderRequest,
  UpdatePurchaseOrderRequest,
} from "@technopro/shared";

export const purchaseOrdersApi = {
  list: (params: { page?: number; pageSize?: number; search?: string } = {}) => {
    const qs = new URLSearchParams();
    if (params.page) qs.set("page", String(params.page));
    if (params.pageSize) qs.set("pageSize", String(params.pageSize));
    if (params.search) qs.set("search", params.search);
    return api.get<PaginatedResponse<PurchaseOrderDetailResponse>>(`/api/v1/purchase-orders?${qs}`);
  },
  get: (id: string) => api.get<ApiResponse<PurchaseOrderDetailResponse>>(`/api/v1/purchase-orders/${id}`),
  create: (body: CreatePurchaseOrderRequest) =>
    api.post<ApiResponse<PurchaseOrderDetailResponse>>("/api/v1/purchase-orders", body),
  update: (id: string, body: UpdatePurchaseOrderRequest) =>
    api.patch<ApiResponse<PurchaseOrderDetailResponse>>(`/api/v1/purchase-orders/${id}`, body),
  receive: (id: string, body?: { notes?: string }) =>
    api.post<ApiResponse<PurchaseOrderDetailResponse>>(`/api/v1/purchase-orders/${id}/receive`, body || {}),
};
