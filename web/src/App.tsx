import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "sonner";
import { queryClient } from "@/lib/queryClient";
import { ProtectedRoute } from "@/components/layout/ProtectedRoute";
import { AppLayout } from "@/components/layout/AppLayout";
import { LoginPage } from "@/pages/auth/LoginPage";
import { DashboardPage } from "@/pages/DashboardPage";
import { CustomersPage } from "@/pages/customers/CustomersPage";
import { CustomerDetailPage } from "@/pages/customers/CustomerDetailPage";
import { CustomerFormPage } from "@/pages/customers/CustomerFormPage";
import { TicketsPage } from "@/pages/tickets/TicketsPage";
import { TicketDetailPage } from "@/pages/tickets/TicketDetailPage";
import { TicketFormPage } from "@/pages/tickets/TicketFormPage";
import { InventoryPage } from "@/pages/inventory/InventoryPage";
import { InventoryFormPage } from "@/pages/inventory/InventoryFormPage";
import { FinancePage } from "@/pages/invoices/FinancePage";
import { InvoiceDetailPage } from "@/pages/invoices/InvoiceDetailPage";
import { InvoiceCreatePage } from "@/pages/invoices/InvoiceCreatePage";
import { SettingsPage } from "@/pages/settings/SettingsPage";
import { BusinessSettingsPage } from "@/pages/settings/BusinessSettingsPage";
import { DeviceModelsPage } from "@/pages/settings/DeviceModelsPage";

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Toaster richColors position="top-right" />
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            element={
              <ProtectedRoute>
                <AppLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="customers" element={<CustomersPage />} />
            <Route path="customers/new" element={<CustomerFormPage />} />
            <Route path="customers/:id" element={<CustomerDetailPage />} />
            <Route path="customers/:id/edit" element={<CustomerFormPage />} />
            <Route path="tickets" element={<TicketsPage />} />
            <Route path="tickets/new" element={<TicketFormPage />} />
            <Route path="tickets/:id" element={<TicketDetailPage />} />
            <Route path="tickets/:id/edit" element={<TicketFormPage />} />
            <Route path="inventory" element={<InventoryPage />} />
            <Route path="inventory/new" element={<InventoryFormPage />} />
            <Route path="inventory/:id/edit" element={<InventoryFormPage />} />
            <Route path="invoices" element={<FinancePage />} />
            <Route path="invoices/new" element={<InvoiceCreatePage />} />
            <Route path="invoices/:id" element={<InvoiceDetailPage />} />
            <Route path="quotes/new" element={<InvoiceCreatePage />} />
            <Route path="quotes/:id" element={<InvoiceDetailPage />} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="settings/business" element={<BusinessSettingsPage />} />
            <Route path="settings/device-models" element={<DeviceModelsPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
