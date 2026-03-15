import { api } from "./client";
import type {
  ApiResponse,
  PaginatedResponse,
  InventoryItemResponse,
  CreateInventoryItemRequest,
  UpdateInventoryItemRequest,
} from "@technopro/shared";

export const inventoryApi = {
  list: (params: { page?: number; pageSize?: number; search?: string } = {}) => {
    const qs = new URLSearchParams();
    if (params.page) qs.set("page", String(params.page));
    if (params.pageSize) qs.set("pageSize", String(params.pageSize));
    if (params.search) qs.set("search", params.search);
    return api.get<PaginatedResponse<InventoryItemResponse>>(`/api/v1/inventory?${qs}`);
  },
  get: (id: string) =>
    api.get<ApiResponse<InventoryItemResponse>>(`/api/v1/inventory/${id}`),
  create: (body: CreateInventoryItemRequest) =>
    api.post<ApiResponse<InventoryItemResponse>>("/api/v1/inventory", body),
  update: (id: string, body: UpdateInventoryItemRequest) =>
    api.patch<ApiResponse<InventoryItemResponse>>(`/api/v1/inventory/${id}`, body),
  delete: (id: string) => api.delete<void>(`/api/v1/inventory/${id}`),
};
