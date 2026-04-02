import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Plus, Search, Filter, ExternalLink } from "lucide-react";
import { purchaseOrdersApi } from "@/api/purchaseOrders";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export function PurchaseOrdersPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ["purchase-orders", { page, search: searchTerm }],
    queryFn: () => purchaseOrdersApi.list({ page, search: searchTerm }),
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case "received": return "bg-green-100 text-green-700 border-green-200";
      case "ordered": return "bg-blue-100 text-blue-700 border-blue-200";
      case "cancelled": return "bg-red-100 text-red-700 border-red-200";
      default: return "bg-gray-100 text-gray-700 border-gray-200";
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-semibold">Purchase Orders</h1>
          <p className="text-sm text-muted-foreground mt-1">Manage vendor orders and stock replenishment</p>
        </div>
        <Button asChild>
          <Link to="/purchase-orders/new">
            <Plus size={16} className="mr-2" /> New Order
          </Link>
        </Button>
      </div>

      <div className="flex gap-4 items-center">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search PO number..."
            className="pl-9"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <Button variant="outline" size="icon">
          <Filter size={16} />
        </Button>
      </div>

      {isLoading ? (
        <div className="grid gap-4">
          {[1, 2, 3].map((i) => (
            <Card key={i} className="animate-pulse h-24 bg-muted/20" />
          ))}
        </div>
      ) : (
        <div className="border rounded-lg bg-card overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-muted/50 border-b">
              <tr>
                <th className="text-left p-4 font-medium">PO Number</th>
                <th className="text-left p-4 font-medium">Supplier</th>
                <th className="text-left p-4 font-medium">Status</th>
                <th className="text-left p-4 font-medium">Date</th>
                <th className="text-right p-4 font-medium">Total</th>
                <th className="p-4 w-10"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {data?.data.map((po: any) => (
                <tr key={po.id} className="hover:bg-muted/30 transition-colors group">
                  <td className="p-4 font-medium">{po.poNumber}</td>
                  <td className="p-4">{po.supplierName || "—"}</td>
                  <td className="p-4">
                    <Badge variant="outline" className={getStatusColor(po.status)}>
                      {po.status.toUpperCase()}
                    </Badge>
                  </td>
                  <td className="p-4 text-muted-foreground">
                    {new Date(po.createdAt).toLocaleDateString()}
                  </td>
                  <td className="p-4 text-right font-semibold">${po.totalCost}</td>
                  <td className="p-4">
                    <Button variant="ghost" size="icon" asChild className="opacity-0 group-hover:opacity-100 transition-opacity">
                      <Link to={`/purchase-orders/${po.id}`}>
                        <ExternalLink size={14} />
                      </Link>
                    </Button>
                  </td>
                </tr>
              ))}
              {data?.data.length === 0 && (
                <tr>
                  <td colSpan={6} className="p-12 text-center text-muted-foreground">
                    No purchase orders found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
