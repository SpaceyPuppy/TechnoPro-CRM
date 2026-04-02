import { useState, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useForm, useFieldArray } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ArrowLeft, Plus, Trash, Search, Package } from "lucide-react";
import { purchaseOrdersApi } from "@/api/purchaseOrders";
import { suppliersApi } from "@/api/suppliers";
import { inventoryApi } from "@/api/inventory";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { TableSkeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";

const poItemSchema = z.object({
  inventoryItemId: z.string().optional(),
  description: z.string().optional(),
  name: z.string().optional(), // UI placeholder for existing items
  quantity: z.number().min(1),
  unitCost: z.string().regex(/^\d+(\.\d{1,2})?$/, "Must be a valid price"),
}).refine(data => data.inventoryItemId || data.description, {
  message: "Either an inventory item or a description is required",
  path: ["description"],
});

const poFormSchema = z.object({
  supplierId: z.string().min(1, "Please select a supplier"),
  expectedDeliveryDate: z.string().optional(),
  notes: z.string().optional(),
  items: z.array(poItemSchema).min(1, "At least one item is required"),
});

type POFormValues = z.infer<typeof poFormSchema>;

export function PurchaseOrderCreatePage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [searchTerm, setSearchTerm] = useState("");

  const { data: suppliersData } = useQuery({
    queryKey: ["suppliers", { pageSize: 100 }],
    queryFn: () => suppliersApi.list({ pageSize: 100 }),
  });

  const { data: itemsData } = useQuery({
    queryKey: ["inventory-search", searchTerm],
    queryFn: () => inventoryApi.list({ search: searchTerm }),
    enabled: searchTerm.length > 1,
  });

  const {
    register,
    control,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<POFormValues>({
    resolver: zodResolver(poFormSchema),
    defaultValues: {
      supplierId: "",
      notes: "",
      items: [],
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "items",
  });

  const watchedItems = watch("items");
  const totalCost = useMemo(() => {
    return watchedItems.reduce((acc, item) => {
      const q = item.quantity || 0;
      const c = parseFloat(item.unitCost) || 0;
      return acc + q * c;
    }, 0);
  }, [watchedItems]);

  const mutation = useMutation({
    mutationFn: (data: POFormValues) => purchaseOrdersApi.create(data as any),
    onSuccess: () => {
      toast.success("Purchase Order created successfully");
      qc.invalidateQueries({ queryKey: ["purchase-orders"] });
      navigate("/purchase-orders");
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to create PO");
    },
  });

  const onSelectItem = (item: any) => {
    // Check if already added
    const existing = watchedItems.findIndex((i) => i.inventoryItemId === item.id);
    if (existing >= 0) {
      setValue(`items.${existing}.quantity`, watchedItems[existing].quantity + 1);
    } else {
      append({
        inventoryItemId: item.id,
        name: item.name,
        quantity: 1,
        unitCost: item.cost,
      });
    }
    setSearchTerm("");
  };

  const addOneOffItem = () => {
    append({
      description: "Custom Item",
      quantity: 1,
      unitCost: "0.00",
    });
  };

  return (
    <div className="p-6 max-w-5xl">
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="icon" asChild>
          <Link to="/purchase-orders">
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">New Purchase Order</h1>
      </div>

      <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="grid grid-cols-3 gap-6">
        {/* Left Column: PO Details */}
        <div className="col-span-1 space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>PO Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Supplier</Label>
                <select
                  {...register("supplierId")}
                  className="w-full text-sm border border-input rounded-md px-3 py-2 bg-background"
                >
                  <option value="">Select a supplier...</option>
                  {suppliersData?.data.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
                {errors.supplierId && <p className="text-xs text-destructive">{errors.supplierId.message}</p>}
              </div>

              <div className="space-y-2">
                <Label>Expected Delivery</Label>
                <Input type="date" {...register("expectedDeliveryDate")} />
              </div>

              <div className="space-y-2">
                <Label>Notes</Label>
                <textarea
                  {...register("notes")}
                  rows={3}
                  className="w-full text-sm border border-input rounded-md px-3 py-2 bg-background"
                  placeholder="Additional instructions..."
                />
              </div>
            </CardContent>
          </Card>

          <Card className="bg-muted/50">
            <CardContent className="p-6">
              <div className="flex justify-between items-center text-lg font-semibold">
                <span>Grand Total</span>
                <span className="text-primary">${totalCost.toFixed(2)}</span>
              </div>
              <Button type="submit" className="w-full mt-6" disabled={mutation.isPending}>
                {mutation.isPending ? "Creating..." : "Create Purchase Order"}
              </Button>
            </CardContent>
          </Card>
        </div>

        {/* Right Column: Items Builder */}
        <div className="col-span-2 space-y-6">
          {/* Item Search */}
          <Card>
            <CardContent className="p-4 space-y-4">
              <div className="relative">
                <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search inventory to add..."
                  className="pl-9"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>

              {searchTerm.length > 1 && itemsData && (
                <div className="border rounded-md divide-y overflow-hidden">
                  {itemsData.data.length === 0 && <div className="p-3 text-sm text-muted-foreground">No items found.</div>}
                  {itemsData.data.slice(0, 5).map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      className="w-full text-left p-3 hover:bg-muted text-sm flex justify-between"
                      onClick={() => onSelectItem(item)}
                    >
                      <span>{item.name} <span className="text-xs text-muted-foreground">({item.sku})</span></span>
                      <span className="text-muted-foreground font-mono">${item.cost}</span>
                    </button>
                  ))}
                </div>
              )}

              <Button type="button" variant="outline" size="sm" className="w-full" onClick={addOneOffItem}>
                <Plus size={14} className="mr-2" /> Add One-off Item (Custom)
              </Button>
            </CardContent>
          </Card>

          {/* Items List */}
          <div className="space-y-3">
            {fields.length === 0 && (
              <div className="p-12 text-center text-muted-foreground border rounded-lg bg-card border-dashed">
                <Package className="mx-auto mb-2 opacity-20" size={48} />
                <p>No items added yet. Search inventory or add a one-off row.</p>
              </div>
            )}
            {fields.map((field, index) => (
              <Card key={field.id}>
                <CardContent className="p-4 flex gap-4 items-end">
                  <div className="flex-1 space-y-2">
                    <Label className="text-xs uppercase text-muted-foreground font-bold tracking-wider">
                      {watchedItems[index]?.inventoryItemId ? "Inventory Item" : "Description (One-off)"}
                    </Label>
                    {watchedItems[index]?.inventoryItemId ? (
                      <div className="text-sm font-medium h-9 flex items-center bg-muted/30 px-3 rounded-md">
                        {watchedItems[index].name}
                      </div>
                    ) : (
                      <Input
                        {...register(`items.${index}.description`)}
                        placeholder="Enter item description..."
                      />
                    )}
                  </div>

                  <div className="w-24 space-y-2">
                    <Label className="text-xs uppercase text-muted-foreground font-bold tracking-wider">Qty</Label>
                    <Input
                      type="number"
                      {...register(`items.${index}.quantity`, { valueAsNumber: true })}
                      min={1}
                    />
                  </div>

                  <div className="w-32 space-y-2">
                    <Label className="text-xs uppercase text-muted-foreground font-bold tracking-wider">Unit Cost</Label>
                    <Input {...register(`items.${index}.unitCost`)} prefix="$" />
                  </div>

                  <div className="w-24 space-y-2 text-right">
                    <Label className="text-xs uppercase text-muted-foreground font-bold tracking-wider">Line Total</Label>
                    <div className="h-9 flex items-center justify-end text-sm font-semibold">
                      ${( (watchedItems[index]?.quantity || 0) * (parseFloat(watchedItems[index]?.unitCost) || 0) ).toFixed(2)}
                    </div>
                  </div>

                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    className="text-destructive hover:text-destructive hover:bg-destructive/10"
                    onClick={() => remove(index)}
                  >
                    <Trash size={16} />
                  </Button>
                </CardContent>
              </Card>
            ))}
          </div>
          {errors.items && <p className="text-sm text-destructive">{errors.items.message}</p>}
        </div>
      </form>
    </div>
  );
}
