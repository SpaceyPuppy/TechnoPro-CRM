import { drizzle } from "drizzle-orm/mysql2";
import mysql from "mysql2/promise";
import * as schema from "./schema/index";

let db: ReturnType<typeof drizzle<typeof schema>>;
let pool: mysql.Pool;

export function getDb() {
  if (!db) {
    pool = mysql.createPool({
      host: process.env.DB_HOST || "localhost",
      port: Number(process.env.DB_PORT) || 3306,
      user: process.env.DB_USER || "root",
      password: process.env.DB_PASSWORD || "",
      database: process.env.DB_NAME || "technopro_dev",
      waitForConnections: true,
      connectionLimit: 10,
    });
    db = drizzle(pool, { schema, mode: "default" });
  }
  return db;
}

export async function closeDb() {
  if (pool) {
    await pool.end();
  }
}

export { schema };
