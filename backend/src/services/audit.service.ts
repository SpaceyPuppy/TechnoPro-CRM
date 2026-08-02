import { and, desc, eq } from "drizzle-orm";
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

export async function listAuditEvents(options: {
  page: number;
  pageSize: number;
  entityType?: string;
  entityId?: string;
}) {
  const filters = [];
  if (options.entityType) filters.push(eq(schema.auditEvents.entityType, options.entityType));
  if (options.entityId) filters.push(eq(schema.auditEvents.entityId, options.entityId));
  return getDb()
    .select()
    .from(schema.auditEvents)
    .where(filters.length ? and(...filters) : undefined)
    .orderBy(desc(schema.auditEvents.createdAt), desc(schema.auditEvents.id))
    .limit(options.pageSize)
    .offset((options.page - 1) * options.pageSize);
}
