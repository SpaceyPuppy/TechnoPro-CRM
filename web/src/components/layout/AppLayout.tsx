import { Link, NavLink, Outlet, useNavigate } from "react-router-dom";
import { Users, Ticket, LayoutDashboard, LogOut, Package, FileText, Settings, Building2 } from "lucide-react";
import { useAuthStore, useRole } from "@/store/authStore";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";

export function AppLayout() {
  const { user, clearAuth } = useAuthStore();
  const { canManage } = useRole();
  const navigate = useNavigate();

  function handleLogout() {
    clearAuth();
    navigate("/login");
  }

  const navLinkClass = ({ isActive }: { isActive: boolean }) =>
    `flex items-center gap-2 px-3 py-2 rounded-md text-sm transition-colors ${
      isActive
        ? "bg-accent text-accent-foreground font-medium"
        : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
    }`;

  return (
    <div className="flex h-screen bg-background">
      <aside className="w-56 flex flex-col border-r bg-card">
        <div className="p-4">
          <Link to="/" className="text-lg font-bold tracking-tight">
            <span className="text-primary">Techno</span>Pro
          </Link>
          <p className="text-xs text-muted-foreground mt-0.5">CRM</p>
        </div>
        <Separator />
        <nav className="flex-1 p-2 space-y-1">
          <NavLink to="/" end className={navLinkClass}>
            <LayoutDashboard size={16} />
            Dashboard
          </NavLink>
          <NavLink to="/customers" className={navLinkClass}>
            <Users size={16} />
            Customers
          </NavLink>
          <NavLink to="/tickets" className={navLinkClass}>
            <Ticket size={16} />
            Tickets
          </NavLink>
          <NavLink to="/invoices" className={navLinkClass}>
            <FileText size={16} />
            Invoices
          </NavLink>
          <NavLink to="/inventory" className={navLinkClass}>
            <Package size={16} />
            Inventory
          </NavLink>
          <NavLink to="/suppliers" className={navLinkClass}>
            <Building2 size={16} />
            Suppliers
          </NavLink>
          {canManage && (
            <NavLink to="/settings" className={navLinkClass}>
              <Settings size={16} />
              Settings
            </NavLink>
          )}
        </nav>
        <Separator />
        <div className="p-3 space-y-1">
          <p className="text-xs font-medium px-2 truncate">{user?.name}</p>
          <p className="text-xs text-muted-foreground px-2 truncate capitalize">{user?.role}</p>
          <Button
            variant="ghost"
            size="sm"
            className="w-full justify-start gap-2 text-muted-foreground mt-1"
            onClick={handleLogout}
          >
            <LogOut size={14} />
            Sign out
          </Button>
        </div>
      </aside>
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
}
