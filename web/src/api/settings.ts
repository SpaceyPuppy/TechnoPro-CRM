import { api } from "./client";
import type { ApiResponse } from "@technopro/shared";

export interface AppSettings {
  business_name?: string;
  business_abn?: string;
  business_address?: string;
  business_phone?: string;
  business_email?: string;
  gst_rate?: string;
  invoice_notes?: string;
}

export const settingsApi = {
  getSettings: () =>
    api.get<ApiResponse<AppSettings>>("/api/v1/settings"),
  updateSettings: (data: Partial<AppSettings>) =>
    api.patch<ApiResponse<AppSettings>>("/api/v1/settings", data),
};
