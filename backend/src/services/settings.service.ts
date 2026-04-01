import { getDb } from "../db/index.js";
import { appSettings } from "../db/schema/index.js";
import { eq } from "drizzle-orm";

export const DEFAULT_SETTINGS: Record<string, string> = {
  business_name: "First Choice Phone Repair",
  business_abn: "",
  business_address: "",
  business_phone: "",
  business_email: "",
  gst_rate: "10.00",
  invoice_notes: "",
  labour_rate: "75.00",
};

export async function getAllSettings(): Promise<Record<string, string>> {
  const db = getDb();
  const rows = await db.select().from(appSettings);
  const result: Record<string, string> = { ...DEFAULT_SETTINGS };
  for (const row of rows) {
    result[row.key] = row.value;
  }
  return result;
}

export async function getSetting(key: string): Promise<string> {
  const db = getDb();
  const rows = await db
    .select()
    .from(appSettings)
    .where(eq(appSettings.key, key))
    .limit(1);
  return rows[0]?.value ?? DEFAULT_SETTINGS[key] ?? "";
}

export async function updateSettings(updates: Record<string, string>): Promise<void> {
  const db = getDb();
  for (const [key, value] of Object.entries(updates)) {
    await db
      .insert(appSettings)
      .values({ key, value })
      .onDuplicateKeyUpdate({ set: { value } });
  }
}
