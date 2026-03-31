import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { toast } from "sonner";
import { settingsApi, type AppSettings } from "@/api/settings";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export function BusinessSettingsPage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [isSaving, setIsSaving] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ["settings"],
    queryFn: () => settingsApi.getSettings(),
  });

  const mutation = useMutation({
    mutationFn: (updates: Partial<AppSettings>) => settingsApi.updateSettings(updates),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["settings"] });
      toast.success("Settings saved");
      setIsSaving(false);
    },
    onError: (err: Error) => {
      toast.error(err.message);
      setIsSaving(false);
    },
  });

  const settings = data?.data || {};

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setIsSaving(true);

    const formData = new FormData(e.currentTarget);
    const updates: Partial<AppSettings> = {};

    const fields = [
      "business_name",
      "business_abn",
      "business_address",
      "business_phone",
      "business_email",
      "gst_rate",
      "invoice_notes",
    ];

    fields.forEach((field) => {
      const value = formData.get(field) as string;
      if (value !== undefined) {
        updates[field as keyof AppSettings] = value;
      }
    });

    mutation.mutate(updates);
  };

  if (isLoading) return <div className="p-6">Loading...</div>;

  return (
    <div className="p-6 max-w-2xl">
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="icon" asChild>
          <Link to="/settings">
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">Business Settings</h1>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Business Details</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label htmlFor="business_name">Business Name</Label>
                <Input
                  id="business_name"
                  name="business_name"
                  defaultValue={settings.business_name || ""}
                  placeholder="Your business name"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="business_abn">ABN</Label>
                <Input
                  id="business_abn"
                  name="business_abn"
                  defaultValue={settings.business_abn || ""}
                  placeholder="Australian Business Number"
                />
              </div>
            </div>

            <div className="space-y-1">
              <Label htmlFor="business_address">Address</Label>
              <Input
                id="business_address"
                name="business_address"
                defaultValue={settings.business_address || ""}
                placeholder="Business address"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label htmlFor="business_phone">Phone</Label>
                <Input
                  id="business_phone"
                  name="business_phone"
                  defaultValue={settings.business_phone || ""}
                  placeholder="Business phone number"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="business_email">Email</Label>
                <Input
                  id="business_email"
                  name="business_email"
                  type="email"
                  defaultValue={settings.business_email || ""}
                  placeholder="Business email"
                />
              </div>
            </div>

            <div className="pt-4 border-t">
              <h3 className="font-semibold mb-4">Tax & Invoice Settings</h3>
              <div className="space-y-4">
                <div className="space-y-1">
                  <Label htmlFor="gst_rate">GST Rate (%)</Label>
                  <Input
                    id="gst_rate"
                    name="gst_rate"
                    type="number"
                    step="0.01"
                    defaultValue={settings.gst_rate || ""}
                    placeholder="e.g. 10.00"
                  />
                </div>

                <div className="space-y-1">
                  <Label htmlFor="invoice_notes">Default Invoice Notes</Label>
                  <Textarea
                    id="invoice_notes"
                    name="invoice_notes"
                    defaultValue={settings.invoice_notes || ""}
                    placeholder="Notes to appear on invoices by default"
                    rows={3}
                  />
                </div>
              </div>
            </div>

            {mutation.error && (
              <p className="text-sm text-destructive">{mutation.error.message}</p>
            )}

            <div className="flex gap-2 pt-4">
              <Button type="submit" disabled={isSaving || mutation.isPending}>
                Save Settings
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => navigate("/settings")}
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
