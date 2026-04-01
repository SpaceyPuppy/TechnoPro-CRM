import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Edit, Trash2, Loader2 } from "lucide-react";
import { customersApi } from "@/api/customers";
import { ticketsApi } from "@/api/tickets";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { ticketStatusVariant, ticketStatusLabel } from "@/lib/ticketHelpers";
import { useRole } from "@/store/authStore";

export function CustomerDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const qc = useQueryClient();

  const { data: customerData, isLoading, isError } = useQuery({
    queryKey: ["customers", id],
    queryFn: () => customersApi.get(id!),
  });

  const { data: ticketsData } = useQuery({
    queryKey: ["tickets", { customerId: id }],
    queryFn: () => ticketsApi.list({ customerId: id }),
    enabled: !!id,
  });

  const deleteMutation = useMutation({
    mutationFn: () => customersApi.delete(id!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["customers"] });
      navigate("/customers");
    },
  });

  const { canManage } = useRole();

  if (isLoading) return <div className="p-6 text-sm text-muted-foreground">Loading...</div>;
  if (isError || !customerData)
    return <div className="p-6 text-sm text-destructive">Customer not found.</div>;

  const customer = customerData.data;

  function handleDelete() {
    if (confirm(`Delete ${customer.name}? This cannot be undone.`)) {
      deleteMutation.mutate();
    }
  }

  return (
    <div className="p-6 space-y-6 max-w-3xl">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link to="/customers">
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold flex-1">{customer.name}</h1>
        <Button variant="outline" size="sm" asChild>
          <Link to={`/customers/${id}/edit`}>
            <Edit size={14} />
            Edit
          </Link>
        </Button>
        {canManage && (
          <Button
            variant="destructive"
            size="sm"
            onClick={handleDelete}
            disabled={deleteMutation.isPending}
          >
            {deleteMutation.isPending ? (
              <Loader2 size={14} className="animate-spin" />
            ) : (
              <Trash2 size={14} />
            )}
            Delete
          </Button>
        )}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Contact Info</CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-muted-foreground">Email</p>
            <p>{customer.email ?? "—"}</p>
          </div>
          <div>
            <p className="text-muted-foreground">Phone</p>
            <p>{customer.phone ?? "—"}</p>
          </div>
          {customer.notes && (
            <div className="col-span-2">
              <p className="text-muted-foreground">Notes</p>
              <p className="whitespace-pre-wrap mt-1">{customer.notes}</p>
            </div>
          )}
        </CardContent>
      </Card>

      <div>
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold">Tickets</h2>
          <Button size="sm" asChild>
            <Link to={`/tickets/new?customerId=${id}`}>New Ticket</Link>
          </Button>
        </div>
        {!ticketsData || ticketsData.data.length === 0 ? (
          <p className="text-sm text-muted-foreground">No tickets yet.</p>
        ) : (
          <div className="rounded-lg border max-h-96 overflow-y-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">#</th>
                  <th className="px-4 py-3 text-left font-medium">Summary</th>
                  <th className="px-4 py-3 text-left font-medium">Status</th>
                  <th className="px-4 py-3 text-left font-medium">Created</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {ticketsData.data.map((t) => (
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
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(t.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
