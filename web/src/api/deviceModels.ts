import { api } from "./client";
import type { ApiResponse } from "@technopro/shared";

export interface DeviceModel {
  id: string;
  manufacturer: string;
  name: string;
  sortOrder: number;
}

export interface ImportResult {
  imported: number;
  skipped: number;
  errors: Array<{ row: number; reason: string }>;
}

export const deviceModelsApi = {
  list: () =>
    api.get<ApiResponse<DeviceModel[]>>("/api/v1/settings/device-models"),
  create: (data: { manufacturer: string; name: string; sortOrder?: number }) =>
    api.post<ApiResponse<DeviceModel>>("/api/v1/settings/device-models", data),
  update: (id: string, data: Partial<{ manufacturer: string; name: string; sortOrder: number }>) =>
    api.patch<ApiResponse<DeviceModel>>(`/api/v1/settings/device-models/${id}`, data),
  delete: (id: string) =>
    api.delete<void>(`/api/v1/settings/device-models/${id}`),
  import: (rows: Array<{ manufacturer: string; name: string }>) =>
    api.post<ApiResponse<ImportResult>>("/api/v1/settings/device-models/import", { rows }),
};
