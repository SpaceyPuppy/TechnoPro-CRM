import { useEffect } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { suppliersApi } from "@/api/suppliers";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const schema = z.object({
  name: z.string().min(1, "Name is required").max(255),
  contactName: z.string().max(255).optional(),
  email: z.string().email("Invalid email").max(255).or(z.literal("")).optional(),
  phone: z.string().max(50).optional(),
  accountNumber: z.string().max(100).optional(),
  leadTimeDays: z.coerce.number().min(0).optional().or(z.literal("")),
  notes: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export function SupplierFormPage() {
  const { id } = useParams<{ id: string }>();
  const isEdit = !!id;
  const navigate = useNavigate();
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["suppliers", id],
    queryFn: () => suppliersApi.get(id!),
    enabled: isEdit,
  });

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  useEffect(() => {
    if (data) {
      const s = data.data;
      reset({
        name: s.name,
        contactName: s.contactName ?? "",
        email: s.email ?? "",
        phone: s.phone ?? "",
        accountNumber: s.accountNumber ?? "",
        leadTimeDays: s.leadTimeDays ?? "",
        notes: s.notes ?? "",
      });
    }
  }, [data, reset]);

  const createMutation = useMutation({
    mutationFn: suppliersApi.create,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["suppliers"] });
      navigate("/suppliers");
    },
  });

  const updateMutation = useMutation({
    mutationFn: (values: FormValues) => {
      const payload = {
        ...values,
        leadTimeDays: values.leadTimeDays === "" ? undefined : (values.leadTimeDays as number),
      };
      return suppliersApi.update(id!, payload);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["suppliers"] });
      navigate("/suppliers");
    },
  });

  async function onSubmit(values: FormValues) {
    const payload = {
      ...values,
      leadTimeDays: values.leadTimeDays === "" ? undefined : (values.leadTimeDays as number),
    };
    if (isEdit) {
      await updateMutation.mutateAsync(payload);
    } else {
      await createMutation.mutateAsync(payload);
    }
  }

  const mutationError = createMutation.error ?? updateMutation.error;

  if (isEdit && isLoading) {
    return <div className="p-6 text-sm text-muted-foreground">Loading...</div>;
  }

  return (
    <div className="p-6 max-w-lg">
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="icon" asChild>
          <Link to="/suppliers">
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">{isEdit ? "Edit Supplier" : "New Supplier"}</h1>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Supplier Details</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="name">Company Name *</Label>
              <Input id="name" {...register("name")} />
              {errors.name && <p className="text-xs text-destructive">{errors.name.message}</p>}
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="contactName">Contact Name</Label>
              <Input id="contactName" {...register("contactName")} />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" {...register("email")} />
                {errors.email && <p className="text-xs text-destructive">{errors.email.message}</p>}
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="phone">Phone</Label>
                <Input id="phone" type="tel" {...register("phone")} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="accountNumber">Account Number</Label>
                <Input id="accountNumber" {...register("accountNumber")} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="leadTimeDays">Lead Time (Days)</Label>
                <Input id="leadTimeDays" type="number" {...register("leadTimeDays")} />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="notes">Notes</Label>
              <Textarea id="notes" rows={3} {...register("notes")} />
            </div>
            {mutationError && (
              <p className="text-sm text-destructive">{(mutationError as Error).message}</p>
            )}
            <div className="flex gap-2 pt-2">
              <Button type="submit" disabled={isSubmitting}>
                {isEdit ? "Save Changes" : "Create Supplier"}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => navigate("/suppliers")}
              >
                Cancel
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
