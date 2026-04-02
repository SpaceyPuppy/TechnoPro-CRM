import { useParams, Link, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Package, Calendar, User, FileText, CheckCircle } from "lucide-react";
import { purchaseOrdersApi } from "@/api/purchaseOrders";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";

export function PurchaseOrderDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["purchase-orders", id],
    queryFn: () => purchaseOrdersApi.get(id!),
  });

  const receiveMutation = useMutation({
    mutationFn: (notes?: string) => purchaseOrdersApi.receive(id!, { notes }),
    onSuccess: () => {
      toast.success("Order received and inventory updated!");
      qc.invalidateQueries({ queryKey: ["purchase-orders", id] });
      qc.invalidateQueries({ queryKey: ["inventory"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to receive order");
    },
  });

  const po = data?.data;

  if (isLoading) {
    return <div className="p-6 text-sm text-muted-foreground animate-pulse">Loading order details...</div>;
  }

  if (!po) {
    return (
      <div className="p-12 text-center">
        <h2 className="text-xl font-semibold mb-4">Order not found</h2>
        <Button asChild variant="outline">
          <Link to="/purchase-orders">Back to Orders</Link>
        </Button>
      </div>
    );
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "received": return "bg-green-100 text-green-700 border-green-200";
      case "ordered": return "bg-blue-100 text-blue-700 border-blue-200";
      case "cancelled": return "bg-red-100 text-red-700 border-red-200";
      default: return "bg-gray-100 text-gray-700 border-gray-200";
    }
  };

  const isReceived = po.status === "received";

  return (
    <div className="p-6 max-w-6xl space-y-6">
      <div className="flex justify-between items-start">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link to="/purchase-orders">
              <ArrowLeft size={16} />
            </Link>
          </Button>
          <div>
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-bold">{po.poNumber}</h1>
              <Badge variant="outline" className={getStatusColor(po.status)}>
                {po.status.toUpperCase()}
              </Badge>
            </div>
            <p className="text-sm text-muted-foreground mt-1">
              Created on {new Date(po.createdAt).toLocaleDateString()}
            </p>
          </div>
        </div>

        <div className="flex gap-2">
          {!isReceived && (
            <Button 
              className="bg-green-600 hover:bg-green-700 text-white"
              onClick={() => receiveMutation.mutate(undefined)}
              disabled={receiveMutation.isPending}
            >
              <CheckCircle size={16} className="mr-2" /> 
              {receiveMutation.isPending ? "Processing..." : "Mark as Received"}
            </Button>
          )}
          <Button variant="outline" asChild>
             {/* Edit logic omitted for brevity, usually link to edit mode */}
            <Link to={`/purchase-orders`}>Close</Link>
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-6">
        {/* Left Column: Info Cards */}
        <div className="col-span-1 space-y-6">
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold flex items-center gap-2">
                <User size={14} className="text-muted-foreground" /> Supplier Information
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div>
                <p className="text-sm font-medium">{(po as any).supplier?.name || "Unknown Supplier"}</p>
                <p className="text-xs text-muted-foreground">{(po as any).supplier?.email || "No email provided"}</p>
                <p className="text-xs text-muted-foreground">{(po as any).supplier?.phone || "No phone provided"}</p>
              </div>
              <div className="pt-2 border-t text-xs text-muted-foreground">
                <div className="flex justify-between py-1">
                  <span>Account No</span>
                  <span className="font-medium text-foreground">{(po as any).supplier?.accountNumber || "—"}</span>
                </div>
                <div className="flex justify-between py-1">
                  <span>Lead Time</span>
                  <span className="font-medium text-foreground">{(po as any).supplier?.leadTimeDays || "—"} days</span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold flex items-center gap-2">
                <Calendar size={14} className="text-muted-foreground" /> Logistics
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between text-sm py-1 border-b border-dashed">
                <span className="text-muted-foreground">Expected Date</span>
                <span className="font-medium">{po.expectedDeliveryDate ? new Date(po.expectedDeliveryDate).toLocaleDateString() : "Not specified"}</span>
              </div>
              <div className="flex justify-between text-sm py-1">
                <span className="text-muted-foreground">Total Cost</span>
                <span className="font-bold text-lg">${po.totalCost}</span>
              </div>
            </CardContent>
          </Card>

          {po.notes && (
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold flex items-center gap-2">
                  <FileText size={14} className="text-muted-foreground" /> Notes
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground whitespace-pre-wrap">{po.notes}</p>
              </CardContent>
            </Card>
          )}
        </div>

        {/* Right Column: Items Table */}
        <div className="col-span-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Order Items</CardTitle>
              <CardDescription>Line items included in this purchase order</CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              <table className="w-full text-sm">
                <thead className="bg-muted/30 border-y">
                  <tr>
                    <th className="text-left p-4 font-medium">Item Description</th>
                    <th className="text-right p-4 font-medium">Qty</th>
                    <th className="text-right p-4 font-medium">Unit Cost</th>
                    <th className="text-right p-4 font-medium">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {po.items.map((item: any) => (
                    <tr key={item.id}>
                      <td className="p-4">
                        <div className="flex items-center gap-3">
                          {item.inventoryItem ? (
                            <div className="p-2 bg-primary/10 rounded-md text-primary">
                              <Package size={14} />
                            </div>
                          ) : (
                            <div className="p-2 bg-muted rounded-md text-muted-foreground">
                              <FileText size={14} />
                            </div>
                          )}
                          <div>
                            <p className="font-medium">{item.inventoryItem?.name || item.description || "Unknown Item"}</p>
                            {item.inventoryItem && (
                              <p className="text-xs text-muted-foreground font-mono">{item.inventoryItem.sku}</p>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="p-4 text-right">{item.quantity}</td>
                      <td className="p-4 text-right">${item.unitCost}</td>
                      <td className="p-4 text-right font-semibold">${item.totalCost}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="bg-muted/10 border-t">
                  <tr>
                    <td colSpan={3} className="p-4 text-right font-medium text-muted-foreground">Order Total</td>
                    <td className="p-4 text-right font-bold text-lg">${po.totalCost}</td>
                  </tr>
                </tfoot>
              </table>
            </CardContent>
          </Card>

          {isReceived && (
            <div className="mt-4 p-4 border rounded-lg bg-green-50 border-green-100 text-green-700 flex gap-3 text-sm">
              <CheckCircle size={16} className="shrink-0 mt-0.5" />
              <div>
                <p className="font-bold">Order Received</p>
                <p>This order has been processed and inventory stock has been updated accordingly.</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
