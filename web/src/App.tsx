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
import { InvoicesPage } from "@/pages/invoices/InvoicesPage";
import { InvoiceDetailPage } from "@/pages/invoices/InvoiceDetailPage";
import { InvoiceCreatePage } from "@/pages/invoices/InvoiceCreatePage";

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
            <Route path="invoices" element={<InvoicesPage />} />
            <Route path="invoices/new" element={<InvoiceCreatePage />} />
            <Route path="invoices/:id" element={<InvoiceDetailPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
