import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Plus } from "lucide-react";
import { invoicesApi } from "@/api/invoices";
import { InvoiceStatus } from "@technopro/shared";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useRole } from "@/store/authStore";

const INVOICE_STATUS_OPTIONS = [
  { value: "", label: "All statuses" },
  { value: InvoiceStatus.DRAFT, label: "Draft" },
  { value: InvoiceStatus.OPEN, label: "Open" },
  { value: InvoiceStatus.PAID, label: "Paid" },
  { value: InvoiceStatus.VOID, label: "Void" },
];

const QUOTE_STATUS_OPTIONS = [
  { value: "", label: "All statuses" },
  { value: "draft", label: "Draft" },
  { value: "sent", label: "Sent" },
  { value: "accepted", label: "Accepted" },
  { value: "declined", label: "Declined" },
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

function quoteStatusVariant(status: string) {
  switch (status) {
    case "draft": return "secondary" as const;
    case "sent": return "info" as const;
    case "accepted": return "success" as const;
    case "declined": return "destructive" as const;
    default: return "secondary" as const;
  }
}

export function FinancePage() {
  const navigate = useNavigate();
  const { canCounter } = useRole();
  const [tab, setTab] = useState<"invoices" | "quotes">("invoices");
  const [invoiceStatus, setInvoiceStatus] = useState("");
  const [quoteStatus, setQuoteStatus] = useState("");
  const [page, setPage] = useState(1);

  const { data: invoiceData, isLoading: invoiceLoading, isError: invoiceError } = useQuery({
    queryKey: ["invoices", { page, status: invoiceStatus, type: "invoice" }],
    queryFn: () => invoicesApi.list({ page, pageSize: 20, status: invoiceStatus || undefined, type: "invoice" }),
    enabled: tab === "invoices",
  });

  const { data: quoteData, isLoading: quoteLoading, isError: quoteError } = useQuery({
    queryKey: ["invoices", { page, status: quoteStatus, type: "quote" }],
    queryFn: () => invoicesApi.list({ page, pageSize: 20, type: "quote", quoteStatus: quoteStatus || undefined }),
    enabled: tab === "quotes",
  });

  const data = tab === "invoices" ? invoiceData : quoteData;
  const isLoading = tab === "invoices" ? invoiceLoading : quoteLoading;
  const isError = tab === "invoices" ? invoiceError : quoteError;
  const status = tab === "invoices" ? invoiceStatus : quoteStatus;
  const setStatus = tab === "invoices" ? setInvoiceStatus : setQuoteStatus;
  const statusOptions = tab === "invoices" ? INVOICE_STATUS_OPTIONS : QUOTE_STATUS_OPTIONS;

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Finance</h1>
        {canCounter && (
          <Button asChild size="sm">
            <Link to={tab === "invoices" ? "/invoices/new" : "/quotes/new"}>
              <Plus size={16} />
              {tab === "invoices" ? "New Invoice" : "New Quote"}
            </Link>
          </Button>
        )}
      </div>

      {/* Tabs */}
      <div className="flex gap-2 border-b">
        <button
          onClick={() => {
            setTab("invoices");
            setPage(1);
          }}
          className={`px-4 py-2 font-medium text-sm transition-colors ${
            tab === "invoices"
              ? "border-b-2 border-primary text-primary"
              : "text-muted-foreground hover:text-foreground"
          }`}
        >
          Invoices
        </button>
        <button
          onClick={() => {
            setTab("quotes");
            setPage(1);
          }}
          className={`px-4 py-2 font-medium text-sm transition-colors ${
            tab === "quotes"
              ? "border-b-2 border-primary text-primary"
              : "text-muted-foreground hover:text-foreground"
          }`}
        >
          Quotes
        </button>
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
          {statusOptions.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </div>

      {isLoading && <p className="text-sm text-muted-foreground">Loading...</p>}
      {isError && <p className="text-sm text-destructive">Failed to load {tab}.</p>}

      {data && (
        <>
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">{tab === "invoices" ? "Invoice" : "Quote"} #</th>
                  <th className="px-4 py-3 text-left font-medium">Customer</th>
                  <th className="px-4 py-3 text-left font-medium">Status</th>
                  <th className="px-4 py-3 text-right font-medium">Total</th>
                  {tab === "invoices" && <th className="px-4 py-3 text-right font-medium">Balance</th>}
                  <th className="px-4 py-3 text-left font-medium">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.data.length === 0 && (
                  <tr>
                    <td colSpan={tab === "invoices" ? 5 : 4} className="px-4 py-8 text-center text-muted-foreground">
                      No {tab} found.
                    </td>
                  </tr>
                )}
                {data.data.map((item) => (
                  <tr
                    key={item.id}
                    className="hover:bg-muted/30 cursor-pointer transition-colors"
                    onClick={() => navigate(`/${tab === "invoices" ? "invoices" : "quotes"}/${item.id}`)}
                  >
                    <td className="px-4 py-3 font-mono text-xs font-medium">
                      {tab === "invoices" ? item.invoiceNumber : item.invoiceNumber?.replace(/^INV/, "QTE")}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{item.customerName || "—"}</td>
                    <td className="px-4 py-3">
                      <Badge
                        variant={
                          tab === "invoices"
                            ? invoiceStatusVariant(item.status)
                            : quoteStatusVariant(item.quoteStatus || "draft")
                        }
                      >
                        {tab === "invoices"
                          ? item.status.charAt(0).toUpperCase() + item.status.slice(1)
                          : (item.quoteStatus || "draft").charAt(0).toUpperCase() +
                            (item.quoteStatus || "draft").slice(1)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-right">${item.total}</td>
                    {tab === "invoices" && (
                      <td className="px-4 py-3 text-right">
                        {parseFloat(item.balance) > 0 ? (
                          <span className="text-destructive">${item.balance}</span>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </td>
                    )}
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(item.createdAt).toLocaleDateString()}
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
