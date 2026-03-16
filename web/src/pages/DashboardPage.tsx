import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Users, Ticket, FileText, AlertTriangle, TrendingUp, Clock, Plus } from "lucide-react";
import { dashboardApi } from "@/api/dashboard";
import { useAuthStore } from "@/store/authStore";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  ticketStatusLabel,
  ticketStatusVariant,
  ticketPriorityVariant,
  ticketPriorityLabel,
} from "@/lib/ticketHelpers";
import type { TicketStatus, TicketPriority } from "@technopro/shared";

function formatCurrency(amount: string) {
  return `$${parseFloat(amount).toLocaleString("en-AU", { minimumFractionDigits: 2 })}`;
}

function formatAge(dateStr: string) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

const STATUS_ORDER = [
  "open",
  "in_progress",
  "waiting_parts",
  "waiting_customer",
  "resolved",
  "closed",
  "cancelled",
];

export function DashboardPage() {
  const { user } = useAuthStore();

  const { data, isLoading } = useQuery({
    queryKey: ["dashboard", "stats"],
    queryFn: () => dashboardApi.getStats(),
    refetchInterval: 60_000,
  });

  const stats = data?.data;

  const activeCount =
    stats?.ticketCounts
      .filter((c) => !["closed", "cancelled"].includes(c.status))
      .reduce((sum, c) => sum + c.count, 0) ?? 0;

  const inProgressCount =
    stats?.ticketCounts.find((c) => c.status === "in_progress")?.count ?? 0;

  const sortedCounts = [...(stats?.ticketCounts ?? [])].sort(
    (a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status),
  );

  return (
    <div className="p-6 space-y-6 max-w-5xl">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Welcome back, {user?.name}</p>
        </div>
        <div className="flex gap-2">
          <Button size="sm" asChild>
            <Link to="/tickets/new">
              <Plus size={14} />
              New Ticket
            </Link>
          </Button>
          <Button size="sm" variant="outline" asChild>
            <Link to="/customers/new">
              <Plus size={14} />
              New Customer
            </Link>
          </Button>
          <Button size="sm" variant="outline" asChild>
            <Link to="/invoices/new">
              <Plus size={14} />
              New Invoice
            </Link>
          </Button>
        </div>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="pt-5">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs text-muted-foreground">Active Tickets</p>
                {isLoading ? <Skeleton className="h-8 w-12 mt-1" /> : <p className="text-2xl font-bold mt-1">{activeCount}</p>}
              </div>
              <Ticket size={18} className="text-muted-foreground mt-0.5" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-5">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs text-muted-foreground">In Progress</p>
                {isLoading ? <Skeleton className="h-8 w-12 mt-1" /> : <p className="text-2xl font-bold mt-1">{inProgressCount}</p>}
              </div>
              <Clock size={18} className="text-muted-foreground mt-0.5" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-5">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs text-muted-foreground">Overdue</p>
                {isLoading ? <Skeleton className="h-8 w-12 mt-1" /> : (
                  <p className={`text-2xl font-bold mt-1 ${(stats?.overdueCount ?? 0) > 0 ? "text-destructive" : ""}`}>
                    {stats?.overdueCount ?? 0}
                  </p>
                )}
              </div>
              <AlertTriangle
                size={18}
                className={
                  (stats?.overdueCount ?? 0) > 0
                    ? "text-destructive mt-0.5"
                    : "text-muted-foreground mt-0.5"
                }
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-5">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs text-muted-foreground">Today's Revenue</p>
                {isLoading ? <Skeleton className="h-8 w-20 mt-1" /> : <p className="text-2xl font-bold mt-1">{formatCurrency(stats?.todayRevenue ?? "0")}</p>}
              </div>
              <TrendingUp size={18} className="text-muted-foreground mt-0.5" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Status breakdown + today summary */}
      <div className="grid md:grid-cols-2 gap-4">
        <Card>
          <CardHeader>
            <CardTitle>Tickets by Status</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {isLoading && (
              <div className="space-y-2">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex items-center justify-between">
                    <Skeleton className="h-5 w-24" />
                    <Skeleton className="h-4 w-6" />
                  </div>
                ))}
              </div>
            )}
            {sortedCounts.map((c) => (
              <div key={c.status} className="flex items-center justify-between text-sm">
                <Badge variant={ticketStatusVariant(c.status as TicketStatus)}>
                  {ticketStatusLabel(c.status as TicketStatus)}
                </Badge>
                <span className="font-medium tabular-nums">{c.count}</span>
              </div>
            ))}
            {!isLoading && sortedCounts.length === 0 && (
              <p className="text-sm text-muted-foreground">No tickets yet.</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Today</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center gap-3 text-sm">
              <Ticket size={15} className="text-muted-foreground shrink-0" />
              <span className="text-muted-foreground">New tickets</span>
              <span className="ml-auto font-medium">{isLoading ? "—" : (stats?.todayNewTickets ?? 0)}</span>
            </div>
            <div className="flex items-center gap-3 text-sm">
              <TrendingUp size={15} className="text-muted-foreground shrink-0" />
              <span className="text-muted-foreground">Revenue collected</span>
              <span className="ml-auto font-medium">
                {isLoading ? "—" : formatCurrency(stats?.todayRevenue ?? "0")}
              </span>
            </div>
            <div className="pt-3 border-t flex gap-2">
              <Button size="sm" variant="outline" className="flex-1" asChild>
                <Link to="/tickets">
                  <Ticket size={13} />
                  Tickets
                </Link>
              </Button>
              <Button size="sm" variant="outline" className="flex-1" asChild>
                <Link to="/customers">
                  <Users size={13} />
                  Customers
                </Link>
              </Button>
              <Button size="sm" variant="outline" className="flex-1" asChild>
                <Link to="/invoices">
                  <FileText size={13} />
                  Invoices
                </Link>
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* My Tickets (technician/counter only) */}
      {stats?.myTickets && stats.myTickets.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>My Open Tickets</CardTitle>
          </CardHeader>
          <CardContent className="divide-y">
            {stats.myTickets.map((t) => (
              <Link
                key={t.id}
                to={`/tickets/${t.id}`}
                className="flex items-center gap-3 py-2.5 text-sm hover:bg-accent -mx-4 px-4 transition-colors"
              >
                <span className="font-mono text-xs text-muted-foreground w-24 shrink-0">
                  {t.ticketNumber}
                </span>
                <span className="flex-1 truncate">{t.summary}</span>
                <Badge variant={ticketStatusVariant(t.status as TicketStatus)}>
                  {ticketStatusLabel(t.status as TicketStatus)}
                </Badge>
                <Badge variant={ticketPriorityVariant(t.priority as TicketPriority)}>
                  {ticketPriorityLabel(t.priority as TicketPriority)}
                </Badge>
                {t.dueDate && (
                  <span className="text-xs text-muted-foreground shrink-0">
                    Due {new Date(t.dueDate).toLocaleDateString()}
                  </span>
                )}
              </Link>
            ))}
          </CardContent>
        </Card>
      )}

      {/* Recent Activity */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Activity</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading && (
            <div className="space-y-3">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex gap-3">
                  <Skeleton className="h-4 w-14 shrink-0" />
                  <Skeleton className="h-4 flex-1" />
                </div>
              ))}
            </div>
          )}
          {!isLoading && (stats?.recentEvents.length ?? 0) === 0 && (
            <p className="text-sm text-muted-foreground">No recent activity.</p>
          )}
          <div className="space-y-3">
            {stats?.recentEvents.map((ev) => (
              <div key={ev.id} className="flex gap-3 text-sm">
                <span className="text-xs text-muted-foreground w-14 shrink-0 pt-0.5 tabular-nums">
                  {formatAge(ev.createdAt)}
                </span>
                <div className="flex-1 min-w-0">
                  <Link
                    to={`/tickets/${ev.ticketId}`}
                    className="font-mono text-xs text-primary hover:underline"
                  >
                    {ev.ticketNumber}
                  </Link>
                  <span className="text-muted-foreground mx-1.5">·</span>
                  <span className="capitalize text-muted-foreground">
                    {ev.eventType.replace(/_/g, " ")}
                  </span>
                  {ev.content && (
                    <p className="text-xs text-muted-foreground mt-0.5 truncate">{ev.content}</p>
                  )}
                </div>
                <span className="text-xs text-muted-foreground shrink-0 truncate max-w-[200px]">
                  {ev.ticketSummary}
                </span>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
