import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Plus, Search, Users, Upload } from "lucide-react";
import { toast } from "sonner";
import { customersApi } from "@/api/customers";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { TableSkeleton } from "@/components/ui/skeleton";
import { CsvImportDialog } from "@/components/ui/csv-import-dialog";
import type { ImportResult } from "@/components/ui/csv-import-dialog";
import { useRole } from "@/store/authStore";

export function CustomersPage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { canManage } = useRole();
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [showImport, setShowImport] = useState(false);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["customers", { page, search }],
    queryFn: () => customersApi.list({ page, pageSize: 20, search: search || undefined }),
  });

  return (
    <div className="p-6 space-y-4">
      {showImport && (
        <CsvImportDialog
          title="Import Customers"
          columns={[
            { key: "name", label: "Name", required: true },
            { key: "email", label: "Email" },
            { key: "phone", label: "Phone" },
            { key: "notes", label: "Notes" },
          ]}
          exampleRow="John Smith,john@example.com,0412345678,VIP customer"
          onImport={async (rows) => {
            const typed = rows.map((r) => ({
              name: r["name"] ?? "",
              email: r["email"] || undefined,
              phone: r["phone"] || undefined,
              notes: r["notes"] || undefined,
            }));
            const res = await customersApi.import(typed);
            qc.invalidateQueries({ queryKey: ["customers"] });
            if (res.data.imported > 0) toast.success(`${res.data.imported} customers imported`);
            return res.data;
          }}
          onClose={() => setShowImport(false)}
        />
      )}
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Customers</h1>
        <div className="flex gap-2">
          {canManage && (
            <Button variant="outline" size="sm" onClick={() => setShowImport(true)}>
              <Upload size={16} />
              Import CSV
            </Button>
          )}
          <Button asChild size="sm">
            <Link to="/customers/new">
              <Plus size={16} />
              New Customer
            </Link>
          </Button>
        </div>
      </div>

      <div className="relative max-w-sm">
        <Search size={14} className="absolute left-2.5 top-2.5 text-muted-foreground" />
        <Input
          className="pl-8"
          placeholder="Search customers..."
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
      </div>

      {isLoading && <TableSkeleton rows={5} cols={4} />}
      {isError && <p className="text-sm text-destructive">Failed to load customers.</p>}

      {data && (
        <>
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">Name</th>
                  <th className="px-4 py-3 text-left font-medium">Email</th>
                  <th className="px-4 py-3 text-left font-medium">Phone</th>
                  <th className="px-4 py-3 text-left font-medium">Added</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.data.length === 0 && (
                  <tr>
                    <td colSpan={4} className="px-4 py-12 text-center">
                      <div className="flex flex-col items-center gap-2 text-muted-foreground">
                        <Users size={32} className="opacity-30" />
                        <p className="text-sm">No customers found.</p>
                      </div>
                    </td>
                  </tr>
                )}
                {data.data.map((c) => (
                  <tr
                    key={c.id}
                    className="hover:bg-muted/30 cursor-pointer transition-colors"
                    onClick={() => navigate(`/customers/${c.id}`)}
                  >
                    <td className="px-4 py-3 font-medium">{c.name}</td>
                    <td className="px-4 py-3 text-muted-foreground">{c.email ?? "—"}</td>
                    <td className="px-4 py-3 text-muted-foreground">{c.phone ?? "—"}</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(c.createdAt).toLocaleDateString()}
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
