import type { FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import { env } from "../config/env";

export async function registerCors(app: FastifyInstance) {
  await app.register(cors, {
    origin: env.CORS_ORIGIN.split(",").map((o) => o.trim()),
    credentials: true,
  });
}
