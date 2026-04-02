import { api } from "./client";
import type {
  ApiResponse,
  PaginatedResponse,
  SupplierResponse,
  CreateSupplierRequest,
  UpdateSupplierRequest,
} from "@technopro/shared";

export const suppliersApi = {
  list: (params: { page?: number; pageSize?: number; search?: string } = {}) => {
    const qs = new URLSearchParams();
    if (params.page) qs.set("page", String(params.page));
    if (params.pageSize) qs.set("pageSize", String(params.pageSize));
    if (params.search) qs.set("search", params.search);
    return api.get<PaginatedResponse<SupplierResponse>>(`/api/v1/suppliers?${qs}`);
  },
  get: (id: string) => api.get<ApiResponse<SupplierResponse>>(`/api/v1/suppliers/${id}`),
  create: (body: CreateSupplierRequest) =>
    api.post<ApiResponse<SupplierResponse>>("/api/v1/suppliers", body),
  update: (id: string, body: UpdateSupplierRequest) =>
    api.patch<ApiResponse<SupplierResponse>>(`/api/v1/suppliers/${id}`, body),
  delete: (id: string) => api.delete<void>(`/api/v1/suppliers/${id}`),
};
