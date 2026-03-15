import { api } from "./client";
import type { ApiResponse, DashboardStatsResponse } from "@technopro/shared";

export const dashboardApi = {
  getStats: () => api.get<ApiResponse<DashboardStatsResponse>>("/api/v1/dashboard/stats"),
};
