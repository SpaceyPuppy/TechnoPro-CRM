import type { UserRole } from "@technopro/shared";

/**
 * The API role matrix. Route handlers must use these groups for any operation
 * that changes financial, operational, catalogue, procurement, or staff data.
 * Authentication is applied separately at each route module.
 */
export const rolePolicies = {
  operations: ["technician", "counter", "manager", "admin"],
  counter: ["counter", "manager", "admin"],
  manager: ["manager", "admin"],
  admin: ["admin"],
} as const satisfies Record<string, readonly UserRole[]>;

export type RolePolicy = keyof typeof rolePolicies;
