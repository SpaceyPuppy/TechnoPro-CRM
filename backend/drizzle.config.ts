import { defineConfig } from "drizzle-kit";

export default defineConfig({
  // The backend uses NodeNext-style `.js` specifiers in TypeScript. Point
  // Drizzle Kit at the compiled schema so generation and migration resolve
  // imports the same way as production Node.
  schema: "./dist/db/schema/index.js",
  out: "./src/db/migrations",
  dialect: "mysql",
  dbCredentials: {
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "technopro_dev",
    database: process.env.DB_NAME || "technopro_dev",
  },
});
