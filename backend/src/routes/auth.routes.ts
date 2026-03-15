import type { FastifyInstance } from "fastify";
import { findUserByEmail, findUserById, verifyPassword } from "../services/auth.service";
import type { LoginRequest, LoginResponse } from "@technopro/shared";

const loginSchema = {
  body: {
    type: "object",
    required: ["email", "password"],
    properties: {
      email: { type: "string", format: "email", maxLength: 255 },
      password: { type: "string", minLength: 1, maxLength: 255 },
    },
    additionalProperties: false,
  },
} as const;

export async function authRoutes(app: FastifyInstance) {
  app.post<{ Body: LoginRequest }>("/auth/login", { schema: loginSchema }, async (request, reply) => {
    const { email, password } = request.body;

    const user = await findUserByEmail(email);
    if (!user || !user.active) {
      return reply.code(401).send({
        error: { code: "INVALID_CREDENTIALS", message: "Invalid email or password" },
      });
    }

    const valid = await verifyPassword(password, user.passwordHash);
    if (!valid) {
      return reply.code(401).send({
        error: { code: "INVALID_CREDENTIALS", message: "Invalid email or password" },
      });
    }

    const token = app.jwt.sign({ id: user.id, role: user.role });

    const response: LoginResponse = {
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        active: user.active,
        createdAt: user.createdAt.toISOString(),
      },
    };

    return reply.send({ data: response });
  });

  // Get current authenticated user
  app.get("/auth/me", { preHandler: [app.authenticate] }, async (request, reply) => {
    const user = await findUserById(request.user.id);
    if (!user) {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "User not found" },
      });
    }
    return reply.send({
      data: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        active: user.active,
        createdAt: user.createdAt.toISOString(),
      },
    });
  });
}
