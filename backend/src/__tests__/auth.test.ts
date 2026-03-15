import { describe, it, expect } from "vitest";
import { hashPassword, verifyPassword } from "../services/auth.service";

describe("auth service", () => {
  describe("password hashing", () => {
    it("should hash a password and verify it", async () => {
      const password = "test-password-123";
      const hash = await hashPassword(password);

      expect(hash).not.toBe(password);
      expect(hash.length).toBeGreaterThan(0);

      const isValid = await verifyPassword(password, hash);
      expect(isValid).toBe(true);
    });

    it("should reject wrong password", async () => {
      const hash = await hashPassword("correct-password");
      const isValid = await verifyPassword("wrong-password", hash);
      expect(isValid).toBe(false);
    });

    it("should produce different hashes for same password", async () => {
      const password = "same-password";
      const hash1 = await hashPassword(password);
      const hash2 = await hashPassword(password);
      expect(hash1).not.toBe(hash2);
    });
  });
});
