import type { FastifyInstance } from "fastify";

export function registerErrorHandler(app: FastifyInstance) {
  app.setErrorHandler((error, _request, reply) => {
    const statusCode = error.statusCode ?? 500;

    // Log internal errors without leaking details to client
    if (statusCode >= 500) {
      app.log.error(error);
    }

    // Fastify validation errors
    if (error.validation) {
      return reply.code(400).send({
        error: {
          code: "VALIDATION_ERROR",
          message: "Request validation failed",
          details: error.validation.map((v) => ({
            field: v.instancePath || v.params?.missingProperty || "unknown",
            message: v.message || "Invalid value",
          })),
        },
      });
    }

    // Rate limit errors
    if (statusCode === 429) {
      return reply.code(429).send({
        error: { code: "RATE_LIMITED", message: "Too many requests, please try again later" },
      });
    }

    // All other errors — never expose internal details
    return reply.code(statusCode).send({
      error: {
        code: statusCode >= 500 ? "INTERNAL_ERROR" : error.code || "ERROR",
        message: statusCode >= 500 ? "An unexpected error occurred" : error.message,
      },
    });
  });
}
