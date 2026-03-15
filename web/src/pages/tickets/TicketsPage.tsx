import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Plus } from "lucide-react";
import { ticketsApi } from "@/api/tickets";
import { TicketStatus } from "@technopro/shared";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  ticketStatusVariant,
  ticketStatusLabel,
  ticketPriorityLabel,
  ticketPriorityVariant,
} from "@/lib/ticketHelpers";

const STATUS_OPTIONS = [
  { value: "", label: "All statuses" },
  ...Object.values(TicketStatus).map((s) => ({ value: s, label: ticketStatusLabel(s) })),
];

export function TicketsPage() {
  const navigate = useNavigate();
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["tickets", { page, status }],
    queryFn: () => ticketsApi.list({ page, pageSize: 20, status: status || undefined }),
  });

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Tickets</h1>
        <Button asChild size="sm">
          <Link to="/tickets/new">
            <Plus size={16} />
            New Ticket
          </Link>
        </Button>
      </div>

      <div>
        <select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          className="text-sm border border-input rounded-md px-3 py-1.5 bg-background focus:outline-none focus:ring-1 focus:ring-ring"
        >
          {STATUS_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </div>

      {isLoading && <p className="text-sm text-muted-foreground">Loading...</p>}
      {isError && <p className="text-sm text-destructive">Failed to load tickets.</p>}

      {data && (
        <>
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">#</th>
                  <th className="px-4 py-3 text-left font-medium">Summary</th>
                  <th className="px-4 py-3 text-left font-medium">Status</th>
                  <th className="px-4 py-3 text-left font-medium">Priority</th>
                  <th className="px-4 py-3 text-left font-medium">Created</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.data.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">
                      No tickets found.
                    </td>
                  </tr>
                )}
                {data.data.map((t) => (
                  <tr
                    key={t.id}
                    className="hover:bg-muted/30 cursor-pointer transition-colors"
                    onClick={() => navigate(`/tickets/${t.id}`)}
                  >
                    <td className="px-4 py-3 font-mono text-xs">{t.ticketNumber}</td>
                    <td className="px-4 py-3">{t.summary}</td>
                    <td className="px-4 py-3">
                      <Badge variant={ticketStatusVariant(t.status)}>
                        {ticketStatusLabel(t.status)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3">
                      <Badge variant={ticketPriorityVariant(t.priority)}>
                        {ticketPriorityLabel(t.priority)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(t.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {data.pagination.totalPages > 1 && (
            <div className="flex items-center gap-2 justify-end text-sm">
              <Button
                variant="outline"
                size="sm"
                disabled={page === 1}
                onClick={() => setPage((p) => p - 1)}
              >
                Previous
              </Button>
              <span className="text-muted-foreground">
                Page {data.pagination.page} of {data.pagination.totalPages}
              </span>
              <Button
                variant="outline"
                size="sm"
                disabled={page >= data.pagination.totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
