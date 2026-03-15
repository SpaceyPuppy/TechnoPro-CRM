import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { invoicesApi } from "@/api/invoices";
import { customersApi } from "@/api/customers";
import { ticketsApi } from "@/api/tickets";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useState } from "react";

const selectClass =
  "w-full text-sm border border-input rounded-md px-3 py-1.5 bg-background focus:outline-none focus:ring-1 focus:ring-ring";

export function InvoiceCreatePage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [searchParams] = useSearchParams();
  const prefilledTicketId = searchParams.get("ticketId") ?? "";

  const [mode, setMode] = useState<"standalone" | "ticket">(
    prefilledTicketId ? "ticket" : "standalone",
  );
  const [ticketId, setTicketId] = useState(prefilledTicketId);

  const { data: ticketsData } = useQuery({
    queryKey: ["tickets", { pageSize: 100 }],
    queryFn: () => ticketsApi.list({ pageSize: 100 }),
    enabled: mode === "ticket" && !prefilledTicketId,
  });

  const { data: prefilledTicket } = useQuery({
    queryKey: ["tickets", prefilledTicketId],
    queryFn: () => ticketsApi.get(prefilledTicketId),
    enabled: !!prefilledTicketId,
  });

  const mutation = useMutation({
    mutationFn: () =>
      invoicesApi.create({ ticketId: mode === "ticket" && ticketId ? ticketId : undefined }),
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ["invoices"] });
      const from = mode === "ticket" && ticketId ? "ticket" : "";
      navigate(`/invoices/${res.data.id}${from ? "?from=ticket" : ""}`);
    },
  });

  return (
    <div className="p-6 max-w-lg">
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="icon" asChild>
          <Link to={prefilledTicketId ? `/tickets/${prefilledTicketId}` : "/invoices"}>
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">New Invoice</h1>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Invoice Details</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {!prefilledTicketId && (
            <div className="space-y-1.5">
              <Label>Type</Label>
              <div className="flex gap-3">
                <label className="flex items-center gap-2 cursor-pointer text-sm">
                  <input
                    type="radio"
                    value="standalone"
                    checked={mode === "standalone"}
                    onChange={() => { setMode("standalone"); setTicketId(""); }}
                  />
                  Standalone sale
                </label>
                <label className="flex items-center gap-2 cursor-pointer text-sm">
                  <input
                    type="radio"
                    value="ticket"
                    checked={mode === "ticket"}
                    onChange={() => setMode("ticket")}
                  />
                  Linked to ticket
                </label>
              </div>
            </div>
          )}

          {mode === "ticket" && (
            <div className="space-y-1.5">
              <Label>Ticket</Label>
              {prefilledTicketId ? (
                <p className="text-sm py-1">
                  {prefilledTicket?.data.ticketNumber} — {prefilledTicket?.data.summary}
                </p>
              ) : (
                <select className={selectClass} value={ticketId} onChange={(e) => setTicketId(e.target.value)}>
                  <option value="">Select a ticket...</option>
                  {ticketsData?.data.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.ticketNumber} — {t.summary}
                    </option>
                  ))}
                </select>
              )}
            </div>
          )}

          {mutation.error && (
            <p className="text-sm text-destructive">{mutation.error.message}</p>
          )}

          <div className="flex gap-2 pt-2">
            <Button
              onClick={() => mutation.mutate()}
              disabled={mutation.isPending || (mode === "ticket" && !ticketId)}
            >
              Create Invoice
            </Button>
            <Button
              variant="outline"
              onClick={() => navigate(prefilledTicketId ? `/tickets/${prefilledTicketId}` : "/invoices")}
            >
              Cancel
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
