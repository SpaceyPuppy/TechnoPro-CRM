import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Plus } from "lucide-react";
import { invoicesApi } from "@/api/invoices";
import { InvoiceStatus } from "@technopro/shared";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

const STATUS_OPTIONS = [
  { value: "", label: "All statuses" },
  { value: InvoiceStatus.DRAFT, label: "Draft" },
  { value: InvoiceStatus.OPEN, label: "Open" },
  { value: InvoiceStatus.PAID, label: "Paid" },
  { value: InvoiceStatus.VOID, label: "Void" },
];

function invoiceStatusVariant(status: string) {
  switch (status) {
    case "draft": return "secondary" as const;
    case "open": return "warning" as const;
    case "paid": return "success" as const;
    case "void": return "outline" as const;
    default: return "secondary" as const;
  }
}

export function InvoicesPage() {
  const navigate = useNavigate();
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["invoices", { page, status }],
    queryFn: () => invoicesApi.list({ page, pageSize: 20, status: status || undefined }),
  });

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Invoices</h1>
        <Button asChild size="sm">
          <Link to="/invoices/new">
            <Plus size={16} />
            New Invoice
          </Link>
        </Button>
      </div>

      <div>
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          className="text-sm border border-input rounded-md px-3 py-1.5 bg-background focus:outline-none focus:ring-1 focus:ring-ring"
        >
          {STATUS_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
      </div>

      {isLoading && <p className="text-sm text-muted-foreground">Loading...</p>}
      {isError && <p className="text-sm text-destructive">Failed to load invoices.</p>}

      {data && (
        <>
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">Invoice #</th>
                  <th className="px-4 py-3 text-left font-medium">Status</th>
                  <th className="px-4 py-3 text-right font-medium">Total</th>
                  <th className="px-4 py-3 text-right font-medium">Balance</th>
                  <th className="px-4 py-3 text-left font-medium">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.data.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">
                      No invoices found.
                    </td>
                  </tr>
                )}
                {data.data.map((inv) => (
                  <tr
                    key={inv.id}
                    className="hover:bg-muted/30 cursor-pointer transition-colors"
                    onClick={() => navigate(`/invoices/${inv.id}`)}
                  >
                    <td className="px-4 py-3 font-mono text-xs font-medium">{inv.invoiceNumber}</td>
                    <td className="px-4 py-3">
                      <Badge variant={invoiceStatusVariant(inv.status)}>
                        {inv.status.charAt(0).toUpperCase() + inv.status.slice(1)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-right">${inv.total}</td>
                    <td className="px-4 py-3 text-right">
                      {parseFloat(inv.balance) > 0 ? (
                        <span className="text-destructive">${inv.balance}</span>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(inv.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {data.pagination.totalPages > 1 && (
            <div className="flex items-center gap-2 justify-end text-sm">
              <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage((p) => p - 1)}>
                Previous
              </Button>
              <span className="text-muted-foreground">
                Page {data.pagination.page} of {data.pagination.totalPages}
              </span>
              <Button variant="outline" size="sm" disabled={page >= data.pagination.totalPages} onClick={() => setPage((p) => p + 1)}>
                Next
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
