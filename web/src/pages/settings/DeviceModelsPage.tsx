import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Plus, Edit, Trash2, X } from "lucide-react";
import { toast } from "sonner";
import { deviceModelsApi } from "@/api/deviceModels";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";

export function DeviceModelsPage() {
  const qc = useQueryClient();
  const [showDialog, setShowDialog] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({ manufacturer: "", name: "", sortOrder: "0" });

  const { data, isLoading } = useQuery({
    queryKey: ["device-models"],
    queryFn: () => deviceModelsApi.list(),
  });

  const createMutation = useMutation({
    mutationFn: () =>
      deviceModelsApi.create({
        manufacturer: formData.manufacturer.trim(),
        name: formData.name.trim(),
        sortOrder: parseInt(formData.sortOrder, 10),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["device-models"] });
      toast.success("Device model added");
      resetForm();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const updateMutation = useMutation({
    mutationFn: () =>
      deviceModelsApi.update(editingId!, {
        manufacturer: formData.manufacturer.trim(),
        name: formData.name.trim(),
        sortOrder: parseInt(formData.sortOrder, 10),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["device-models"] });
      toast.success("Device model updated");
      resetForm();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deviceModelsApi.delete(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["device-models"] });
      toast.success("Device model deleted");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const resetForm = () => {
    setFormData({ manufacturer: "", name: "", sortOrder: "0" });
    setEditingId(null);
    setShowDialog(false);
  };

  const handleAdd = () => {
    resetForm();
    setShowDialog(true);
  };

  const handleEdit = (item: any) => {
    setFormData({
      manufacturer: item.manufacturer,
      name: item.name,
      sortOrder: item.sortOrder?.toString() || "0",
    });
    setEditingId(item.id);
    setShowDialog(true);
  };

  const handleDelete = (id: string, name: string) => {
    if (confirm(`Delete ${name}?`)) {
      deleteMutation.mutate(id);
    }
  };

  const handleSubmit = () => {
    if (!formData.manufacturer.trim() || !formData.name.trim()) {
      toast.error("Manufacturer and model name are required");
      return;
    }
    if (editingId) {
      updateMutation.mutate();
    } else {
      createMutation.mutate();
    }
  };

  const models = data?.data || [];
  const grouped = models.reduce(
    (acc, model) => {
      const mfr = model.manufacturer;
      if (!acc[mfr]) acc[mfr] = [];
      acc[mfr].push(model);
      return acc;
    },
    {} as Record<string, typeof models>,
  );

  if (isLoading) return <div className="p-6">Loading...</div>;

  return (
    <div className="p-6 max-w-3xl">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link to="/settings">
              <ArrowLeft size={16} />
            </Link>
          </Button>
          <h1 className="text-2xl font-semibold">Device Models</h1>
        </div>
        <Button onClick={handleAdd} size="sm">
          <Plus size={16} />
          Add Model
        </Button>
      </div>

      <Card className="p-6">
        {models.length === 0 ? (
          <p className="text-muted-foreground">No device models yet. Add your first one!</p>
        ) : (
          <div className="space-y-4">
            {Object.entries(grouped).map(([manufacturer, items]) => (
              <div key={manufacturer}>
                <p className="text-sm font-semibold text-primary mb-2">{manufacturer}</p>
                <div className="space-y-2 ml-4">
                  {items.map((item) => (
                    <div
                      key={item.id}
                      className="flex items-center justify-between p-3 bg-muted/30 rounded-md"
                    >
                      <span className="text-sm">{item.name}</span>
                      <div className="flex gap-2">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8"
                          onClick={() => handleEdit(item)}
                        >
                          <Edit size={14} />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 text-destructive hover:text-destructive"
                          onClick={() => handleDelete(item.id, item.name)}
                          disabled={deleteMutation.isPending}
                        >
                          <Trash2 size={14} />
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      {/* Form Modal */}
      {showDialog && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-sm p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">{editingId ? "Edit" : "Add"} Device Model</h2>
              <Button
                variant="ghost"
                size="icon"
                className="h-6 w-6"
                onClick={resetForm}
              >
                <X size={16} />
              </Button>
            </div>
            <div className="space-y-4">
              <div className="space-y-1">
                <Label htmlFor="manufacturer">Manufacturer *</Label>
                <Input
                  id="manufacturer"
                  value={formData.manufacturer}
                  onChange={(e) => setFormData({ ...formData, manufacturer: e.target.value })}
                  placeholder="e.g. Apple"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="name">Model Name *</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g. iPhone 15 Pro"
                />
              </div>
            </div>
            <div className="flex gap-2 mt-6">
              <Button variant="outline" onClick={resetForm} className="flex-1">
                Cancel
              </Button>
              <Button
                onClick={handleSubmit}
                disabled={createMutation.isPending || updateMutation.isPending}
                className="flex-1"
              >
                {editingId ? "Update" : "Add"}
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
