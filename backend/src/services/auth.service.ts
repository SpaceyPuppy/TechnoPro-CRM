import { eq } from "drizzle-orm";
import bcrypt from "bcryptjs";
import { getDb, schema } from "../db/index";

const BCRYPT_ROUNDS = 12;

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export async function findUserByEmail(email: string) {
  const db = getDb();
  const results = await db.select().from(schema.users).where(eq(schema.users.email, email)).limit(1);
  return results[0] ?? null;
}

export async function findUserById(id: string) {
  const db = getDb();
  const results = await db.select().from(schema.users).where(eq(schema.users.id, id)).limit(1);
  return results[0] ?? null;
}
