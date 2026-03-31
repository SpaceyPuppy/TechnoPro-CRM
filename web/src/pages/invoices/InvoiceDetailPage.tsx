import { useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { invoicesApi } from "@/api/invoices";
import { inventoryApi } from "@/api/inventory";
import { LineItemType, PaymentMethod, InvoiceStatus } from "@technopro/shared";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";

const selectClass =
  "w-full text-sm border border-input rounded-md px-3 py-1.5 bg-background focus:outline-none focus:ring-1 focus:ring-ring";

function invoiceStatusVariant(status: string) {
  switch (status) {
    case "draft": return "secondary" as const;
    case "open": return "warning" as const;
    case "paid": return "success" as const;
    case "void": return "outline" as const;
    default: return "secondary" as const;
  }
}

function quoteStatusVariant(status?: string) {
  switch (status) {
    case "draft": return "secondary" as const;
    case "sent": return "info" as const;
    case "accepted": return "success" as const;
    case "declined": return "destructive" as const;
    default: return "secondary" as const;
  }
}

// --- Add Line Item Form ---
function AddLineItemForm({ invoiceId, onDone }: { invoiceId: string; onDone: () => void }) {
  const qc = useQueryClient();
  const [type, setType] = useState<"service" | "part">("service");
  const [description, setDescription] = useState("");
  const [quantity, setQuantity] = useState("1");
  const [unitPrice, setUnitPrice] = useState("0.00");
  const [inventoryItemId, setInventoryItemId] = useState("");

  const { data: inventoryData } = useQuery({
    queryKey: ["inventory", { pageSize: 200 }],
    queryFn: () => inventoryApi.list({ pageSize: 200 }),
    enabled: type === "part",
  });

  const mutation = useMutation({
    mutationFn: () =>
      invoicesApi.addLineItem(invoiceId, {
        type,
        description,
        quantity: parseInt(quantity, 10),
        unitPrice: parseFloat(unitPrice).toFixed(2),
        inventoryItemId: inventoryItemId || undefined,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["invoices", invoiceId] });
      toast.success("Item added");
      setDescription("");
      setQuantity("1");
      setUnitPrice("0.00");
      setInventoryItemId("");
      onDone();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  function handleInventorySelect(id: string) {
    setInventoryItemId(id);
    if (id && inventoryData) {
      const item = inventoryData.data.find((i) => i.id === id);
      if (item) {
        setDescription(item.name);
        setUnitPrice(item.price);
      }
    }
  }

  return (
    <div className="border rounded-lg p-4 space-y-3 bg-muted/20">
      <p className="text-sm font-medium">Add Line Item</p>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1">
          <Label className="text-xs">Type</Label>
          <select className={selectClass} value={type} onChange={(e) => setType(e.target.value as "service" | "part")}>
            <option value="service">Labour / Service</option>
            <option value="part">Part</option>
          </select>
        </div>
        <div className="space-y-1">
          <Label className="text-xs">Qty</Label>
          <Input type="number" min={1} value={quantity} onChange={(e) => setQuantity(e.target.value)} />
        </div>
      </div>

      {type === "part" && inventoryData && inventoryData.data.length > 0 && (
        <div className="space-y-1">
          <Label className="text-xs">Pick from inventory (optional)</Label>
          <select className={selectClass} value={inventoryItemId} onChange={(e) => handleInventorySelect(e.target.value)}>
            <option value="">— custom / free-form —</option>
            {inventoryData.data.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name} — ${item.price}
              </option>
            ))}
          </select>
        </div>
      )}

      <div className="space-y-1">
        <Label className="text-xs">Description *</Label>
        <Input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="e.g. Screen replacement, Labour 1hr" />
      </div>

      <div className="space-y-1">
        <Label className="text-xs">Unit Price ($)</Label>
        <Input value={unitPrice} onChange={(e) => setUnitPrice(e.target.value)} placeholder="0.00" className="w-32" />
      </div>

      <div className="flex gap-2">
        <Button
          size="sm"
          disabled={!description.trim() || mutation.isPending}
          onClick={() => mutation.mutate()}
        >
          Add
        </Button>
        <Button size="sm" variant="outline" onClick={onDone}>Cancel</Button>
      </div>
    </div>
  );
}

