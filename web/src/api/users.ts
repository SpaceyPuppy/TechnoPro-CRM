import { api } from "./client";
import type { ApiResponse, UserResponse } from "@technopro/shared";

export const usersApi = {
  list: (params: { role?: string } = {}) => {
    const qs = new URLSearchParams();
    if (params.role) qs.set("role", params.role);
    return api.get<ApiResponse<UserResponse[]>>(`/api/v1/users?${qs}`);
  },
};
