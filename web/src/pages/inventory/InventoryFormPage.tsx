import { useEffect } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Trash2 } from "lucide-react";
import { inventoryApi } from "@/api/inventory";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const moneyPattern = /^\d+\.\d{2}$/;

const schema = z.object({
  sku: z.string().min(1, "SKU is required").max(100),
  name: z.string().min(1, "Name is required").max(255),
  description: z.string().max(5000).optional(),
  price: z.string().regex(moneyPattern, "Format: 0.00"),
  cost: z.string().regex(moneyPattern, "Format: 0.00").optional(),
  barcode: z.string().max(255).optional(),
  trackStock: z.boolean(),
  stockQty: z.number().int().min(0).optional(),
});

type FormValues = z.infer<typeof schema>;

export function InventoryFormPage() {
  const { id } = useParams<{ id: string }>();
  const isEdit = !!id;
  const navigate = useNavigate();
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["inventory", id],
    queryFn: () => inventoryApi.get(id!),
    enabled: isEdit,
  });

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { trackStock: false, price: "0.00", cost: "0.00" },
  });

  const trackStock = watch("trackStock");

  useEffect(() => {
    if (data) {
      const item = data.data;
      reset({
        sku: item.sku,
        name: item.name,
        description: item.description ?? "",
        price: item.price,
        cost: item.cost,
        barcode: item.barcode ?? "",
        trackStock: item.stockQty !== null,
        stockQty: item.stockQty ?? 0,
      });
    }
  }, [data, reset]);

  const createMutation = useMutation({
    mutationFn: (values: FormValues) =>
      inventoryApi.create({
        sku: values.sku,
        name: values.name,
        description: values.description || undefined,
        price: values.price,
        cost: values.cost,
        barcode: values.barcode || undefined,
        stockQty: values.trackStock ? (values.stockQty ?? 0) : null,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["inventory"] });
      navigate("/inventory");
    },
  });

  const updateMutation = useMutation({
    mutationFn: (values: FormValues) =>
      inventoryApi.update(id!, {
        sku: values.sku,
        name: values.name,
        description: values.description || undefined,
        price: values.price,
        cost: values.cost,
        barcode: values.barcode || undefined,
        stockQty: values.trackStock ? (values.stockQty ?? 0) : null,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["inventory"] });
      navigate("/inventory");
    },
  });

  const deleteMutation = useMutation({
    mutationFn: () => inventoryApi.delete(id!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["inventory"] });
      navigate("/inventory");
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
          <Link to="/inventory">
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold flex-1">
          {isEdit ? "Edit Item" : "New Inventory Item"}
        </h1>
        {isEdit && (
          <Button
            variant="destructive"
            size="sm"
            disabled={deleteMutation.isPending}
            onClick={() => {
              if (confirm("Delete this item? This cannot be undone.")) deleteMutation.mutate();
            }}
          >
            <Trash2 size={14} />
            Delete
          </Button>
        )}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Item Details</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="sku">SKU *</Label>
                <Input id="sku" {...register("sku")} />
                {errors.sku && <p className="text-xs text-destructive">{errors.sku.message}</p>}
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="barcode">Barcode</Label>
                <Input id="barcode" {...register("barcode")} />
              </div>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="name">Name *</Label>
              <Input id="name" {...register("name")} />
              {errors.name && <p className="text-xs text-destructive">{errors.name.message}</p>}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="description">Description</Label>
              <Textarea id="description" rows={2} {...register("description")} />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="price">Sell Price * ($)</Label>
                <Input id="price" {...register("price")} placeholder="0.00" />
                {errors.price && (
                  <p className="text-xs text-destructive">{errors.price.message}</p>
                )}
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="cost">Cost Price ($)</Label>
                <Input id="cost" {...register("cost")} placeholder="0.00" />
                {errors.cost && <p className="text-xs text-destructive">{errors.cost.message}</p>}
              </div>
            </div>

            <div className="space-y-3">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  className="rounded border-input"
                  {...register("trackStock")}
                  onChange={(e) => {
                    setValue("trackStock", e.target.checked);
                    if (!e.target.checked) setValue("stockQty", undefined);
                  }}
                />
                <span className="text-sm font-medium">Track stock quantity</span>
              </label>
              {trackStock && (
                <div className="space-y-1.5 ml-6">
                  <Label htmlFor="stockQty">Quantity on hand</Label>
                  <Input
                    id="stockQty"
                    type="number"
                    min={0}
                    className="w-32"
                    {...register("stockQty", { valueAsNumber: true })}
                  />
                </div>
              )}
            </div>

            {mutationError && (
              <p className="text-sm text-destructive">{mutationError.message}</p>
            )}

            <div className="flex gap-2 pt-2">
              <Button type="submit" disabled={isSubmitting}>
                {isEdit ? "Save Changes" : "Create Item"}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => navigate("/inventory")}
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