// --- Add Payment Form ---
function AddPaymentForm({ invoiceId, balance, onDone }: { invoiceId: string; balance: string; onDone: () => void }) {
  const qc = useQueryClient();
  const [amount, setAmount] = useState(balance);
  const [method, setMethod] = useState<string>(PaymentMethod.CASH);
  const [reference, setReference] = useState("");

  const mutation = useMutation({
    mutationFn: () =>
      invoicesApi.addPayment(invoiceId, {
        amount: parseFloat(amount).toFixed(2),
        method: method as typeof PaymentMethod[keyof typeof PaymentMethod],
        reference: reference || undefined,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["invoices", invoiceId] });
      qc.invalidateQueries({ queryKey: ["invoices"] });
      toast.success("Payment recorded");
      onDone();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <div className="border rounded-lg p-4 space-y-3 bg-muted/20">
      <p className="text-sm font-medium">Record Payment</p>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1">
          <Label className="text-xs">Amount ($)</Label>
          <Input value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0.00" />
        </div>
        <div className="space-y-1">
          <Label className="text-xs">Method</Label>
          <select className={selectClass} value={method} onChange={(e) => setMethod(e.target.value)}>
            <option value={PaymentMethod.CASH}>Cash</option>
            <option value={PaymentMethod.CARD}>Card</option>
            <option value={PaymentMethod.EFTPOS}>EFTPOS</option>
            <option value={PaymentMethod.BANK_TRANSFER}>Bank Transfer</option>
            <option value={PaymentMethod.OTHER}>Other</option>
          </select>
        </div>
      </div>
      <div className="space-y-1">
        <Label className="text-xs">Reference (optional)</Label>
        <Input value={reference} onChange={(e) => setReference(e.target.value)} placeholder="Receipt #, transaction ID..." />
      </div>
      <div className="flex gap-2">
        <Button size="sm" disabled={!amount || mutation.isPending} onClick={() => mutation.mutate()}>
          Record
        </Button>
        <Button size="sm" variant="outline" onClick={onDone}>Cancel</Button>
      </div>
    </div>
  );
}

// --- Main page ---
export function InvoiceDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [showAddItem, setShowAddItem] = useState(false);
  const [showAddPayment, setShowAddPayment] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ["invoices", id],
    queryFn: () => invoicesApi.get(id!),
  });

  const statusMutation = useMutation({
    mutationFn: (status: string) => invoicesApi.updateStatus(id!, status),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["invoices"] });
      toast.success("Invoice updated");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const quoteStatusMutation = useMutation({
    mutationFn: (quoteStatus: "draft" | "sent" | "accepted" | "declined") =>
      invoicesApi.updateQuoteStatus(id!, quoteStatus),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["invoices"] });
      toast.success("Quote updated");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const convertToTicketMutation = useMutation({
    mutationFn: () => invoicesApi.convertQuoteToTicket(id!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["invoices"] });
      toast.success("Quote converted to ticket");
      navigate("/tickets");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const removeItemMutation = useMutation({
    mutationFn: (lineItemId: string) => invoicesApi.removeLineItem(id!, lineItemId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["invoices", id] });
      toast.success("Item removed");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  if (isLoading) return <div className="p-6 text-sm text-muted-foreground">Loading...</div>;
  if (!data) return <div className="p-6 text-sm text-destructive">Invoice not found.</div>;

  const inv = data.data;
  const backTo = searchParams.get("from") === "ticket" && inv.ticketId
    ? `/tickets/${inv.ticketId}`
    : "/invoices";

  return (
    <div className="p-6 space-y-6 max-w-3xl">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link to={backTo}><ArrowLeft size={16} /></Link>
        </Button>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <span className="font-mono text-sm font-medium">{inv.invoiceNumber}</span>
            {inv.type === "quote" ? (
              <Badge variant={quoteStatusVariant(inv.quoteStatus)}>
                {(inv.quoteStatus || "draft").charAt(0).toUpperCase() + (inv.quoteStatus || "draft").slice(1)}
              </Badge>
            ) : (
              <Badge variant={invoiceStatusVariant(inv.status)}>
                {inv.status.charAt(0).toUpperCase() + inv.status.slice(1)}
              </Badge>
            )}
          </div>
          {inv.ticketId && (
            <Link to={`/tickets/${inv.ticketId}`} className="text-xs text-muted-foreground hover:underline">
              Linked ticket
            </Link>
          )}
        </div>

        {/* Status actions */}
        <div className="flex gap-2">
          {inv.type === "quote" ? (
            <>
              {inv.quoteStatus === "draft" && (
                <Button size="sm" variant="outline" onClick={() => quoteStatusMutation.mutate("sent")} disabled={quoteStatusMutation.isPending}>
                  Mark Sent
                </Button>
              )}
              {inv.quoteStatus === "sent" && (
                <>
                  <Button size="sm" variant="outline" onClick={() => quoteStatusMutation.mutate("accepted")} disabled={quoteStatusMutation.isPending}>
                    Accept
                  </Button>
                  <Button size="sm" variant="ghost" className="text-muted-foreground" onClick={() => quoteStatusMutation.mutate("declined")} disabled={quoteStatusMutation.isPending}>
                    Decline
                  </Button>
                </>
              )}
              {inv.quoteStatus === "accepted" && (
                <Button size="sm" variant="outline" onClick={() => convertToTicketMutation.mutate()} disabled={convertToTicketMutation.isPending}>
                  Convert to Ticket
                </Button>
              )}
            </>
          ) : (
            <>
              {inv.status === "draft" && (
                <Button size="sm" variant="outline" onClick={() => statusMutation.mutate("open")} disabled={statusMutation.isPending}>
                  Mark Open
                </Button>
              )}
              {inv.status === "open" && (
                <Button size="sm" variant="outline" onClick={() => statusMutation.mutate("paid")} disabled={statusMutation.isPending}>
                  Mark Paid
                </Button>
              )}
              {inv.status !== "void" && inv.status !== "paid" && (
                <Button size="sm" variant="ghost" className="text-muted-foreground" onClick={() => { if (confirm("Void this invoice?")) statusMutation.mutate("void"); }} disabled={statusMutation.isPending}>
                  Void
                </Button>
              )}
            </>
          )}
        </div>
      </div>

      {/* Line Items */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Line Items</CardTitle>
            {inv.status !== "void" && inv.status !== "paid" && (
              <Button size="sm" variant="outline" onClick={() => setShowAddItem((v) => !v)}>
                <Plus size={14} />
                Add Item
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent className="space-y-3">
          {showAddItem && (
            <AddLineItemForm invoiceId={id!} onDone={() => setShowAddItem(false)} />
          )}

          {inv.lineItems.length === 0 && !showAddItem && (
            <p className="text-sm text-muted-foreground">No items yet.</p>
          )}

          {inv.lineItems.map((li) => (
            <div key={li.id} className="flex items-start gap-3 text-sm">
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <Badge variant={li.type === "service" ? "info" : "secondary"} className="text-xs">
                    {li.type === "service" ? "Labour" : "Part"}
                  </Badge>
                  <span>{li.description}</span>
                </div>
                <p className="text-xs text-muted-foreground mt-0.5">
                  {li.quantity} × ${li.unitPrice}
                </p>
              </div>
              <span className="font-medium">${li.total}</span>
              {inv.status !== "void" && inv.status !== "paid" && (
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-7 w-7 text-muted-foreground hover:text-destructive"
                  disabled={removeItemMutation.isPending}
                  onClick={() => removeItemMutation.mutate(li.id)}
                >
                  <Trash2 size={13} />
                </Button>
              )}
            </div>
          ))}

          {inv.lineItems.length > 0 && (
            <>
              <Separator />
              <div className="space-y-1 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Subtotal</span>
                  <span>${inv.subtotal}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Tax</span>
                  <span>${inv.tax}</span>
                </div>
                <div className="flex justify-between font-semibold text-base">
                  <span>Total</span>
                  <span>${inv.total}</span>
                </div>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      {/* Payments */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Payments</CardTitle>
            {inv.status !== "void" && inv.status !== "draft" && parseFloat(inv.balance) > 0 && (
              <Button size="sm" variant="outline" onClick={() => setShowAddPayment((v) => !v)}>
                <Plus size={14} />
                Record Payment
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent className="space-y-3">
          {showAddPayment && (
            <AddPaymentForm invoiceId={id!} balance={inv.balance} onDone={() => setShowAddPayment(false)} />
          )}

          {inv.payments.length === 0 && !showAddPayment && (
            <p className="text-sm text-muted-foreground">No payments recorded.</p>
          )}

          {inv.payments.map((p) => (
            <div key={p.id} className="flex items-center gap-3 text-sm">
              <div className="flex-1">
                <span className="capitalize">{p.method.replace("_", " ")}</span>
                {p.reference && (
                  <span className="text-muted-foreground ml-2 text-xs">ref: {p.reference}</span>
                )}
                <p className="text-xs text-muted-foreground">
                  {new Date(p.paidAt).toLocaleDateString()}
                </p>
              </div>
              <span className="font-medium text-green-700">${p.amount}</span>
            </div>
          ))}

          {(inv.payments.length > 0 || parseFloat(inv.amountPaid) > 0) && (
            <>
              <Separator />
              <div className="space-y-1 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Amount Paid</span>
                  <span className="text-green-700">${inv.amountPaid}</span>
                </div>
                <div className="flex justify-between font-semibold">
                  <span>Balance Due</span>
                  <span className={parseFloat(inv.balance) > 0 ? "text-destructive" : "text-muted-foreground"}>
                    ${inv.balance}
                  </span>
                </div>
              </div>
            </>
          )}

          {inv.status === "draft" && parseFloat(inv.total) > 0 && (
            <p className="text-xs text-muted-foreground">Mark invoice as Open before recording payments.</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
