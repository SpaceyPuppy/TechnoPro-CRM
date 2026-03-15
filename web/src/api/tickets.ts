import { api } from "./client";
import type {
  ApiResponse,
  PaginatedResponse,
  TicketResponse,
  TicketEventResponse,
  CreateTicketRequest,
  UpdateTicketRequest,
} from "@technopro/shared";

export const ticketsApi = {
  list: (
    params: {
      page?: number;
      pageSize?: number;
      status?: string;
      customerId?: string;
      assignedToId?: string;
    } = {},
  ) => {
    const qs = new URLSearchParams();
    if (params.page) qs.set("page", String(params.page));
    if (params.pageSize) qs.set("pageSize", String(params.pageSize));
    if (params.status) qs.set("status", params.status);
    if (params.customerId) qs.set("customerId", params.customerId);
    if (params.assignedToId) qs.set("assignedToId", params.assignedToId);
    return api.get<PaginatedResponse<TicketResponse>>(`/api/v1/tickets?${qs}`);
  },
  get: (id: string) => api.get<ApiResponse<TicketResponse>>(`/api/v1/tickets/${id}`),
  create: (body: CreateTicketRequest) =>
    api.post<ApiResponse<TicketResponse>>("/api/v1/tickets", body),
  update: (id: string, body: UpdateTicketRequest) =>
    api.patch<ApiResponse<TicketResponse>>(`/api/v1/tickets/${id}`, body),
  getEvents: (id: string) =>
    api.get<ApiResponse<TicketEventResponse[]>>(`/api/v1/tickets/${id}/events`),
  addNote: (id: string, content: string) =>
    api.post<ApiResponse<{ message: string }>>(`/api/v1/tickets/${id}/notes`, { content }),
};
