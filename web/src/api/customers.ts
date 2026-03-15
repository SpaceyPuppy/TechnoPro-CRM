import { api } from "./client";
import type {
  ApiResponse,
  PaginatedResponse,
  CustomerResponse,
  CreateCustomerRequest,
  UpdateCustomerRequest,
} from "@technopro/shared";

export const customersApi = {
  list: (params: { page?: number; pageSize?: number; search?: string } = {}) => {
    const qs = new URLSearchParams();
    if (params.page) qs.set("page", String(params.page));
    if (params.pageSize) qs.set("pageSize", String(params.pageSize));
    if (params.search) qs.set("search", params.search);
    return api.get<PaginatedResponse<CustomerResponse>>(`/api/v1/customers?${qs}`);
  },
  get: (id: string) => api.get<ApiResponse<CustomerResponse>>(`/api/v1/customers/${id}`),
  create: (body: CreateCustomerRequest) =>
    api.post<ApiResponse<CustomerResponse>>("/api/v1/customers", body),
  update: (id: string, body: UpdateCustomerRequest) =>
    api.patch<ApiResponse<CustomerResponse>>(`/api/v1/customers/${id}`, body),
  delete: (id: string) => api.delete<void>(`/api/v1/customers/${id}`),
};
