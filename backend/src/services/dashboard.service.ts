import { eq, and, lt, gte, sql, desc } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { isNull, isNotNull } from "drizzle-orm";
import { decimalToHundredths, hundredthsToDecimal } from "../utils/money.js";

export async function getDashboardStats(userId: string, userRole: string) {
  const db = getDb();

  const now = new Date();
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);
  const tomorrowStart = new Date(todayStart);
  tomorrowStart.setDate(tomorrowStart.getDate() + 1);

  const [
    ticketCountRows,
    overdueResult,
    unassignedResult,
    unbilledResult,
    todayTicketsResult,
    todayRevenueResult,
    recentEvents,
  ] =
    await Promise.all([
      // Ticket counts by status
      db
        .select({
          status: schema.tickets.status,
          count: sql<number>`count(*)`,
        })
        .from(schema.tickets)
        .groupBy(schema.tickets.status),

      // Overdue: dueDate < now AND status not closed/cancelled
      db
        .select({ count: sql<number>`count(*)` })
        .from(schema.tickets)
        .where(
          and(
            lt(schema.tickets.dueDate, now),
            sql`${schema.tickets.status} NOT IN ('resolved', 'closed', 'cancelled')`,
          ),
        ),

      db
        .select({ count: sql<number>`count(*)` })
        .from(schema.tickets)
        .where(
          and(
            isNull(schema.tickets.assignedToId),
            sql`${schema.tickets.status} NOT IN ('resolved', 'closed', 'cancelled')`,
          ),
        ),

      db
        .select({ count: sql<number>`count(DISTINCT ${schema.timeEntries.ticketId})` })
        .from(schema.timeEntries)
        .where(
          and(
            isNotNull(schema.timeEntries.stoppedAt),
            isNull(schema.timeEntries.billedAs),
          ),
        ),

      // Today's new tickets
      db
        .select({ count: sql<number>`count(*)` })
        .from(schema.tickets)
        .where(
          and(
            gte(schema.tickets.createdAt, todayStart),
            lt(schema.tickets.createdAt, tomorrowStart),
          ),
        ),

      // Today's revenue
      db
        .select({
          total: sql<string>`COALESCE(SUM(CASE WHEN ${schema.payments.type} = 'refund' THEN -${schema.payments.amount} ELSE ${schema.payments.amount} END), 0)`,
        })
        .from(schema.payments)
        .where(
          and(
            gte(schema.payments.paidAt, todayStart),
            lt(schema.payments.paidAt, tomorrowStart),
          ),
        ),

      // Recent events (last 10) with ticket info
      db
        .select({
          id: schema.ticketEvents.id,
          ticketId: schema.ticketEvents.ticketId,
          ticketNumber: schema.tickets.ticketNumber,
          ticketSummary: schema.tickets.summary,
          eventType: schema.ticketEvents.eventType,
          content: schema.ticketEvents.content,
          createdAt: schema.ticketEvents.createdAt,
        })
        .from(schema.ticketEvents)
        .innerJoin(schema.tickets, eq(schema.ticketEvents.ticketId, schema.tickets.id))
        .orderBy(desc(schema.ticketEvents.createdAt))
        .limit(10),
    ]);

  // My open tickets (for technician/counter roles)
  let myTickets = undefined;
  if (userRole === "technician" || userRole === "counter") {
    myTickets = await db
      .select()
      .from(schema.tickets)
      .where(
        and(
          eq(schema.tickets.assignedToId, userId),
          sql`${schema.tickets.status} NOT IN ('resolved', 'closed', 'cancelled')`,
        ),
      )
      .orderBy(desc(schema.tickets.createdAt))
      .limit(20);
  }

  return {
    ticketCounts: ticketCountRows.map((r) => ({
      status: r.status,
      count: Number(r.count),
    })),
    overdueCount: Number(overdueResult[0]?.count ?? 0),
    unassignedCount: Number(unassignedResult[0]?.count ?? 0),
    unbilledCount: Number(unbilledResult[0]?.count ?? 0),
    todayNewTickets: Number(todayTicketsResult[0]?.count ?? 0),
    todayRevenue: hundredthsToDecimal(
      decimalToHundredths(String(todayRevenueResult[0]?.total ?? "0.00")),
    ),
    recentEvents: recentEvents.map((e) => ({
      ...e,
      createdAt: e.createdAt.toISOString(),
    })),
    myTickets: myTickets?.map((t) => ({
      id: t.id,
      ticketNumber: t.ticketNumber,
      customerId: t.customerId,
      deviceId: t.deviceId,
      assignedToId: t.assignedToId,
      ticketType: t.ticketType,
      status: t.status,
      priority: t.priority,
      summary: t.summary,
      description: t.description,
      diagnosis: t.diagnosis,
      resolution: t.resolution,
      scheduledAt: t.scheduledAt?.toISOString() ?? null,
      dueDate: t.dueDate?.toISOString() ?? null,
      createdAt: t.createdAt.toISOString(),
      updatedAt: t.updatedAt.toISOString(),
    })),
  };
}
