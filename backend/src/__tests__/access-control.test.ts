import { describe, expect, it } from "vitest";
import { rolePolicies } from "../access-control.js";
import { assertTicketStatusTransition, TicketConflictError } from "../services/ticket.service.js";

const roles = ["technician", "counter", "manager", "admin"] as const;

describe("role policy matrix", () => {
  it.each(roles)("allows %s to perform the expected critical workflows", (role) => {
    const includes = (policy: readonly string[]) => policy.includes(role);
    expect(rolePolicies.operations).toContain(role);
    expect(includes(rolePolicies.counter)).toBe(role !== "technician");
    expect(includes(rolePolicies.manager)).toBe(role === "manager" || role === "admin");
    expect(includes(rolePolicies.admin)).toBe(role === "admin");
  });

  it("keeps lower roles out of privileged workflows", () => {
    expect(rolePolicies.counter).not.toContain("technician");
    expect(rolePolicies.manager).not.toContain("technician");
    expect(rolePolicies.manager).not.toContain("counter");
    expect(rolePolicies.admin).toEqual(["admin"]);
  });

  it("allows operational transitions but reserves terminal ticket states for managers", () => {
    expect(() => assertTicketStatusTransition("triage", "in_progress", "technician")).not.toThrow();
    expect(() => assertTicketStatusTransition("ready", "closed", "technician")).toThrow(
      TicketConflictError,
    );
    expect(() => assertTicketStatusTransition("ready", "closed", "manager")).not.toThrow();
    expect(() => assertTicketStatusTransition("closed", "in_progress", "admin")).toThrow(
      TicketConflictError,
    );
  });
});
