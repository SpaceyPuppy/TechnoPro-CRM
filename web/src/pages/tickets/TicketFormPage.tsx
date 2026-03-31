import { useEffect } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { ticketsApi } from "@/api/tickets";
import { customersApi } from "@/api/customers";
import { usersApi } from "@/api/users";
import { TicketPriority } from "@technopro/shared";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const selectClass =
  "w-full text-sm border border-input rounded-md px-3 py-1.5 bg-background focus:outline-none focus:ring-1 focus:ring-ring";

const createSchema = z.object({
  customerId: z.string().min(1, "Customer is required"),
  summary: z.string().min(1, "Summary is required").max(500),
  priority: z.nativeEnum(TicketPriority),
  assignedToId: z.string().optional(),
  description: z.string().max(10000).optional(),
  dueDate: z.string().optional(),
});

const editSchema = z.object({
  summary: z.string().min(1, "Summary is required").max(500),
  priority: z.nativeEnum(TicketPriority),
  assignedToId: z.string().optional(),
  description: z.string().max(10000).optional(),
  diagnosis: z.string().max(10000).optional(),
  resolution: z.string().max(10000).optional(),
  dueDate: z.string().optional(),
});

type CreateValues = z.infer<typeof createSchema>;
type EditValues = z.infer<typeof editSchema>;

