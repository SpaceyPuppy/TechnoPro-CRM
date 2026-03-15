import "dotenv/config";
import { getDb, closeDb, schema } from "../db/index";
import { hashPassword } from "../services/auth.service";
import { generateId } from "../utils/id";

const SEED_USERS = [
  { email: "admin@technopro.local", name: "Admin User", role: "admin" as const, password: "admin123" },
  { email: "manager@technopro.local", name: "Shop Manager", role: "manager" as const, password: "manager123" },
  { email: "tech1@technopro.local", name: "Alex Technician", role: "technician" as const, password: "tech123" },
  { email: "counter@technopro.local", name: "Front Counter", role: "counter" as const, password: "counter123" },
];

async function seed() {
  console.log("Seeding database...");
  const db = getDb();

  for (const user of SEED_USERS) {
    const existing = await db
      .select()
      .from(schema.users)
      .where(({ email }) => ({ email: user.email }))
      .limit(1);

    // Skip if user already exists (check by simple query)
    const check = await db.select().from(schema.users).limit(100);
    const found = check.find((u) => u.email === user.email);
    if (found) {
      console.log(`  Skipping ${user.email} (already exists)`);
      continue;
    }

    const passwordHash = await hashPassword(user.password);
    await db.insert(schema.users).values({
      id: generateId(),
      email: user.email,
      name: user.name,
      role: user.role,
      passwordHash,
    });
    console.log(`  Created ${user.role}: ${user.email} (password: ${user.password})`);
  }

  console.log("Seed complete.");
  await closeDb();
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
