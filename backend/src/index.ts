import Fastify from "fastify";
import { env, validateEnv } from "./config/env";
import { registerCors } from "./plugins/cors";
import { registerHelmet } from "./plugins/helmet";
import { registerRateLimit } from "./plugins/rate-limit";
import { registerJwt } from "./plugins/jwt";
import { registerErrorHandler } from "./plugins/error-handler";
import { healthRoutes } from "./routes/health.routes";
import { authRoutes } from "./routes/auth.routes";
import { customerRoutes } from "./routes/customer.routes";
import { ticketRoutes } from "./routes/ticket.routes";
import { closeDb } from "./db/index";

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

  // Register routes under /api/v1
  await app.register(
    async (api) => {
      await api.register(healthRoutes);
      await api.register(authRoutes);
      await api.register(customerRoutes);
      await api.register(ticketRoutes);
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
