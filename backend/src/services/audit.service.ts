import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";

export async function recordAuditEvent(
  entityType: string,
  entityId: string,
  action: string,
  userId: string | null,
  data?: Record<string, unknown>,
) {
  const db = getDb();
  await db.insert(schema.auditEvents).values({
    id: generateId(),
    entityType,
    entityId,
    action,
    userId,
    data: data === undefined ? null : JSON.stringify(data),
  });
}
