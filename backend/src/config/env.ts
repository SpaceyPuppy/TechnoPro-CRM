import "dotenv/config";

export const env = {
  PORT: Number(process.env.PORT) || 3000,
  NODE_ENV: process.env.NODE_ENV || "development",

  DB_HOST: process.env.DB_HOST || "localhost",
  DB_PORT: Number(process.env.DB_PORT) || 3306,
  DB_USER: process.env.DB_USER || "root",
  DB_PASSWORD: process.env.DB_PASSWORD || "",
  DB_NAME: process.env.DB_NAME || "technopro_dev",

  JWT_SECRET: process.env.JWT_SECRET || "",
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || "24h",

  CORS_ORIGIN: process.env.CORS_ORIGIN || "http://localhost:5173",

  UPLOAD_DIR: process.env.UPLOAD_DIR || "./uploads",
  MAX_FILE_SIZE_MB: Number(process.env.MAX_FILE_SIZE_MB) || 10,
} as const;

// Fail fast if critical env vars are missing in production
export function validateEnv() {
  if (!env.JWT_SECRET) {
    throw new Error("JWT_SECRET environment variable is required");
  }
  if (env.JWT_SECRET.length < 32) {
    throw new Error("JWT_SECRET must be at least 32 characters");
  }
  if (env.NODE_ENV === "production" && !env.DB_PASSWORD) {
    throw new Error("DB_PASSWORD environment variable is required in production");
  }
  if (!Number.isFinite(env.PORT) || env.PORT < 1 || env.PORT > 65535) {
    throw new Error("PORT must be a valid TCP port");
  }
  if (!Number.isFinite(env.MAX_FILE_SIZE_MB) || env.MAX_FILE_SIZE_MB <= 0) {
    throw new Error("MAX_FILE_SIZE_MB must be greater than zero");
  }
}
