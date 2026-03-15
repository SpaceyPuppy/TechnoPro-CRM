import { api } from "./client";
import type { ApiResponse, LoginRequest, LoginResponse, UserResponse } from "@technopro/shared";

export const authApi = {
  login: (body: LoginRequest) =>
    api.post<ApiResponse<LoginResponse>>("/api/v1/auth/login", body),
  me: () => api.get<ApiResponse<UserResponse>>("/api/v1/auth/me"),
};
