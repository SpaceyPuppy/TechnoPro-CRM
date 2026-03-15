import { describe, it, expect } from "vitest";
import { parsePagination, paginationMeta } from "../utils/pagination";

describe("pagination", () => {
  describe("parsePagination", () => {
    it("should use defaults when no params provided", () => {
      const result = parsePagination({});
      expect(result).toEqual({ page: 1, pageSize: 20 });
    });

    it("should clamp page to minimum 1", () => {
      const result = parsePagination({ page: -5 });
      expect(result.page).toBe(1);
    });

    it("should clamp pageSize to max 100", () => {
      const result = parsePagination({ pageSize: 500 });
      expect(result.pageSize).toBe(100);
    });

    it("should clamp pageSize to min 1", () => {
      const result = parsePagination({ pageSize: 0 });
      expect(result.pageSize).toBe(1);
    });
  });

  describe("paginationMeta", () => {
    it("should calculate total pages correctly", () => {
      const meta = paginationMeta(1, 20, 85);
      expect(meta).toEqual({
        page: 1,
        pageSize: 20,
        totalCount: 85,
        totalPages: 5,
      });
    });

    it("should handle zero results", () => {
      const meta = paginationMeta(1, 20, 0);
      expect(meta.totalPages).toBe(0);
    });
  });
});
