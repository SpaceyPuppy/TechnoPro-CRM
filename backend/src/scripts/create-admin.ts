import "dotenv/config";
import { eq } from "drizzle-orm";
import { closeDb, getDb, schema } from "../db/index.js";
import { hashPassword } from "../services/auth.service.js";
import { generateId } from "../utils/id.js";

function requiredEnvironmentValue(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

async function createAdministrator() {
  const email = requiredEnvironmentValue("ADMIN_EMAIL").toLowerCase();
  const name = requiredEnvironmentValue("ADMIN_NAME");
  const password = requiredEnvironmentValue("ADMIN_PASSWORD");

  if (!/^\S+@\S+\.\S+$/.test(email)) {
    throw new Error("ADMIN_EMAIL must be a valid email address");
  }
  if (password.length < 12) {
    throw new Error("ADMIN_PASSWORD must contain at least 12 characters");
  }

  const db = getDb();
  const [existing] = await db
    .select({ id: schema.users.id, role: schema.users.role })
    .from(schema.users)
    .where(eq(schema.users.email, email))
    .limit(1);

  if (existing) {
    if (existing.role !== "admin") {
      throw new Error(`A non-admin user already exists for ${email}`);
    }
    console.log(`Administrator ${email} already exists; no changes made.`);
    return;
  }

  await db.insert(schema.users).values({
    id: generateId(),
    email,
    name,
    role: "admin",
    passwordHash: await hashPassword(password),
  });
  console.log(`Created production administrator ${email}.`);
}

createAdministrator()
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error(`Administrator creation failed: ${message}`);
    process.exitCode = 1;
  })
  .finally(closeDb);
