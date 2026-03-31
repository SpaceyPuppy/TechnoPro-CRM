import { Link } from "react-router-dom";
import { ChevronRight, Settings as SettingsIcon, Box } from "lucide-react";
import { Card } from "@/components/ui/card";

export function SettingsPage() {
  const settingsSections = [
    {
      icon: SettingsIcon,
      title: "Business Settings",
      description: "Company name, ABN, address, and GST configuration",
      href: "/settings/business",
    },
    {
      icon: Box,
      title: "Device Models",
      description: "Manage phone and tablet models used in repairs",
      href: "/settings/device-models",
    },
  ];

  return (
    <div className="p-6 max-w-2xl">
      <div className="mb-8">
        <h1 className="text-3xl font-semibold">Settings</h1>
        <p className="text-muted-foreground mt-1">Configure your business and system preferences</p>
      </div>

      <div className="grid grid-cols-1 gap-4">
        {settingsSections.map((section) => {
          const Icon = section.icon;
          return (
            <Link key={section.href} to={section.href}>
              <Card className="p-6 hover:bg-accent transition-colors cursor-pointer group">
                <div className="flex items-start justify-between">
                  <div className="flex items-start gap-4">
                    <div className="p-2 bg-muted rounded-lg group-hover:bg-primary/10 transition-colors">
                      <Icon size={24} className="text-primary" />
                    </div>
                    <div>
                      <h3 className="font-semibold text-lg">{section.title}</h3>
                      <p className="text-sm text-muted-foreground">{section.description}</p>
                    </div>
                  </div>
                  <ChevronRight size={20} className="text-muted-foreground group-hover:text-primary transition-colors" />
                </div>
              </Card>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
