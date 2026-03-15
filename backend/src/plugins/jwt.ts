import type { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import fjwt from "@fastify/jwt";
import { env } from "../config/env";
import type { UserRole } from "@technopro/shared";

// Extend Fastify's JWT user type
declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { id: string; role: UserRole };
    user: { id: string; role: UserRole };
  }
}

export async function registerJwt(app: FastifyInstance) {
  await app.register(fjwt, {
    secret: env.JWT_SECRET,
    sign: { expiresIn: env.JWT_EXPIRES_IN },
  });

  // Decorator to require auth on routes
  app.decorate("authenticate", async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      reply.code(401).send({
        error: { code: "UNAUTHORIZED", message: "Invalid or expired token" },
      });
    }
  });

  // Decorator to require specific roles
  app.decorate(
    "requireRole",
    (...roles: UserRole[]) =>
      async (request: FastifyRequest, reply: FastifyReply) => {
        try {
          await request.jwtVerify();
        } catch {
          return reply.code(401).send({
            error: { code: "UNAUTHORIZED", message: "Invalid or expired token" },
          });
        }
        if (!roles.includes(request.user.role)) {
          return reply.code(403).send({
            error: { code: "FORBIDDEN", message: "Insufficient permissions" },
          });
        }
      },
  );
}

// Extend Fastify's type system
declare module "fastify" {
  interface FastifyInstance {
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
    requireRole: (
      ...roles: UserRole[]
    ) => (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}