export function TicketFormPage() {
  const { id } = useParams<{ id: string }>();
  const isEdit = !!id;
  const [searchParams] = useSearchParams();
  const prefilledCustomerId = searchParams.get("customerId") ?? "";
  const navigate = useNavigate();
  const qc = useQueryClient();

  const createForm = useForm<CreateValues>({
    resolver: zodResolver(createSchema),
    defaultValues: { customerId: prefilledCustomerId, priority: TicketPriority.NORMAL },
  });

  const editForm = useForm<EditValues>({
    resolver: zodResolver(editSchema),
    defaultValues: { priority: TicketPriority.NORMAL },
  });

  const { data: ticketData, isLoading: ticketLoading } = useQuery({
    queryKey: ["tickets", id],
    queryFn: () => ticketsApi.get(id!),
    enabled: isEdit,
  });

  const { data: customersData } = useQuery({
    queryKey: ["customers", { pageSize: 1000 }],
    queryFn: () => customersApi.list({ pageSize: 1000 }),
    enabled: !isEdit,
  });

  const { data: usersData } = useQuery({
    queryKey: ["users"],
    queryFn: () => usersApi.list(),
  });

  const { data: prefilledCustomer } = useQuery({
    queryKey: ["customers", prefilledCustomerId],
    queryFn: () => customersApi.get(prefilledCustomerId),
    enabled: !!prefilledCustomerId,
  });

  useEffect(() => {
    if (ticketData && isEdit) {
      const t = ticketData.data;
      editForm.reset({
        summary: t.summary,
        priority: t.priority,
        assignedToId: t.assignedToId ?? "",
        description: t.description ?? "",
        diagnosis: t.diagnosis ?? "",
        resolution: t.resolution ?? "",
        dueDate: t.dueDate ? t.dueDate.slice(0, 10) : "",
      });
    }
  }, [ticketData, isEdit, editForm]);

  const createMutation = useMutation({
    mutationFn: ticketsApi.create,
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ["tickets"] });
      navigate(`/tickets/${res.data.id}`);
    },
  });

  const updateMutation = useMutation({
    mutationFn: (values: EditValues) => ticketsApi.update(id!, values),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tickets"] });
      navigate(`/tickets/${id}`);
    },
  });

  if (isEdit && ticketLoading)
    return <div className="p-6 text-sm text-muted-foreground">Loading...</div>;

  if (isEdit) {
    return (
      <div className="p-6 max-w-lg">
        <div className="flex items-center gap-3 mb-6">
          <Button variant="ghost" size="icon" asChild>
            <Link to={`/tickets/${id}`}>
              <ArrowLeft size={16} />
            </Link>
          </Button>
          <h1 className="text-2xl font-semibold">Edit Ticket</h1>
        </div>
        <Card>
          <CardHeader>
            <CardTitle>Ticket Details</CardTitle>
          </CardHeader>
          <CardContent>
            <form
              onSubmit={editForm.handleSubmit((v) => {
                const body = {
                  ...v,
                  assignedToId: v.assignedToId || undefined,
                  dueDate: v.dueDate ? new Date(v.dueDate).toISOString() : undefined,
                };
                return updateMutation.mutateAsync(body);
              })}
              className="space-y-4"
            >
              <div className="space-y-1.5">
                <Label>Summary *</Label>
                <Input {...editForm.register("summary")} />
                {editForm.formState.errors.summary && (
                  <p className="text-xs text-destructive">
                    {editForm.formState.errors.summary.message}
                  </p>
                )}
              </div>
              <div className="space-y-1.5">
                <Label>Priority</Label>
                <select className={selectClass} {...editForm.register("priority")}>
                  {Object.values(TicketPriority).map((p) => (
                    <option key={p} value={p}>
                      {p.charAt(0).toUpperCase() + p.slice(1)}
                    </option>
                  ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <Label>Assigned To</Label>
                <select className={selectClass} {...editForm.register("assignedToId")}>
                  <option value="">Unassigned</option>
                  {usersData?.data.map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.name} ({u.role})
                    </option>
                  ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <Label>Description</Label>
                <Textarea rows={3} {...editForm.register("description")} />
              </div>
              <div className="space-y-1.5">
                <Label>Diagnosis</Label>
                <Textarea rows={3} {...editForm.register("diagnosis")} />
              </div>
              <div className="space-y-1.5">
                <Label>Resolution</Label>
                <Textarea rows={3} {...editForm.register("resolution")} />
              </div>
              <div className="space-y-1.5">
                <Label>Due Date</Label>
                <Input type="date" {...editForm.register("dueDate")} />
              </div>
              {updateMutation.error && (
                <p className="text-sm text-destructive">{updateMutation.error.message}</p>
              )}
              <div className="flex gap-2 pt-2">
                <Button type="submit" disabled={editForm.formState.isSubmitting}>
                  Save Changes
                </Button>
                <Button type="button" variant="outline" onClick={() => navigate(`/tickets/${id}`)}>
                  Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-lg">
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="icon" asChild>
          <Link to="/tickets">
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">New Ticket</h1>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Ticket Details</CardTitle>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={createForm.handleSubmit((v) => {
              const body = {
                ...v,
                assignedToId: v.assignedToId || undefined,
                dueDate: v.dueDate ? new Date(v.dueDate).toISOString() : undefined,
              };
              return createMutation.mutateAsync(body);
            })}
            className="space-y-4"
          >
            <div className="space-y-1.5">
              <Label>Customer *</Label>
              {prefilledCustomerId ? (
                <>
                  <input type="hidden" {...createForm.register("customerId")} />
                  <p className="text-sm py-1">
                    {prefilledCustomer?.data.name ?? prefilledCustomerId}
                  </p>
                </>
              ) : (
                <select className={selectClass} {...createForm.register("customerId")}>
                  <option value="">Select a customer...</option>
                  {customersData?.data.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              )}
              {createForm.formState.errors.customerId && (
                <p className="text-xs text-destructive">
                  {createForm.formState.errors.customerId.message}
                </p>
              )}
            </div>
            <div className="space-y-1.5">
              <Label>Summary *</Label>
              <Input {...createForm.register("summary")} />
              {createForm.formState.errors.summary && (
                <p className="text-xs text-destructive">
                  {createForm.formState.errors.summary.message}
                </p>
              )}
            </div>
            <div className="space-y-1.5">
              <Label>Priority</Label>
              <select className={selectClass} {...createForm.register("priority")}>
                {Object.values(TicketPriority).map((p) => (
                  <option key={p} value={p}>
                    {p.charAt(0).toUpperCase() + p.slice(1)}
                  </option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <Label>Assigned To</Label>
              <select className={selectClass} {...createForm.register("assignedToId")}>
                <option value="">Unassigned</option>
                {usersData?.data.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.name} ({u.role})
                  </option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <Label>Description</Label>
              <Textarea rows={3} {...createForm.register("description")} />
            </div>
            <div className="space-y-1.5">
              <Label>Due Date</Label>
              <Input type="date" {...createForm.register("dueDate")} />
            </div>
            {createMutation.error && (
              <p className="text-sm text-destructive">{createMutation.error.message}</p>
            )}
            <div className="flex gap-2 pt-2">
              <Button type="submit" disabled={createForm.formState.isSubmitting}>
                Create Ticket
              </Button>
              <Button type="button" variant="outline" onClick={() => navigate("/tickets")}>
                Cancel
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
