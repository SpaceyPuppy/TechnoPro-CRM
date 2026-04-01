import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Plus, Search, Upload } from "lucide-react";
import { toast } from "sonner";
import { inventoryApi } from "@/api/inventory";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { useRole } from "@/store/authStore";
import { CsvImportDialog } from "@/components/ui/csv-import-dialog";
import type { ImportResult } from "@/components/ui/csv-import-dialog";

export function InventoryPage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [showImport, setShowImport] = useState(false);
  const { canManage } = useRole();

  const { data, isLoading, isError } = useQuery({
    queryKey: ["inventory", { page, search }],
    queryFn: () => inventoryApi.list({ page, pageSize: 20, search: search || undefined }),
  });

  return (
    <div className="p-6 space-y-4">
      {showImport && (
        <CsvImportDialog
          title="Import Inventory Items"
          columns={[
            { key: "sku", label: "SKU", required: true },
            { key: "name", label: "Name", required: true },
            { key: "price", label: "Price", required: true },
            { key: "cost", label: "Cost" },
            { key: "stockQty", label: "StockQty" },
            { key: "description", label: "Description" },
          ]}
          exampleRow="SCR-001,iPhone 16 Screen,149.99,89.99,5,Replacement screen"
          onImport={async (rows) => {
            const typed = rows.map((r) => ({
              sku: r["sku"] ?? "",
              name: r["name"] ?? "",
              price: r["price"] ?? "0.00",
              cost: r["cost"] || undefined,
              stockQty: r["stockQty"] || undefined,
              description: r["description"] || undefined,
            }));
            const res = await inventoryApi.import(typed);
            qc.invalidateQueries({ queryKey: ["inventory"] });
            if (res.data.imported > 0) toast.success(`${res.data.imported} items imported`);
            return res.data;
          }}
          onClose={() => setShowImport(false)}
        />
      )}
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Inventory</h1>
        {canManage && (
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={() => setShowImport(true)}>
              <Upload size={16} />
              Import CSV
            </Button>
            <Button asChild size="sm">
              <Link to="/inventory/new">
                <Plus size={16} />
                New Item
              </Link>
            </Button>
          </div>
        )}
      </div>

      <div className="relative max-w-sm">
        <Search size={14} className="absolute left-2.5 top-2.5 text-muted-foreground" />
        <Input
          className="pl-8"
          placeholder="Search by name or SKU..."
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
      </div>

      {isLoading && <p className="text-sm text-muted-foreground">Loading...</p>}
      {isError && <p className="text-sm text-destructive">Failed to load inventory.</p>}

      {data && (
        <>
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">SKU</th>
                  <th className="px-4 py-3 text-left font-medium">Name</th>
                  <th className="px-4 py-3 text-left font-medium">Price</th>
                  <th className="px-4 py-3 text-left font-medium">Stock</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.data.length === 0 && (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-muted-foreground">
                      No items found.
                    </td>
                  </tr>
                )}
                {data.data.map((item) => (
                  <tr
                    key={item.id}
                    className={canManage ? "hover:bg-muted/30 cursor-pointer transition-colors" : ""}
                    onClick={() => canManage && navigate(`/inventory/${item.id}/edit`)}
                  >
                    <td className="px-4 py-3 font-mono text-xs">{item.sku}</td>
                    <td className="px-4 py-3 font-medium">{item.name}</td>
                    <td className="px-4 py-3">${item.price}</td>
                    <td className="px-4 py-3">
                      {item.stockQty === null ? (
                        <Badge variant="outline">Untracked</Badge>
                      ) : item.stockQty === 0 ? (
                        <Badge variant="destructive">Out of stock</Badge>
                      ) : (
                        <Badge variant="success">{item.stockQty} in stock</Badge>
                      )}
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
