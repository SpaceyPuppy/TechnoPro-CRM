import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { UserResponse } from "@technopro/shared";

interface AuthState {
  token: string | null;
  user: UserResponse | null;
  setAuth: (token: string, user: UserResponse) => void;
  clearAuth: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      user: null,
      setAuth: (token, user) => set({ token, user }),
      clearAuth: () => set({ token: null, user: null }),
    }),
    { name: "technopro-auth" },
  ),
);

/** Role-based permission helpers. All checks are UI-only — backend enforces the real rules. */
export function useRole() {
  const role = useAuthStore((s) => s.user?.role);
  return {
    role,
    /** Can manage: manager or admin */
    canManage: role === "manager" || role === "admin",
    /** Can access counter operations: counter, manager, admin */
    canCounter: role === "counter" || role === "manager" || role === "admin",
    /** Can access tech operations: technician, manager, admin */
    canTech: role === "technician" || role === "manager" || role === "admin",
    /** Admin only */
    isAdmin: role === "admin",
  };
}
