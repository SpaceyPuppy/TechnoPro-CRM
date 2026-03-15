import { useEffect } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { customersApi } from "@/api/customers";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const schema = z.object({
  name: z.string().min(1, "Name is required").max(255),
  email: z.string().email("Invalid email").max(255).or(z.literal("")).optional(),
  phone: z.string().max(50).optional(),
  notes: z.string().max(5000).optional(),
});

type FormValues = z.infer<typeof schema>;

export function CustomerFormPage() {
  const { id } = useParams<{ id: string }>();
  const isEdit = !!id;
  const navigate = useNavigate();
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["customers", id],
    queryFn: () => customersApi.get(id!),
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
      const c = data.data;
      reset({
        name: c.name,
        email: c.email ?? "",
        phone: c.phone ?? "",
        notes: c.notes ?? "",
      });
    }
  }, [data, reset]);

  const createMutation = useMutation({
    mutationFn: customersApi.create,
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ["customers"] });
      navigate(`/customers/${res.data.id}`);
    },
  });

  const updateMutation = useMutation({
    mutationFn: (values: FormValues) => customersApi.update(id!, values),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["customers", id] });
      navigate(`/customers/${id}`);
    },
  });

  async function onSubmit(values: FormValues) {
    if (isEdit) {
      await updateMutation.mutateAsync(values);
    } else {
      await createMutation.mutateAsync(values);
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
          <Link to={isEdit ? `/customers/${id}` : "/customers"}>
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">{isEdit ? "Edit Customer" : "New Customer"}</h1>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Customer Details</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="name">Name *</Label>
              <Input id="name" {...register("name")} />
              {errors.name && <p className="text-xs text-destructive">{errors.name.message}</p>}
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="email">Email</Label>
              <Input id="email" type="email" {...register("email")} />
              {errors.email && <p className="text-xs text-destructive">{errors.email.message}</p>}
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="phone">Phone</Label>
              <Input id="phone" type="tel" {...register("phone")} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="notes">Notes</Label>
              <Textarea id="notes" rows={3} {...register("notes")} />
            </div>
            {mutationError && (
              <p className="text-sm text-destructive">{mutationError.message}</p>
            )}
            <div className="flex gap-2 pt-2">
              <Button type="submit" disabled={isSubmitting}>
                {isEdit ? "Save Changes" : "Create Customer"}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => navigate(isEdit ? `/customers/${id}` : "/customers")}
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
