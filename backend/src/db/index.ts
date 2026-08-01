import { drizzle } from "drizzle-orm/mysql2";
import mysql from "mysql2/promise";
import * as schema from "./schema/index.js";

let pool: mysql.Pool | undefined;
let db: ReturnType<typeof createDatabase> | undefined;

function createDatabase() {
  pool = mysql.createPool({
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME || "technopro_dev",
    waitForConnections: true,
    connectionLimit: 10,
  });
  return drizzle(pool, { schema, mode: "default" });
}

export function getDb() {
  if (!db) {
    db = createDatabase();
  }
  return db;
}

export async function closeDb() {
  if (pool) {
    await pool.end();
    pool = undefined;
    db = undefined;
  }
}

export { schema };
