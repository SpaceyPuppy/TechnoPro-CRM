import { api, API_BASE } from "./client";
import type { ApiResponse, AttachmentResponse } from "@technopro/shared";

export const attachmentsApi = {
  list: (ticketId: string) =>
    api.get<ApiResponse<AttachmentResponse[]>>(`/api/v1/tickets/${ticketId}/attachments`),

  upload: (ticketId: string, file: File) =>
    api.upload<ApiResponse<AttachmentResponse>>(
      `/api/v1/tickets/${ticketId}/attachments`,
      file,
    ),

  delete: (ticketId: string, attachmentId: string) =>
    api.delete<void>(`/api/v1/tickets/${ticketId}/attachments/${attachmentId}`),

  getUrl: (filePath: string) => `${API_BASE}/uploads/${filePath}`,
};
