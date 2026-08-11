import Fastify from "fastify";
import multipart from "@fastify/multipart";
import { env, validateEnv } from "./config/env.js";
import { registerCors } from "./plugins/cors.js";
import { registerHelmet } from "./plugins/helmet.js";
import { registerRateLimit } from "./plugins/rate-limit.js";
import { registerJwt } from "./plugins/jwt.js";
import { registerErrorHandler } from "./plugins/error-handler.js";
import { healthRoutes } from "./routes/health.routes.js";
import { authRoutes } from "./routes/auth.routes.js";
import { customerRoutes } from "./routes/customer.routes.js";
import { ticketRoutes } from "./routes/ticket.routes.js";
import { attachmentRoutes } from "./routes/attachment.routes.js";
import { inventoryRoutes } from "./routes/inventory.routes.js";
import { invoiceRoutes } from "./routes/invoice.routes.js";
import { dashboardRoutes } from "./routes/dashboard.routes.js";
import { userRoutes } from "./routes/user.routes.js";
import { settingsRoutes } from "./routes/settings.routes.js";
import { timeEntryRoutes } from "./routes/time-entry.routes.js";
import { supplierRoutes } from "./routes/suppliers.routes.js";
import { purchaseOrderRoutes } from "./routes/purchase-orders.routes.js";
import { stockRoutes } from "./routes/stock.routes.js";
import { auditRoutes } from "./routes/audit.routes.js";
import { closeDb } from "./db/index.js";

async function main() {
  validateEnv();

  const app = Fastify({
    logger: {
      level: env.NODE_ENV === "production" ? "info" : "debug",
      // Never log request/response bodies — they may contain sensitive data
      serializers: {
        req(request) {
          return { method: request.method, url: request.url };
        },
      },
    },
  });

  // Register plugins
  await registerCors(app);
  await registerHelmet(app);
  await registerRateLimit(app);
  await registerJwt(app);
  registerErrorHandler(app);

  // Multipart (file uploads) — registered before routes, 10MB limit
  await app.register(multipart, {
    limits: {
      fileSize: env.MAX_FILE_SIZE_MB * 1024 * 1024,
      files: 1,
    },
  });

  // Register routes under /api/v1
  await app.register(
    async (api) => {
      await api.register(healthRoutes);
      await api.register(authRoutes);
      await api.register(customerRoutes);
      await api.register(ticketRoutes);
      await api.register(attachmentRoutes);
      await api.register(timeEntryRoutes);
      await api.register(inventoryRoutes);
      await api.register(invoiceRoutes);
      await api.register(dashboardRoutes);
      await api.register(userRoutes);
      await api.register(settingsRoutes);
      await api.register(supplierRoutes);
      await api.register(purchaseOrderRoutes);
      await api.register(stockRoutes);
      await api.register(auditRoutes);
    },
    { prefix: "/api/v1" },

  );

  // Graceful shutdown
  const signals = ["SIGINT", "SIGTERM"] as const;
  for (const signal of signals) {
    process.on(signal, async () => {
      app.log.info(`Received ${signal}, shutting down...`);
      await app.close();
      await closeDb();
      process.exit(0);
    });
  }

  await app.listen({ port: env.PORT, host: "0.0.0.0" });
  app.log.info(`TechnoPro API running on port ${env.PORT}`);
}

main().catch((err) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});
