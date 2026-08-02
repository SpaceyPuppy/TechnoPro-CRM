import { describe, expect, it } from "vitest";
import {
  AttachmentValidationError,
  maxAttachmentBytes,
  validateAttachmentMetadata,
} from "../services/attachment.service.js";

describe("attachment validation", () => {
  it("accepts supported types at or below the configured size limit", () => {
    expect(() => validateAttachmentMetadata("image/jpeg", maxAttachmentBytes)).not.toThrow();
    expect(() => validateAttachmentMetadata("application/pdf", 1024)).not.toThrow();
  });

  it("returns a stable error for unsupported types", () => {
    try {
      validateAttachmentMetadata("application/x-msdownload", 1024);
      throw new Error("Expected attachment type validation to fail");
    } catch (error) {
      expect(error).toBeInstanceOf(AttachmentValidationError);
      expect((error as AttachmentValidationError).code).toBe("UNSUPPORTED_ATTACHMENT_TYPE");
    }
  });

  it("returns a stable error for oversized uploads", () => {
    try {
      validateAttachmentMetadata("image/png", maxAttachmentBytes + 1);
      throw new Error("Expected attachment size validation to fail");
    } catch (error) {
      expect(error).toBeInstanceOf(AttachmentValidationError);
      expect((error as AttachmentValidationError).code).toBe("ATTACHMENT_TOO_LARGE");
    }
  });
});
